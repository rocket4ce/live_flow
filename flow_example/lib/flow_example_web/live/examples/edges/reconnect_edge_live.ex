defmodule FlowExampleWeb.Examples.Edges.ReconnectEdgeLive do
  @moduledoc """
  Reconnect Edge: drag the end of an existing edge to another handle.

  Edges created with `reconnectable: true` show a handle at both ends while
  selected. Dropping one on a handle pushes `lf:reconnect_edge`, applied with
  `LiveFlow.State.reconnect_edge/3`. Dropping it on the pane pushes
  `lf:delete_reconnect_edge`, which this example ignores: the edge stays as it
  was.
  """
  use FlowExampleWeb, :live_view

  alias FlowExample.Samples
  alias FlowExampleWeb.{Examples, FlowEvents, FlowNodes}
  alias LiveFlow.{Edge, State}

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title)
     |> FlowEvents.assign_flow(build_flow())
     |> assign(:edge_opts,
       type: :smoothstep,
       reconnectable: true,
       marker_end: %{type: :arrow_closed},
       data: %{ends: :both}
     )
     |> assign(reconnects: 0, kept: 0)}
  end

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns, :edges, assigns.flow.edges |> Map.values() |> Enum.sort_by(& &1.id))

    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      #reconnect-flow .lf-edge-reconnect-handle {
        opacity: 1;
        fill: var(--lf-node-bg);
        stroke: var(--lf-edge-stroke-selected);
        stroke-width: 2;
      }
      #reconnect-flow .lf-edge-reconnect-handle:hover {
        fill: var(--lf-edge-stroke-selected);
      }
      #reconnect-flow .reconnect-target-only .lf-edge-reconnect-handle[data-reconnect-end="source"],
      #reconnect-flow .reconnect-source-only .lf-edge-reconnect-handle[data-reconnect-end="target"] {
        display: none;
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <.live_component
        module={LiveFlow.Components.Flow}
        id="reconnect-flow"
        flow={@flow}
        node_types={FlowNodes.types()}
        opts={
          %{
            background: :dots,
            controls: true,
            fit_view_on_init: true,
            fit_view_options: %{padding: 0.2},
            connection_line_type: :smoothstep
          }
        }
      />

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            Click an edge to select it, then drag one of the round handles at its ends onto another
            handle. LiveFlow pushes <code>lf:reconnect_edge</code>
            with the edge id, the dragged end and the new node/handle, applied with <code>State.reconnect_edge(flow, params)</code>.
          </.hint>
          <.hint>
            Edges are reconnectable with <code>Edge.new(..., reconnectable: true)</code>. The
            <b>target end</b>
            / <b>source end</b>
            edges hide one of the handles with CSS and the
            server refuses the other end too.
          </.hint>
          <.hint>
            Dropping an end on the pane pushes <code>lf:delete_reconnect_edge</code>. This example
            ignores it, so the edge is left unchanged (the <b>Delete Edge on Drop</b>
            example removes it instead).
          </.hint>
        </.option_group>

        <.option_group title="Edges">
          <div id="edge-list" class="space-y-1">
            <div
              :for={edge <- @edges}
              id={"edge-row-#{edge.id}"}
              class="flex items-center justify-between gap-2 rounded-md bg-base-200/70 px-2 py-1 font-mono text-[11px]"
            >
              <span class="truncate text-base-content/70">{edge.label || edge.id}</span>
              <span class="shrink-0 font-semibold">{edge.source} → {edge.target}</span>
            </div>
          </div>
          <p class="pt-1 text-xs text-base-content/55">
            Reconnected <b id="reconnect-count">{@reconnects}</b>
            times · kept on pane drop <b id="kept-count">{@kept}</b>
            times
          </p>
        </.option_group>

        <.option_group title="Event log">
          <.event_log entries={@event_log} />
        </.option_group>
      </:sidebar>
    </Layouts.example>
    """
  end

  @impl true
  def handle_event("lf:reconnect_edge", %{"edge_id" => id, "end" => end_} = params, socket) do
    case State.get_edge(socket.assigns.flow, id) do
      %Edge{} = edge ->
        if end_allowed?(edge, end_) do
          {:noreply,
           socket
           |> FlowEvents.snapshot()
           |> update(:flow, &State.reconnect_edge(&1, params))
           |> update(:reconnects, &(&1 + 1))
           |> FlowEvents.log("lf:reconnect_edge", params)}
        else
          {:noreply, FlowEvents.log(socket, "lf:reconnect_edge", %{"refused" => "#{end_} end"})}
        end

      nil ->
        {:noreply, socket}
    end
  end

  # Released on the pane: keep the edge instead of deleting it
  def handle_event("lf:delete_reconnect_edge", %{"edge_id" => id}, socket) do
    {:noreply,
     socket
     |> update(:kept, &(&1 + 1))
     |> FlowEvents.log("lf:delete_reconnect_edge", %{"ignored" => "#{id} kept"})}
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  defp end_allowed?(%Edge{data: data}, end_) do
    case Map.get(data, :ends, :both) do
      :both -> true
      :source -> end_ == "source"
      :target -> end_ == "target"
    end
  end

  defp build_flow do
    nodes = [
      Samples.card("a", 0, 0, "Node A", "source", "hero-play", :amber, inputs: false),
      Samples.card("b", 0, 200, "Node B", "source", "hero-play", :amber, inputs: false),
      Samples.card("c", 340, 100, "Node C", "in & out", "hero-cog-6-tooth", :violet),
      Samples.card("d", 700, 0, "Node D", "target", "hero-flag", :emerald, outputs: false),
      Samples.card("e", 700, 200, "Node E", "target", "hero-flag", :emerald, outputs: false)
    ]

    edge = fn id, source, target, label, ends ->
      Edge.new(id, source, target,
        type: :smoothstep,
        label: label,
        reconnectable: true,
        marker_end: %{type: :arrow_closed},
        class: if(ends != :both, do: "reconnect-#{ends}-only"),
        data: %{ends: ends}
      )
    end

    edges = [
      edge.("a-c", "a", "c", "both ends", :both),
      edge.("b-c", "b", "c", "target end", :target),
      edge.("c-d", "c", "d", "source end", :source),
      edge.("c-e", "c", "e", "both ends", :both)
    ]

    [nodes: nodes, edges: edges]
    |> State.new()
    |> State.select_edge("a-c")
  end
end
