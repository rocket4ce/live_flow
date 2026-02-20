defmodule LiveFlow.StateTest do
  use ExUnit.Case, async: true

  alias LiveFlow.{State, Node, Edge, Viewport}

  defp make_node(id, x \\ 0, y \\ 0, data \\ %{}) do
    Node.new(id, %{x: x, y: y}, data)
  end

  defp make_edge(id, source, target, opts \\ []) do
    Edge.new(id, source, target, opts)
  end

  defp make_measured_node(id, x, y, w, h) do
    Node.new(id, %{x: x, y: y}, %{}) |> Node.set_dimensions(w, h)
  end

  describe "new/1" do
    test "creates empty state" do
      state = State.new()

      assert state.nodes == %{}
      assert state.edges == %{}
      assert state.selected_nodes == MapSet.new()
      assert state.selected_edges == MapSet.new()
      assert %Viewport{} = state.viewport
    end

    test "creates state with nodes list" do
      nodes = [make_node("n1"), make_node("n2")]
      state = State.new(nodes: nodes)

      assert map_size(state.nodes) == 2
      assert Map.has_key?(state.nodes, "n1")
      assert Map.has_key?(state.nodes, "n2")
    end

    test "creates state with edges list" do
      nodes = [make_node("n1"), make_node("n2")]
      edges = [make_edge("e1", "n1", "n2")]
      state = State.new(nodes: nodes, edges: edges)

      assert map_size(state.edges) == 1
      assert Map.has_key?(state.edges, "e1")
    end

    test "creates state with custom viewport" do
      vp = Viewport.new(x: 100, y: 50, zoom: 2.0)
      state = State.new(viewport: vp)

      assert state.viewport.x == 100.0
      assert state.viewport.y == 50.0
      assert state.viewport.zoom == 2.0
    end
  end

  describe "add_node/2" do
    test "adds a node to the state" do
      state = State.new() |> State.add_node(make_node("n1"))

      assert map_size(state.nodes) == 1
      assert state.nodes["n1"].id == "n1"
    end

    test "overwrites existing node with same id" do
      state =
        State.new()
        |> State.add_node(make_node("n1", 0, 0, %{label: "Old"}))
        |> State.add_node(make_node("n1", 10, 20, %{label: "New"}))

      assert map_size(state.nodes) == 1
      assert state.nodes["n1"].data == %{label: "New"}
    end
  end

  describe "get_node/2" do
    test "returns the node when it exists" do
      state = State.new() |> State.add_node(make_node("n1"))

      assert %Node{id: "n1"} = State.get_node(state, "n1")
    end

    test "returns nil when node does not exist" do
      state = State.new()

      assert State.get_node(state, "nonexistent") == nil
    end
  end

  describe "update_node/3" do
    test "updates node with keyword list" do
      state = State.new() |> State.add_node(make_node("n1"))
      state = State.update_node(state, "n1", position: %{x: 50, y: 75})

      assert state.nodes["n1"].position == %{x: 50.0, y: 75.0}
    end

    test "updates node with function" do
      state = State.new() |> State.add_node(make_node("n1"))

      state =
        State.update_node(state, "n1", fn node ->
          Node.set_dimensions(node, 100, 50)
        end)

      assert state.nodes["n1"].width == 100
      assert state.nodes["n1"].height == 50
      assert state.nodes["n1"].measured == true
    end

    test "returns unchanged state for nonexistent node (keyword)" do
      state = State.new()
      updated = State.update_node(state, "missing", position: %{x: 1, y: 1})

      assert updated == state
    end

    test "returns unchanged state for nonexistent node (function)" do
      state = State.new()
      updated = State.update_node(state, "missing", fn n -> n end)

      assert updated == state
    end
  end

  describe "remove_node/2" do
    test "removes the node" do
      state = State.new() |> State.add_node(make_node("n1"))
      state = State.remove_node(state, "n1")

      assert map_size(state.nodes) == 0
    end

    test "also removes edges connected to the node" do
      state =
        State.new()
        |> State.add_node(make_node("n1"))
        |> State.add_node(make_node("n2"))
        |> State.add_node(make_node("n3"))
        |> State.add_edge(make_edge("e1", "n1", "n2"))
        |> State.add_edge(make_edge("e2", "n2", "n3"))

      state = State.remove_node(state, "n2")

      assert map_size(state.edges) == 0
      assert map_size(state.nodes) == 2
    end

    test "removes node from selected_nodes" do
      state =
        State.new()
        |> State.add_node(make_node("n1"))
        |> State.select_node("n1")
        |> State.remove_node("n1")

      assert MapSet.size(state.selected_nodes) == 0
    end
  end

  describe "add_edge/2" do
    test "adds an edge to the state" do
      state =
        State.new()
        |> State.add_node(make_node("n1"))
        |> State.add_node(make_node("n2"))
        |> State.add_edge(make_edge("e1", "n1", "n2"))

      assert map_size(state.edges) == 1
      assert state.edges["e1"].source == "n1"
    end
  end

  describe "get_edge/2" do
    test "returns the edge when it exists" do
      state =
        State.new()
        |> State.add_edge(make_edge("e1", "a", "b"))

      assert %Edge{id: "e1"} = State.get_edge(state, "e1")
    end

    test "returns nil when edge does not exist" do
      assert State.get_edge(State.new(), "nope") == nil
    end
  end

  describe "update_edge/3" do
    test "updates edge attributes" do
      state = State.new() |> State.add_edge(make_edge("e1", "a", "b"))
      state = State.update_edge(state, "e1", label: "Updated", animated: true)

      assert state.edges["e1"].label == "Updated"
      assert state.edges["e1"].animated == true
    end

    test "returns unchanged state for nonexistent edge" do
      state = State.new()
      updated = State.update_edge(state, "missing", label: "X")

      assert updated == state
    end
  end

  describe "remove_edge/2" do
    test "removes the edge" do
      state = State.new() |> State.add_edge(make_edge("e1", "a", "b"))
      state = State.remove_edge(state, "e1")

      assert map_size(state.edges) == 0
    end

    test "removes from selected_edges" do
      state =
        State.new()
        |> State.add_edge(make_edge("e1", "a", "b"))
        |> State.select_edge("e1")
        |> State.remove_edge("e1")

      assert MapSet.size(state.selected_edges) == 0
    end
  end

  describe "edges_for_node/2" do
    test "returns all edges connected to a node" do
      state =
        State.new()
        |> State.add_edge(make_edge("e1", "n1", "n2"))
        |> State.add_edge(make_edge("e2", "n2", "n3"))
        |> State.add_edge(make_edge("e3", "n3", "n1"))

      edges = State.edges_for_node(state, "n1")

      assert length(edges) == 2
      ids = Enum.map(edges, & &1.id) |> Enum.sort()
      assert ids == ["e1", "e3"]
    end

    test "returns empty list for node with no edges" do
      state = State.new()

      assert State.edges_for_node(state, "n1") == []
    end
  end

  describe "edge_exists?/5" do
    test "returns true when matching edge exists" do
      state = State.new() |> State.add_edge(make_edge("e1", "a", "b"))

      assert State.edge_exists?(state, "a", "b") == true
    end

    test "returns false when no matching edge" do
      state = State.new() |> State.add_edge(make_edge("e1", "a", "b"))

      assert State.edge_exists?(state, "a", "c") == false
    end

    test "checks with specific handles" do
      state =
        State.new()
        |> State.add_edge(make_edge("e1", "a", "b", source_handle: "out", target_handle: "in"))

      assert State.edge_exists?(state, "a", "b", "out", "in") == true
      assert State.edge_exists?(state, "a", "b", "other", "in") == false
    end

    test "nil handles match any" do
      state =
        State.new()
        |> State.add_edge(make_edge("e1", "a", "b", source_handle: "out"))

      assert State.edge_exists?(state, "a", "b", nil, nil) == true
    end
  end

  describe "select_node/3" do
    test "selects a single node (no multi)" do
      state =
        State.new()
        |> State.add_node(make_node("n1"))
        |> State.add_node(make_node("n2"))
        |> State.select_node("n1")

      assert MapSet.member?(state.selected_nodes, "n1")
      assert state.nodes["n1"].selected == true
      assert state.nodes["n2"].selected == false
    end

    test "replaces selection when multi is false" do
      state =
        State.new()
        |> State.add_node(make_node("n1"))
        |> State.add_node(make_node("n2"))
        |> State.select_node("n1")
        |> State.select_node("n2")

      assert MapSet.size(state.selected_nodes) == 1
      assert MapSet.member?(state.selected_nodes, "n2")
      assert state.nodes["n1"].selected == false
      assert state.nodes["n2"].selected == true
    end

    test "adds to selection when multi is true" do
      state =
        State.new()
        |> State.add_node(make_node("n1"))
        |> State.add_node(make_node("n2"))
        |> State.select_node("n1")
        |> State.select_node("n2", multi: true)

      assert MapSet.size(state.selected_nodes) == 2
      assert state.nodes["n1"].selected == true
      assert state.nodes["n2"].selected == true
    end

    test "ignores nonexistent node" do
      state = State.new() |> State.select_node("nonexistent")

      assert MapSet.size(state.selected_nodes) == 0
    end
  end

  describe "select_nodes/2" do
    test "selects multiple nodes" do
      state =
        State.new()
        |> State.add_node(make_node("n1"))
        |> State.add_node(make_node("n2"))
        |> State.add_node(make_node("n3"))
        |> State.select_nodes(["n1", "n3"])

      assert MapSet.size(state.selected_nodes) == 2
      assert state.nodes["n1"].selected == true
      assert state.nodes["n2"].selected == false
      assert state.nodes["n3"].selected == true
    end

    test "filters out nonexistent node ids" do
      state =
        State.new()
        |> State.add_node(make_node("n1"))
        |> State.select_nodes(["n1", "missing"])

      assert MapSet.size(state.selected_nodes) == 1
    end
  end

  describe "deselect_node/2" do
    test "deselects a selected node" do
      state =
        State.new()
        |> State.add_node(make_node("n1"))
        |> State.select_node("n1")
        |> State.deselect_node("n1")

      assert state.nodes["n1"].selected == false
      assert MapSet.size(state.selected_nodes) == 0
    end
  end

  describe "select_edge/3" do
    test "selects an edge" do
      state =
        State.new()
        |> State.add_edge(make_edge("e1", "a", "b"))
        |> State.select_edge("e1")

      assert MapSet.member?(state.selected_edges, "e1")
      assert state.edges["e1"].selected == true
    end

    test "replaces selection by default" do
      state =
        State.new()
        |> State.add_edge(make_edge("e1", "a", "b"))
        |> State.add_edge(make_edge("e2", "b", "c"))
        |> State.select_edge("e1")
        |> State.select_edge("e2")

      assert MapSet.size(state.selected_edges) == 1
      assert MapSet.member?(state.selected_edges, "e2")
    end

    test "adds to selection with multi: true" do
      state =
        State.new()
        |> State.add_edge(make_edge("e1", "a", "b"))
        |> State.add_edge(make_edge("e2", "b", "c"))
        |> State.select_edge("e1")
        |> State.select_edge("e2", multi: true)

      assert MapSet.size(state.selected_edges) == 2
    end

    test "ignores nonexistent edge" do
      state = State.new() |> State.select_edge("nope")

      assert MapSet.size(state.selected_edges) == 0
    end
  end

  describe "clear_selection/1" do
    test "clears all node and edge selections" do
      state =
        State.new()
        |> State.add_node(make_node("n1"))
        |> State.add_edge(make_edge("e1", "a", "b"))
        |> State.select_node("n1")
        |> State.select_edge("e1")
        |> State.clear_selection()

      assert MapSet.size(state.selected_nodes) == 0
      assert MapSet.size(state.selected_edges) == 0
      assert state.nodes["n1"].selected == false
      assert state.edges["e1"].selected == false
    end
  end

  describe "select_all/1" do
    test "selects all nodes and edges" do
      state =
        State.new()
        |> State.add_node(make_node("n1"))
        |> State.add_node(make_node("n2"))
        |> State.add_edge(make_edge("e1", "n1", "n2"))
        |> State.select_all()

      assert MapSet.size(state.selected_nodes) == 2
      assert MapSet.size(state.selected_edges) == 1
      assert state.nodes["n1"].selected == true
      assert state.nodes["n2"].selected == true
      assert state.edges["e1"].selected == true
    end
  end

  describe "delete_selected/1" do
    test "deletes selected nodes and their edges" do
      state =
        State.new()
        |> State.add_node(make_node("n1"))
        |> State.add_node(make_node("n2"))
        |> State.add_node(make_node("n3"))
        |> State.add_edge(make_edge("e1", "n1", "n2"))
        |> State.add_edge(make_edge("e2", "n2", "n3"))
        |> State.select_node("n2")
        |> State.delete_selected()

      assert map_size(state.nodes) == 2
      refute Map.has_key?(state.nodes, "n2")
      # Both edges connected to n2 should be removed
      assert map_size(state.edges) == 0
    end

    test "deletes selected edges" do
      state =
        State.new()
        |> State.add_node(make_node("n1"))
        |> State.add_node(make_node("n2"))
        |> State.add_edge(make_edge("e1", "n1", "n2"))
        |> State.select_edge("e1")
        |> State.delete_selected()

      assert map_size(state.edges) == 0
      assert map_size(state.nodes) == 2
    end
  end

  describe "set_viewport/2" do
    test "sets the viewport" do
      vp = Viewport.new(x: 100, y: 200, zoom: 2.0)
      state = State.new() |> State.set_viewport(vp)

      assert state.viewport.x == 100.0
      assert state.viewport.y == 200.0
      assert state.viewport.zoom == 2.0
    end
  end

  describe "update_viewport/2" do
    test "updates viewport with atom keys" do
      state = State.new() |> State.update_viewport(%{x: 50, y: 75, zoom: 1.5})

      assert state.viewport.x == 50.0
      assert state.viewport.y == 75.0
      assert state.viewport.zoom == 1.5
    end

    test "updates viewport with string keys" do
      state = State.new() |> State.update_viewport(%{"x" => 10, "y" => 20, "zoom" => 0.8})

      assert state.viewport.x == 10.0
      assert state.viewport.y == 20.0
      assert state.viewport.zoom == 0.8
    end

    test "preserves unmodified viewport values" do
      state =
        State.new()
        |> State.update_viewport(%{x: 100, y: 200, zoom: 2.0})
        |> State.update_viewport(%{x: 150})

      assert state.viewport.x == 150.0
      assert state.viewport.y == 200.0
      assert state.viewport.zoom == 2.0
    end
  end

  describe "bounds/1" do
    test "returns nil for empty state" do
      assert State.bounds(State.new()) == nil
    end

    test "returns position-based bounds when no nodes are measured" do
      state =
        State.new()
        |> State.add_node(make_node("n1", 0, 0))
        |> State.add_node(make_node("n2", 100, 200))

      bounds = State.bounds(state)

      assert bounds.x == 0.0
      assert bounds.y == 0.0
      assert bounds.width == 100.0
      assert bounds.height == 200.0
    end

    test "returns measurement-based bounds when nodes are measured" do
      state =
        State.new()
        |> State.add_node(make_measured_node("n1", 0, 0, 100, 50))
        |> State.add_node(make_measured_node("n2", 200, 100, 150, 80))

      bounds = State.bounds(state)

      assert bounds.x == 0.0
      assert bounds.y == 0.0
      assert bounds.width == 350.0
      assert bounds.height == 180.0
    end
  end
end
