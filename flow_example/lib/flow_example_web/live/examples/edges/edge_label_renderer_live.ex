defmodule FlowExampleWeb.Examples.Edges.EdgeLabelRendererLive do
  @moduledoc """
  Edge Label Renderer: render edge labels as HTML on top of edges.

  `edge_label_renderer={&rich_label/1}` replaces the plain text label of every
  edge that has a `label`: it receives `@edge`, `@x` and `@y` and is rendered
  in a `foreignObject` centered on the label point, so it can hold badges,
  icons and buttons. An edge can override it with `data: %{label_renderer: fun}`.

  The `:start_end` custom edge also renders labels at both ends of the edge
  (`foreignObject`s at `@source_pos` / `@target_pos`); a small colocated hook
  keeps them on the edge while the client redraws it during a drag.
  """
  use FlowExampleWeb, :live_view

  alias FlowExample.Samples
  alias FlowExampleWeb.{Examples, FlowEvents, FlowNodes}
  alias LiveFlow.{Edge, State}

  @flow_id "edge-label-renderer-flow"
  @endpoint_w 76
  @endpoint_h 22
  @endpoint_gap 50

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title)
     |> FlowEvents.assign_flow(build_flow())}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :flow_id, @flow_id)

    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      #edge-label-renderer-flow .elr-wrap {
        display: flex;
        align-items: center;
        justify-content: center;
        width: 100%;
        height: 100%;
      }
      #edge-label-renderer-flow .elr-chip {
        display: inline-flex;
        align-items: center;
        gap: 6px;
        height: 26px;
        padding: 0 9px;
        border-radius: 9999px;
        border: 1px solid var(--lf-node-border);
        background: var(--lf-node-bg);
        color: var(--lf-text-primary);
        font-size: 11px;
        white-space: nowrap;
        box-shadow: 0 1px 4px rgb(0 0 0 / 0.1);
        transition:
          box-shadow 150ms ease,
          transform 150ms ease;
      }
      #edge-label-renderer-flow .elr-chip:hover {
        box-shadow: 0 3px 10px rgb(0 0 0 / 0.14);
        transform: translateY(-1px);
      }
      #edge-label-renderer-flow .elr-muted {
        color: var(--lf-text-secondary);
      }
      #edge-label-renderer-flow .elr-btn {
        display: grid;
        place-items: center;
        width: 18px;
        height: 18px;
        margin-right: -5px;
        border-radius: 9999px;
        background: #6366f1;
        color: white;
        cursor: pointer;
        transition:
          transform 150ms ease,
          background-color 150ms ease;
      }
      #edge-label-renderer-flow .elr-btn:hover {
        background: #4f46e5;
        transform: scale(1.12);
      }
      #edge-label-renderer-flow .elr-btn:active {
        transform: scale(0.92);
      }
      #edge-label-renderer-flow .elr-alert {
        border-color: #f59e0b;
        background: #fffbeb;
        color: #b45309;
      }
      #edge-label-renderer-flow .elr-endpoint {
        overflow: visible;
        pointer-events: none;
      }
      #edge-label-renderer-flow .elr-endpoint div {
        display: flex;
        align-items: center;
        justify-content: center;
        height: 100%;
        border-radius: 6px;
        font-size: 10px;
        font-weight: 700;
        letter-spacing: 0.04em;
        text-transform: uppercase;
        color: white;
      }
      #edge-label-renderer-flow .elr-endpoint.is-start div {
        background: #0ea5e9;
      }
      #edge-label-renderer-flow .elr-endpoint.is-end div {
        background: #ff0072;
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <.live_component
        module={LiveFlow.Components.Flow}
        id={@flow_id}
        flow={@flow}
        node_types={FlowNodes.types()}
        edge_types={%{start_end: &start_end_edge/1}}
        edge_label_renderer={&rich_label/1}
        opts={
          %{
            background: :dots,
            controls: true,
            fit_view_on_init: true,
            fit_view_options: %{padding: 0.15}
          }
        }
      />
      <%!-- Keeps the start/end labels on their edge while the client redraws it --%>
      <div id="edge-endpoint-labels" phx-hook=".EndpointLabels" data-flow-id={@flow_id} hidden></div>
      <script :type={Phoenix.LiveView.ColocatedHook} name=".EndpointLabels">
        // Mirrors endpoint_xy/2 in the LiveView
        const DIRECTIONS = { left: [-1, 0], right: [1, 0], top: [0, -1], bottom: [0, 1] }

        function place(fo, point, side, gap) {
          if (!fo) return
          const [dx, dy] = DIRECTIONS[side] || [0, 0]
          const w = parseFloat(fo.getAttribute("width"))
          const h = parseFloat(fo.getAttribute("height"))
          fo.setAttribute("x", point.x + dx * gap - w / 2)
          fo.setAttribute("y", point.y + dy * gap - h / 2)
        }

        export default {
          mounted() {
            const flow = document.getElementById(this.el.dataset.flowId)
            const edgeLayer = flow?.querySelector("[data-edge-layer]")
            if (!edgeLayer) return

            this.observer = new MutationObserver(mutations => {
              for (const m of mutations) {
                const path = m.target
                if (!path.classList?.contains("lf-edge")) continue
                const g = path.closest("g[data-endpoint-labels]")
                if (!g) continue

                const gap = parseFloat(g.dataset.endpointGap)
                const length = path.getTotalLength()
                place(g.querySelector('[data-endpoint="start"]'), path.getPointAtLength(0), g.dataset.sourceSide, gap)
                place(g.querySelector('[data-endpoint="end"]'), path.getPointAtLength(length), g.dataset.targetSide, gap)
              }
            })
            this.observer.observe(edgeLayer, { attributes: true, attributeFilter: ["d"], subtree: true })
          },

          destroyed() {
            this.observer?.disconnect()
          },
        }
      </script>

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            <code phx-no-curly-interpolation>edge_label_renderer={&rich_label/1}</code>
            renders the label of every edge with a <code>label</code>
            as HTML: it gets <code>@edge</code>, <code>@x</code>, <code>@y</code>
            and lives in a 150×40 <code>foreignObject</code>
            centered on the label point.
          </.hint>
          <.hint>
            Labels can hold anything: status badges, icons, live counters, buttons with
            <code>phx-click</code>
            (try <b>+</b>
            on the billing edge). <b>Retrying</b>
            uses a per-edge renderer: <code phx-no-curly-interpolation>data: %{label_renderer: &alert_label/1}</code>.
          </.hint>
          <.hint>
            The <code>:start_end</code>
            custom edge adds labels at its source and target (<code>@source_pos</code>
            / <code>@target_pos</code>). A small hook moves them with the edge during drags.
          </.hint>
        </.option_group>
        <.option_group title="Approvals">
          <p class="text-sm">
            Billing edge approvals:
            <span id="approvals-count" class="font-mono font-semibold">
              {approvals(@flow)}
            </span>
          </p>
        </.option_group>
        <.option_group title="Event log">
          <.event_log entries={@event_log} />
        </.option_group>
      </:sidebar>
    </Layouts.example>
    """
  end

  # ── Label renderers ───────────────────────────────────────────────────

  attr :edge, :map, required: true
  attr :x, :any, required: true
  attr :y, :any, required: true

  defp rich_label(%{edge: %Edge{data: %{kind: :status}}} = assigns) do
    ~H"""
    <div class="elr-wrap">
      <div id={"label-#{@edge.id}"} class="elr-chip">
        <span class="relative flex size-2">
          <span class="absolute inline-flex size-full animate-ping rounded-full bg-emerald-400 opacity-75"></span>
          <span class="relative inline-flex size-2 rounded-full bg-emerald-500"></span>
        </span>
        <span class="font-semibold">{@edge.label}</span>
        <span class="elr-muted">{@edge.data.latency}</span>
      </div>
    </div>
    """
  end

  defp rich_label(%{edge: %Edge{data: %{kind: :metric}}} = assigns) do
    ~H"""
    <div class="elr-wrap">
      <div id={"label-#{@edge.id}"} class="elr-chip">
        <.icon name="hero-arrow-trending-up-mini" class="size-3.5 text-sky-500" />
        <span class="font-semibold">{@edge.label}</span>
        <span class="elr-muted">req/s</span>
      </div>
    </div>
    """
  end

  defp rich_label(%{edge: %Edge{data: %{kind: :counter}}} = assigns) do
    ~H"""
    <div class="elr-wrap">
      <div id={"label-#{@edge.id}"} class="elr-chip">
        <.icon name="hero-check-badge-mini" class="size-3.5 text-indigo-500" />
        <span class="font-semibold">{@edge.data.count}</span>
        <span class="elr-muted">{@edge.label}</span>
        <button
          id={"approve-#{@edge.id}"}
          type="button"
          class="elr-btn"
          phx-click="approve"
          phx-value-edge_id={@edge.id}
          title="Approve"
        >
          <.icon name="hero-plus-micro" class="size-3" />
        </button>
      </div>
    </div>
    """
  end

  defp rich_label(assigns) do
    ~H"""
    <div class="elr-wrap">
      <div id={"label-#{@edge.id}"} class="elr-chip font-medium">{@edge.label}</div>
    </div>
    """
  end

  attr :edge, :map, required: true
  attr :x, :any, required: true
  attr :y, :any, required: true

  # Per-edge override (edge.data.label_renderer)
  defp alert_label(assigns) do
    ~H"""
    <div class="elr-wrap">
      <div id={"label-#{@edge.id}"} class="elr-chip elr-alert">
        <.icon name="hero-exclamation-triangle-mini" class="size-3.5 animate-pulse" />
        <span class="font-semibold">{@edge.label}</span>
      </div>
    </div>
    """
  end

  # ── Custom edge with labels at both ends ──────────────────────────────

  defp start_end_edge(%{source_pos: nil} = assigns) do
    ~H"""
    <g data-edge-id={@edge.id}></g>
    """
  end

  defp start_end_edge(assigns) do
    assigns =
      assign(assigns,
        start: endpoint_xy(assigns.source_pos, assigns.source_position),
        finish: endpoint_xy(assigns.target_pos, assigns.target_position),
        w: @endpoint_w,
        h: @endpoint_h,
        gap: @endpoint_gap
      )

    ~H"""
    <g
      class="lf-edge-group"
      data-edge-id={@edge.id}
      data-source={@edge.source}
      data-target={@edge.target}
      data-source-handle={@edge.source_handle}
      data-target-handle={@edge.target_handle}
      data-path-type="bezier"
      data-endpoint-labels
      data-endpoint-gap={@gap}
      data-source-side={@source_position}
      data-target-side={@target_position}
    >
      <path class="lf-edge-interaction" d={@path} data-edge-id={@edge.id} />
      <path
        class="lf-edge"
        d={@path}
        data-edge-id={@edge.id}
        data-selected={to_string(@edge.selected)}
        marker-end={@marker_end_id}
      />
      <%!-- Direct child: the client re-centers it on the label point --%>
      <foreignObject
        :if={@edge.label}
        data-lf-label-anchor
        x={@label_x - 75}
        y={@label_y - 20}
        width="150"
        height="40"
        class="lf-edge-label-custom"
      >
        <.rich_label edge={@edge} x={@label_x} y={@label_y} />
      </foreignObject>
      <%!-- Nested: positioned by the server and by the .EndpointLabels hook --%>
      <g>
        <foreignObject
          id={"endpoint-start-#{@edge.id}"}
          data-endpoint="start"
          x={@start.x - @w / 2}
          y={@start.y - @h / 2}
          width={@w}
          height={@h}
          class="elr-endpoint is-start"
        >
          <div>{@edge.data.start_label}</div>
        </foreignObject>
        <foreignObject
          id={"endpoint-end-#{@edge.id}"}
          data-endpoint="end"
          x={@finish.x - @w / 2}
          y={@finish.y - @h / 2}
          width={@w}
          height={@h}
          class="elr-endpoint is-end"
        >
          <div>{@edge.data.end_label}</div>
        </foreignObject>
      </g>
    </g>
    """
  end

  # Center of an endpoint label: `@endpoint_gap` px away from the node, along
  # the direction the edge leaves (or enters) it
  defp endpoint_xy(%{x: x, y: y}, side) do
    {dx, dy} =
      case side do
        :left -> {-1, 0}
        :right -> {1, 0}
        :top -> {0, -1}
        :bottom -> {0, 1}
        _ -> {0, 0}
      end

    %{x: x + dx * @endpoint_gap, y: y + dy * @endpoint_gap}
  end

  # ── Events ────────────────────────────────────────────────────────────

  @impl true
  def handle_event("approve", %{"edge_id" => id} = params, socket) do
    case State.get_edge(socket.assigns.flow, id) do
      %Edge{data: %{kind: :counter} = data} ->
        data = Map.update(data, :count, 1, &(&1 + 1))

        {:noreply,
         socket
         |> assign(:flow, State.update_edge(socket.assigns.flow, id, data: data))
         |> FlowEvents.log("approve", params)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  defp approvals(flow) do
    case State.get_edge(flow, "api-billing") do
      %Edge{data: data} -> Map.get(data, :count, 0)
      nil -> 0
    end
  end

  defp build_flow do
    nodes = [
      Samples.card("web", 0, 150, "Web app", "LiveView UI", "hero-window", :sky),
      Samples.card("api", 440, 150, "API gateway", "Rate limited", "hero-server", :violet),
      Samples.card("auth", 900, 0, "Auth", "Sessions & tokens", "hero-key", :amber),
      Samples.card("billing", 900, 300, "Billing", "Invoices", "hero-credit-card", :emerald),
      Samples.card("events", 1480, 0, "Event bus", "PubSub topic", "hero-signal", :rose,
        outputs: false
      ),
      Samples.card("ledger", 1480, 300, "Ledger", "Double entry", "hero-book-open", :slate,
        outputs: false
      )
    ]

    edges = [
      Edge.new("web-api", "web", "api",
        label: "200 OK",
        data: %{kind: :status, latency: "32 ms"}
      ),
      Edge.new("api-auth", "api", "auth", label: "1.2k", data: %{kind: :metric}),
      Edge.new("api-billing", "api", "billing",
        label: "approvals",
        data: %{kind: :counter, count: 2}
      ),
      Edge.new("billing-ledger", "billing", "ledger",
        label: "Retrying",
        animated: true,
        data: %{label_renderer: &alert_label/1}
      ),
      Edge.new("auth-events", "auth", "events",
        type: :start_end,
        label: "session.created",
        data: %{start_label: "publish", end_label: "deliver"}
      )
    ]

    State.new(nodes: nodes, edges: edges)
  end
end
