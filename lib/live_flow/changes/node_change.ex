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
    case fetch_position(change["position"]) do
      {:ok, position} ->
        dragging = change["dragging"] || false

        State.update_node(state, change["id"], fn node ->
          %{node | position: position, dragging: dragging}
        end)

      :error ->
        state
    end
  end

  def apply_change(state, %{"type" => "dimensions"} = change) do
    with {:ok, width} <- fetch_dimension(change["width"]),
         {:ok, height} <- fetch_dimension(change["height"]) do
      State.update_node(state, change["id"], fn node ->
        # Skip content-measurement dimensions for resizable nodes that have
        # already been explicitly resized — prevents ResizeObserver from
        # overwriting user-set dimensions with content-fit sizes.
        if node.resizable && node.measured && node.width && node.height do
          node
        else
          Node.set_dimensions(node, width, height)
        end
      end)
    else
      :error -> state
    end
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
    case build_node(change["node"]) do
      {:ok, node} -> State.add_node(state, node)
      :error -> state
    end
  end

  def apply_change(state, %{"type" => "replace"} = change) do
    case build_node(change["node"]) do
      {:ok, node} ->
        state
        |> State.remove_node(node.id)
        |> State.add_node(node)

      :error ->
        state
    end
  end

  def apply_change(state, %{"type" => "resize"} = change) do
    with {:ok, width} <- fetch_dimension(change["width"]),
         {:ok, height} <- fetch_dimension(change["height"]),
         {:ok, position} <- fetch_optional_position(change["position"]) do
      resizing = change["resizing"] || false

      State.update_node(state, change["id"], fn node ->
        node = %{node | width: width, height: height, measured: true, resizing: resizing}

        if position do
          %{node | position: position}
        else
          node
        end
      end)
    else
      :error -> state
    end
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

  @doc """
  Creates a resize change.
  """
  @spec resize(String.t(), number(), number(), map() | nil) :: map()
  def resize(id, width, height, position \\ nil) do
    change = %{
      "type" => "resize",
      "id" => id,
      "width" => width,
      "height" => height,
      "resizing" => false
    }

    if position, do: Map.put(change, "position", position), else: change
  end

  defp build_node(node_data) when is_map(node_data) do
    id = node_data["id"]

    with true <- not is_nil(id),
         {:ok, position} <- fetch_position(node_data["position"]) do
      {:ok,
       Node.new(
         id,
         position,
         Map.get(node_data, "data", %{}),
         type: parse_node_type(node_data["type"])
       )}
    else
      _ -> :error
    end
  end

  defp build_node(_node_data), do: :error

  # Change payloads arrive from the browser, so every number is untrusted:
  # a malformed one drops the change instead of crashing the LiveView that
  # applies it (and, in collaborative flows, every peer it is relayed to).
  defp fetch_position(%{"x" => x, "y" => y}), do: build_position(x, y)
  defp fetch_position(%{x: x, y: y}), do: build_position(x, y)
  defp fetch_position(_position), do: :error

  defp fetch_optional_position(nil), do: {:ok, nil}
  defp fetch_optional_position(position), do: fetch_position(position)

  defp build_position(x, y) when is_number(x) and is_number(y) do
    {:ok, %{x: x / 1.0, y: y / 1.0}}
  end

  defp build_position(_x, _y), do: :error

  defp fetch_dimension(value) when is_number(value), do: {:ok, value}
  defp fetch_dimension(_value), do: :error

  defp stringify_keys(map) when is_map(map) do
    map
    |> Enum.map(fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), stringify_keys(v)}
      {k, v} -> {k, stringify_keys(v)}
    end)
    |> Map.new()
  end

  defp stringify_keys(value), do: value

  # A node type the client names must already exist as an atom; anything else
  # draws as a default node instead of crashing the page.
  defp parse_node_type(type) when is_binary(type) do
    String.to_existing_atom(type)
  rescue
    ArgumentError -> :default
  end

  defp parse_node_type(type) when is_atom(type) and not is_nil(type), do: type
  defp parse_node_type(_type), do: :default
end
