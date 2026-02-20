defmodule LiveFlow.Changes.NodeChange do
  @moduledoc """
  Node change event types for LiveFlow.

  Node changes describe mutations to nodes that are sent from the JS hook
  to the LiveView. These follow the xyflow pattern of immutable state changes.

  ## Change Types

    * `:position` - Node was moved
    * `:dimensions` - Node dimensions were measured/changed
    * `:select` - Node selection changed
    * `:remove` - Node was removed
    * `:add` - Node was added
    * `:replace` - Node was replaced entirely

  ## Examples

      # Position change from JS drag
      %{"type" => "position", "id" => "node-1", "position" => %{"x" => 100, "y" => 200}, "dragging" => false}

      # Dimensions change after node render
      %{"type" => "dimensions", "id" => "node-1", "width" => 150, "height" => 50}
  """

  alias LiveFlow.{State, Node}

  @type position_change :: %{
          type: :position,
          id: String.t(),
          position: %{x: number(), y: number()},
          dragging: boolean()
        }

  @type dimensions_change :: %{
          type: :dimensions,
          id: String.t(),
          width: number(),
          height: number()
        }

  @type selection_change :: %{
          type: :select,
          id: String.t(),
          selected: boolean()
        }

  @type remove_change :: %{
          type: :remove,
          id: String.t()
        }

  @type add_change :: %{
          type: :add,
          node: map()
        }

  @type replace_change :: %{
          type: :replace,
          node: map()
        }

  @type t ::
          position_change()
          | dimensions_change()
          | selection_change()
          | remove_change()
          | add_change()
          | replace_change()

  @doc """
  Applies a single change to the state.
  """
  @spec apply_change(State.t(), map()) :: State.t()
  def apply_change(state, %{"type" => "position"} = change) do
    id = change["id"]
    position = normalize_position(change["position"])
    dragging = change["dragging"] || false

    State.update_node(state, id, fn node ->
      %{node | position: position, dragging: dragging}
    end)
  end

  def apply_change(state, %{"type" => "dimensions"} = change) do
    id = change["id"]
    width = change["width"]
    height = change["height"]

    State.update_node(state, id, fn node ->
      Node.set_dimensions(node, width, height)
    end)
  end

  def apply_change(state, %{"type" => "select"} = change) do
    id = change["id"]
    selected = change["selected"]

    if selected do
      State.select_node(state, id, multi: true)
    else
      State.deselect_node(state, id)
    end
  end

  def apply_change(state, %{"type" => "remove"} = change) do
    State.remove_node(state, change["id"])
  end

  def apply_change(state, %{"type" => "add"} = change) do
    node_data = change["node"]

    node =
      Node.new(
        node_data["id"],
        normalize_position(node_data["position"]),
        Map.get(node_data, "data", %{}),
        type: String.to_existing_atom(node_data["type"] || "default")
      )

    State.add_node(state, node)
  end

  def apply_change(state, %{"type" => "replace"} = change) do
    node_data = change["node"]

    node =
      Node.new(
        node_data["id"],
        normalize_position(node_data["position"]),
        Map.get(node_data, "data", %{}),
        type: String.to_existing_atom(node_data["type"] || "default")
      )

    state
    |> State.remove_node(node.id)
    |> State.add_node(node)
  end

  # Handle atom keys (when created from Elixir)
  def apply_change(state, %{type: _} = change) do
    apply_change(state, stringify_keys(change))
  end

  def apply_change(state, _unknown_change), do: state

  @doc """
  Applies a list of changes to the state.
  """
  @spec apply_changes(State.t(), [map()]) :: State.t()
  def apply_changes(state, changes) when is_list(changes) do
    Enum.reduce(changes, state, &apply_change(&2, &1))
  end

  @doc """
  Creates a position change.
  """
  @spec position(String.t(), map(), boolean()) :: map()
  def position(id, position, dragging \\ false) do
    %{
      "type" => "position",
      "id" => id,
      "position" => position,
      "dragging" => dragging
    }
  end

  @doc """
  Creates a dimensions change.
  """
  @spec dimensions(String.t(), number(), number()) :: map()
  def dimensions(id, width, height) do
    %{
      "type" => "dimensions",
      "id" => id,
      "width" => width,
      "height" => height
    }
  end

  @doc """
  Creates a selection change.
  """
  @spec select(String.t(), boolean()) :: map()
  def select(id, selected) do
    %{
      "type" => "select",
      "id" => id,
      "selected" => selected
    }
  end

  @doc """
  Creates a remove change.
  """
  @spec remove(String.t()) :: map()
  def remove(id) do
    %{
      "type" => "remove",
      "id" => id
    }
  end

  defp normalize_position(%{"x" => x, "y" => y}), do: %{x: x / 1.0, y: y / 1.0}
  defp normalize_position(%{x: x, y: y}), do: %{x: x / 1.0, y: y / 1.0}

  defp stringify_keys(map) when is_map(map) do
    map
    |> Enum.map(fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), stringify_keys(v)}
      {k, v} -> {k, stringify_keys(v)}
    end)
    |> Map.new()
  end

  defp stringify_keys(value), do: value
end
