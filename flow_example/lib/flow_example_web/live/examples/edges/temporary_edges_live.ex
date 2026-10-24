defmodule FlowExampleWeb.Examples.Edges.TemporaryEdgesLive do
  @moduledoc """
  Temporary Edges: keep incomplete connections around.

  Releasing a connection on the pane pushes `lf:connect_cancel` with
  `"reason" => "pane"` and the drop position (flow coordinates). The example
  adds a small, non-selectable ghost node there and a dashed, `reconnectable`
  temporary edge to it. Dragging the dangling end onto a real handle pushes
  `lf:reconnect_edge`: the edge becomes a normal one and the ghost is removed.
  """
  use FlowExampleWeb, :live_view

  alias FlowExample.Samples
  alias FlowExampleWeb.{Examples, FlowEvents, FlowNodes}
  alias LiveFlow.{Edge, Handle, Node, State}

  @ghost_size 24
  @default_width 100
  @default_height 40

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title)
     |> FlowEvents.assign_flow(build_flow())
     |> assign(:edge_opts, type: :smoothstep, marker_end: %{type: :arrow_closed})}
  end

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns, :temporary_count, assigns.flow.edges |> temporary_edges() |> length())

    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      #temporary-edges-flow .lf-node[data-node-type="ghost"] {
        background: transparent;
        border: none;
        box-shadow: none;
      }
      #temporary-edges-flow .lf-node[data-node-type="ghost"] > .lf-node-content {
        padding: 0;
        min-width: 0;
      }
      #temporary-edges-flow .lf-node[data-node-type="ghost"] .lf-handle {
        opacity: 0;
        pointer-events: none;
      }
      #temporary-edges-flow .temporary-edge .lf-edge {
        stroke: #f59e0b;
        stroke-dasharray: 6 5;
        animation: temporary-edge-dash 1s linear infinite;
      }
      #temporary-edges-flow .temporary-edge .lf-edge[data-selected="true"] {
        stroke: #d97706;
      }
      #temporary-edges-flow .temporary-edge .lf-edge-reconnect-handle {
        opacity: 1;
        fill: #f59e0b;
        stroke: var(--lf-node-bg);
        stroke-width: 2;
      }
      #temporary-edges-flow .ghost-at-target .lf-edge-reconnect-handle[data-reconnect-end="source"],
      #temporary-edges-flow .ghost-at-source .lf-edge-reconnect-handle[data-reconnect-end="target"] {
        display: none;
      }
      @keyframes temporary-edge-dash {
        to {
          stroke-dashoffset: -22;
        }
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <:actions>
        <.action
          id="clear-temporary"
          icon="hero-trash"
          phx-click="clear_temporary"
          disabled={@temporary_count == 0}
        >
          Clear temporary edges
        </.action>
      </:actions>

      <.live_component
        module={LiveFlow.Components.Flow}
        id="temporary-edges-flow"
        flow={@flow}
        node_types={Map.put(FlowNodes.types(), :ghost, &ghost_node/1)}
        opts={
          %{
            background: :dots,
            controls: true,
            fit_view_on_init: true,
            fit_view_options: %{padding: 0.25},
            connection_line_type: :smoothstep
          }
        }
      />

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            Drag a connection from any handle and release it on the empty pane: instead of being
            lost, it stays as a dashed <b>temporary edge</b> ending in a small ghost node.
          </.hint>
          <.hint>
            Click a temporary edge to select it, then drag the amber handle at its loose end onto
            a real handle: the edge becomes a regular one and the ghost disappears.
          </.hint>
          <.hint>
            Server side: <code>lf:connect_cancel</code>
            (<code>reason: "pane"</code>, <code>position</code>
            in flow coordinates) adds the ghost and a <code>reconnectable: true</code>
            edge; <code>lf:reconnect_edge</code>
            finalizes it. Dropping the loose end on the pane again pushes <code>lf:delete_reconnect_edge</code>, which is ignored: the temporary edge stays where
            it was.
          </.hint>
        </.option_group>

        <.option_group title="State">
          <p class="text-sm">
            <span id="temporary-count" class="font-mono font-semibold">{@temporary_count}</span>
            <span class="text-base-content/60">temporary edge(s)</span>
          </p>
        </.option_group>

        <.option_group title="Event log">
          <.event_log entries={@event_log} />
        </.option_group>
      </:sidebar>
    </Layouts.example>
    """
  end

  attr :node, :map, required: true

  defp ghost_node(assigns) do
    ~H"""
    <div class="relative grid size-6 place-items-center rounded-full border-2 border-dashed border-amber-500 bg-amber-500/10">
      <span class="size-1.5 animate-ping rounded-full bg-amber-500"></span>
    </div>
    """
  end

  @impl true
  def handle_event("clear_temporary", _params, socket) do
    socket = FlowEvents.snapshot(socket)
    flow = socket.assigns.flow
    flow = State.remove_edges(flow, Enum.map(temporary_edges(flow.edges), & &1.id))
    {:noreply, assign(socket, :flow, prune_ghosts(flow))}
  end

  def handle_event(
        "lf:connect_cancel",
        %{"reason" => "pane", "node_id" => node_id, "position" => %{"x" => x, "y" => y}} =
          params,
        socket
      ) do
    flow = socket.assigns.flow

    case State.get_node(flow, node_id) do
      %Node{type: type} = node when type != :ghost ->
        {:noreply,
         socket
         |> FlowEvents.snapshot()
         |> assign(:flow, add_temporary_edge(flow, node, params, %{x: x, y: y}))
         |> FlowEvents.log("lf:connect_cancel", Map.take(params, ["node_id", "reason"]))}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("lf:reconnect_edge", %{"edge_id" => id, "end" => end_} = params, socket) do
    case State.get_edge(socket.assigns.flow, id) do
      %Edge{data: %{temporary: true, ghost_end: ^end_}} ->
        {:noreply,
         socket
         |> FlowEvents.snapshot()
         |> update(:flow, &finalize(&1, params))
         |> FlowEvents.log("lf:reconnect_edge", params)}

      _ ->
        delegate("lf:reconnect_edge", params, socket)
    end
  end

  # Dropped on the pane again: keep the temporary edge as it is
  def handle_event("lf:delete_reconnect_edge", %{"edge_id" => id}, socket) do
    {:noreply, FlowEvents.log(socket, "lf:delete_reconnect_edge", %{"kept" => id})}
  end

  def handle_event("lf:" <> _ = event, params, socket), do: delegate(event, params, socket)

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  # Deleting a temporary edge also removes its ghost
  defp delegate(event, params, socket) do
    {:noreply, socket} = FlowEvents.handle_event(event, params, socket)
    {:noreply, update(socket, :flow, &prune_ghosts/1)}
  end

  defp add_temporary_edge(flow, %Node{} = node, params, drop) do
    n = System.unique_integer([:positive])
    ghost_id = "ghost-#{n}"
    from_source? = params["handle_type"] != "target"
    side = facing_side(drop, center(node))

    ghost =
      Node.new(
        ghost_id,
        %{x: drop.x - @ghost_size / 2, y: drop.y - @ghost_size / 2},
        %{},
        type: :ghost,
        selectable: false,
        deletable: false,
        width: @ghost_size,
        height: @ghost_size,
        handles: [
          if(from_source?,
            do: Handle.target(side, id: "ghost", connectable: false),
            else: Handle.source(side, id: "ghost", connectable: false)
          )
        ]
      )

    {source, source_handle, target, target_handle} =
      if from_source?,
        do: {node.id, params["handle_id"], ghost_id, "ghost"},
        else: {ghost_id, "ghost", node.id, params["handle_id"]}

    ghost_end = if from_source?, do: "target", else: "source"

    edge =
      Edge.new("temp-#{n}", source, target,
        type: :smoothstep,
        source_handle: source_handle,
        target_handle: target_handle,
        reconnectable: true,
        marker_end: %{type: :none},
        class: "temporary-edge ghost-at-#{ghost_end}",
        data: %{temporary: true, ghost: ghost_id, ghost_end: ghost_end}
      )

    flow
    |> State.add_node(ghost)
    |> State.add_edge(edge)
    |> State.clear_selection()
    |> State.select_edge(edge.id)
  end

  # The loose end landed on a real handle: regular edge, ghost removed
  defp finalize(flow, params) do
    %Edge{id: id, data: %{ghost: ghost_id}} = State.get_edge(flow, params["edge_id"])

    flow
    |> State.reconnect_edge(params)
    |> State.update_edge(id,
      class: nil,
      reconnectable: false,
      selected: false,
      marker_end: %{type: :arrow_closed},
      data: %{}
    )
    |> Map.update!(:selected_edges, &MapSet.delete(&1, id))
    |> State.remove_node(ghost_id)
  end

  defp prune_ghosts(flow) do
    connected =
      flow.edges
      |> Map.values()
      |> Enum.flat_map(&[&1.source, &1.target])
      |> MapSet.new()

    flow.nodes
    |> Map.values()
    |> Enum.filter(&(&1.type == :ghost and not MapSet.member?(connected, &1.id)))
    |> Enum.reduce(flow, &State.remove_node(&2, &1.id))
  end

  defp temporary_edges(edges) when is_map(edges) do
    edges |> Map.values() |> Enum.filter(&Map.get(&1.data, :temporary, false))
  end

  # Side of the ghost facing the node the connection started from
  defp facing_side(%{x: x1, y: y1}, %{x: x2, y: y2}) do
    dx = x2 - x1
    dy = y2 - y1

    cond do
      abs(dx) >= abs(dy) and dx > 0 -> :right
      abs(dx) >= abs(dy) -> :left
      dy > 0 -> :bottom
      true -> :top
    end
  end

  defp center(%Node{position: %{x: x, y: y}} = node) do
    %{x: x + (node.width || @default_width) / 2, y: y + (node.height || @default_height) / 2}
  end

  defp build_flow do
    nodes = [
      Samples.card("start", 0, 120, "Start", "new order", "hero-play", :amber, inputs: false),
      Samples.card("process", 320, 40, "Process", "charge card", "hero-credit-card", :sky),
      Samples.card("review", 320, 220, "Review", "manual check", "hero-eye", :violet),
      Samples.card("done", 680, 120, "Done", "ship it", "hero-check-circle", :emerald,
        outputs: false
      )
    ]

    edges = [
      Edge.new("start-process", "start", "process",
        type: :smoothstep,
        marker_end: %{type: :arrow_closed}
      )
    ]

    flow = State.new(nodes: nodes, edges: edges)

    # One temporary edge to start with, released to the right of "Review"
    add_temporary_edge(
      flow,
      State.get_node(flow, "review"),
      %{"handle_id" => "source", "handle_type" => "source"},
      %{x: 640, y: 330}
    )
  end
end
