defmodule LiveFlow.HistoryTest do
  use ExUnit.Case, async: true

  alias LiveFlow.{History, State, Node, Edge}

  defp make_state(nodes, edges \\ []) do
    State.new(nodes: nodes, edges: edges)
  end

  defp make_node(id, x \\ 0, y \\ 0) do
    Node.new(id, %{x: x, y: y}, %{label: id})
  end


  describe "new/1" do
    test "creates empty history with default max_entries" do
      h = History.new()

      assert h.undo_stack == []
      assert h.redo_stack == []
      assert h.max_entries == 50
    end

    test "creates history with custom max_entries" do
      h = History.new(max_entries: 10)

      assert h.max_entries == 10
    end
  end

  describe "push/2" do
    test "saves snapshot to undo stack" do
      flow = make_state([make_node("n1")])
      h = History.new() |> History.push(flow)

      assert length(h.undo_stack) == 1
      assert h.undo_stack |> hd() |> Map.has_key?(:nodes)
      assert h.undo_stack |> hd() |> Map.has_key?(:edges)
    end

    test "clears redo stack on push" do
      flow1 = make_state([make_node("n1")])
      flow2 = make_state([make_node("n1"), make_node("n2")])

      h = History.new() |> History.push(flow1)
      # Simulate undo to populate redo stack
      {:ok, _restored, h} = History.undo(h, flow2)
      assert length(h.redo_stack) == 1

      # New push clears redo
      flow3 = make_state([make_node("n3")])
      h = History.push(h, flow3)

      assert h.redo_stack == []
      assert length(h.undo_stack) == 1
    end

    test "trims to max_entries" do
      h = History.new(max_entries: 3)

      h =
        Enum.reduce(1..5, h, fn i, acc ->
          History.push(acc, make_state([make_node("n#{i}")]))
        end)

      assert length(h.undo_stack) == 3
    end
  end

  describe "undo/2" do
    test "restores previous state" do
      flow1 = make_state([make_node("n1")])
      flow2 = make_state([make_node("n1"), make_node("n2")])

      h = History.new() |> History.push(flow1)
      {:ok, restored, _h} = History.undo(h, flow2)

      assert Map.has_key?(restored.nodes, "n1")
      refute Map.has_key?(restored.nodes, "n2")
    end

    test "pushes current state to redo stack" do
      flow1 = make_state([make_node("n1")])
      flow2 = make_state([make_node("n1"), make_node("n2")])

      h = History.new() |> History.push(flow1)
      {:ok, _restored, h} = History.undo(h, flow2)

      assert length(h.redo_stack) == 1
      assert length(h.undo_stack) == 0
    end

    test "returns :empty when undo stack is empty" do
      h = History.new()
      flow = make_state([make_node("n1")])

      assert History.undo(h, flow) == :empty
    end

    test "clears selection on restore" do
      flow1 = make_state([make_node("n1")])
      flow2 =
        make_state([make_node("n1"), make_node("n2")])
        |> State.select_node("n1")

      h = History.new() |> History.push(flow1)
      {:ok, restored, _h} = History.undo(h, flow2)

      assert MapSet.size(restored.selected_nodes) == 0
      assert MapSet.size(restored.selected_edges) == 0
    end

    test "preserves measurements on restore" do
      n1 = make_node("n1") |> Node.set_dimensions(200, 100)
      flow1 = make_state([make_node("n1")])
      flow2 = make_state([n1])

      h = History.new() |> History.push(flow1)
      {:ok, restored, _h} = History.undo(h, flow2)

      # Current flow has measurements, restored should preserve them
      assert restored.nodes["n1"].width == 200
      assert restored.nodes["n1"].height == 100
      assert restored.nodes["n1"].measured == true
    end
  end

  describe "redo/2" do
    test "re-applies undone state" do
      flow1 = make_state([make_node("n1")])
      flow2 = make_state([make_node("n1"), make_node("n2")])

      h = History.new() |> History.push(flow1)
      {:ok, restored, h} = History.undo(h, flow2)
      {:ok, redone, _h} = History.redo(h, restored)

      assert Map.has_key?(redone.nodes, "n1")
      assert Map.has_key?(redone.nodes, "n2")
    end

    test "pushes current state to undo stack on redo" do
      flow1 = make_state([make_node("n1")])
      flow2 = make_state([make_node("n1"), make_node("n2")])

      h = History.new() |> History.push(flow1)
      {:ok, restored, h} = History.undo(h, flow2)
      {:ok, _redone, h} = History.redo(h, restored)

      assert length(h.undo_stack) == 1
      assert length(h.redo_stack) == 0
    end

    test "returns :empty when redo stack is empty" do
      h = History.new()
      flow = make_state([make_node("n1")])

      assert History.redo(h, flow) == :empty
    end
  end

  describe "can_undo?/1 and can_redo?/1" do
    test "can_undo? returns false for empty history" do
      assert History.can_undo?(History.new()) == false
    end

    test "can_undo? returns true after push" do
      h = History.new() |> History.push(make_state([]))

      assert History.can_undo?(h) == true
    end

    test "can_redo? returns false for empty history" do
      assert History.can_redo?(History.new()) == false
    end

    test "can_redo? returns true after undo" do
      flow = make_state([make_node("n1")])
      h = History.new() |> History.push(flow)
      {:ok, _restored, h} = History.undo(h, flow)

      assert History.can_redo?(h) == true
    end
  end

  describe "undo_count/1 and redo_count/1" do
    test "undo_count returns number of undo entries" do
      h =
        History.new()
        |> History.push(make_state([]))
        |> History.push(make_state([make_node("n1")]))

      assert History.undo_count(h) == 2
    end

    test "redo_count returns number of redo entries" do
      assert History.redo_count(History.new()) == 0

      flow = make_state([make_node("n1")])
      h = History.new() |> History.push(flow)
      {:ok, _restored, h} = History.undo(h, flow)

      assert History.redo_count(h) == 1
    end
  end

  describe "multiple undo/redo cycles" do
    test "can undo multiple times" do
      flow0 = make_state([])
      flow1 = make_state([make_node("n1")])
      flow2 = make_state([make_node("n1"), make_node("n2")])

      h =
        History.new()
        |> History.push(flow0)
        |> History.push(flow1)

      {:ok, restored1, h} = History.undo(h, flow2)
      assert map_size(restored1.nodes) == 1

      {:ok, restored0, _h} = History.undo(h, restored1)
      assert map_size(restored0.nodes) == 0
    end

    test "undo then redo returns to same state" do
      flow1 = make_state([make_node("n1")])
      flow2 = make_state([make_node("n1"), make_node("n2")])

      h = History.new() |> History.push(flow1)
      {:ok, restored, h} = History.undo(h, flow2)
      {:ok, redone, _h} = History.redo(h, restored)

      assert Map.keys(redone.nodes) |> Enum.sort() == ["n1", "n2"]
    end
  end
end
