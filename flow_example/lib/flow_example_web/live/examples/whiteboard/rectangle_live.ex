defmodule FlowExampleWeb.Examples.Whiteboard.RectangleLive do
  @moduledoc """
  Rectangle: draw rectangles on a whiteboard.

  While the rectangle tool is active, a tool overlay (`phx-update="ignore"`)
  above the flow captures the pointer. Its colocated hook records both corners
  in flow coordinates (`liveflow.screenToFlowPosition/1`), previews the
  rectangle with the chosen color (Shift draws a square) and pushes
  `add_rectangle` with the rect in flow coordinates on release.

  The LiveView adds a resizable `:rectangle` node (`resizable: true` with
  explicit `width`/`height`, `NodeResizer` while selected). Unless the tool is
  locked, it switches back to Select with the new rectangle selected so it can
  be moved and resized right away.
  """
  use FlowExampleWeb, :live_view

  alias FlowExampleWeb.{Examples, FlowEvents}
  alias LiveFlow.{Node, State}
  alias LiveFlow.Components.NodeResizer

  @flow_id "rectangle-flow"

  @tools [
    %{id: "select", label: "Select", key: "V", icon: "hero-cursor-arrow-rays"},
    %{id: "rectangle", label: "Rectangle", key: "R", icon: "hero-stop"}
  ]
  @tool_ids Enum.map(@tools, & &1.id)

  @colors [
    {"slate", "#64748b"},
    {"sky", "#0ea5e9"},
    {"violet", "#8b5cf6"},
    {"emerald", "#10b981"},
    {"amber", "#f59e0b"},
    {"rose", "#f43f5e"}
  ]

  @min_size 10
  @max_size 10_000
  @max_coord 1_000_000

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title)
     |> assign(flow_id: @flow_id, tools: @tools, tool: "rectangle", colors: @colors)
     |> assign(color: "sky", keep_tool: false, next_id: 4)
     |> assign(:options_form, options_form(false))
     |> FlowEvents.assign_flow(build_flow())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      #rectangle-overlay {
        z-index: 4;
        pointer-events: none;
        touch-action: none;
      }
      #rectangle-overlay[data-tool="rectangle"] {
        pointer-events: auto;
        cursor: crosshair;
      }
      #rectangle-overlay.is-passthrough {
        pointer-events: none;
      }
      #rectangle-overlay .rect-preview {
        position: absolute;
        display: none;
        border: 2px solid var(--rect);
        border-radius: 6px;
        background: color-mix(in oklab, var(--rect) 14%, transparent);
        box-shadow: 0 6px 20px -10px var(--rect);
        pointer-events: none;
      }
      #rectangle-overlay .rect-preview[data-visible] {
        display: block;
      }
      #rectangle-overlay .rect-size {
        position: absolute;
        top: 100%;
        left: 50%;
        translate: -50% 6px;
        padding: 1px 6px;
        border-radius: 6px;
        background: var(--rect);
        color: white;
        font: 500 11px/16px ui-monospace, SFMono-Regular, Menlo, monospace;
        white-space: nowrap;
      }
      #rectangle-flow .lf-node[data-node-type="rectangle"] {
        background: color-mix(in oklab, var(--rect) 16%, var(--lf-node-bg));
        border: 2px solid var(--rect);
        border-radius: 6px;
        box-shadow: none;
        transition:
          box-shadow 0.15s ease,
          background-color 0.2s ease,
          border-color 0.2s ease;
      }
      #rectangle-flow .lf-node[data-node-type="rectangle"]:hover {
        box-shadow: 0 8px 22px -12px var(--rect);
      }
      #rectangle-flow .lf-node[data-node-type="rectangle"].lf-node-selected {
        outline: 2px solid var(--lf-node-selected-border);
        outline-offset: 3px;
      }
      #rectangle-flow .lf-node[data-node-type="rectangle"] > .lf-node-content {
        width: 100%;
        height: 100%;
        min-width: 0;
        padding: 0;
      }
      #rectangle-toolbar-hint {
        animation: rectangle-hint-in 180ms ease-out;
      }
      @keyframes rectangle-hint-in {
        from {
          opacity: 0;
          translate: 0 -4px;
        }
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <div id="rectangle-canvas" class="relative h-full w-full">
        <.live_component
          module={LiveFlow.Components.Flow}
          id={@flow_id}
          flow={@flow}
          node_types={%{rectangle: &rectangle_node/1}}
          opts={
            %{
              background: :lines,
              background_gap: 24,
              controls: true,
              fit_view_on_init: true,
              fit_view_options: %{padding: 0.35, max_zoom: 1}
            }
          }
        />

        <div
          id="rectangle-overlay"
          phx-hook=".Rectangle"
          phx-update="ignore"
          data-flow-id={@flow_id}
          data-tool={@tool}
          data-color={hex(@color)}
          class="absolute inset-0 select-none"
        />
        <script :type={Phoenix.LiveView.ColocatedHook} name=".Rectangle">
          // Rectangle tool overlay: drag to draw. Both corners are kept in flow
          // coordinates (liveflow.screenToFlowPosition) and the preview is
          // projected with the current viewport. Shift draws a square. On
          // release the rect (flow coordinates) is pushed as "add_rectangle".
          const SHORTCUTS = {v: "select", r: "rectangle"}
          const MIN_SIZE = 4 // screen px

          export default {
            mounted() {
              this.flowId = this.el.dataset.flowId
              this.preview = document.createElement("div")
              this.preview.className = "rect-preview"
              this.size = document.createElement("span")
              this.size.className = "rect-size"
              this.preview.append(this.size)
              this.el.append(this.preview)
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
              on(this.el, "wheel", e => this.forwardWheel(e), {passive: false})
              on(this.el, "contextmenu", e => e.preventDefault())
              on(window, "keydown", e => this.onKeyDown(e))
              on(window, "keyup", e => this.onKeyUp(e))
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
              return this.el.dataset.tool === "rectangle"
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

              const flowRect = flow.getBoundingClientRect()
              const rect = this.el.getBoundingClientRect()
              this.offset = {x: flowRect.left - rect.left, y: flowRect.top - rect.top}
              this.origin = api.screenToFlowPosition({x: e.clientX, y: e.clientY})
              this.corner = this.origin
              this.square = e.shiftKey
              this.render()
            },

            move(e) {
              if (e.pointerId !== this.pointerId) return
              const api = this.api()
              if (!api) return this.cancel()
              this.corner = api.screenToFlowPosition({x: e.clientX, y: e.clientY})
              this.square = e.shiftKey
              this.schedule()
            },

            finish(e) {
              if (e.pointerId !== this.pointerId) return
              this.pointerId = null
              const api = this.api()
              const r = this.rect()
              const zoom = api ? api.getViewport().zoom : 1
              if (!api || r.width * zoom < MIN_SIZE || r.height * zoom < MIN_SIZE) return this.hide()
              const round = v => Math.round(v * 10) / 10
              const payload = {x: round(r.x), y: round(r.y), width: round(r.width), height: round(r.height)}
              // The preview stays until the node is rendered
              this.pushEvent("add_rectangle", payload, () => this.hide())
            },

            cancel() {
              if (this.pointerId !== null && this.el.hasPointerCapture(this.pointerId)) {
                this.el.releasePointerCapture(this.pointerId)
              }
              this.pointerId = null
              this.hide()
            },

            hide() {
              delete this.preview.dataset.visible
            },

            rect() {
              let dx = this.corner.x - this.origin.x
              let dy = this.corner.y - this.origin.y
              if (this.square) {
                const side = Math.max(Math.abs(dx), Math.abs(dy))
                dx = Math.sign(dx || 1) * side
                dy = Math.sign(dy || 1) * side
              }
              return {
                x: Math.min(this.origin.x, this.origin.x + dx),
                y: Math.min(this.origin.y, this.origin.y + dy),
                width: Math.abs(dx),
                height: Math.abs(dy)
              }
            },

            schedule() {
              if (this.frame) return
              this.frame = requestAnimationFrame(() => {
                this.frame = null
                if (this.pointerId !== null) this.render()
              })
            },

            render() {
              const api = this.api()
              if (!api) return
              const {x, y, zoom} = api.getViewport()
              const r = this.rect()
              Object.assign(this.preview.style, {
                left: `${r.x * zoom + x + this.offset.x}px`,
                top: `${r.y * zoom + y + this.offset.y}px`,
                width: `${r.width * zoom}px`,
                height: `${r.height * zoom}px`
              })
              this.preview.style.setProperty("--rect", this.el.dataset.color)
              this.size.textContent = `${Math.round(r.width)} × ${Math.round(r.height)}`
              this.preview.dataset.visible = ""
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
              if (e.key === "Shift" && this.pointerId !== null) {
                this.square = true
                return this.render()
              }
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
            },

            onKeyUp(e) {
              if (e.key === " ") this.el.classList.remove("is-passthrough")
              if (e.key === "Shift" && this.pointerId !== null) {
                this.square = false
                this.render()
              }
            }
          }
        </script>

        <.toolbar id="rectangle-toolbar" flow_id={@flow_id} tools={@tools} tool={@tool}>
          <:hint :if={@tool == "rectangle"}>
            Drag to draw · <b>Shift</b> for a square · <b>Space</b> + drag pans
          </:hint>
        </.toolbar>
      </div>

      <:sidebar>
        <.option_group title="Color">
          <div id="rectangle-colors" class="flex flex-wrap items-center gap-2">
            <button
              :for={{name, hex} <- @colors}
              id={"rectangle-color-#{name}"}
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
              style={"background: #{hex}"}
            />
          </div>
          <.hint>
            Used for new rectangles. With rectangles selected, it also recolors them.
          </.hint>
        </.option_group>

        <.option_group title="Tool">
          <.form for={@options_form} id="rectangle-options" phx-change="set_options">
            <.input
              field={@options_form[:keep_tool]}
              type="checkbox"
              label="Keep the tool active"
              class={switch_class()}
            />
          </.form>
          <.hint>
            Off: after drawing, the tool switches back to <b>Select</b>
            with the new rectangle selected, ready to move or resize.
          </.hint>
        </.option_group>

        <.option_group title="How it works">
          <.hint>
            An overlay above the flow (<code>phx-update="ignore"</code>) captures the pointer
            while the tool is active. Its hook converts both corners with <code>liveflow.screenToFlowPosition</code>, previews the rectangle and pushes
            <code>add_rectangle</code>
            with the rect in flow coordinates.
          </.hint>
          <.hint>
            The LiveView adds a <code>type: :rectangle</code>
            node with <code>resizable: true</code>, explicit <code>width</code>/<code>height</code>
            and the color as a CSS variable in <code>style</code>. It renders a
            <code>NodeResizer</code>
            while selected.
          </.hint>
          <.hint>
            Scroll to zoom, hold
            <.kbd>Space</.kbd>
            and drag to pan.
            <.kbd>V</.kbd>
            /
            <.kbd>R</.kbd>
            switch tools,
            <.kbd>Esc</.kbd>
            cancels the drawing.
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

  defp rectangle_node(assigns) do
    ~H"""
    <NodeResizer.node_resizer
      node_id={@node.id}
      is_visible={@node.selected}
      min_width={20}
      min_height={20}
    />
    <div class="relative size-full">
      <span
        :if={@node.selected}
        class="absolute right-1.5 bottom-1 rounded px-1 font-mono text-[10px] text-white/90"
        style="background: var(--rect)"
      >
        {round(@node.width || 0)} × {round(@node.height || 0)}
      </span>
    </div>
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

  def handle_event(
        "add_rectangle",
        %{"x" => x, "y" => y, "width" => w, "height" => h} = params,
        socket
      )
      when is_number(x) and is_number(y) and is_number(w) and is_number(h) and w > 0 and h > 0 do
    n = socket.assigns.next_id
    id = "rect-#{n}"
    keep_tool = socket.assigns.keep_tool

    node =
      rectangle(
        id,
        clamp(x, -@max_coord, @max_coord),
        clamp(y, -@max_coord, @max_coord),
        clamp(w, @min_size, @max_size),
        clamp(h, @min_size, @max_size),
        socket.assigns.color,
        n
      )

    flow = socket.assigns.flow |> State.clear_selection() |> State.add_node(node)

    {flow, tool} =
      if keep_tool,
        do: {flow, "rectangle"},
        else: {State.select_nodes(flow, [id]), "select"}

    socket
    |> FlowEvents.snapshot()
    |> assign(flow: flow, tool: tool, next_id: n + 1)
    |> FlowEvents.log("add_rectangle", Map.put(params, "id", id))
    |> noreply()
  end

  def handle_event("add_rectangle", params, socket) do
    socket |> FlowEvents.log("add_rectangle", Map.put(params, "ignored", true)) |> noreply()
  end

  def handle_event("set_color", %{"color" => color}, socket) do
    case List.keyfind(@colors, color, 0) do
      {name, hex} ->
        socket |> assign(:color, name) |> recolor_selected(name, hex) |> noreply()

      nil ->
        {:noreply, socket}
    end
  end

  def handle_event("set_options", %{"options" => %{"keep_tool" => keep_tool}}, socket) do
    keep_tool = keep_tool == "true"
    {:noreply, assign(socket, keep_tool: keep_tool, options_form: options_form(keep_tool))}
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  # ===== Helpers =====

  defp recolor_selected(socket, name, hex) do
    flow = socket.assigns.flow

    ids =
      flow.selected_nodes
      |> Enum.filter(&match?(%Node{type: :rectangle}, State.get_node(flow, &1)))
      |> Enum.sort()

    if ids == [] do
      socket
    else
      recolored =
        Enum.reduce(ids, flow, fn id, acc ->
          State.update_node(acc, id, fn node ->
            %{
              node
              | data: Map.put(node.data, :color, name),
                style: Map.put(node.style, "--rect", hex)
            }
          end)
        end)

      socket
      |> FlowEvents.snapshot()
      |> assign(:flow, recolored)
      |> FlowEvents.log("set_color", %{"nodes" => ids, "color" => name})
    end
  end

  defp hex(color) do
    {_name, hex} = List.keyfind(@colors, color, 0, hd(@colors))
    hex
  end

  defp clamp(value, min, max), do: value |> max(min) |> min(max)

  defp options_form(keep_tool), do: to_form(%{"keep_tool" => keep_tool}, as: :options)

  defp noreply(socket), do: {:noreply, socket}

  # ===== Initial board =====

  defp rectangle(id, x, y, width, height, color, z) do
    Node.new(id, %{x: x, y: y}, %{color: color},
      type: :rectangle,
      resizable: true,
      width: width,
      height: height,
      connectable: false,
      z_index: z,
      style: %{"--rect" => hex(color)}
    )
  end

  defp build_flow do
    State.new(
      nodes: [
        rectangle("rect-1", 0, 0, 320, 200, "sky", 1),
        rectangle("rect-2", 360, 40, 160, 160, "amber", 2),
        rectangle("rect-3", 40, 240, 480, 96, "emerald", 3)
      ],
      edges: []
    )
  end
end
