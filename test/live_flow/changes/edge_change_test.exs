defmodule LiveFlow.Changes.EdgeChangeTest do
  use ExUnit.Case, async: true

  alias LiveFlow.Changes.EdgeChange
  alias LiveFlow.Edge
  alias LiveFlow.Node
  alias LiveFlow.State

  setup do
    state =
      State.new(
        nodes: [Node.new("a", %{x: 0, y: 0}, %{}), Node.new("b", %{x: 100, y: 0}, %{})],
        edges: [Edge.new("e1", "a", "b")]
      )

    %{state: state}
  end

  test "add builds the edge the client asked for", %{state: state} do
    change = %{
      "type" => "add",
      "edge" => %{"id" => "e2", "source" => "b", "target" => "a", "type" => "step"}
    }

    edge = EdgeChange.apply_changes(state, [change]).edges["e2"]

    assert edge.source == "b"
    assert edge.target == "a"
    assert edge.type == :step
  end

  describe "malformed payloads from the client" do
    test "add with an unusable edge payload adds nothing", %{state: state} do
      changes = [
        %{"type" => "add", "edge" => nil},
        %{"type" => "add", "edge" => "oops"},
        %{"type" => "add", "edge" => [1, 2]},
        %{"type" => "add", "edge" => %{"id" => "e2", "source" => "a"}},
        %{"type" => "add", "edge" => %{"source" => "a", "target" => "b"}}
      ]

      assert EdgeChange.apply_changes(state, changes).edges == state.edges
    end

    test "replace with an unusable edge payload keeps the existing edge", %{state: state} do
      changes = [
        %{"type" => "replace", "edge" => 42},
        %{"type" => "replace", "edge" => %{"id" => "e1", "source" => "a"}}
      ]

      assert EdgeChange.apply_changes(state, changes).edges == state.edges
    end

    test "a bad change does not stop the good ones around it", %{state: state} do
      changes = [
        %{"type" => "add", "edge" => nil},
        %{"type" => "add", "edge" => %{"id" => "e2", "source" => "b", "target" => "a"}}
      ]

      assert Map.has_key?(EdgeChange.apply_changes(state, changes).edges, "e2")
    end
  end
end
