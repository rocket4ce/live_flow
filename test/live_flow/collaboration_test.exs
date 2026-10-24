defmodule LiveFlow.CollaborationTest do
  use ExUnit.Case, async: true

  alias LiveFlow.{Collaboration, Edge, Node, State}

  defp flow do
    State.new(
      nodes: [
        Node.new("a", %{x: 0, y: 0}, %{label: "A"}),
        Node.new("b", %{x: 200, y: 0}, %{label: "B"}),
        Node.new("c", %{x: 400, y: 0}, %{label: "C"})
      ],
      edges: [Edge.new("a-b", "a", "b")]
    )
  end

  describe "apply_remote_change/2" do
    test "applies node changes but keeps the local selection" do
      flow = State.select_node(flow(), "c")

      flow =
        Collaboration.apply_remote_change(
          flow,
          {:node_changes,
           [
             %{"type" => "position", "id" => "a", "position" => %{"x" => 10, "y" => 20}},
             %{"type" => "resize", "id" => "b", "width" => 300, "height" => 120},
             %{"type" => "select", "id" => "a", "selected" => true}
           ]}
        )

      assert State.get_node(flow, "a").position == %{x: 10, y: 20}
      assert {State.get_node(flow, "b").width, State.get_node(flow, "b").height} == {300, 120}
      assert MapSet.to_list(flow.selected_nodes) == ["c"]
    end

    test "adds, updates and removes nodes" do
      flow =
        flow()
        |> Collaboration.apply_remote_change({:node_add, Node.new("d", %{x: 0, y: 100}, %{})})
        |> Collaboration.apply_remote_change({:node_update, "a", [data: %{label: "A2"}]})
        |> Collaboration.apply_remote_change({:node_remove, "c"})

      assert State.get_node(flow, "d")
      assert State.get_node(flow, "a").data == %{label: "A2"}
      refute State.get_node(flow, "c")
    end

    test "updates and reconnects edges" do
      flow =
        flow()
        |> Collaboration.apply_remote_change({:edge_update, "a-b", [label: "next"]})
        |> Collaboration.apply_remote_change(
          {:edge_reconnect, %{"edge_id" => "a-b", "end" => "target", "node_id" => "c"}}
        )

      edge = State.get_edge(flow, "a-b")
      assert {edge.label, edge.target} == {"next", "c"}
    end

    test "ignores unknown changes" do
      assert Collaboration.apply_remote_change(flow(), {:unknown, 1}) == flow()
    end
  end
end
