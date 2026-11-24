defmodule LiveFlow.Changes.NodeChangeTest do
  use ExUnit.Case, async: true

  alias LiveFlow.Changes.NodeChange
  alias LiveFlow.Node
  alias LiveFlow.State

  for kind <- ["add", "replace"] do
    test "#{kind} with a node type the client made up adds a default node and makes no atom" do
      type = "lf_type_#{System.unique_integer([:positive])}"

      change = %{
        "type" => unquote(kind),
        "node" => %{"id" => "b", "type" => type, "position" => %{"x" => 50, "y" => 50}}
      }

      flow = NodeChange.apply_changes(State.new(), [change])

      assert flow.nodes["b"].type == :default
      assert_raise ArgumentError, fn -> String.to_existing_atom(type) end
    end
  end

  test "add keeps a node type that already exists" do
    change = %{
      "type" => "add",
      "node" => %{"id" => "b", "type" => "group", "position" => %{"x" => 0, "y" => 0}}
    }

    assert NodeChange.apply_changes(State.new(), [change]).nodes["b"].type == :group
  end

  test "add keeps a node type an Elixir caller passes as an atom" do
    change = %{
      "type" => "add",
      "node" => %{"id" => "b", "type" => :status, "position" => %{"x" => 0, "y" => 0}}
    }

    assert NodeChange.apply_changes(State.new(), [change]).nodes["b"].type == :status
  end

  test "add without a type adds a default node" do
    change = %{"type" => "add", "node" => %{"id" => "b", "position" => %{"x" => 0, "y" => 0}}}

    assert NodeChange.apply_changes(State.new(), [change]).nodes["b"].type == :default
  end

  describe "malformed payloads from the client" do
    setup do
      node = Node.new("a", %{x: 10, y: 20}, %{label: "A"})
      %{state: State.new(nodes: [node])}
    end

    test "position with a non-numeric coordinate leaves the node alone", %{state: state} do
      change = %{"type" => "position", "id" => "a", "position" => %{"x" => "abc", "y" => 1}}

      assert NodeChange.apply_changes(state, [change]).nodes["a"].position == %{x: 10, y: 20}
    end

    test "position without a position map leaves the node alone", %{state: state} do
      for position <- [nil, "nope", %{"x" => 1}, []] do
        change = %{"type" => "position", "id" => "a", "position" => position}

        assert NodeChange.apply_changes(state, [change]).nodes["a"].position == %{x: 10, y: 20}
      end
    end

    test "dimensions with non-numeric sizes leaves the node alone", %{state: state} do
      change = %{"type" => "dimensions", "id" => "a", "width" => "x", "height" => nil}

      node = NodeChange.apply_changes(state, [change]).nodes["a"]
      assert node.width == nil
      assert node.height == nil
    end

    test "resize with non-numeric sizes leaves the node alone", %{state: state} do
      change = %{"type" => "resize", "id" => "a", "width" => "x", "height" => "y"}

      assert NodeChange.apply_changes(state, [change]).nodes["a"].position == %{x: 10, y: 20}
    end

    test "add with an unusable node payload adds nothing", %{state: state} do
      changes = [
        %{"type" => "add", "node" => %{"id" => "b", "position" => %{"x" => [], "y" => 0}}},
        %{"type" => "add", "node" => %{"id" => "b"}},
        %{"type" => "add", "node" => %{"position" => %{"x" => 0, "y" => 0}}},
        %{"type" => "add", "node" => nil},
        %{"type" => "add", "node" => "oops"}
      ]

      assert NodeChange.apply_changes(state, changes).nodes == state.nodes
    end

    test "replace with an unusable node payload keeps the existing node", %{state: state} do
      change = %{
        "type" => "replace",
        "node" => %{"id" => "a", "position" => %{"x" => "z", "y" => 0}}
      }

      assert NodeChange.apply_changes(state, [change]).nodes["a"].position == %{x: 10, y: 20}
    end

    test "a bad change does not stop the good ones around it", %{state: state} do
      changes = [
        %{"type" => "position", "id" => "a", "position" => %{"x" => "boom", "y" => 0}},
        %{"type" => "position", "id" => "a", "position" => %{"x" => 1, "y" => 2}}
      ]

      assert NodeChange.apply_changes(state, changes).nodes["a"].position == %{x: 1.0, y: 2.0}
    end
  end
end
