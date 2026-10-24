defmodule FlowExampleWeb.Examples.Whiteboard.EraserLive do
  @moduledoc """
  Eraser Tool: delete nodes and edges by wiping over them.

  The flow lives in a relatively positioned wrapper together with a tool
  overlay (`phx-update="ignore"`) that only receives the pointer while the
  eraser is active. Its colocated hook draws a fading trail and hit-tests the
  pointer path with `document.elementsFromPoint/2`, which sees every element
  below the overlay: nodes (`.lf-node[data-node-id]`) and edges
  (`g[data-edge-id]`, through their wide invisible interaction path).

  Touched elements are dimmed while erasing and, on release, their ids are
  pushed as `erase`. The LiveView removes them with `State.remove_nodes/2` and
  `State.remove_edges/2` after a history snapshot, so undo brings them back.
  Wheel events over the overlay are re-dispatched on the flow container so
  zooming keeps working, and holding Space lets the pointer through to pan.
  """
  use FlowExampleWeb, :live_view

  alias FlowExample.Samples
  alias FlowExampleWeb.{Examples, FlowEvents, FlowNodes}
  alias LiveFlow.{History, Node, State}

  @flow_id "eraser-flow"

  @tools [
    %{id: "select", label: "Select", key: "V", icon: "hero-cursor-arrow-rays"},
    %{id: "eraser", label: "Eraser", key: "E", icon: :eraser}
  ]
  @tool_ids Enum.map(@tools, & &1.id)

  # Upper bound for the ids accepted from a single stroke
  @max_ids 500

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title)
     |> assign(flow_id: @flow_id, tools: @tools, tool: "eraser", erased: %{nodes: 0, edges: 0})
     |> FlowEvents.assign_flow(build_flow())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      #eraser-overlay {
        z-index: 4;
        pointer-events: none;
        touch-action: none;
      }
      #eraser-overlay[data-tool="eraser"] {
        pointer-events: auto;
        cursor: none;
      }
      #eraser-overlay.is-passthrough {
        pointer-events: none;
      }
      #eraser-overlay .eraser-trail {
        position: absolute;
        inset: 0;
        width: 100%;
        height: 100%;
        overflow: visible;
        pointer-events: none;
      }
      #eraser-overlay .eraser-trail line {
        stroke: #f43f5e;
        stroke-linecap: round;
      }
      #eraser-overlay .eraser-cursor {
        position: absolute;
        top: -11px;
        left: -11px;
        width: 22px;
        height: 22px;
        border: 2px solid #f43f5e;
        border-radius: 9999px;
        background: color-mix(in oklab, #f43f5e 10%, transparent);
        box-shadow:
          0 0 0 1px rgb(255 255 255 / 0.7),
          0 1px 4px rgb(0 0 0 / 0.18);
        opacity: 0;
        pointer-events: none;
        transition:
          opacity 120ms ease,
          scale 120ms ease,
          background-color 120ms ease;
      }
      #eraser-overlay[data-tool="eraser"]:not(.is-passthrough) .eraser-cursor[data-visible] {
        opacity: 1;
      }
      #eraser-overlay .eraser-cursor[data-pressed] {
        scale: 0.82;
        background: color-mix(in oklab, #f43f5e 28%, transparent);
      }
      #eraser-flow .lf-node,
      #eraser-flow .lf-edge-group {
        transition:
          opacity 120ms ease,
          filter 120ms ease,
          box-shadow 0.15s ease,
          border-color 0.15s ease;
      }
      #eraser-flow .lf-node.eraser-locked {
        border-style: dashed;
      }
      #eraser-toolbar-hint {
        animation: eraser-hint-in 180ms ease-out;
      }
      @keyframes eraser-hint-in {
        from {
          opacity: 0;
          translate: 0 -4px;
        }
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <:actions>
        <.action
          id="eraser-undo"
          icon="hero-arrow-uturn-left"
          phx-click="undo"
          disabled={not History.can_undo?(@history)}
        >
          Undo
        </.action>
        <.action id="eraser-reset" icon="hero-arrow-path" phx-click="reset">Reset</.action>
      </:actions>

      <div id="eraser-canvas" class="relative h-full w-full">
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
          id="eraser-overlay"
          phx-hook=".Eraser"
          phx-update="ignore"
          data-flow-id={@flow_id}
          data-tool={@tool}
          class="absolute inset-0 select-none"
        />
        <script :type={Phoenix.LiveView.ColocatedHook} name=".Eraser">
          // Eraser overlay. While the eraser is active the overlay receives the
          // pointer. The pointer path is hit-tested every few pixels with
          // document.elementsFromPoint, which returns every element under the
          // point — also the nodes and the invisible interaction paths of the
          // edges below this overlay. Marked elements are dimmed through a
          // <style> owned by the hook (LiveView patches never reset it) and their
          // ids are pushed as "erase" on release.
          const SVG_NS = "http://www.w3.org/2000/svg"
          const TRAIL_MS = 280
          const STEP = 4
          const SHORTCUTS = {v: "select", e: "eraser"}

          export default {
            mounted() {
              this.flowId = this.el.dataset.flowId
              this.trailEl = document.createElementNS(SVG_NS, "svg")
              this.trailEl.setAttribute("class", "eraser-trail")
              this.cursor = document.createElement("div")
              this.cursor.className = "eraser-cursor"
              this.marks = document.createElement("style")
              this.el.append(this.trailEl, this.cursor, this.marks)

              this.trail = []
              this.nodes = new Set()
              this.edges = new Set()
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
              return this.el.dataset.tool === "eraser"
            },

            flow() {
              return document.getElementById(this.flowId)
            },

            start(e) {
              if (!this.active() || e.button !== 0 || this.pointerId !== null) return
              e.preventDefault()
              // Keyboard shortcuts (undo, Space to pan...) go to this flow
              this.flow()?.focus({preventScroll: true})
              this.el.setPointerCapture(e.pointerId)
              this.pointerId = e.pointerId
              this.cursor.dataset.pressed = ""
              this.last = {x: e.clientX, y: e.clientY}
              this.hit(e.clientX, e.clientY)
              this.renderMarks()
              this.addTrailPoint(e)
            },

            move(e) {
              if (!this.active()) return
              const rect = this.el.getBoundingClientRect()
              this.cursor.style.transform = `translate(${e.clientX - rect.left}px, ${e.clientY - rect.top}px)`
              this.cursor.dataset.visible = ""
              if (e.pointerId !== this.pointerId) return

              // Fast strokes skip pixels: hit-test every STEP px along the segment
              const {x, y} = this.last
              const dx = e.clientX - x
              const dy = e.clientY - y
              const steps = Math.max(1, Math.ceil(Math.hypot(dx, dy) / STEP))
              const before = this.nodes.size + this.edges.size
              for (let i = 1; i <= steps; i++) this.hit(x + (dx * i) / steps, y + (dy * i) / steps)
              if (this.nodes.size + this.edges.size !== before) this.renderMarks()

              this.last = {x: e.clientX, y: e.clientY}
              this.addTrailPoint(e, rect)
            },

            finish(e) {
              if (e.pointerId !== this.pointerId) return
              this.pointerId = null
              delete this.cursor.dataset.pressed
              const nodes = [...this.nodes]
              const edges = [...this.edges]
              this.nodes.clear()
              this.edges.clear()
              if (nodes.length === 0 && edges.length === 0) return this.renderMarks()
              // They stay dimmed until the reply: the patch removes them
              this.pushEvent("erase", {nodes, edges}, () => this.renderMarks())
            },

            cancel() {
              if (this.pointerId !== null && this.el.hasPointerCapture(this.pointerId)) {
                this.el.releasePointerCapture(this.pointerId)
              }
              this.pointerId = null
              delete this.cursor.dataset.pressed
              this.nodes.clear()
              this.edges.clear()
              this.renderMarks()
            },

            hit(x, y) {
              const flow = this.flow()
              if (!flow) return
              // Topmost first: nothing hidden below the toolbar or the flow's
              // controls and minimap is erased
              for (const el of document.elementsFromPoint(x, y)) {
                if (el.closest("[role=toolbar], .lf-controls, .lf-minimap")) return
                if (!flow.contains(el)) continue
                const node = el.closest(".lf-node[data-node-id]")
                if (node) {
                  if (!node.classList.contains("eraser-locked")) this.nodes.add(node.dataset.nodeId)
                  continue
                }
                const edge = el.closest("g[data-edge-id]")
                if (edge) this.edges.add(edge.dataset.edgeId)
              }
            },

            // Marked nodes, their connected edges and marked edges fade out
            renderMarks() {
              const scope = `#${CSS.escape(this.flowId)}`
              const sel = (tag, attr, value) => `${scope} ${tag}[${attr}="${CSS.escape(value)}"]`
              const nodes = [...this.nodes].map(id => sel(".lf-node", "data-node-id", id))
              const edges = [
                ...[...this.edges].map(id => sel("g", "data-edge-id", id)),
                ...[...this.nodes].flatMap(id => [sel("g", "data-source", id), sel("g", "data-target", id)])
              ]
              this.marks.textContent =
                (nodes.length ? `${nodes.join(",")}{opacity:.25;filter:grayscale(1)}` : "") +
                (edges.length ? `${edges.join(",")}{opacity:.12}` : "")
            },

            addTrailPoint(e, rect = this.el.getBoundingClientRect()) {
              this.trail.push({x: e.clientX - rect.left, y: e.clientY - rect.top, t: performance.now()})
              if (!this.frame) this.frame = requestAnimationFrame(() => this.drawTrail())
            },

            // A comet tail: segments get thinner and fainter with age
            drawTrail() {
              const now = performance.now()
              this.trail = this.trail.filter(p => now - p.t < TRAIL_MS)
              let out = ""
              for (let i = 1; i < this.trail.length; i++) {
                const a = this.trail[i - 1]
                const b = this.trail[i]
                const life = 1 - (now - b.t) / TRAIL_MS
                out += `<line x1="${a.x}" y1="${a.y}" x2="${b.x}" y2="${b.y}" stroke-width="${(2 + 8 * life).toFixed(1)}" stroke-opacity="${(0.1 + 0.55 * life).toFixed(2)}"/>`
              }
              this.trailEl.innerHTML = out
              this.frame = this.trail.length > 0 ? requestAnimationFrame(() => this.drawTrail()) : null
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

        <.toolbar id="eraser-toolbar" flow_id={@flow_id} tools={@tools} tool={@tool}>
          <:hint :if={@tool == "eraser"}>
            Drag over nodes and edges to erase them · <b>Space</b> + drag pans
          </:hint>
        </.toolbar>
      </div>

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            Press and drag with the <b>Eraser</b>: everything the trail touches fades out and is
            deleted when you release.
            <.kbd>Esc</.kbd>
            cancels the stroke.
          </.hint>
          <.hint>
            The tool is an overlay above the flow (<code>phx-update="ignore"</code>), only
            interactive while the eraser is on. Its hook hit-tests the pointer path with
            <code>document.elementsFromPoint</code>
            and collects <code>.lf-node[data-node-id]</code>
            and <code>g[data-edge-id]</code>
            ids.
          </.hint>
          <.hint>
            The LiveView removes them with <code>State.remove_nodes/2</code>
            and <code>State.remove_edges/2</code>
            after <code>FlowEvents.snapshot/1</code>, so <b>Undo</b>
            or
            <.kbd>⌘ Z</.kbd>
            brings them back. The <b>Webhook</b>
            node is <code>deletable: false</code>
            and resists the eraser.
          </.hint>
          <.hint>
            Wheel events over the overlay are re-dispatched on the flow, so zooming keeps
            working.
            <.kbd>V</.kbd>
            /
            <.kbd>E</.kbd>
            switch tools.
          </.hint>
        </.option_group>

        <.option_group title="Erased">
          <div class="grid grid-cols-2 gap-2">
            <.stat id="erased-nodes" label="Nodes" value={@erased.nodes} />
            <.stat id="erased-edges" label="Edges" value={@erased.edges} />
          </div>
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

  defp tool_icon(%{icon: :eraser} = assigns) do
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
      <path d="m7 21-4.3-4.3c-1-1-1-2.5 0-3.4l9.6-9.6c1-1 2.5-1 3.4 0l5.6 5.6c1 1 1 2.5 0 3.4L13 21" />
      <path d="M22 21H7" />
      <path d="m5 11 9 9" />
    </svg>
    """
  end

  defp tool_icon(assigns) do
    ~H"""
    <.icon name={@icon} class="size-4" />
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :value, :integer, required: true

  defp stat(assigns) do
    ~H"""
    <div id={@id} class="rounded-lg border border-base-300 bg-base-200/40 px-3 py-2">
      <p class="text-[11px] text-base-content/50">{@label}</p>
      <p class="font-mono text-lg font-semibold tabular-nums" data-value={@value}>{@value}</p>
    </div>
    """
  end

  # ===== Events =====

  @impl true
  def handle_event("set_tool", %{"tool" => tool}, socket) when tool in @tool_ids do
    {:noreply, assign(socket, :tool, tool)}
  end

  def handle_event("set_tool", _params, socket), do: {:noreply, socket}

  # Ids come from the browser: only existing, deletable nodes and existing
  # edges are removed
  def handle_event("erase", params, socket) do
    flow = socket.assigns.flow
    node_ids = params |> Map.get("nodes") |> ids() |> Enum.filter(&erasable?(flow, &1))
    edge_ids = params |> Map.get("edges") |> ids() |> Enum.filter(&Map.has_key?(flow.edges, &1))

    if node_ids == [] and edge_ids == [] do
      socket |> FlowEvents.log("erase", Map.put(params, "ignored", true)) |> noreply()
    else
      erased = flow |> State.remove_nodes(node_ids) |> State.remove_edges(edge_ids)

      socket
      |> FlowEvents.snapshot()
      |> assign(:flow, erased)
      |> update(:erased, fn %{nodes: n, edges: e} ->
        %{
          nodes: n + map_size(flow.nodes) - map_size(erased.nodes),
          edges: e + map_size(flow.edges) - map_size(erased.edges)
        }
      end)
      |> FlowEvents.log("erase", %{"nodes" => node_ids, "edges" => edge_ids})
      |> noreply()
    end
  end

  def handle_event("undo", _params, socket) do
    FlowEvents.handle_event("lf:undo", %{}, socket)
  end

  def handle_event("reset", _params, socket) do
    socket
    |> FlowEvents.snapshot()
    |> assign(flow: build_flow(), erased: %{nodes: 0, edges: 0})
    |> FlowEvents.log("reset", %{})
    |> noreply()
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  defp ids(list) when is_list(list) do
    list |> Enum.filter(&is_binary/1) |> Enum.uniq() |> Enum.take(@max_ids)
  end

  defp ids(_other), do: []

  defp erasable?(flow, id), do: match?(%Node{deletable: true}, State.get_node(flow, id))

  defp noreply(socket), do: {:noreply, socket}

  # ===== Initial graph =====

  defp build_flow do
    State.update_node(Samples.pipeline(), "trigger", fn node ->
      %{
        node
        | deletable: false,
          class: "eraser-locked",
          data: %{node.data | subtitle: "Locked · deletable: false", icon: "hero-lock-closed"}
      }
    end)
  end
end
