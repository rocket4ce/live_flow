defmodule LiveFlow.History do
  @moduledoc """
  Undo/redo history stack for LiveFlow.

  Stores snapshots of `nodes` and `edges` only (not viewport, selection,
  or transient UI state). Elixir's immutable data structures provide
  efficient structural sharing, making full snapshots cheap.

  ## Usage

      # Initialize in mount
      history = LiveFlow.History.new()

      # Before a mutation, save the current state
      history = LiveFlow.History.push(history, flow)
      flow = State.add_edge(flow, edge)

      # Undo
      case LiveFlow.History.undo(history, flow) do
        {:ok, restored_flow, history} -> ...
        :empty -> ...
      end

      # Redo
      case LiveFlow.History.redo(history, flow) do
        {:ok, restored_flow, history} -> ...
        :empty -> ...
      end

  ## Options

    * `:max_entries` — Maximum history entries (default: 50)
  """

  @type snapshot :: %{nodes: map(), edges: map()}

  @type t :: %__MODULE__{
          undo_stack: [snapshot()],
          redo_stack: [snapshot()],
          max_entries: pos_integer()
        }

  defstruct undo_stack: [], redo_stack: [], max_entries: 50

  @doc """
  Creates a new empty history.

  ## Options

    * `:max_entries` — Maximum number of undo entries (default: 50)
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      max_entries: Keyword.get(opts, :max_entries, 50)
    }
  end

  @doc """
  Saves a snapshot of the current flow state to the undo stack.

  Clears the redo stack (a new action after undo invalidates the redo path).
  Trims the undo stack to `max_entries`.
  """
  @spec push(t(), LiveFlow.State.t()) :: t()
  def push(%__MODULE__{} = history, flow) do
    snapshot = take_snapshot(flow)

    undo_stack =
      [snapshot | history.undo_stack]
      |> Enum.take(history.max_entries)

    %{history | undo_stack: undo_stack, redo_stack: []}
  end

  @doc """
  Restores the previous state from the undo stack.

  Pushes the current state onto the redo stack before restoring.
  Returns `{:ok, restored_flow, updated_history}` or `:empty`.
  """
  @spec undo(t(), LiveFlow.State.t()) :: {:ok, LiveFlow.State.t(), t()} | :empty
  def undo(%__MODULE__{undo_stack: [snapshot | rest]} = history, current_flow) do
    current_snapshot = take_snapshot(current_flow)
    restored = restore_flow(current_flow, snapshot)

    updated_history = %{history |
      undo_stack: rest,
      redo_stack: [current_snapshot | history.redo_stack]
    }

    {:ok, restored, updated_history}
  end

  def undo(%__MODULE__{undo_stack: []}, _current_flow), do: :empty

  @doc """
  Re-applies a previously undone state from the redo stack.

  Pushes the current state onto the undo stack before restoring.
  Returns `{:ok, restored_flow, updated_history}` or `:empty`.
  """
  @spec redo(t(), LiveFlow.State.t()) :: {:ok, LiveFlow.State.t(), t()} | :empty
  def redo(%__MODULE__{redo_stack: [snapshot | rest]} = history, current_flow) do
    current_snapshot = take_snapshot(current_flow)
    restored = restore_flow(current_flow, snapshot)

    updated_history = %{history |
      undo_stack: [current_snapshot | history.undo_stack],
      redo_stack: rest
    }

    {:ok, restored, updated_history}
  end

  def redo(%__MODULE__{redo_stack: []}, _current_flow), do: :empty

  @doc "Returns true if there are entries to undo."
  @spec can_undo?(t()) :: boolean()
  def can_undo?(%__MODULE__{undo_stack: [_ | _]}), do: true
  def can_undo?(%__MODULE__{}), do: false

  @doc "Returns true if there are entries to redo."
  @spec can_redo?(t()) :: boolean()
  def can_redo?(%__MODULE__{redo_stack: [_ | _]}), do: true
  def can_redo?(%__MODULE__{}), do: false

  @doc "Returns the number of undo entries."
  @spec undo_count(t()) :: non_neg_integer()
  def undo_count(%__MODULE__{undo_stack: stack}), do: length(stack)

  @doc "Returns the number of redo entries."
  @spec redo_count(t()) :: non_neg_integer()
  def redo_count(%__MODULE__{redo_stack: stack}), do: length(stack)

  # Private

  defp take_snapshot(flow) do
    %{nodes: flow.nodes, edges: flow.edges}
  end

  defp restore_flow(current_flow, snapshot) do
    # Preserve measurement data (width/height/measured) for nodes that exist in both
    nodes =
      Map.new(snapshot.nodes, fn {id, node} ->
        case Map.get(current_flow.nodes, id) do
          nil ->
            {id, node}

          current ->
            {id, %{node | width: current.width, height: current.height, measured: current.measured}}
        end
      end)

    %{current_flow |
      nodes: nodes,
      edges: snapshot.edges,
      selected_nodes: MapSet.new(),
      selected_edges: MapSet.new()
    }
  end
end
