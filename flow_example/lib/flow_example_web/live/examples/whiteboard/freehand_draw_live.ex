defmodule FlowExampleWeb.Examples.Whiteboard.FreehandDrawLive do
  @moduledoc """
  Freehand Draw: draw strokes on the canvas and keep them as nodes.

  While the pen is active, a tool overlay (`phx-update="ignore"`) above the
  flow captures the pointer. Its colocated hook records the stroke in flow
  coordinates (`liveflow.screenToFlowPosition/1`, using coalesced pointer
  events) and previews it with the final smoothing: quadratic curves through
  the midpoints of consecutive points. On release the raw points are pushed as
  `add_stroke`.

  The LiveView simplifies them with Ramer–Douglas–Peucker, computes the
  bounding box and adds a resizable `:freehand` node at its position. The node
  renders an SVG path relative to its box: `viewBox` keeps the original box
  size and `preserveAspectRatio="none"` stretches the drawing when the node is
  resized, while `vector-effect="non-scaling-stroke"` keeps the line width.
  """
  use FlowExampleWeb, :live_view

  alias FlowExample.Samples
  alias FlowExampleWeb.{Examples, FlowEvents, FlowNodes}
  alias LiveFlow.{Edge, History, Node, State}
  alias LiveFlow.Components.NodeResizer

  @flow_id "freehand-flow"

  @tools [
    %{id: "select", label: "Select", key: "V", icon: "hero-cursor-arrow-rays"},
    %{id: "draw", label: "Draw", key: "D", icon: "hero-pencil"}
  ]
  @tool_ids Enum.map(@tools, & &1.id)

  # name, stroke (inside the flow), swatch (sidebar). "ink" follows the flow
  # theme's text color.
  @colors [
    {"ink", "var(--lf-text-primary)", "var(--color-base-content)"},
    {"rose", "#f43f5e", "#f43f5e"},
    {"amber", "#f59e0b", "#f59e0b"},
    {"emerald", "#10b981", "#10b981"},
    {"sky", "#0ea5e9", "#0ea5e9"},
    {"violet", "#8b5cf6", "#8b5cf6"}
  ]

  @max_points 5000
  @min_width 1
  @max_width 16

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title)
     |> assign(flow_id: @flow_id, tools: @tools, tool: "draw", colors: @colors)
     |> assign(color: "ink", width: 4, next_id: 3, last_stroke: nil)
     |> assign(:pen_form, pen_form(4))
     |> FlowEvents.assign_flow(build_flow())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      #freehand-overlay {
        z-index: 4;
        pointer-events: none;
        touch-action: none;
      }
      #freehand-overlay[data-tool="draw"] {
        pointer-events: auto;
        cursor: none;
      }
      #freehand-overlay.is-passthrough {
        pointer-events: none;
      }
      #freehand-overlay .freehand-preview {
        position: absolute;
        inset: 0;
        width: 100%;
        height: 100%;
        overflow: visible;
        pointer-events: none;
      }
      #freehand-overlay .freehand-preview path {
        fill: none;
        stroke-linecap: round;
        stroke-linejoin: round;
      }
      #freehand-overlay .pen-cursor {
        position: absolute;
        top: 0;
        left: 0;
        border-radius: 9999px;
        box-shadow:
          0 0 0 1.5px rgb(255 255 255 / 0.85),
          0 1px 4px rgb(0 0 0 / 0.25);
        opacity: 0;
        pointer-events: none;
        transition: opacity 120ms ease;
      }
      #freehand-overlay[data-tool="draw"]:not(.is-passthrough) .pen-cursor[data-visible] {
        opacity: 1;
      }
      #freehand-flow .lf-node[data-node-type="freehand"] {
        background: transparent;
        border: 0;
        border-radius: 2px;
        box-shadow: none;
        pointer-events: none;
      }
      #freehand-flow .lf-node[data-node-type="freehand"] > .lf-node-content {
        width: 100%;
        height: 100%;
        min-width: 0;
        padding: 0;
      }
      #freehand-flow .lf-node[data-node-type="freehand"].lf-node-selected {
        pointer-events: auto;
        outline: 1.5px dashed var(--lf-node-selected-border);
        outline-offset: 4px;
      }
      #freehand-flow .freehand-svg {
        display: block;
        width: 100%;
        height: 100%;
        overflow: visible;
      }
      #freehand-flow .freehand-hit {
        fill: none;
        stroke: transparent;
        stroke-linecap: round;
        stroke-linejoin: round;
        pointer-events: stroke;
      }
      #freehand-flow .freehand-ink {
        fill: none;
        stroke-linecap: round;
        stroke-linejoin: round;
        pointer-events: none;
        transition: filter 0.15s ease;
      }
      #freehand-flow .lf-node[data-node-type="freehand"]:hover .freehand-ink {
        filter: drop-shadow(0 0 3px color-mix(in oklab, var(--lf-node-selected-border) 55%, transparent));
      }
      #freehand-toolbar-hint {
        animation: freehand-hint-in 180ms ease-out;
      }
      @keyframes freehand-hint-in {
        from {
          opacity: 0;
          translate: 0 -4px;
        }
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <:actions>
        <.action
          id="freehand-undo"
          icon="hero-arrow-uturn-left"
          phx-click="undo"
          disabled={not History.can_undo?(@history)}
        >
          Undo
        </.action>
        <.action id="freehand-clear" icon="hero-trash" phx-click="clear_drawings">
          Clear drawings
        </.action>
      </:actions>

      <div id="freehand-canvas" class="relative h-full w-full">
        <.live_component
          module={LiveFlow.Components.Flow}
          id={@flow_id}
          flow={@flow}
          node_types={Map.put(FlowNodes.types(), :freehand, &freehand_node/1)}
          opts={
            %{
              background: :dots,
              controls: true,
              fit_view_on_init: true,
              fit_view_options: %{padding: 0.3, max_zoom: 1}
            }
          }
        />

        <div
          id="freehand-overlay"
          phx-hook=".FreehandDraw"
          phx-update="ignore"
          data-flow-id={@flow_id}
          data-tool={@tool}
          data-color={stroke_color(@color)}
          data-width={@width}
          class="absolute inset-0 select-none"
        />
        <script :type={Phoenix.LiveView.ColocatedHook} name=".FreehandDraw">
          // Freehand overlay. Points are recorded in flow coordinates
          // (liveflow.screenToFlowPosition, with coalesced pointer events for
          // smooth strokes) and the preview uses the same smoothing as the final
          // node: quadratic curves through the midpoints of consecutive points.
          // On release the raw points are pushed as "add_stroke"; the server
          // simplifies them and creates the node.
          const SVG_NS = "http://www.w3.org/2000/svg"
          const SHORTCUTS = {v: "select", d: "draw"}
          const MAX_POINTS = 5000

          const smoothPath = pts => {
            if (pts.length === 0) return ""
            const f = v => v.toFixed(1)
            const [x0, y0] = pts[0]
            const [lx, ly] = pts[pts.length - 1]
            let d = `M${f(x0)} ${f(y0)}`
            for (let i = 1; i < pts.length - 1; i++) {
              const [x1, y1] = pts[i]
              const [x2, y2] = pts[i + 1]
              d += `Q${f(x1)} ${f(y1)} ${f((x1 + x2) / 2)} ${f((y1 + y2) / 2)}`
            }
            return `${d}L${f(lx)} ${f(ly)}`
          }

          export default {
            mounted() {
              this.flowId = this.el.dataset.flowId
              this.svg = document.createElementNS(SVG_NS, "svg")
              this.svg.setAttribute("class", "freehand-preview")
              this.path = document.createElementNS(SVG_NS, "path")
              this.svg.append(this.path)
              this.cursor = document.createElement("div")
              this.cursor.className = "pen-cursor"
              this.el.append(this.svg, this.cursor)

              this.points = []
              this.pointerId = null
              this.frame = null

              this.listeners = []
              const on = (target, type, fn, options) => {
                target.addEventListener(type, fn, options)
                this.listeners.push([target, type, fn, options])
              }
              on(this.el, "pointerdown", e => this.start(e))
              on(this.el, "pointermove", e => this.move(e))
              on(this.el, "pointerup", e => this.finish(e))
              on(this.el, "pointercancel", () => this.cancel())
              on(this.el, "pointerleave", () => delete this.cursor.dataset.visible)
              on(this.el, "wheel", e => this.forwardWheel(e), {passive: false})
              on(this.el, "contextmenu", e => e.preventDefault())
              on(window, "keydown", e => this.onKeyDown(e))
              on(window, "keyup", e => {
                if (e.key === " ") this.el.classList.remove("is-passthrough")
              })
              on(window, "blur", () => {
                this.el.classList.remove("is-passthrough")
                this.cancel()
              })
            },

            updated() {
              if (!this.active()) this.cancel()
            },

            destroyed() {
              this.listeners.forEach(([target, type, fn, options]) => target.removeEventListener(type, fn, options))
              if (this.frame) cancelAnimationFrame(this.frame)
            },

            active() {
              return this.el.dataset.tool === "draw"
            },

            flow() {
              return document.getElementById(this.flowId)
            },

            api() {
              return this.flow()?.liveflow
            },

            // "ink" is a theme variable of the flow container, which the
            // overlay (a sibling) doesn't inherit: resolve it there
            color() {
              const color = this.el.dataset.color || "#334155"
              const match = color.match(/^var\((--[\w-]+)\)$/)
              if (!match || !this.flow()) return color
              return getComputedStyle(this.flow()).getPropertyValue(match[1]).trim() || "#334155"
            },

            width() {
              return Number(this.el.dataset.width) || 4
            },

            start(e) {
              const api = this.api()
              if (!this.active() || !api || e.button !== 0 || this.pointerId !== null) return
              e.preventDefault()
              const flow = this.flow()
              flow.focus({preventScroll: true})
              this.el.setPointerCapture(e.pointerId)
              this.pointerId = e.pointerId

              const flowRect = flow.getBoundingClientRect()
              const rect = this.el.getBoundingClientRect()
              this.offset = {x: flowRect.left - rect.left, y: flowRect.top - rect.top}
              this.path.style.stroke = this.color()
              this.points = []
              this.addPoint(api, e)
              this.render()
            },

            move(e) {
              if (!this.active()) return
              const api = this.api()
              if (!api) return
              const rect = this.el.getBoundingClientRect()
              const size = Math.max(4, this.width() * api.getViewport().zoom)
              Object.assign(this.cursor.style, {
                width: `${size}px`,
                height: `${size}px`,
                background: this.color(),
                transform: `translate(${e.clientX - rect.left - size / 2}px, ${e.clientY - rect.top - size / 2}px)`
              })
              this.cursor.dataset.visible = ""
              if (e.pointerId !== this.pointerId) return

              const events = e.getCoalescedEvents?.() || []
              for (const event of events.length ? events : [e]) this.addPoint(api, event)
              this.schedule()
            },

            addPoint(api, e) {
              if (this.points.length >= MAX_POINTS) return
              const point = api.screenToFlowPosition({x: e.clientX, y: e.clientY})
              const last = this.points[this.points.length - 1]
              // Skip points closer than 1 screen px to the previous one
              if (last && Math.hypot(point.x - last.x, point.y - last.y) * api.getViewport().zoom < 1) return
              this.points.push(point)
            },

            finish(e) {
              if (e.pointerId !== this.pointerId) return
              this.pointerId = null
              if (this.points.length === 0) return this.clear()
              const api = this.api()
              const round = v => Math.round(v * 100) / 100
              const points = this.points.map(p => [round(p.x), round(p.y)])
              const zoom = api ? api.getViewport().zoom : 1
              // The preview stays until the node is rendered
              this.pushEvent("add_stroke", {points, zoom}, () => {
                if (this.pointerId === null) this.clear()
              })
            },

            cancel() {
              if (this.pointerId !== null && this.el.hasPointerCapture(this.pointerId)) {
                this.el.releasePointerCapture(this.pointerId)
              }
              this.pointerId = null
              this.clear()
            },

            clear() {
              this.points = []
              this.path.removeAttribute("d")
            },

            schedule() {
              if (this.frame) return
              this.frame = requestAnimationFrame(() => {
                this.frame = null
                this.render()
              })
            },

            // Projected with the current viewport: the width is in flow units
            render() {
              const api = this.api()
              if (!api || this.points.length === 0) return
              const {x, y, zoom} = api.getViewport()
              const pts = this.points.map(p => [p.x * zoom + x + this.offset.x, p.y * zoom + y + this.offset.y])
              this.path.setAttribute("d", smoothPath(pts))
              this.path.style.strokeWidth = `${this.width() * zoom}px`
            },

            // The overlay sits above the flow: hand wheel events to the flow
            // container so zooming keeps working while the tool is active
            forwardWheel(e) {
              const flow = this.flow()
              if (!flow) return
              e.preventDefault()
              flow.dispatchEvent(new WheelEvent("wheel", {
                bubbles: true,
                cancelable: true,
                deltaX: e.deltaX,
                deltaY: e.deltaY,
                deltaZ: e.deltaZ,
                deltaMode: e.deltaMode,
                clientX: e.clientX,
                clientY: e.clientY,
                screenX: e.screenX,
                screenY: e.screenY,
                ctrlKey: e.ctrlKey,
                metaKey: e.metaKey,
                shiftKey: e.shiftKey,
                altKey: e.altKey
              }))
              if (this.points.length > 0) requestAnimationFrame(() => this.render())
            },

            onKeyDown(e) {
              if (e.target.closest?.("input, textarea, select, [contenteditable]")) return
              // Space lets the pointer through: Space + drag pans the flow
              if (e.key === " ") {
                if (this.pointerId === null) this.el.classList.add("is-passthrough")
                return
              }
              if (e.key === "Escape") {
                if (this.pointerId !== null) this.cancel()
                else if (this.active()) this.pushEvent("set_tool", {tool: "select"})
                return
              }
              if (e.repeat || e.metaKey || e.ctrlKey || e.altKey) return
              const tool = SHORTCUTS[(e.key || "").toLowerCase()]
              if (tool && tool !== this.el.dataset.tool) this.pushEvent("set_tool", {tool})
            }
          }
        </script>

        <.toolbar id="freehand-toolbar" flow_id={@flow_id} tools={@tools} tool={@tool}>
          <:hint :if={@tool == "draw"}>
            Draw anywhere · <b>Space</b> + drag pans · <b>V</b> to move or resize strokes
          </:hint>
        </.toolbar>
      </div>

      <:sidebar>
        <.option_group title="Pen">
          <div id="pen-colors" class="mb-3 flex flex-wrap items-center gap-2">
            <button
              :for={{name, _stroke, swatch} <- @colors}
              id={"pen-color-#{name}"}
              type="button"
              phx-click="set_color"
              phx-value-color={name}
              aria-label={"Color #{name}"}
              aria-pressed={to_string(@color == name)}
              title={name}
              class={[
                "size-7 rounded-full ring-offset-2 ring-offset-base-100 transition-transform duration-150 hover:scale-110 active:scale-95 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary",
                @color == name && "ring-2 ring-base-content/50"
              ]}
              style={"background: #{swatch}"}
            />
          </div>
          <.form for={@pen_form} id="pen-form" phx-change="set_width">
            <.range field={@pen_form[:width]} label="Stroke width" min="1" max="16" />
          </.form>
          <svg
            id="pen-preview"
            viewBox="0 0 240 40"
            class="mt-1 h-10 w-full rounded-lg bg-base-200/60"
            aria-hidden="true"
          >
            <path
              d="M14 26 Q 44 6 74 20 T 134 22 T 194 14 T 226 18"
              fill="none"
              stroke-linecap="round"
              stroke-linejoin="round"
              style={"stroke: #{swatch_color(@color)}; stroke-width: #{@width}px"}
            />
          </svg>
        </.option_group>

        <.option_group title="Last stroke">
          <div id="last-stroke">
            <%= if @last_stroke do %>
              <p class="flex items-baseline gap-2 font-mono text-sm">
                <span class="font-semibold">{@last_stroke.raw}</span>
                <span class="text-base-content/40">→</span>
                <span class="font-semibold text-primary">{@last_stroke.kept}</span>
                <span class="text-xs text-base-content/50">points</span>
              </p>
              <.hint>
                Ramer–Douglas–Peucker with ε = {fmt(@last_stroke.epsilon)} flow px kept {percent(
                  @last_stroke
                )}% of the points.
              </.hint>
            <% else %>
              <.hint>Draw a stroke to see how much the simplification saves.</.hint>
            <% end %>
          </div>
        </.option_group>

        <.option_group title="How it works">
          <.hint>
            While <b>Draw</b>
            is on, an overlay above the flow (<code>phx-update="ignore"</code>) captures the
            pointer. Its hook records the stroke with <code>liveflow.screenToFlowPosition</code>
            and pushes the points as <code>add_stroke</code>.
          </.hint>
          <.hint>
            The LiveView simplifies them (Ramer–Douglas–Peucker), computes the bounding box and
            adds a <code>type: :freehand</code>, <code>resizable: true</code>
            node. Its SVG keeps the original box as <code>viewBox</code>
            with <code>preserveAspectRatio="none"</code>, so resizing stretches the drawing while
            <code>vector-effect="non-scaling-stroke"</code>
            keeps the line width.
          </.hint>
          <.hint>
            Strokes are smooth quadratic curves through the midpoints of consecutive points. Only
            the ink is grabbable (an invisible wide path), so drawings don't block the nodes
            around them.
          </.hint>
          <.hint>
            Scroll to zoom, hold
            <.kbd>Space</.kbd>
            and drag to pan.
            <.kbd>V</.kbd>
            /
            <.kbd>D</.kbd>
            switch tools,
            <.kbd>Esc</.kbd>
            cancels a stroke.
          </.hint>
        </.option_group>

        <.option_group title="Event log">
          <.event_log entries={@event_log} />
        </.option_group>
      </:sidebar>
    </Layouts.example>
    """
  end

  attr :node, :map, required: true

  defp freehand_node(assigns) do
    ~H"""
    <NodeResizer.node_resizer
      node_id={@node.id}
      is_visible={@node.selected}
      min_width={8}
      min_height={8}
    />
    <svg
      viewBox={"0 0 #{fmt(@node.data.view_width)} #{fmt(@node.data.view_height)}"}
      preserveAspectRatio="none"
      class="freehand-svg"
      aria-hidden="true"
    >
      <path
        d={@node.data.path}
        class="freehand-hit"
        stroke-width={max(@node.data.stroke_width, 14)}
        vector-effect="non-scaling-stroke"
      />
      <path
        d={@node.data.path}
        class="freehand-ink"
        style={"stroke: #{@node.data.color}"}
        stroke-width={@node.data.stroke_width}
        vector-effect="non-scaling-stroke"
      />
    </svg>
    """
  end

  attr :id, :string, required: true
  attr :flow_id, :string, required: true
  attr :tools, :list, required: true
  attr :tool, :string, required: true
  slot :hint

  defp toolbar(assigns) do
    ~H"""
    <div class="pointer-events-none absolute inset-x-0 top-3 z-10 flex flex-col items-center gap-2 px-3">
      <div
        id={@id}
        role="toolbar"
        aria-label="Whiteboard tools"
        class="pointer-events-auto flex items-center gap-0.5 rounded-xl border border-base-300 bg-base-100/90 p-1 shadow-lg shadow-black/5 backdrop-blur"
      >
        <button
          :for={tool <- @tools}
          id={"tool-#{tool.id}"}
          type="button"
          phx-click={JS.push("set_tool", value: %{tool: tool.id}) |> JS.focus(to: "##{@flow_id}")}
          aria-pressed={to_string(@tool == tool.id)}
          title={"#{tool.label} (#{tool.key})"}
          class={[
            "inline-flex items-center gap-1.5 rounded-lg px-2.5 py-1.5 text-[13px] font-medium transition-all duration-150 active:scale-95 focus-visible:outline-2 focus-visible:outline-primary",
            if(@tool == tool.id,
              do: "bg-primary text-primary-content shadow-sm",
              else: "text-base-content/70 hover:bg-base-200 hover:text-base-content"
            )
          ]}
        >
          <.icon name={tool.icon} class="size-4" />
          {tool.label}
          <kbd class={[
            "rounded px-1 font-mono text-[10px] leading-4",
            if(@tool == tool.id,
              do: "bg-primary-content/20",
              else: "bg-base-200 text-base-content/50"
            )
          ]}>
            {tool.key}
          </kbd>
        </button>
      </div>
      <p
        :for={hint <- @hint}
        id={"#{@id}-hint"}
        class="rounded-full bg-base-100/85 px-3 py-1 text-[11px] text-base-content/60 shadow-sm ring-1 ring-base-300/60 backdrop-blur"
      >
        {render_slot(hint)}
      </p>
    </div>
    """
  end

  # ===== Events =====

  @impl true
  def handle_event("set_tool", %{"tool" => tool}, socket) when tool in @tool_ids do
    {:noreply, assign(socket, :tool, tool)}
  end

  def handle_event("set_tool", _params, socket), do: {:noreply, socket}

  def handle_event("add_stroke", %{"points" => raw} = params, socket) when is_list(raw) do
    points = raw |> Enum.take(@max_points) |> Enum.flat_map(&point/1)

    if points == [] do
      socket |> FlowEvents.log("add_stroke", %{"ignored" => true}) |> noreply()
    else
      zoom = zoom(params["zoom"], socket.assigns.flow.viewport.zoom)
      # ~0.75 screen px at the zoom the stroke was drawn with
      epsilon = (0.75 / zoom) |> max(0.1) |> min(4.0)
      simplified = simplify(points, epsilon)

      n = socket.assigns.next_id
      id = "stroke-#{n}"
      node = stroke(id, simplified, socket.assigns.color, socket.assigns.width, 10 + n)

      socket
      |> FlowEvents.snapshot()
      |> assign(flow: State.add_node(socket.assigns.flow, node), next_id: n + 1)
      |> assign(:last_stroke, %{raw: length(points), kept: length(simplified), epsilon: epsilon})
      |> FlowEvents.log("add_stroke", %{
        "id" => id,
        "points" => "#{length(points)} → #{length(simplified)}"
      })
      |> noreply()
    end
  end

  def handle_event("add_stroke", _params, socket) do
    socket |> FlowEvents.log("add_stroke", %{"ignored" => true}) |> noreply()
  end

  def handle_event("set_color", %{"color" => color}, socket) do
    if List.keymember?(@colors, color, 0),
      do: {:noreply, assign(socket, :color, color)},
      else: {:noreply, socket}
  end

  def handle_event("set_width", %{"pen" => %{"width" => width}}, socket) do
    width =
      case Integer.parse(to_string(width)) do
        {n, _rest} -> n |> max(@min_width) |> min(@max_width)
        :error -> socket.assigns.width
      end

    {:noreply, assign(socket, width: width, pen_form: pen_form(width))}
  end

  def handle_event("undo", _params, socket) do
    FlowEvents.handle_event("lf:undo", %{}, socket)
  end

  def handle_event("clear_drawings", _params, socket) do
    ids = for {id, %Node{type: :freehand}} <- socket.assigns.flow.nodes, do: id

    if ids == [] do
      {:noreply, socket}
    else
      socket
      |> FlowEvents.snapshot()
      |> assign(:flow, State.remove_nodes(socket.assigns.flow, ids))
      |> FlowEvents.log("clear_drawings", %{"strokes" => length(ids)})
      |> noreply()
    end
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  # ===== Strokes =====

  defp point([x, y]) when is_number(x) and is_number(y) and abs(x) < 1.0e6 and abs(y) < 1.0e6,
    do: [{x / 1, y / 1}]

  defp point(_other), do: []

  defp zoom(zoom, _fallback) when is_number(zoom) and zoom >= 0.05 and zoom <= 10, do: zoom
  defp zoom(_zoom, fallback), do: fallback

  # A :freehand node covering the stroke's bounding box (plus room for the
  # line width). The path is stored relative to the box, whose original size
  # becomes the SVG viewBox.
  defp stroke(id, points, color, width, z) do
    pad = width / 2 + 2
    {min_x, max_x} = points |> Enum.map(&elem(&1, 0)) |> Enum.min_max()
    {min_y, max_y} = points |> Enum.map(&elem(&1, 1)) |> Enum.min_max()
    {ox, oy} = {min_x - pad, min_y - pad}
    box_w = max_x - min_x + 2 * pad
    box_h = max_y - min_y + 2 * pad

    path = points |> Enum.map(fn {x, y} -> {x - ox, y - oy} end) |> smooth_path()

    Node.new(
      id,
      %{x: ox, y: oy},
      %{
        path: path,
        view_width: box_w,
        view_height: box_h,
        color: stroke_color(color),
        stroke_width: width,
        points: length(points)
      },
      type: :freehand,
      resizable: true,
      width: box_w,
      height: box_h,
      connectable: false,
      z_index: z
    )
  end

  @doc """
  Smooth SVG path through `points`: a quadratic curve to the midpoint of each
  pair of consecutive points, using the first one as control point.
  """
  def smooth_path([{x, y}]), do: "M#{fmt(x)} #{fmt(y)}L#{fmt(x)} #{fmt(y)}"

  def smooth_path([{x0, y0} | rest] = points) do
    {lx, ly} = List.last(points)

    curves =
      rest
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map_join(fn [{x1, y1}, {x2, y2}] ->
        "Q#{fmt(x1)} #{fmt(y1)} #{fmt((x1 + x2) / 2)} #{fmt((y1 + y2) / 2)}"
      end)

    "M#{fmt(x0)} #{fmt(y0)}#{curves}L#{fmt(lx)} #{fmt(ly)}"
  end

  @doc """
  Ramer–Douglas–Peucker: drops the points closer than `epsilon` to the
  simplified line. The first and last points are always kept.
  """
  def simplify(points, _epsilon) when length(points) < 3, do: points

  def simplify(points, epsilon) do
    tuple = List.to_tuple(points)
    last = tuple_size(tuple) - 1

    tuple
    |> rdp(0, last, epsilon, [0, last])
    |> Enum.sort()
    |> Enum.map(&elem(tuple, &1))
  end

  defp rdp(_points, first, last, _epsilon, keep) when last - first < 2, do: keep

  defp rdp(points, first, last, epsilon, keep) do
    a = elem(points, first)
    b = elem(points, last)

    {index, distance} =
      Enum.reduce((first + 1)..(last - 1)//1, {first, -1.0}, fn i, {best, best_distance} ->
        d = segment_distance(elem(points, i), a, b)
        if d > best_distance, do: {i, d}, else: {best, best_distance}
      end)

    if distance > epsilon do
      keep = rdp(points, first, index, epsilon, [index | keep])
      rdp(points, index, last, epsilon, keep)
    else
      keep
    end
  end

  # Distance to the segment (not the infinite line): closed loops have their
  # first and last points close to each other
  defp segment_distance({px, py}, {ax, ay}, {bx, by}) do
    {dx, dy} = {bx - ax, by - ay}
    length2 = dx * dx + dy * dy

    t =
      if length2 == 0,
        do: 0.0,
        else: ((px - ax) * dx + (py - ay) * dy) / length2

    t = t |> max(0.0) |> min(1.0)
    :math.sqrt(:math.pow(px - (ax + t * dx), 2) + :math.pow(py - (ay + t * dy), 2))
  end

  # ===== Helpers =====

  defp stroke_color(name) do
    {_name, stroke, _swatch} = List.keyfind(@colors, name, 0, hd(@colors))
    stroke
  end

  defp swatch_color(name) do
    {_name, _stroke, swatch} = List.keyfind(@colors, name, 0, hd(@colors))
    swatch
  end

  defp pen_form(width), do: to_form(%{"width" => width}, as: :pen)

  defp percent(%{raw: raw, kept: kept}), do: round(kept * 100 / max(raw, 1))

  defp fmt(value), do: :erlang.float_to_binary(value / 1, [:compact, decimals: 2])

  defp noreply(socket), do: {:noreply, socket}

  # ===== Initial board =====

  defp build_flow do
    nodes = [
      Samples.card("idea", 0, 0, "Brainstorm", "Circle what matters", "hero-light-bulb", :amber),
      Samples.card("ship", 420, 150, "Ship it", "Friday release", "hero-rocket-launch", :emerald)
    ]

    edges = [Edge.new("e-idea-ship", "idea", "ship", type: :smoothstep, animated: true)]

    # Strokes go through the same pipeline as the drawn ones
    circle =
      for i <- 0..56 do
        t = -0.35 + i / 56 * (2 * :math.pi() + 0.6)
        wobble = 1 + 0.035 * :math.sin(5 * t)
        {112 + 150 * wobble * :math.cos(t), 29 + 62 * wobble * :math.sin(t)}
      end

    underline = for i <- 0..40, do: {410 + i * 6.0, 232 + 7 * :math.sin(i / 2.2)}

    strokes = [
      stroke("stroke-1", simplify(circle, 0.75), "rose", 3, 11),
      stroke("stroke-2", simplify(underline, 0.75), "amber", 5, 12)
    ]

    State.new(nodes: nodes ++ strokes, edges: edges)
  end
end
