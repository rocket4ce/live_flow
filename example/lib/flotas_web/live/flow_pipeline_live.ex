defmodule FlotasWeb.FlowPipelineLive do
  @moduledoc """
  Visual Pipeline Builder — an executable workflow engine demo.
  Wire nodes together and click "Run" to watch data flow through the pipeline in real-time.
  """

  use FlotasWeb, :live_view

  alias LiveFlow.{State, Node, Edge, Handle, Layout}
  alias Flotas.Pipeline.Engine

  @impl true
  def mount(_params, _session, socket) do
    flow = create_demo_pipeline()

    {:ok,
     assign(socket,
       page_title: "Pipeline Builder",
       flow: flow,
       node_types: %{
         start: FlotasWeb.FlowPipeline.StartNode,
         http: FlotasWeb.FlowPipeline.HttpNode,
         transform: FlotasWeb.FlowPipeline.TransformNode,
         condition: FlotasWeb.FlowPipeline.ConditionNode,
         delay: FlotasWeb.FlowPipeline.DelayNode,
         log: FlotasWeb.FlowPipeline.LogNode
       },
       pipeline_status: :idle,
       node_statuses: %{},
       selected_output: nil,
       pipeline_pid: nil,
       total_time: nil
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="h-screen flex flex-col">
        <div class="p-4 bg-base-200 border-b border-base-300">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-2xl font-bold">Pipeline Builder</h1>
              <p class="text-sm text-base-content/70">
                Visual workflow engine — wire nodes and click Run to execute
              </p>
            </div>
            <div class="flex items-center gap-3">
              <button
                :if={@pipeline_status != :running}
                class="btn btn-sm btn-success"
                phx-click="run_pipeline"
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
                  <polygon points="5 3 19 12 5 21 5 3" />
                </svg>
                Run Pipeline
              </button>
              <button
                :if={@pipeline_status == :running}
                class="btn btn-sm btn-error"
                phx-click="stop_pipeline"
              >
                Stop
              </button>
              <button class="btn btn-sm btn-secondary" phx-click="reset_pipeline">
                Reset
              </button>
              <button class="btn btn-sm" phx-click="fit_view">
                Fit View
              </button>
              <button class="btn btn-sm btn-accent" phx-click={JS.dispatch("lf:auto-layout", to: "#pipeline-flow")}>
                Auto Layout
              </button>
              <.pipeline_status_badge status={@pipeline_status} total_time={@total_time} />
            </div>
          </div>
        </div>

        <div class="flex-1 relative">
          <.live_component
            module={LiveFlow.Components.Flow}
            id="pipeline-flow"
            flow={@flow}
            opts={
              %{
                controls: true,
                minimap: true,
                background: :dots,
                fit_view_on_init: true,
                snap_to_grid: true,
                snap_grid: {20, 20}
              }
            }
            node_types={@node_types}
          />

          <div
            :if={@selected_output}
            class="absolute top-2 right-2 w-80 max-h-[calc(100%-1rem)] border border-base-300 bg-base-100 rounded-lg shadow-lg overflow-y-auto z-50"
          >
            <.output_panel
              node_id={@selected_output}
              node={@flow.nodes[@selected_output]}
              status={Map.get(@node_statuses, @selected_output, %{})}
            />
          </div>
        </div>

        <div class="p-4 bg-base-200 border-t border-base-300">
          <div class="text-sm">
            <span class="font-medium">Nodes:</span> {map_size(@flow.nodes)} |
            <span class="font-medium">Edges:</span> {map_size(@flow.edges)} |
            <span class="font-medium">Status:</span> {@pipeline_status}
            <span :if={@total_time} class="text-base-content/60">({@total_time}ms)</span>
          </div>
          <div class="text-xs text-base-content/60 mt-1">
            Click "Run Pipeline" to execute | Click a node to see its output | Drag to rearrange
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :status, :atom, required: true
  attr :total_time, :integer, default: nil

  defp pipeline_status_badge(assigns) do
    ~H"""
    <div class={[
      "badge badge-lg",
      @status == :idle && "badge-ghost",
      @status == :running && "badge-info",
      @status == :completed && "badge-success",
      @status == :error && "badge-error"
    ]}>
      {case @status do
        :idle -> "Ready"
        :running -> "Running..."
        :completed -> "Completed"
        :error -> "Error"
      end}
    </div>
    """
  end

  attr :node_id, :string, required: true
  attr :node, :map, required: true
  attr :status, :map, required: true

  defp output_panel(assigns) do
    input = Map.get(assigns.status, :input)
    output = Map.get(assigns.status, :output)
    error = Map.get(assigns.status, :error)
    duration = Map.get(assigns.status, :duration_ms)
    node_status = Map.get(assigns.status, :status, :idle)
    node_label = get_node_label(assigns.node)

    assigns =
      assigns
      |> assign(:input, input)
      |> assign(:output, output)
      |> assign(:error, error)
      |> assign(:duration, duration)
      |> assign(:node_status, node_status)
      |> assign(:node_label, node_label)

    ~H"""
    <div class="p-4">
      <div class="flex items-center justify-between mb-4">
        <h3 class="font-bold text-lg">{@node_label}</h3>
        <button class="btn btn-xs btn-ghost" phx-click="close_output">x</button>
      </div>

      <div :if={@node_status != :idle} class="space-y-4">
        <div>
          <div class="text-xs font-medium text-base-content/60 mb-1">Status</div>
          <div class={[
            "badge",
            @node_status == :running && "badge-info",
            @node_status == :success && "badge-success",
            @node_status == :error && "badge-error"
          ]}>
            {@node_status}
          </div>
          <span :if={@duration} class="text-xs text-base-content/50 ml-2">{@duration}ms</span>
        </div>

        <div :if={@input}>
          <div class="text-xs font-medium text-base-content/60 mb-1">Input</div>
          <pre class="text-xs bg-base-200 rounded p-2 overflow-x-auto max-h-40 overflow-y-auto">{format_data(@input)}</pre>
        </div>

        <div :if={@output}>
          <div class="text-xs font-medium text-base-content/60 mb-1">Output</div>
          <pre class="text-xs bg-base-200 rounded p-2 overflow-x-auto max-h-60 overflow-y-auto">{format_data(@output)}</pre>
        </div>

        <div :if={@error}>
          <div class="text-xs font-medium text-base-content/60 mb-1">Error</div>
          <pre class="text-xs bg-error/10 text-error rounded p-2">{@error}</pre>
        </div>
      </div>

      <div :if={@node_status == :idle} class="text-sm text-base-content/50">
        Run the pipeline to see output.
      </div>
    </div>
    """
  end

  # Pipeline execution events

  @impl true
  def handle_event("run_pipeline", _params, socket) do
    if socket.assigns.pipeline_status == :running do
      {:noreply, socket}
    else
      # Merge current statuses into node data for rendering, resetting all to idle
      flow = reset_node_statuses(socket.assigns.flow)
      pid = Engine.execute(flow, self())

      {:noreply,
       assign(socket,
         flow: flow,
         pipeline_status: :running,
         node_statuses: %{},
         pipeline_pid: pid,
         total_time: nil
       )}
    end
  end

  @impl true
  def handle_event("stop_pipeline", _params, socket) do
    if socket.assigns.pipeline_pid do
      Process.exit(socket.assigns.pipeline_pid, :kill)
    end

    {:noreply, assign(socket, pipeline_status: :idle, pipeline_pid: nil)}
  end

  @impl true
  def handle_event("reset_pipeline", _params, socket) do
    flow = reset_node_statuses(socket.assigns.flow)

    {:noreply,
     assign(socket,
       flow: flow,
       pipeline_status: :idle,
       node_statuses: %{},
       selected_output: nil,
       total_time: nil
     )}
  end

  @impl true
  def handle_event("fit_view", _params, socket) do
    {:noreply, push_event(socket, "lf:fit_view", %{padding: 0.1, duration: 200})}
  end

  @impl true
  def handle_event("close_output", _params, socket) do
    {:noreply, assign(socket, selected_output: nil)}
  end

  # LiveFlow events

  @impl true
  def handle_event("lf:node_change", %{"changes" => changes}, socket) do
    flow =
      Enum.reduce(changes, socket.assigns.flow, fn change, acc ->
        apply_node_change(acc, change)
      end)

    {:noreply, assign(socket, flow: flow)}
  end

  @impl true
  def handle_event("lf:edge_change", %{"changes" => changes}, socket) do
    flow =
      Enum.reduce(changes, socket.assigns.flow, fn
        %{"type" => "remove", "id" => id}, acc -> State.remove_edge(acc, id)
        _change, acc -> acc
      end)

    {:noreply, assign(socket, flow: flow)}
  end

  @impl true
  def handle_event("lf:connect_end", params, socket) do
    source = params["source"]
    target = params["target"]

    if source && target && source != target do
      edge_id = "e-#{System.unique_integer([:positive])}"

      edge =
        Edge.new(edge_id, source, target,
          source_handle: params["source_handle"],
          target_handle: params["target_handle"],
          marker_end: %{type: :arrow_closed, color: "#64748b"}
        )

      flow = State.add_edge(socket.assigns.flow, edge)
      {:noreply, assign(socket, flow: flow)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("lf:selection_change", %{"nodes" => node_ids, "edges" => edge_ids}, socket) do
    flow =
      socket.assigns.flow
      |> Map.put(:selected_nodes, MapSet.new(node_ids))
      |> Map.put(:selected_edges, MapSet.new(edge_ids))

    nodes =
      Enum.reduce(flow.nodes, %{}, fn {id, node}, acc ->
        Map.put(acc, id, %{node | selected: id in node_ids})
      end)

    edges =
      Enum.reduce(flow.edges, %{}, fn {id, edge}, acc ->
        Map.put(acc, id, %{edge | selected: id in edge_ids})
      end)

    flow = %{flow | nodes: nodes, edges: edges}

    {:noreply, assign(socket, flow: flow)}
  end

  @impl true
  def handle_event("lf:delete_selected", _params, socket) do
    flow = State.delete_selected(socket.assigns.flow)
    {:noreply, assign(socket, flow: flow)}
  end

  @impl true
  def handle_event("lf:viewport_change", params, socket) do
    flow = State.update_viewport(socket.assigns.flow, params)
    {:noreply, assign(socket, flow: flow)}
  end

  @impl true
  def handle_event("lf:request_layout", params, socket) do
    data = Layout.prepare_layout_data(socket.assigns.flow, params)
    {:noreply, push_event(socket, "lf:layout_data", data)}
  end

  @impl true
  def handle_event("lf:" <> _event, _params, socket) do
    {:noreply, socket}
  end

  # Pipeline execution messages

  @impl true
  def handle_info({:pipeline_started}, socket) do
    {:noreply, assign(socket, pipeline_status: :running)}
  end

  @impl true
  def handle_info({:node_started, node_id}, socket) do
    node_statuses = Map.put(socket.assigns.node_statuses, node_id, %{status: :running})

    flow =
      socket.assigns.flow
      |> update_node_data_status(node_id, :running)
      |> set_edges_targeting(node_id, "pipeline-edge-flowing")

    {:noreply, assign(socket, node_statuses: node_statuses, flow: flow)}
  end

  @impl true
  def handle_info({:node_completed, node_id, output, duration_ms, extra}, socket) do
    status_entry = %{
      status: :success,
      output: output,
      duration_ms: duration_ms,
      input: get_node_input_from_statuses(node_id, socket.assigns.flow, socket.assigns.node_statuses)
    }

    status_entry =
      case extra do
        {:branch, value} -> Map.put(status_entry, :branch_taken, value)
        _ -> status_entry
      end

    node_statuses = Map.put(socket.assigns.node_statuses, node_id, status_entry)

    flow =
      socket.assigns.flow
      |> update_node_data_status(node_id, :success)
      |> update_node_data_field(node_id, :output, output)
      |> update_node_data_field(node_id, :duration_ms, duration_ms)

    flow =
      case extra do
        {:branch, value} -> update_node_data_field(flow, node_id, :branch_taken, value)
        _ -> flow
      end

    # Mark incoming edges as completed, outgoing edges as flowing
    flow =
      flow
      |> set_edges_targeting(node_id, "pipeline-edge-completed")
      |> set_edges_from(node_id, "pipeline-edge-flowing", extra)

    {:noreply, assign(socket, node_statuses: node_statuses, flow: flow)}
  end

  @impl true
  def handle_info({:node_error, node_id, reason, _duration_ms}, socket) do
    node_statuses =
      Map.put(socket.assigns.node_statuses, node_id, %{
        status: :error,
        error: reason,
        input: get_node_input_from_statuses(node_id, socket.assigns.flow, socket.assigns.node_statuses)
      })

    flow =
      socket.assigns.flow
      |> update_node_data_status(node_id, :error)
      |> set_edges_targeting(node_id, "pipeline-edge-completed")

    {:noreply, assign(socket, node_statuses: node_statuses, flow: flow)}
  end

  @impl true
  def handle_info({:pipeline_completed, total_ms}, socket) do
    {:noreply,
     assign(socket,
       pipeline_status: :completed,
       pipeline_pid: nil,
       total_time: total_ms
     )}
  end

  @impl true
  def handle_info({:pipeline_error, reason}, socket) do
    {:noreply,
     assign(socket,
       pipeline_status: :error,
       pipeline_pid: nil
     )
     |> put_flash(:error, "Pipeline error: #{reason}")}
  end

  @impl true
  def handle_info({:lf_node_click, node_id}, socket) do
    {:noreply, assign(socket, selected_output: node_id)}
  end

  # Node change helpers

  defp apply_node_change(flow, %{"type" => "position", "id" => id, "position" => pos} = change) do
    case Map.get(flow.nodes, id) do
      nil ->
        flow

      node ->
        updated = %{
          node
          | position: %{x: pos["x"] / 1, y: pos["y"] / 1},
            dragging: Map.get(change, "dragging", false)
        }

        %{flow | nodes: Map.put(flow.nodes, id, updated)}
    end
  end

  defp apply_node_change(flow, %{"type" => "dimensions", "id" => id} = change) do
    case Map.get(flow.nodes, id) do
      nil ->
        flow

      node ->
        updated = %{
          node
          | width: Map.get(change, "width"),
            height: Map.get(change, "height"),
            measured: true
        }

        %{flow | nodes: Map.put(flow.nodes, id, updated)}
    end
  end

  defp apply_node_change(flow, %{"type" => "remove", "id" => id}) do
    State.remove_node(flow, id)
  end

  defp apply_node_change(flow, _change), do: flow

  # Status update helpers

  defp update_node_data_status(flow, node_id, status) do
    update_node_data_field(flow, node_id, :status, status)
  end

  defp update_node_data_field(flow, node_id, field, value) do
    case Map.get(flow.nodes, node_id) do
      nil ->
        flow

      node ->
        updated_data = Map.put(node.data, field, value)
        updated_node = %{node | data: updated_data}
        %{flow | nodes: Map.put(flow.nodes, node_id, updated_node)}
    end
  end

  defp reset_node_statuses(flow) do
    nodes =
      Enum.reduce(flow.nodes, %{}, fn {id, node}, acc ->
        clean_data =
          node.data
          |> Map.drop([:status, :output, :duration_ms, :branch_taken, :error])

        Map.put(acc, id, %{node | data: clean_data})
      end)

    # Reset edge styles and classes
    edges =
      Enum.reduce(flow.edges, %{}, fn {id, edge}, acc ->
        Map.put(acc, id, %{edge | style: %{}, animated: false, class: nil})
      end)

    %{flow | nodes: nodes, edges: edges}
  end

  # Set CSS class on all edges targeting a specific node
  defp set_edges_targeting(flow, target_node_id, class) do
    edges =
      Enum.reduce(flow.edges, flow.edges, fn {id, edge}, acc ->
        if edge.target == target_node_id do
          Map.put(acc, id, %{edge | class: class, style: %{}, animated: false})
        else
          acc
        end
      end)

    %{flow | edges: edges}
  end

  # Set CSS class on edges from a source node, respecting condition branches
  defp set_edges_from(flow, source_node_id, class, extra) do
    edges =
      Enum.reduce(flow.edges, flow.edges, fn {id, edge}, acc ->
        if edge.source == source_node_id do
          case extra do
            {:branch, true} ->
              cond do
                edge.source_handle == "true-out" ->
                  Map.put(acc, id, %{edge | class: class, style: %{}, animated: false})

                edge.source_handle == "false-out" ->
                  Map.put(acc, id, %{edge | class: "pipeline-edge-inactive", style: %{}, animated: false})

                true ->
                  Map.put(acc, id, %{edge | class: class, style: %{}, animated: false})
              end

            {:branch, false} ->
              cond do
                edge.source_handle == "false-out" ->
                  Map.put(acc, id, %{edge | class: class, style: %{}, animated: false})

                edge.source_handle == "true-out" ->
                  Map.put(acc, id, %{edge | class: "pipeline-edge-inactive", style: %{}, animated: false})

                true ->
                  Map.put(acc, id, %{edge | class: class, style: %{}, animated: false})
              end

            _ ->
              Map.put(acc, id, %{edge | class: class, style: %{}, animated: false})
          end
        else
          acc
        end
      end)

    %{flow | edges: edges}
  end

  defp get_node_input_from_statuses(node_id, flow, statuses) do
    upstream_edge =
      Enum.find(flow.edges, fn {_id, edge} -> edge.target == node_id end)

    case upstream_edge do
      nil -> nil
      {_id, edge} -> get_in(statuses, [edge.source, :output])
    end
  end

  defp get_node_label(nil), do: "Node"

  defp get_node_label(node) do
    Map.get(node.data, :label) ||
      Map.get(node.data, :action) ||
      to_string(node.type) |> String.capitalize()
  end

  defp format_data(data) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, decoded} -> Jason.encode!(decoded, pretty: true)
      _ -> data
    end
  end

  defp format_data(data) do
    inspect(data, pretty: true, limit: 20, printable_limit: 500)
  end

  # Demo pipeline

  defp create_demo_pipeline do
    nodes = [
      Node.new("start-1", %{x: 50, y: 200}, %{
        label: "Start",
        payload: %{"city" => "London", "units" => "metric"}
      },
        type: :start,
        handles: [Handle.source(:right)]
      ),
      Node.new("http-1", %{x: 300, y: 200}, %{
        label: "HTTP Request",
        method: "GET",
        url: "https://wttr.in/{{city}}?format=j1"
      },
        type: :http,
        handles: [Handle.target(:left), Handle.source(:right)]
      ),
      Node.new("transform-1", %{x: 560, y: 200}, %{
        label: "Extract Temp",
        expression: ~s|get_in(data, ["current_condition", Access.at(0), "temp_C"])|
      },
        type: :transform,
        handles: [Handle.target(:left), Handle.source(:right)]
      ),
      Node.new("condition-1", %{x: 820, y: 200}, %{
        label: "Warm?",
        expression: "String.to_integer(data) > 15"
      },
        type: :condition,
        handles: [
          Handle.target(:left),
          Handle.source(:right, id: "true-out"),
          Handle.source(:bottom, id: "false-out")
        ]
      ),
      Node.new("log-warm", %{x: 1100, y: 150}, %{
        label: "Warm Day!"
      },
        type: :log,
        handles: [Handle.target(:left)]
      ),
      Node.new("log-cold", %{x: 1100, y: 350}, %{
        label: "Cold Day!"
      },
        type: :log,
        handles: [Handle.target(:left)]
      )
    ]

    edges = [
      Edge.new("e1", "start-1", "http-1",
        marker_end: %{type: :arrow_closed, color: "#64748b"}
      ),
      Edge.new("e2", "http-1", "transform-1",
        marker_end: %{type: :arrow_closed, color: "#64748b"}
      ),
      Edge.new("e3", "transform-1", "condition-1",
        marker_end: %{type: :arrow_closed, color: "#64748b"}
      ),
      Edge.new("e4", "condition-1", "log-warm",
        source_handle: "true-out",
        marker_end: %{type: :arrow_closed, color: "#22c55e"},
        style: %{"stroke" => "#22c55e"}
      ),
      Edge.new("e5", "condition-1", "log-cold",
        source_handle: "false-out",
        marker_end: %{type: :arrow_closed, color: "#ef4444"},
        style: %{"stroke" => "#ef4444"}
      )
    ]

    State.new(nodes: nodes, edges: edges)
  end
end
