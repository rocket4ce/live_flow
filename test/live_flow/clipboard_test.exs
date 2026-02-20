defmodule LiveFlow.ClipboardTest do
  use ExUnit.Case, async: true

  alias LiveFlow.{Clipboard, State, Node, Edge}

  defp make_node(id, x \\ 0, y \\ 0) do
    Node.new(id, %{x: x, y: y}, %{label: id})
  end

  defp make_edge(id, source, target) do
    Edge.new(id, source, target)
  end

  defp setup_flow do
    State.new(
      nodes: [
        make_node("n1", 0, 0),
        make_node("n2", 100, 0),
        make_node("n3", 200, 0)
      ],
      edges: [
        make_edge("e1", "n1", "n2"),
        make_edge("e2", "n2", "n3")
      ]
    )
  end

  describe "new/0" do
    test "creates an empty clipboard" do
      cb = Clipboard.new()

      assert cb.nodes == []
      assert cb.edges == []
      assert cb.paste_count == 0
    end
  end

  describe "empty?/1" do
    test "returns true for empty clipboard" do
      assert Clipboard.empty?(Clipboard.new()) == true
    end

    test "returns false for non-empty clipboard" do
      flow = setup_flow() |> State.select_node("n1")
      cb = Clipboard.copy(Clipboard.new(), flow)

      assert Clipboard.empty?(cb) == false
    end
  end

  describe "node_count/1" do
    test "returns 0 for empty clipboard" do
      assert Clipboard.node_count(Clipboard.new()) == 0
    end

    test "returns correct count after copy" do
      flow =
        setup_flow()
        |> State.select_node("n1")
        |> State.select_node("n2", multi: true)

      cb = Clipboard.copy(Clipboard.new(), flow)

      assert Clipboard.node_count(cb) == 2
    end
  end

  describe "copy/2" do
    test "copies selected nodes" do
      flow = setup_flow() |> State.select_node("n1")
      cb = Clipboard.copy(Clipboard.new(), flow)

      assert length(cb.nodes) == 1
      assert hd(cb.nodes).id == "n1"
    end

    test "copies internal edges between selected nodes" do
      flow =
        setup_flow()
        |> State.select_node("n1")
        |> State.select_node("n2", multi: true)

      cb = Clipboard.copy(Clipboard.new(), flow)

      assert length(cb.nodes) == 2
      # e1 connects n1->n2 (both selected), should be included
      assert length(cb.edges) == 1
      assert hd(cb.edges).id == "e1"
    end

    test "excludes edges where only one endpoint is selected" do
      flow = setup_flow() |> State.select_node("n1")
      cb = Clipboard.copy(Clipboard.new(), flow)

      # e1 connects n1->n2 but only n1 selected
      assert cb.edges == []
    end

    test "includes non-selected internal edges between selected nodes" do
      # Select n1 and n2 nodes only (not the edge)
      flow =
        setup_flow()
        |> State.select_node("n1")
        |> State.select_node("n2", multi: true)

      cb = Clipboard.copy(Clipboard.new(), flow)

      # e1 connects n1->n2 and both nodes are selected, even though edge is not selected
      assert length(cb.edges) == 1
      assert hd(cb.edges).id == "e1"
    end

    test "resets paste_count to 0" do
      flow = setup_flow() |> State.select_node("n1")
      cb = %Clipboard{Clipboard.new() | paste_count: 5}
      cb = Clipboard.copy(cb, flow)

      assert cb.paste_count == 0
    end
  end

  describe "cut/2" do
    test "copies selection and deletes from flow" do
      flow =
        setup_flow()
        |> State.select_node("n2")

      {cb, new_flow} = Clipboard.cut(Clipboard.new(), flow)

      # Clipboard has n2
      assert length(cb.nodes) == 1
      assert hd(cb.nodes).id == "n2"

      # Flow no longer has n2
      refute Map.has_key?(new_flow.nodes, "n2")

      # Edges connected to n2 are removed
      assert map_size(new_flow.edges) == 0
    end
  end

  describe "paste/2" do
    test "returns :empty when clipboard is empty" do
      assert Clipboard.paste(Clipboard.new(), State.new()) == :empty
    end

    test "creates new nodes with unique IDs" do
      flow = setup_flow() |> State.select_node("n1")
      cb = Clipboard.copy(Clipboard.new(), flow)
      {:ok, new_flow, _cb} = Clipboard.paste(cb, flow)

      # Should have original + pasted node
      assert map_size(new_flow.nodes) == 4
      # Pasted node should have a different ID
      new_ids = Map.keys(new_flow.nodes) -- ["n1", "n2", "n3"]
      assert length(new_ids) == 1
      [pasted_id] = new_ids
      assert String.starts_with?(pasted_id, "n1-copy-")
    end

    test "offsets pasted node positions" do
      flow = setup_flow() |> State.select_node("n1")
      cb = Clipboard.copy(Clipboard.new(), flow)
      {:ok, new_flow, _cb} = Clipboard.paste(cb, flow)

      # Find the pasted node
      pasted =
        new_flow.nodes
        |> Map.values()
        |> Enum.find(fn n -> String.contains?(n.id, "copy") end)

      # First paste: offset = 50 * 1
      assert pasted.position.x == 50.0
      assert pasted.position.y == 50.0
    end

    test "increments offset on successive pastes" do
      flow = setup_flow() |> State.select_node("n1")
      cb = Clipboard.copy(Clipboard.new(), flow)

      {:ok, flow1, cb} = Clipboard.paste(cb, flow)
      {:ok, flow2, _cb} = Clipboard.paste(cb, flow1)

      pasted_nodes =
        flow2.nodes
        |> Map.values()
        |> Enum.filter(fn n -> String.contains?(n.id, "copy") end)
        |> Enum.sort_by(fn n -> n.position.x end)

      # First paste: +50, second paste: +100
      assert length(pasted_nodes) == 2
      assert Enum.at(pasted_nodes, 0).position.x == 50.0
      assert Enum.at(pasted_nodes, 1).position.x == 100.0
    end

    test "auto-selects pasted items" do
      flow = setup_flow() |> State.select_node("n1")
      cb = Clipboard.copy(Clipboard.new(), flow)
      {:ok, new_flow, _cb} = Clipboard.paste(cb, flow)

      # Only pasted nodes should be selected
      assert MapSet.size(new_flow.selected_nodes) == 1

      selected_node =
        new_flow.selected_nodes |> MapSet.to_list() |> hd()

      assert String.contains?(selected_node, "copy")
    end

    test "pasted nodes have reset transient state" do
      # Make the original node measured
      n1 = make_node("n1") |> Node.set_dimensions(200, 100)
      flow = State.new(nodes: [n1]) |> State.select_node("n1")
      cb = Clipboard.copy(Clipboard.new(), flow)
      {:ok, new_flow, _cb} = Clipboard.paste(cb, flow)

      pasted =
        new_flow.nodes
        |> Map.values()
        |> Enum.find(fn n -> String.contains?(n.id, "copy") end)

      assert pasted.measured == false
      assert pasted.width == nil
      assert pasted.height == nil
      assert pasted.dragging == false
      assert pasted.selected == true
    end

    test "remaps edge source/target IDs" do
      flow =
        setup_flow()
        |> State.select_node("n1")
        |> State.select_node("n2", multi: true)

      cb = Clipboard.copy(Clipboard.new(), flow)
      {:ok, new_flow, _cb} = Clipboard.paste(cb, flow)

      pasted_edges =
        new_flow.edges
        |> Map.values()
        |> Enum.filter(fn e -> String.contains?(e.id, "copy") end)

      assert length(pasted_edges) == 1
      pasted_edge = hd(pasted_edges)

      assert String.contains?(pasted_edge.source, "copy")
      assert String.contains?(pasted_edge.target, "copy")
    end
  end
end
