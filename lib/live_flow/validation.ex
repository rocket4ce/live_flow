defmodule LiveFlow.Validation do
  @moduledoc """
  Connection validation functions for LiveFlow.

  Provides composable validator functions that check whether a connection
  between two nodes/handles should be allowed. Each validator takes a flow
  state and connection params, returning `:ok` or `{:error, reason}`.

  ## Usage

  Validators can be composed in a list and run with `validate/3`:

      validators = [
        &LiveFlow.Validation.no_duplicate_edges/2,
        &LiveFlow.Validation.nodes_exist/2,
        &LiveFlow.Validation.no_cycles/2
      ]

      case LiveFlow.Validation.validate(flow, params, validators) do
        :ok -> # create the edge
        {:error, reason} -> # reject with reason
      end

  Or use presets for common combinations:

      validators = LiveFlow.Validation.preset(:strict)

  ## Presets

    * `:default` — no duplicate edges + nodes exist
    * `:strict` — default + handles valid + connectable check
  """

  alias LiveFlow.{State, Handle}

  @type conn_params :: %{
          source: String.t(),
          target: String.t(),
          source_handle: String.t() | nil,
          target_handle: String.t() | nil
        }

  @type validator :: (State.t(), conn_params() -> :ok | {:error, String.t()})

  @doc """
  Runs a list of validators against the given flow and connection params.

  Returns `:ok` if all validators pass, or `{:error, reason}` on the
  first failure (short-circuits).
  """
  @spec validate(State.t(), conn_params(), [validator()]) :: :ok | {:error, String.t()}
  def validate(flow, params, validators) do
    Enum.reduce_while(validators, :ok, fn validator, :ok ->
      case validator.(flow, params) do
        :ok -> {:cont, :ok}
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  @doc """
  Returns a preset list of validators.

    * `:default` — `[no_duplicate_edges, nodes_exist]`
    * `:strict` — default + `[handles_valid]`
  """
  @spec preset(:default | :strict) :: [validator()]
  def preset(:default), do: [&no_duplicate_edges/2, &nodes_exist/2]
  def preset(:strict), do: preset(:default) ++ [&handles_valid/2]

  # ===== Built-in Validators =====

  @doc """
  Rejects duplicate edges between the same source/target/handles.

  Uses `State.edge_exists?/5` which was previously unused.
  """
  @spec no_duplicate_edges(State.t(), conn_params()) :: :ok | {:error, String.t()}
  def no_duplicate_edges(flow, params) do
    if State.edge_exists?(flow, params.source, params.target,
         params.source_handle, params.target_handle) do
      {:error, "Connection already exists"}
    else
      :ok
    end
  end

  @doc """
  Validates that both source and target nodes exist in the flow.
  """
  @spec nodes_exist(State.t(), conn_params()) :: :ok | {:error, String.t()}
  def nodes_exist(flow, params) do
    cond do
      is_nil(State.get_node(flow, params.source)) ->
        {:error, "Source node not found"}

      is_nil(State.get_node(flow, params.target)) ->
        {:error, "Target node not found"}

      true ->
        :ok
    end
  end

  @doc """
  Validates that the source and target handles exist on their respective
  nodes and that both handles have `connectable: true`.
  """
  @spec handles_valid(State.t(), conn_params()) :: :ok | {:error, String.t()}
  def handles_valid(flow, params) do
    with {:ok, source_node} <- fetch_node(flow, params.source, "Source"),
         {:ok, target_node} <- fetch_node(flow, params.target, "Target"),
         :ok <- check_handle(source_node, params.source_handle, :source),
         :ok <- check_handle(target_node, params.target_handle, :target) do
      :ok
    end
  end

  @doc """
  Validates that both handles share the same `connect_type`.

  If either handle has no `connect_type` set (nil), the check passes.
  Only rejects when both handles have explicit types that don't match.
  """
  @spec types_compatible(State.t(), conn_params()) :: :ok | {:error, String.t()}
  def types_compatible(flow, params) do
    with {:ok, source_node} <- fetch_node(flow, params.source, "Source"),
         {:ok, target_node} <- fetch_node(flow, params.target, "Target") do
      source_handle = find_handle(source_node, params.source_handle, :source)
      target_handle = find_handle(target_node, params.target_handle, :target)

      source_type = source_handle && source_handle.connect_type
      target_type = target_handle && target_handle.connect_type

      cond do
        is_nil(source_type) or is_nil(target_type) -> :ok
        source_type == target_type -> :ok
        true -> {:error, "Incompatible types: #{source_type} → #{target_type}"}
      end
    end
  end

  @doc """
  Limits the maximum number of connections per handle.

  Checks both the source and target handles. If either already has
  `max` or more connections, the new connection is rejected.

  ## Options

    * `:max` - Maximum connections per handle (required)
  """
  @spec max_connections(State.t(), conn_params(), keyword()) :: :ok | {:error, String.t()}
  def max_connections(flow, params, opts) do
    max = Keyword.fetch!(opts, :max)
    edges = Map.values(flow.edges)

    source_count =
      Enum.count(edges, fn e ->
        e.source == params.source and
          (is_nil(params.source_handle) or e.source_handle == params.source_handle)
      end)

    target_count =
      Enum.count(edges, fn e ->
        e.target == params.target and
          (is_nil(params.target_handle) or e.target_handle == params.target_handle)
      end)

    cond do
      source_count >= max ->
        {:error, "Source handle already has #{max} connection(s)"}

      target_count >= max ->
        {:error, "Target handle already has #{max} connection(s)"}

      true ->
        :ok
    end
  end

  @doc """
  Prevents cycles in the flow graph.

  Rejects a connection if there is already a path from the target node
  back to the source node (which would create a cycle).
  """
  @spec no_cycles(State.t(), conn_params()) :: :ok | {:error, String.t()}
  def no_cycles(flow, params) do
    if has_path?(flow, params.target, params.source) do
      {:error, "Connection would create a cycle"}
    else
      :ok
    end
  end

  # ===== Private Helpers =====

  defp fetch_node(flow, node_id, label) do
    case State.get_node(flow, node_id) do
      nil -> {:error, "#{label} node not found"}
      node -> {:ok, node}
    end
  end

  defp find_handle(node, handle_id, expected_type) do
    Enum.find(node.handles, fn h ->
      Handle.effective_id(h) == (handle_id || Atom.to_string(expected_type)) and
        h.type == expected_type
    end)
  end

  defp check_handle(node, handle_id, expected_type) do
    handle = find_handle(node, handle_id, expected_type)

    cond do
      is_nil(handle) ->
        {:error, "Handle '#{handle_id || expected_type}' not found on node '#{node.id}'"}

      not handle.connectable ->
        {:error, "Handle '#{Handle.effective_id(handle)}' on node '#{node.id}' is not connectable"}

      true ->
        :ok
    end
  end

  defp has_path?(flow, from_node_id, to_node_id) do
    do_has_path?(flow, [from_node_id], MapSet.new(), to_node_id)
  end

  defp do_has_path?(_flow, [], _visited, _target), do: false

  defp do_has_path?(flow, [current | rest], visited, target) do
    if current == target do
      true
    else
      if MapSet.member?(visited, current) do
        do_has_path?(flow, rest, visited, target)
      else
        visited = MapSet.put(visited, current)

        # Find all nodes reachable from current
        neighbors =
          flow.edges
          |> Map.values()
          |> Enum.filter(fn e -> e.source == current end)
          |> Enum.map(fn e -> e.target end)

        do_has_path?(flow, neighbors ++ rest, visited, target)
      end
    end
  end
end
