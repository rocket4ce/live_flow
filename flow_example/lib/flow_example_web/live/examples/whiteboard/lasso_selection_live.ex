defmodule FlowExampleWeb.Examples.Whiteboard.LassoSelectionLive do
  @moduledoc """
  Lasso Selection: select multiple nodes by drawing a free-form lasso.

  A tool overlay (`phx-update="ignore"`) above the flow captures the pointer
  while the lasso is active. Its colocated hook records the lasso in flow
  coordinates with `liveflow.screenToFlowPosition/1` and draws it by projecting
  the points with the current viewport. Nodes inside the lasso are highlighted
  while drawing; on release they are selected with `liveflow.setSelection/1`,
  which pushes the usual `lf:selection_change`.

  Hit testing runs in the browser against `liveflow.getNodes()` (absolute flow
  rects): in partial mode a node only has to be touched by the lasso, in full
  mode it must be completely inside.
  """
  use FlowExampleWeb, :live_view

  alias FlowExample.Samples
  alias FlowExampleWeb.{Examples, FlowEvents, FlowNodes}
  alias LiveFlow.State

  @flow_id "lasso-flow"

  @tools [
    %{id: "select", label: "Select", key: "V", icon: "hero-cursor-arrow-rays"},
    %{id: "lasso", label: "Lasso", key: "L", icon: :lasso}
  ]
  @tool_ids Enum.map(@tools, & &1.id)

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title)
     |> assign(flow_id: @flow_id, tools: @tools, tool: "lasso", partial: true)
     |> assign(:mode_form, mode_form(true))
     |> FlowEvents.assign_flow(Samples.pipeline())}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :selected, selected_nodes(assigns.flow))

    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      #lasso-overlay {
        z-index: 4;
        pointer-events: none;
        touch-action: none;
      }
      #lasso-overlay[data-tool="lasso"] {
        pointer-events: auto;
        cursor: crosshair;
      }
      #lasso-overlay.is-passthrough {
        pointer-events: none;
      }
      #lasso-overlay .lasso-svg {
        position: absolute;
        inset: 0;
        width: 100%;
        height: 100%;
        overflow: visible;
        pointer-events: none;
        transition: opacity 180ms ease;
      }
      #lasso-overlay .lasso-svg[data-fading] {
        opacity: 0;
      }
      #lasso-overlay .lasso-path {
        fill: color-mix(in oklab, var(--color-primary) 10%, transparent);
        fill-rule: evenodd;
        stroke: var(--color-primary);
        stroke-width: 1.5;
        stroke-dasharray: 6 4;
        stroke-linecap: round;
        stroke-linejoin: round;
        animation: lasso-ants 0.6s linear infinite;
      }
      #lasso-overlay .lasso-start {
        fill: var(--color-base-100);
        stroke: var(--color-primary);
        stroke-width: 1.5;
      }
      @keyframes lasso-ants {
        to {
          stroke-dashoffset: -10;
        }
      }
      #lasso-toolbar-hint {
        animation: lasso-hint-in 180ms ease-out;
      }
      @keyframes lasso-hint-in {
        from {
          opacity: 0;
          translate: 0 -4px;
        }
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <div id="lasso-canvas" class="relative h-full w-full">
        <.live_component
          module={LiveFlow.Components.Flow}
          id={@flow_id}
          flow={@flow}
          node_types={FlowNodes.types()}
          opts={
            %{
              background: :dots,
              controls: true,
              minimap: true,
              fit_view_on_init: true,
              fit_view_options: %{padding: 0.25}
            }
          }
        />

        <div
          id="lasso-overlay"
          phx-hook=".Lasso"
          phx-update="ignore"
          data-flow-id={@flow_id}
          data-tool={@tool}
          data-partial={to_string(@partial)}
          class="absolute inset-0 select-none"
        />
        <script :type={Phoenix.LiveView.ColocatedHook} name=".Lasso">
          // Lasso overlay. Points are recorded in flow coordinates
          // (liveflow.screenToFlowPosition) and drawn by projecting them with the
          // current viewport, so the lasso stays in place when zooming mid-stroke.
          // Nodes come from liveflow.getNodes() (absolute flow rects); the
          // result is applied with liveflow.setSelection().
          const SVG_NS = "http://www.w3.org/2000/svg"
          const SHORTCUTS = {v: "select", l: "lasso"}

          // Ray casting (even-odd, like the fill of the lasso)
          const insidePolygon = (p, poly) => {
            let inside = false
            for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
              const a = poly[i]
              const b = poly[j]
              if ((a.y > p.y) !== (b.y > p.y) && p.x < ((b.x - a.x) * (p.y - a.y)) / (b.y - a.y) + a.x) {
                inside = !inside
              }
            }
            return inside
          }

          const cross = (a, b, c) => (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
          const segmentsIntersect = (p1, p2, p3, p4) =>
            (cross(p3, p4, p1) > 0) !== (cross(p3, p4, p2) > 0) &&
            (cross(p1, p2, p3) > 0) !== (cross(p1, p2, p4) > 0)

          const corners = n => [
            {x: n.x, y: n.y},
            {x: n.x + n.width, y: n.y},
            {x: n.x + n.width, y: n.y + n.height},
            {x: n.x, y: n.y + n.height}
          ]

          const inRect = (p, n) => p.x >= n.x && p.x <= n.x + n.width && p.y >= n.y && p.y <= n.y + n.height

          // Does the (closed) lasso outline cross one of the node's sides?
          const outlineCrosses = (poly, n) => {
            const c = corners(n)
            for (let i = 0; i < poly.length; i++) {
              const a = poly[i]
              const b = poly[(i + 1) % poly.length]
              for (let k = 0; k < 4; k++) {
                if (segmentsIntersect(a, b, c[k], c[(k + 1) % 4])) return true
              }
            }
            return false
          }

          // partial: touched by the lasso; full: completely inside of it
          const lassoed = (n, poly, partial) => {
            const c = corners(n)
            if (!partial) return c.every(p => insidePolygon(p, poly)) && !outlineCrosses(poly, n)
            return (
              c.some(p => insidePolygon(p, poly)) ||
              insidePolygon({x: n.x + n.width / 2, y: n.y + n.height / 2}, poly) ||
              poly.some(p => inRect(p, n)) ||
              outlineCrosses(poly, n)
            )
          }

          export default {
            mounted() {
              this.flowId = this.el.dataset.flowId
              this.svg = document.createElementNS(SVG_NS, "svg")
              this.svg.setAttribute("class", "lasso-svg")
              this.path = document.createElementNS(SVG_NS, "path")
              this.path.setAttribute("class", "lasso-path")
              this.dot = document.createElementNS(SVG_NS, "circle")
              this.dot.setAttribute("class", "lasso-start")
              this.dot.setAttribute("r", "3.5")
              this.svg.append(this.path, this.dot)
              this.el.append(this.svg)

              this.points = []
              this.candidates = []
              this.highlighted = new Set()
              this.pointerId = null
              this.frame = null
              this.render()

              this.listeners = []
              const on = (target, type, fn, options) => {
                target.addEventListener(type, fn, options)
                this.listeners.push([target, type, fn, options])
              }
              on(this.el, "pointerdown", e => this.start(e))
              on(this.el, "pointermove", e => this.move(e))
              on(this.el, "pointerup", e => this.finish(e))
              on(this.el, "pointercancel", () => this.cancel())
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
              clearTimeout(this.fadeTimer)
            },

            active() {
              return this.el.dataset.tool === "lasso"
            },

            flow() {
              return document.getElementById(this.flowId)
            },

            api() {
              return this.flow()?.liveflow
            },

            start(e) {
              const api = this.api()
              if (!this.active() || !api || e.button !== 0 || this.pointerId !== null) return
              e.preventDefault()
              const flow = this.flow()
              flow.focus({preventScroll: true})
              this.el.setPointerCapture(e.pointerId)
              this.pointerId = e.pointerId
              clearTimeout(this.fadeTimer)
              delete this.svg.dataset.fading

              const flowRect = flow.getBoundingClientRect()
              const rect = this.el.getBoundingClientRect()
              this.offset = {x: flowRect.left - rect.left, y: flowRect.top - rect.top}
              this.additive = e.shiftKey

              const locked = new Set(
                [...flow.querySelectorAll('.lf-node[data-selectable="false"]')].map(el => el.dataset.nodeId)
              )
              this.candidates = api.getNodes().filter(n => !locked.has(n.id))
              this.points = [api.screenToFlowPosition({x: e.clientX, y: e.clientY})]
              this.render()
            },

            move(e) {
              if (e.pointerId !== this.pointerId) return
              const api = this.api()
              if (!api) return this.cancel()
              const point = api.screenToFlowPosition({x: e.clientX, y: e.clientY})
              const last = this.points[this.points.length - 1]
              // Keep points at least 2 screen px apart
              if (Math.hypot(point.x - last.x, point.y - last.y) * api.getViewport().zoom < 2) return
              this.points.push(point)
              this.schedule()
            },

            schedule() {
              if (this.frame) return
              this.frame = requestAnimationFrame(() => {
                this.frame = null
                this.render()
                if (this.pointerId !== null) this.highlight(this.lassoedIds())
              })
            },

            finish(e) {
              if (e.pointerId !== this.pointerId) return
              this.pointerId = null
              if (this.frame) cancelAnimationFrame(this.frame)
              this.frame = null

              const api = this.api()
              const nodes = this.lassoedIds()
              // The lassoed nodes keep the preview class until the server
              // renders them selected (that patch resets their classes), so
              // nothing flickers while the selection round-trips
              this.highlight(api ? nodes : new Set())
              this.highlighted = new Set()

              if (api) {
                const edges = new Set(this.connectedEdges(nodes))
                // Shift adds to the current selection
                if (this.additive || e.shiftKey) {
                  const current = api.getSelection()
                  current.nodes.forEach(id => nodes.add(id))
                  current.edges.forEach(id => edges.add(id))
                }
                api.setSelection({nodes: [...nodes], edges: [...edges]})
              }

              this.render()
              this.svg.dataset.fading = ""
              this.fadeTimer = setTimeout(() => {
                this.points = []
                this.render()
                delete this.svg.dataset.fading
              }, 180)
            },

            cancel() {
              if (this.pointerId !== null && this.el.hasPointerCapture(this.pointerId)) {
                this.el.releasePointerCapture(this.pointerId)
              }
              this.pointerId = null
              this.highlight(new Set())
              this.points = []
              this.render()
            },

            lassoedIds() {
              if (this.points.length < 3) return new Set()
              const partial = this.el.dataset.partial !== "false"
              return new Set(this.candidates.filter(n => lassoed(n, this.points, partial)).map(n => n.id))
            },

            // Same edges as the built-in selection box: connected to a selected node
            connectedEdges(nodes) {
              if (nodes.size === 0) return []
              return [...(this.flow()?.querySelectorAll("g[data-edge-id][data-source]") || [])]
                .filter(g => nodes.has(g.dataset.source) || nodes.has(g.dataset.target))
                .map(g => g.dataset.edgeId)
            },

            // Preview with the class the selection box uses (lf-node-selecting)
            highlight(ids) {
              const flow = this.flow()
              for (const id of new Set([...this.highlighted, ...ids])) {
                flow
                  ?.querySelector(`.lf-node[data-node-id="${CSS.escape(id)}"]`)
                  ?.classList.toggle("lf-node-selecting", ids.has(id))
              }
              this.highlighted = ids
            },

            render() {
              const api = this.api()
              if (!api || this.points.length === 0) {
                this.path.removeAttribute("d")
                this.dot.style.display = "none"
                return
              }
              const {x, y, zoom} = api.getViewport()
              const project = p => [
                (p.x * zoom + x + this.offset.x).toFixed(1),
                (p.y * zoom + y + this.offset.y).toFixed(1)
              ]
              const d = this.points.map((p, i) => `${i ? "L" : "M"}${project(p).join(" ")}`).join("")
              this.path.setAttribute("d", this.points.length > 2 ? `${d}Z` : d)
              const [sx, sy] = project(this.points[0])
              this.dot.setAttribute("cx", sx)
              this.dot.setAttribute("cy", sy)
              this.dot.style.display = ""
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
              if (this.pointerId !== null) requestAnimationFrame(() => this.render())
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

        <.toolbar id="lasso-toolbar" flow_id={@flow_id} tools={@tools} tool={@tool}>
          <:hint :if={@tool == "lasso"}>
            Draw around nodes to select them · <b>Shift</b> adds to the selection
          </:hint>
        </.toolbar>
      </div>

      <:sidebar>
        <.option_group title="Lasso">
          <.form for={@mode_form} id="lasso-options" phx-change="set_mode">
            <.input
              field={@mode_form[:partial]}
              type="checkbox"
              label="Partial selection"
              class={switch_class()}
            />
          </.form>
          <.hint>
            <%= if @partial do %>
              <b>Partial</b>: nodes touched by the lasso are selected.
            <% else %>
              <b>Full</b>: only nodes completely inside the lasso are selected.
            <% end %>
          </.hint>
        </.option_group>

        <.option_group title="Selection">
          <div id="lasso-selection" class="flex flex-wrap gap-1.5">
            <p :if={@selected == []} id="lasso-selection-empty" class="text-xs text-base-content/45">
              Nothing selected yet.
            </p>
            <span
              :for={node <- @selected}
              id={"lasso-selected-#{node.id}"}
              class="inline-flex items-center gap-1 rounded-md bg-primary/10 px-2 py-0.5 text-xs font-medium text-primary"
            >
              <.icon name="hero-check-mini" class="size-3.5" />
              {node.data[:title] || node.id}
            </span>
          </div>
        </.option_group>

        <.option_group title="How it works">
          <.hint>
            While the <b>Lasso</b>
            is on, an overlay above the flow (<code>phx-update="ignore"</code>) captures the pointer. Its colocated hook records
            the points in flow coordinates with <code>liveflow.screenToFlowPosition</code>.
          </.hint>
          <.hint>
            Nodes come from <code>liveflow.getNodes()</code>
            (absolute flow rects) and are tested against the polygon (point in polygon + segment
            intersection). On release, <code>liveflow.setSelection(...)</code>
            selects them and their connected edges, like the selection box, and pushes <code>lf:selection_change</code>.
          </.hint>
          <.hint>
            Scroll to zoom, hold
            <.kbd>Space</.kbd>
            and drag to pan.
            <.kbd>V</.kbd>
            /
            <.kbd>L</.kbd>
            switch tools,
            <.kbd>Esc</.kbd>
            cancels the lasso.
          </.hint>
        </.option_group>

        <.option_group title="Event log">
          <.event_log entries={@event_log} />
        </.option_group>
      </:sidebar>
    </Layouts.example>
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
          <.tool_icon icon={tool.icon} />
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

  attr :icon, :any, required: true

  defp tool_icon(%{icon: :lasso} = assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      class="size-4"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
    >
      <path d="M7 22a5 5 0 0 1-2-4" />
      <path d="M3.3 14A6.8 6.8 0 0 1 2 10c0-4.4 4.5-8 10-8s10 3.6 10 8-4.5 8-10 8a12 12 0 0 1-5-1" />
      <circle cx="5" cy="16" r="2" />
    </svg>
    """
  end

  defp tool_icon(assigns) do
    ~H"""
    <.icon name={@icon} class="size-4" />
    """
  end

  # ===== Events =====

  @impl true
  def handle_event("set_tool", %{"tool" => tool}, socket) when tool in @tool_ids do
    {:noreply, assign(socket, :tool, tool)}
  end

  def handle_event("set_tool", _params, socket), do: {:noreply, socket}

  def handle_event("set_mode", %{"lasso" => %{"partial" => partial}}, socket) do
    partial = partial == "true"
    {:noreply, assign(socket, partial: partial, mode_form: mode_form(partial))}
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  defp mode_form(partial), do: to_form(%{"partial" => partial}, as: :lasso)

  defp selected_nodes(flow) do
    flow.selected_nodes
    |> Enum.map(&State.get_node(flow, &1))
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(&{&1.position.x, &1.position.y})
  end
end
