defmodule LiveFlow.Changes.EdgeChange do
  @moduledoc """
  Edge change event types for LiveFlow.

  Edge changes describe mutations to edges that are sent from the JS hook
  to the LiveView.

  ## Change Types

    * `:add` - Edge was added (connection made)
    * `:remove` - Edge was removed
    * `:select` - Edge selection changed
    * `:replace` - Edge was replaced

  ## Examples

      # Edge added from connection
      %{"type" => "add", "edge" => %{"id" => "e1", "source" => "a", "target" => "b"}}

      # Edge selection
      %{"type" => "select", "id" => "e1", "selected" => true}
  """

  alias LiveFlow.{State, Edge}

  @type add_change :: %{
          type: :add,
          edge: map()
        }

  @type remove_change :: %{
          type: :remove,
          id: String.t()
        }

  @type selection_change :: %{
          type: :select,
          id: String.t(),
          selected: boolean()
        }

  @type replace_change :: %{
          type: :replace,
          edge: map()
        }

  @type t ::
          add_change()
          | remove_change()
          | selection_change()
          | replace_change()

  @doc """
  Applies a single change to the state.
  """
  @spec apply_change(State.t(), map()) :: State.t()
  def apply_change(state, %{"type" => "add"} = change) do
    edge_data = change["edge"]

    edge =
      Edge.new(
        edge_data["id"],
        edge_data["source"],
        edge_data["target"],
        source_handle: edge_data["source_handle"],
        target_handle: edge_data["target_handle"],
        type: parse_edge_type(edge_data["type"]),
        animated: edge_data["animated"] || false,
        label: edge_data["label"],
        data: Map.get(edge_data, "data", %{})
      )

    State.add_edge(state, edge)
  end

  def apply_change(state, %{"type" => "remove"} = change) do
    State.remove_edge(state, change["id"])
  end

  def apply_change(state, %{"type" => "select"} = change) do
    id = change["id"]
    selected = change["selected"]

    if selected do
      State.select_edge(state, id, multi: true)
    else
      State.update_edge(state, id, selected: false)
    end
  end

  def apply_change(state, %{"type" => "replace"} = change) do
    edge_data = change["edge"]

    edge =
      Edge.new(
        edge_data["id"],
        edge_data["source"],
        edge_data["target"],
        source_handle: edge_data["source_handle"],
        target_handle: edge_data["target_handle"],
        type: parse_edge_type(edge_data["type"]),
        animated: edge_data["animated"] || false,
        label: edge_data["label"],
        data: Map.get(edge_data, "data", %{})
      )

    state
    |> State.remove_edge(edge.id)
    |> State.add_edge(edge)
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
  Creates an add edge change.
  """
  @spec add(map()) :: map()
  def add(edge_data) do
    %{
      "type" => "add",
      "edge" => edge_data
    }
  end

  @doc """
  Creates a remove edge change.
  """
  @spec remove(String.t()) :: map()
  def remove(id) do
    %{
      "type" => "remove",
      "id" => id
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

  defp parse_edge_type(nil), do: :bezier
  defp parse_edge_type(type) when is_atom(type), do: type

  defp parse_edge_type(type) when is_binary(type) do
    case type do
      "bezier" -> :bezier
      "straight" -> :straight
      "step" -> :step
      "smoothstep" -> :smoothstep
      other -> String.to_existing_atom(other)
    end
  rescue
    ArgumentError -> :bezier
  end

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
