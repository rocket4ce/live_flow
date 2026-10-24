defmodule FlowExampleWeb.Examples.Edges.CustomEdgesLive do
  @moduledoc """
  Custom Edges: edges with special routing or controls along the edge.

  Four custom edge types (`edge_types`):

    * `:button` — a regular bezier path with a delete button (a
      `foreignObject` at the label point, `phx-click="delete_edge"`)
    * `:self_loop` — an arc from a node back to itself
    * `:bidirectional` — two edges between the same nodes drawn as quadratic
      curves bending away from each other
    * `:labeled` — a smoothstep path with a rich HTML label

  `:button` and `:labeled` carry `data-source`/`data-target`/... so the
  client redraws them while dragging. The client doesn't know the special
  paths of `:self_loop` and `:bidirectional`: a small colocated hook watches
  the nodes and recomputes them (same formulas as the server).
  """
  use FlowExampleWeb, :live_view

  alias FlowExample.Samples
  alias FlowExampleWeb.{Examples, FlowEvents, FlowNodes}
  alias LiveFlow.{Edge, Handle, State}

  @flow_id "custom-edges-flow"

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title)
     |> assign(:edge_opts, type: :button)
     |> FlowEvents.assign_flow(build_flow())}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :flow_id, @flow_id)

    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      #custom-edges-flow .ce-overlay {
        overflow: visible;
        pointer-events: none;
      }
      #custom-edges-flow .ce-overlay.is-interactive {
        pointer-events: all;
      }
      #custom-edges-flow .ce-delete-btn {
        display: grid;
        place-items: center;
        width: 24px;
        height: 24px;
        margin: 2px;
        border-radius: 9999px;
        border: 1px solid var(--lf-node-border);
        background: var(--lf-node-bg);
        color: var(--lf-text-secondary);
        box-shadow: 0 1px 4px rgb(0 0 0 / 0.12);
        cursor: pointer;
        transition:
          transform 150ms ease,
          background-color 150ms ease,
          color 150ms ease,
          border-color 150ms ease;
      }
      #custom-edges-flow .ce-delete-btn:hover {
        transform: scale(1.15);
        background: var(--lf-delete-hover-bg);
        border-color: var(--lf-delete-hover-border);
        color: var(--lf-delete-hover-color);
      }
      #custom-edges-flow .ce-tag {
        display: flex;
        align-items: center;
        justify-content: center;
        height: 100%;
      }
      #custom-edges-flow .ce-tag span {
        border-radius: 9999px;
        padding: 1px 8px;
        font-size: 11px;
        font-weight: 600;
        line-height: 18px;
        white-space: nowrap;
        background: var(--lf-node-bg);
        border: 1px solid var(--lf-node-border);
        color: var(--lf-text-secondary);
      }
      #custom-edges-flow .ce-tag.is-loop span {
        border-color: #f59e0b;
        color: #d97706;
      }
      #custom-edges-flow .ce-self-loop .lf-edge {
        stroke: #f59e0b;
        stroke-dasharray: 6 4;
      }
      #custom-edges-flow .ce-bidirectional .lf-edge {
        stroke: #6366f1;
      }
      #custom-edges-flow .lf-edge-group .lf-edge[data-selected="true"] {
        stroke: var(--lf-edge-stroke-selected);
      }
      #custom-edges-flow .ce-rich-label {
        display: flex;
        align-items: center;
        justify-content: center;
        height: 100%;
      }
      #custom-edges-flow .ce-rich-label > div {
        display: flex;
        align-items: center;
        gap: 6px;
        border-radius: 8px;
        padding: 3px 8px;
        font-size: 11px;
        font-weight: 600;
        white-space: nowrap;
        color: #fff;
        background: linear-gradient(135deg, #10b981, #0ea5e9);
        box-shadow: 0 2px 8px rgb(16 185 129 / 0.35);
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <.live_component
        module={LiveFlow.Components.Flow}
        id={@flow_id}
        flow={@flow}
        node_types={FlowNodes.types()}
        edge_types={
          %{
            button: &button_edge/1,
            self_loop: &self_loop_edge/1,
            bidirectional: &bidirectional_edge/1,
            labeled: &labeled_edge/1
          }
        }
        opts={
          %{
            background: :dots,
            controls: true,
            fit_view_on_init: true,
            fit_view_options: %{padding: 0.15}
          }
        }
      />
      <%!-- Redraws the special paths (self loop, bidirectional) while nodes move --%>
      <div id="custom-edges-paths" phx-hook=".SpecialPaths" data-flow-id={@flow_id} hidden></div>
      <script :type={Phoenix.LiveView.ColocatedHook} name=".SpecialPaths">
        // Mirrors loop_geometry/2 and bidirectional_geometry/2 in the LiveView
        function loopGeometry(s, t) {
          const rx = Math.max(Math.abs(s.x - t.x) * 0.6, 30)
          const ry = 50
          const x1 = s.x - 5
          const x2 = t.x + 2
          const ratio = Math.min(Math.abs(x1 - x2) / 2 / rx, 1)
          const top = (s.y + t.y) / 2 - ry * Math.sqrt(1 - ratio * ratio) - ry
          return { d: `M ${x1} ${s.y} A ${rx} ${ry} 0 1 0 ${x2} ${t.y}`, x: (x1 + x2) / 2, y: top }
        }

        function bidirectionalGeometry(s, t) {
          const offset = s.x < t.x ? -32 : 32
          const cx = (s.x + t.x) / 2
          const cy = (s.y + t.y) / 2
          return { d: `M ${s.x} ${s.y} Q ${cx} ${cy + offset} ${t.x} ${t.y}`, x: cx, y: cy + offset / 2 }
        }

        // Point of a handle on its node's border (like LiveFlow's EdgeUpdater)
        function handlePoint(nodeEl, handleId, type) {
          const handle =
            (handleId && nodeEl.querySelector(`[data-handle-id="${CSS.escape(handleId)}"]`)) ||
            nodeEl.querySelector(`[data-handle-type="${type}"]`)
          const side = handle?.dataset.handlePosition || (type === "source" ? "right" : "left")
          const offset = parseFloat(handle?.dataset.handleOffset)
          const t = Number.isFinite(offset) ? offset : 0.5
          const x = parseFloat(nodeEl.style.left) || 0
          const y = parseFloat(nodeEl.style.top) || 0
          const w = nodeEl.offsetWidth
          const h = nodeEl.offsetHeight
          switch (side) {
            case "top": return { x: x + w * t, y }
            case "bottom": return { x: x + w * t, y: y + h }
            case "left": return { x, y: y + h * t }
            default: return { x: x + w, y: y + h * t }
          }
        }

        export default {
          mounted() {
            this.flow = document.getElementById(this.el.dataset.flowId)
            const nodeLayer = this.flow?.querySelector("[data-node-layer]")
            if (!nodeLayer) return

            this.observer = new MutationObserver(mutations => {
              const moved = new Set()
              for (const m of mutations) {
                if (m.target.matches?.(".lf-node[data-node-id]")) moved.add(m.target.dataset.nodeId)
              }
              if (moved.size > 0) this.redraw(moved)
            })
            this.observer.observe(nodeLayer, { attributes: true, attributeFilter: ["style"], subtree: true })
          },

          destroyed() {
            this.observer?.disconnect()
          },

          redraw(moved) {
            this.flow.querySelectorAll("g[data-special-path]").forEach(g => {
              const { ceSource, ceTarget, ceSourceHandle, ceTargetHandle, specialPath } = g.dataset
              if (!moved.has(ceSource) && !moved.has(ceTarget)) return

              const node = id => this.flow.querySelector(`.lf-node[data-node-id="${CSS.escape(id)}"]`)
              const sourceEl = node(ceSource)
              const targetEl = node(ceTarget)
              if (!sourceEl || !targetEl) return

              const s = handlePoint(sourceEl, ceSourceHandle, "source")
              const t = handlePoint(targetEl, ceTargetHandle, "target")
              const geo = specialPath === "loop" ? loopGeometry(s, t) : bidirectionalGeometry(s, t)

              g.querySelectorAll(":scope > path").forEach(p => p.setAttribute("d", geo.d))
              g.querySelectorAll(":scope > foreignObject").forEach(fo => {
                fo.setAttribute("x", geo.x - parseFloat(fo.getAttribute("width")) / 2)
                fo.setAttribute("y", geo.y - parseFloat(fo.getAttribute("height")) / 2)
              })
            })
          },
        }
      </script>

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            Custom edge types are function components registered with <code phx-no-curly-interpolation>edge_types={%{button: &button_edge/1, ...}}</code>. They receive the computed <code>@path</code>, <code>@label_x</code>/<code>@label_y</code>, <code>@source_pos</code>/<code>@target_pos</code>
            and render an SVG <code>&lt;g&gt;</code>.
          </.hint>
        </.option_group>
        <.option_group title="Edge types">
          <dl class="space-y-2.5 text-sm">
            <div id="info-button">
              <dt class="font-medium">Button edge</dt>
              <dd class="text-xs text-base-content/55">
                A <code>foreignObject</code>
                at the label point holds a <code>phx-click</code>
                button that deletes the edge. New connections use this type (<code>edge_opts</code>).
              </dd>
            </div>
            <div id="info-self-loop">
              <dt class="font-medium">Self-connecting edge</dt>
              <dd class="text-xs text-base-content/55">
                Source and target are the same node: the renderer draws an SVG arc above it.
                The client doesn't create self connections by dragging, so this one is built on the server.
              </dd>
            </div>
            <div id="info-bidirectional">
              <dt class="font-medium">Bidirectional edges</dt>
              <dd class="text-xs text-base-content/55">
                Two edges between the same nodes, each a quadratic curve bending away from the other.
              </dd>
            </div>
            <div id="info-labeled">
              <dt class="font-medium">Custom label</dt>
              <dd class="text-xs text-base-content/55">
                Any HTML (icons, gradients) in a <code>foreignObject</code>
                that follows the edge while dragging.
              </dd>
            </div>
          </dl>
        </.option_group>
        <.option_group title="Event log">
          <.event_log entries={@event_log} />
        </.option_group>
      </:sidebar>
    </Layouts.example>
    """
  end

  # ── Edge renderers ────────────────────────────────────────────────────

  # Bezier path + delete button. data-source & co. let the client redraw the
  # path and re-center the foreignObject while nodes are dragged.
  defp button_edge(assigns) do
    ~H"""
    <g class="lf-edge-group ce-button" {redraw_attrs(@edge, :bezier)}>
      <path class="lf-edge-interaction" d={@path} data-edge-id={@edge.id} />
      <path
        class="lf-edge"
        d={@path}
        data-edge-id={@edge.id}
        data-selected={to_string(@edge.selected)}
        marker-end={@marker_end_id}
      />
      <foreignObject
        data-lf-label-anchor
        x={@label_x - 14}
        y={@label_y - 14}
        width="28"
        height="28"
        class="ce-overlay is-interactive"
      >
        <button
          id={"delete-edge-#{@edge.id}"}
          type="button"
          class="ce-delete-btn nopan"
          phx-click="delete_edge"
          phx-value-edge_id={@edge.id}
          title="Delete edge"
          aria-label="Delete edge"
        >
          <.icon name="hero-x-mark-mini" class="size-3.5" />
        </button>
      </foreignObject>
    </g>
    """
  end

  defp self_loop_edge(%{source_pos: nil} = assigns), do: empty_edge(assigns)

  defp self_loop_edge(assigns) do
    assigns = assign(assigns, :geo, loop_geometry(assigns.source_pos, assigns.target_pos))

    ~H"""
    <g class="lf-edge-group ce-self-loop" {special_attrs(@edge, "loop")}>
      <path class="lf-edge-interaction" d={@geo.d} data-edge-id={@edge.id} />
      <path
        class="lf-edge"
        d={@geo.d}
        data-edge-id={@edge.id}
        data-selected={to_string(@edge.selected)}
        marker-end={@marker_end_id}
      />
      <foreignObject
        :if={@edge.label}
        x={@geo.x - 32}
        y={@geo.y - 12}
        width="64"
        height="24"
        class="ce-overlay"
      >
        <div class="ce-tag is-loop"><span>{@edge.label}</span></div>
      </foreignObject>
    </g>
    """
  end

  defp bidirectional_edge(%{source_pos: nil} = assigns), do: empty_edge(assigns)

  defp bidirectional_edge(assigns) do
    assigns =
      assign(assigns, :geo, bidirectional_geometry(assigns.source_pos, assigns.target_pos))

    ~H"""
    <g class="lf-edge-group ce-bidirectional" {special_attrs(@edge, "bidirectional")}>
      <path class="lf-edge-interaction" d={@geo.d} data-edge-id={@edge.id} />
      <path
        class="lf-edge"
        d={@geo.d}
        data-edge-id={@edge.id}
        data-selected={to_string(@edge.selected)}
        marker-end={@marker_end_id}
      />
      <foreignObject
        :if={@edge.label}
        x={@geo.x - 40}
        y={@geo.y - 12}
        width="80"
        height="24"
        class="ce-overlay"
      >
        <div class="ce-tag"><span>{@edge.label}</span></div>
      </foreignObject>
    </g>
    """
  end

  defp labeled_edge(assigns) do
    ~H"""
    <g class="lf-edge-group ce-labeled" {redraw_attrs(@edge, :smoothstep)}>
      <path class="lf-edge-interaction" d={@path} data-edge-id={@edge.id} />
      <path
        class="lf-edge"
        d={@path}
        data-edge-id={@edge.id}
        data-selected={to_string(@edge.selected)}
        marker-end={@marker_end_id}
      />
      <foreignObject
        data-lf-label-anchor
        x={@label_x - 70}
        y={@label_y - 16}
        width="140"
        height="32"
        class="ce-overlay"
      >
        <div class="ce-rich-label">
          <div id={"rich-label-#{@edge.id}"}>
            <.icon name={@edge.data[:icon] || "hero-bolt-mini"} class="size-3.5" />
            {@edge.label}
          </div>
        </div>
      </foreignObject>
    </g>
    """
  end

  defp empty_edge(assigns) do
    ~H"""
    <g data-edge-id={@edge.id}></g>
    """
  end

  # Attributes the client uses to redraw built-in path types during drags
  defp redraw_attrs(%Edge{} = edge, path_type) do
    [
      "data-edge-id": edge.id,
      "data-source": edge.source,
      "data-target": edge.target,
      "data-source-handle": edge.source_handle,
      "data-target-handle": edge.target_handle,
      "data-path-type": Map.get(edge.path_options, :base_type, path_type)
    ]
  end

  # No data-source/data-target: the built-in redraw would replace the special
  # path with a bezier. The .SpecialPaths hook uses these instead.
  defp special_attrs(%Edge{} = edge, kind) do
    [
      "data-edge-id": edge.id,
      "data-special-path": kind,
      "data-ce-source": edge.source,
      "data-ce-target": edge.target,
      "data-ce-source-handle": edge.source_handle,
      "data-ce-target-handle": edge.target_handle
    ]
  end

  # The arc of React Flow's SelfConnectingEdge: from the source handle (right)
  # around the top of the node to the target handle (left). `x`/`y` is the
  # top of the arc, where the label goes.
  defp loop_geometry(%{x: sx, y: sy}, %{x: tx, y: ty}) do
    rx = max(abs(sx - tx) * 0.6, 30)
    ry = 50
    x1 = sx - 5
    x2 = tx + 2
    ratio = min(abs(x1 - x2) / 2 / rx, 1)
    top = (sy + ty) / 2 - ry * :math.sqrt(1 - ratio * ratio) - ry

    %{
      d: "M #{n(x1)} #{n(sy)} A #{n(rx)} #{ry} 0 1 0 #{n(x2)} #{n(ty)}",
      x: (x1 + x2) / 2,
      y: top
    }
  end

  # A quadratic curve whose control point is moved off the straight line, up
  # when going right and down when going left: the two directions separate.
  defp bidirectional_geometry(%{x: sx, y: sy}, %{x: tx, y: ty}) do
    offset = if sx < tx, do: -32, else: 32
    cx = (sx + tx) / 2
    cy = (sy + ty) / 2

    %{
      d: "M #{n(sx)} #{n(sy)} Q #{n(cx)} #{n(cy + offset)} #{n(tx)} #{n(ty)}",
      x: cx,
      y: cy + offset / 2
    }
  end

  defp n(value) when is_integer(value), do: Integer.to_string(value)
  defp n(value), do: value |> Float.round(2) |> Float.to_string()

  # ── Events ────────────────────────────────────────────────────────────

  @impl true
  def handle_event("delete_edge", %{"edge_id" => id} = params, socket) do
    if State.get_edge(socket.assigns.flow, id) do
      {:noreply,
       socket
       |> FlowEvents.snapshot()
       |> assign(:flow, State.remove_edge(socket.assigns.flow, id))
       |> FlowEvents.log("delete_edge", params)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  defp build_flow do
    nodes = [
      Samples.card("client", 0, 120, "Client", "Browser", "hero-computer-desktop", :sky,
        handles: [
          Handle.source(:right, id: "out", offset: 0.3),
          Handle.target(:right, id: "in", offset: 0.7)
        ]
      ),
      Samples.card("api", 400, 120, "API", "Phoenix endpoint", "hero-server", :violet,
        handles: [
          Handle.target(:left, id: "in", offset: 0.3),
          Handle.source(:left, id: "back", offset: 0.7),
          Handle.source(:right, id: "out")
        ]
      ),
      Samples.card("worker", 800, 120, "Worker", "Oban job", "hero-cog-6-tooth", :amber,
        handles: [Handle.target(:left, id: "in"), Handle.source(:right, id: "out")]
      ),
      Samples.card("done", 1180, 260, "Done", "Result stored", "hero-check-circle", :emerald,
        handles: [Handle.target(:left, id: "in")]
      )
    ]

    edges = [
      Edge.new("request", "client", "api",
        type: :bidirectional,
        source_handle: "out",
        target_handle: "in",
        label: "request",
        marker_end: %{type: :arrow_closed, color: "#6366f1"}
      ),
      Edge.new("response", "api", "client",
        type: :bidirectional,
        source_handle: "back",
        target_handle: "in",
        label: "response",
        marker_end: %{type: :arrow_closed, color: "#6366f1"}
      ),
      Edge.new("enqueue", "api", "worker",
        type: :button,
        source_handle: "out",
        target_handle: "in"
      ),
      Edge.new("retry", "worker", "worker",
        type: :self_loop,
        source_handle: "out",
        target_handle: "in",
        label: "retry",
        marker_end: %{type: :arrow_closed, color: "#f59e0b"}
      ),
      Edge.new("complete", "worker", "done",
        type: :labeled,
        source_handle: "out",
        target_handle: "in",
        label: "~120 ms",
        data: %{icon: "hero-clock-mini"},
        path_options: %{base_type: :smoothstep}
      )
    ]

    State.new(nodes: nodes, edges: edges)
  end
end
