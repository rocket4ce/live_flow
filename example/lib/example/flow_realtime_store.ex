defmodule Example.FlowRealtimeStore do
  @moduledoc """
  GenServer that holds the shared flow state for the real-time collaborative demo.
  All connected users share this single source of truth.
  """

  use GenServer

  alias LiveFlow.{State, Node, Edge, Handle}

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def get_flow do
    GenServer.call(__MODULE__, :get_flow)
  end

  def apply_change(change) do
    GenServer.call(__MODULE__, {:apply_change, change})
  end

  def reset_flow do
    GenServer.call(__MODULE__, :reset_flow)
  end

  # Server callbacks

  @impl true
  def init(:ok) do
    {:ok, create_demo_flow()}
  end

  @impl true
  def handle_call(:get_flow, _from, flow) do
    {:reply, flow, flow}
  end

  @impl true
  def handle_call({:apply_change, change}, _from, flow) do
    flow = do_apply_change(flow, change)
    {:reply, flow, flow}
  end

  @impl true
  def handle_call(:reset_flow, _from, _flow) do
    flow = create_demo_flow()
    {:reply, flow, flow}
  end

  # Change application

  defp do_apply_change(flow, {:node_position, id, pos, dragging}) do
    case Map.get(flow.nodes, id) do
      nil ->
        flow

      node ->
        updated = %{
          node
          | position: %{x: pos["x"] / 1, y: pos["y"] / 1},
            dragging: dragging
        }

        %{flow | nodes: Map.put(flow.nodes, id, updated)}
    end
  end

  defp do_apply_change(flow, {:node_dimensions, id, width, height}) do
    case Map.get(flow.nodes, id) do
      nil ->
        flow

      node ->
        updated = %{node | width: width, height: height, measured: true}
        %{flow | nodes: Map.put(flow.nodes, id, updated)}
    end
  end

  defp do_apply_change(flow, {:node_remove, id}) do
    State.remove_node(flow, id)
  end

  defp do_apply_change(flow, {:edge_add, edge}) do
    State.add_edge(flow, edge)
  end

  defp do_apply_change(flow, {:edge_remove, id}) do
    State.remove_edge(flow, id)
  end

  defp do_apply_change(flow, {:delete_selected, node_ids, edge_ids}) do
    flow
    |> State.remove_nodes(node_ids)
    |> State.remove_edges(edge_ids)
  end

  defp do_apply_change(flow, _unknown), do: flow

  # Demo flow

  defp create_demo_flow do
    nodes = [
      Node.new("start", %{x: 50, y: 150}, %{label: "Start"},
        type: :default,
        handles: [Handle.source(:right)]
      ),
      Node.new("process-1", %{x: 250, y: 50}, %{label: "Process A"},
        handles: [Handle.target(:left), Handle.source(:right)]
      ),
      Node.new("process-2", %{x: 250, y: 250}, %{label: "Process B"},
        handles: [Handle.target(:left), Handle.source(:right)]
      ),
      Node.new("merge", %{x: 450, y: 150}, %{label: "Merge"},
        handles: [
          Handle.target(:left, id: "in-1"),
          Handle.target(:top, id: "in-2"),
          Handle.source(:right)
        ]
      ),
      Node.new("end", %{x: 650, y: 150}, %{label: "End"}, handles: [Handle.target(:left)])
    ]

    edges = [
      Edge.new("e1", "start", "process-1", marker_end: %{type: :arrow_closed, color: "#64748b"}),
      Edge.new("e2", "start", "process-2", marker_end: %{type: :arrow_closed, color: "#64748b"}),
      Edge.new("e3", "process-1", "merge",
        target_handle: "in-1",
        marker_end: %{type: :arrow_closed, color: "#64748b"}
      ),
      Edge.new("e4", "process-2", "merge",
        target_handle: "in-2",
        marker_end: %{type: :arrow_closed, color: "#64748b"}
      ),
      Edge.new("e5", "merge", "end", marker_end: %{type: :arrow_closed, color: "#64748b"})
    ]

    State.new(nodes: nodes, edges: edges)
  end
end
