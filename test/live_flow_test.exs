defmodule LiveFlowTest do
  use ExUnit.Case

  describe "new_state/1" do
    test "creates empty state" do
      state = LiveFlow.new_state()
      assert state.nodes == %{}
      assert state.edges == %{}
    end
  end

  describe "new_node/4" do
    test "creates a node" do
      node = LiveFlow.new_node("1", %{x: 10, y: 20}, %{label: "Hello"})
      assert node.id == "1"
      assert node.position == %{x: 10.0, y: 20.0}
      assert node.data == %{label: "Hello"}
    end
  end

  describe "new_edge/4" do
    test "creates an edge" do
      edge = LiveFlow.new_edge("e1", "a", "b")
      assert edge.id == "e1"
      assert edge.source == "a"
      assert edge.target == "b"
    end
  end

  describe "create_flow/1" do
    test "creates flow from node and edge maps" do
      flow =
        LiveFlow.create_flow(
          nodes: [
            %{id: "1", position: %{x: 0, y: 0}, data: %{label: "A"}},
            %{id: "2", position: %{x: 100, y: 100}, data: %{label: "B"}}
          ],
          edges: [
            %{id: "e1", source: "1", target: "2"}
          ]
        )

      assert map_size(flow.nodes) == 2
      assert map_size(flow.edges) == 1
    end

    test "accepts existing Node/Edge structs" do
      node = LiveFlow.Node.new("1", %{x: 0, y: 0}, %{})
      edge = LiveFlow.Edge.new("e1", "1", "2")

      flow = LiveFlow.create_flow(nodes: [node], edges: [edge])
      assert map_size(flow.nodes) == 1
      assert map_size(flow.edges) == 1
    end
  end
end
