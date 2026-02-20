defmodule Example.Pipeline.Engine do
  @moduledoc """
  Executes a visual pipeline flow.

  Builds an execution graph from the flow's edges, topologically sorts nodes,
  and executes each node in sequence, sending status messages to the LiveView
  process for real-time UI updates.
  """

  require Logger

  @doc """
  Starts pipeline execution in a spawned process.
  Returns the PID of the execution process.

  Sends messages to `caller_pid`:
  - `{:pipeline_started}`
  - `{:node_started, node_id}`
  - `{:node_completed, node_id, output, duration_ms}`
  - `{:node_error, node_id, reason}`
  - `{:pipeline_completed, total_ms}`
  - `{:pipeline_error, reason}`
  """
  def execute(flow, caller_pid) do
    spawn(fn ->
      start_time = System.monotonic_time(:millisecond)
      send(caller_pid, {:pipeline_started})

      try do
        graph = build_graph(flow)
        sorted = topological_sort(graph, flow)
        run_pipeline(sorted, flow, caller_pid)

        total_ms = System.monotonic_time(:millisecond) - start_time
        send(caller_pid, {:pipeline_completed, total_ms})
      rescue
        e ->
          send(caller_pid, {:pipeline_error, Exception.message(e)})
      end
    end)
  end

  # Build adjacency list from edges: %{source_id => [{target_id, source_handle, target_handle}]}
  defp build_graph(flow) do
    Enum.reduce(flow.edges, %{}, fn {_id, edge}, acc ->
      entry = {edge.target, edge.source_handle, edge.target_handle}
      Map.update(acc, edge.source, [entry], &[entry | &1])
    end)
  end

  # Topological sort using Kahn's algorithm
  defp topological_sort(graph, flow) do
    node_ids = Map.keys(flow.nodes)

    # Calculate in-degrees
    in_degrees =
      Enum.reduce(graph, Map.new(node_ids, fn id -> {id, 0} end), fn {_src, targets}, acc ->
        Enum.reduce(targets, acc, fn {target_id, _, _}, inner_acc ->
          Map.update(inner_acc, target_id, 1, &(&1 + 1))
        end)
      end)

    # Start with nodes that have no incoming edges
    queue =
      in_degrees
      |> Enum.filter(fn {_id, deg} -> deg == 0 end)
      |> Enum.map(fn {id, _} -> id end)

    do_topo_sort(queue, graph, in_degrees, [])
  end

  defp do_topo_sort([], _graph, _in_degrees, result), do: Enum.reverse(result)

  defp do_topo_sort([node_id | rest], graph, in_degrees, result) do
    targets = Map.get(graph, node_id, [])

    {new_queue_additions, new_in_degrees} =
      Enum.reduce(targets, {[], in_degrees}, fn {target_id, _, _}, {queue_acc, deg_acc} ->
        new_deg = Map.get(deg_acc, target_id, 1) - 1
        deg_acc = Map.put(deg_acc, target_id, new_deg)

        if new_deg == 0 do
          {[target_id | queue_acc], deg_acc}
        else
          {queue_acc, deg_acc}
        end
      end)

    do_topo_sort(rest ++ new_queue_additions, graph, new_in_degrees, [node_id | result])
  end

  # Execute pipeline in topological order
  defp run_pipeline(sorted_node_ids, flow, caller_pid) do
    # outputs tracks: %{node_id => output_data}
    Enum.reduce(sorted_node_ids, %{}, fn node_id, outputs ->
      node = Map.get(flow.nodes, node_id)

      if node do
        # Get input: find which upstream node feeds into this one
        input = get_node_input(node_id, flow, outputs)

        # Skip nodes on inactive condition branches
        if input == :skip do
          Map.put(outputs, node_id, :skip)
        else
          send(caller_pid, {:node_started, node_id})

          start_time = System.monotonic_time(:millisecond)

          try do
            result = execute_node(node.type, node, input)
            duration = System.monotonic_time(:millisecond) - start_time

            case result do
              {:condition, branch_value, output} ->
                send(caller_pid, {:node_completed, node_id, output, duration, {:branch, branch_value}})
                Map.put(outputs, node_id, {:branched, branch_value, output})

              output ->
                send(caller_pid, {:node_completed, node_id, output, duration, nil})
                Map.put(outputs, node_id, output)
            end
          rescue
            e ->
              duration = System.monotonic_time(:millisecond) - start_time
              send(caller_pid, {:node_error, node_id, Exception.message(e), duration})
              Map.put(outputs, node_id, :error)
          end
        end
      else
        outputs
      end
    end)
  end

  # Find input data for a node by looking at upstream edges
  defp get_node_input(node_id, flow, outputs) do
    # Find edges that point TO this node
    upstream_edge =
      Enum.find(flow.edges, fn {_id, edge} -> edge.target == node_id end)

    case upstream_edge do
      nil ->
        nil

      {_id, edge} ->
        case Map.get(outputs, edge.source) do
          {:branched, branch_value, output} ->
            # Only pass data if this node is on the correct branch
            if should_receive_branch?(edge, branch_value) do
              output
            else
              :skip
            end

          output ->
            output
        end
    end
  end

  # Check if an edge should carry data based on condition branch
  # Convention: source_handle "true" for right, "false" for bottom
  defp should_receive_branch?(edge, branch_value) do
    handle = edge.source_handle

    cond do
      handle == "true-out" -> branch_value == true
      handle == "false-out" -> branch_value == false
      true -> true
    end
  end

  # Execute individual node types
  defp execute_node(:start, node, _input) do
    Map.get(node.data, :payload, %{})
  end

  defp execute_node(:http, node, input) do
    url = interpolate_url(Map.get(node.data, :url, ""), input)
    method = Map.get(node.data, :method, "GET")
    opts = [receive_timeout: 10_000, retry: :transient, max_retries: 1]

    response =
      case method do
        "POST" -> Req.post!(url, [json: input] ++ opts)
        "PUT" -> Req.put!(url, [json: input] ++ opts)
        _ -> Req.get!(url, opts)
      end

    response.body
  end

  defp execute_node(:transform, node, input) do
    expression = Map.get(node.data, :expression, "data")
    {result, _binding} = Code.eval_string(expression, data: input)
    result
  end

  defp execute_node(:condition, node, input) do
    expression = Map.get(node.data, :expression, "true")
    {result, _binding} = Code.eval_string(expression, data: input)
    {:condition, result == true, input}
  end

  defp execute_node(:delay, node, input) do
    delay_ms = Map.get(node.data, :delay, 1000)
    Process.sleep(delay_ms)
    input
  end

  defp execute_node(:log, _node, input) do
    input
  end

  defp execute_node(_type, _node, input) do
    input
  end

  # Replace {{key}} patterns in URL with values from input data
  defp interpolate_url(url, nil), do: url
  defp interpolate_url(url, :skip), do: url

  defp interpolate_url(url, input) when is_map(input) do
    Regex.replace(~r/\{\{(\w+)\}\}/, url, fn _full, key ->
      input
      |> Map.get(key, Map.get(input, String.to_atom(key), ""))
      |> to_string()
    end)
  end

  defp interpolate_url(url, _input), do: url
end
