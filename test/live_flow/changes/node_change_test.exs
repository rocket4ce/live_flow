defmodule LiveFlow.Changes.NodeChangeTest do
  use ExUnit.Case, async: true

  alias LiveFlow.Changes.NodeChange
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
end
