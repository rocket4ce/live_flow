defmodule ExampleWeb.FlowDemoLive do
  @moduledoc """
  Demo page for testing LiveFlow library.
  """

  use ExampleWeb, :live_view

  alias LiveFlow.{State, Node, Edge, Handle, History, Clipboard, Serializer, Layout}
  alias LiveFlow.Validation

  @impl true
  def mount(_params, _session, socket) do
    # Create initial flow state
    flow = create_demo_flow()

    {:ok,
     assign(socket,
       page_title: "LiveFlow Demo",
       flow: flow,
       history: History.new(),
       clipboard: Clipboard.new(),
       node_types: %{},
       lf_theme: nil
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="h-screen flex flex-col">
        <div class="p-4 bg-base-200 border-b border-base-300">
          <h1 class="text-2xl font-bold">LiveFlow Demo</h1>
          <p class="text-sm text-base-content/70">Interactive node-based flow diagram</p>

          <div class="flex gap-2 mt-3 items-center">
            <button class="btn btn-sm btn-primary" phx-click="add_node">
              Add Node
            </button>
            <button class="btn btn-sm btn-secondary" phx-click="reset_flow">
              Reset
            </button>
            <button class="btn btn-sm" phx-click="fit_view">
              Fit View
            </button>
            <button class="btn btn-sm btn-accent" phx-click={JS.dispatch("lf:auto-layout", to: "#demo-flow")}>
              Auto Layout
            </button>
            <div class="divider divider-horizontal mx-1"></div>
            <button class="btn btn-sm btn-outline" phx-click="export_json" id="export-btn">
              Export JSON
            </button>
            <button
              class="btn btn-sm btn-outline"
              onclick="document.getElementById('import-file-input').click()"
            >
              Import JSON
            </button>
            <input
              type="file"
              id="import-file-input"
              accept=".json"
              class="hidden"
              phx-hook="FileImport"
            />
            <button class="btn btn-sm btn-outline" phx-click={JS.dispatch("lf:export-svg", to: "#demo-flow")}>
              SVG
            </button>
            <button class="btn btn-sm btn-outline" phx-click={JS.dispatch("lf:export-png", to: "#demo-flow")}>
              PNG
            </button>
            <div class="divider divider-horizontal mx-1"></div>
            <form phx-change="change_theme" class="flex items-center gap-2">
              <label class="text-sm font-medium">Theme:</label>
              <select class="select select-sm select-bordered w-40" name="theme">
                <option value="" selected={@lf_theme == nil}>auto</option>
                <option :for={t <- ~w(light dark ocean forest sunset synthwave nord autumn cyberpunk pastel dracula coffee acid black luxury retro lofi valentine lemonade garden aqua corporate bumblebee silk dim abyss night caramellatte emerald cupcake cmyk business winter halloween fantasy wireframe)} value={t} selected={@lf_theme == t}>
                  {t}
                </option>
              </select>
            </form>
          </div>
        </div>

        <div class="flex-1 relative">
          <.live_component
            module={LiveFlow.Components.Flow}
            id="demo-flow"
            flow={@flow}
            opts={
              %{
                controls: true,
                minimap: true,
                background: :dots,
                fit_view_on_init: true,
                snap_to_grid: true,
                snap_grid: {20, 20},
                theme: @lf_theme,
                helper_lines: true
              }
            }
            node_types={@node_types}
            on_nodes_change={fn changes -> send(self(), {:nodes_change, changes}) end}
            on_edges_change={fn changes -> send(self(), {:edges_change, changes}) end}
            on_connect={fn edge -> send(self(), {:connect, edge}) end}
          />
        </div>

        <div class="p-4 bg-base-200 border-t border-base-300">
          <div class="text-sm">
            <span class="font-medium">Nodes:</span> {map_size(@flow.nodes)} |
            <span class="font-medium">Edges:</span> {map_size(@flow.edges)} |
            <span class="font-medium">Selected:</span> {MapSet.size(@flow.selected_nodes)} |
            <span class="font-medium">Undo:</span> {History.undo_count(@history)} |
            <span class="font-medium">Redo:</span> {History.redo_count(@history)} |
            <span class="font-medium">Clipboard:</span> {Clipboard.node_count(@clipboard)}
          </div>
          <div class="text-xs text-base-content/60 mt-1">
            Ctrl+C copy | Ctrl+V paste | Ctrl+X cut | Ctrl+D duplicate | Ctrl+Z undo | Ctrl+Shift+Z redo
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("add_node", _params, socket) do
    node_count = map_size(socket.assigns.flow.nodes)
    node_id = "node-#{node_count + 1}"

    # Random position offset
    x = 100 + rem(node_count, 5) * 150
    y = 100 + div(node_count, 5) * 100

    node =
      Node.new(
        node_id,
        %{x: x, y: y},
        %{label: "Node #{node_count + 1}"},
        handles: [
          Handle.target(:left),
          Handle.source(:right)
        ]
      )

    history = History.push(socket.assigns.history, socket.assigns.flow)
    flow = State.add_node(socket.assigns.flow, node)

    {:noreply, assign(socket, flow: flow, history: history)}
  end

  @impl true
  def handle_event("reset_flow", _params, socket) do
    flow = create_demo_flow()
    {:noreply, assign(socket, flow: flow, history: History.new(), clipboard: Clipboard.new())}
  end

  @impl true
  def handle_event("change_theme", %{"theme" => ""}, socket) do
    {:noreply, assign(socket, lf_theme: nil)}
  end

  def handle_event("change_theme", %{"theme" => theme}, socket) do
    {:noreply, assign(socket, lf_theme: theme)}
  end

  @impl true
  def handle_event("export_json", _params, socket) do
    json = Serializer.to_json(socket.assigns.flow)
    {:noreply, push_event(socket, "lf:download_file", %{content: json, filename: "flow.json", type: "application/json"})}
  end

  @impl true
  def handle_event("export_svg", _params, socket) do
    {:noreply, push_event(socket, "lf:export_svg", %{})}
  end

  @impl true
  def handle_event("export_png", _params, socket) do
    {:noreply, push_event(socket, "lf:export_png", %{})}
  end

  @impl true
  def handle_event("import_json", %{"content" => content}, socket) do
    case Serializer.from_json(content) do
      {:ok, flow} ->
        history = History.push(socket.assigns.history, socket.assigns.flow)
        {:noreply, assign(socket, flow: flow, history: history)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Import failed: #{reason}")}
    end
  end

  @impl true
  def handle_event("fit_view", _params, socket) do
    {:noreply, push_event(socket, "lf:fit_view", %{padding: 0.1, duration: 200})}
  end

  @impl true
  def handle_event("lf:selection_change", %{"nodes" => node_ids, "edges" => edge_ids}, socket) do
    # Update the flow state with new selection
    flow =
      socket.assigns.flow
      |> Map.put(:selected_nodes, MapSet.new(node_ids))
      |> Map.put(:selected_edges, MapSet.new(edge_ids))

    # Also update individual node/edge selected flags
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
  def handle_event("lf:node_change", %{"changes" => changes}, socket) do
    # Push history on drag start (not every position change)
    history =
      Enum.reduce(changes, socket.assigns.history, fn change, acc ->
        maybe_push_history_for_drag(acc, socket.assigns.flow, change)
      end)

    flow =
      Enum.reduce(changes, socket.assigns.flow, fn change, acc ->
        apply_node_change(acc, change)
      end)

    {:noreply, assign(socket, flow: flow, history: history)}
  end

  # Connection events - these are handled by the Flow component internally,
  # but we need handlers here in case they bubble up to the parent LiveView
  @impl true
  def handle_event("lf:connect_start", _params, socket) do
    # Connection started - Flow component handles the visual feedback
    {:noreply, socket}
  end

  @impl true
  def handle_event("lf:connect_move", _params, socket) do
    # Connection line moving - handled by JS hook
    {:noreply, socket}
  end

  @impl true
  def handle_event("lf:connect_end", params, socket) do
    case Validation.Connection.validate_and_create(socket.assigns.flow, params) do
      {:ok, edge} ->
        history = History.push(socket.assigns.history, socket.assigns.flow)
        flow = State.add_edge(socket.assigns.flow, edge)
        {:noreply, assign(socket, flow: flow, history: history)}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("lf:connect_cancel", _params, socket) do
    # Connection was cancelled (dropped outside a valid target)
    {:noreply, socket}
  end

  @impl true
  def handle_event("lf:edge_label_change", %{"id" => id, "label" => label}, socket) do
    history = History.push(socket.assigns.history, socket.assigns.flow)
    flow = State.update_edge(socket.assigns.flow, id, label: label)
    {:noreply, assign(socket, flow: flow, history: history)}
  end

  @impl true
  def handle_event("lf:viewport_change", params, socket) do
    flow = State.update_viewport(socket.assigns.flow, params)
    {:noreply, assign(socket, flow: flow)}
  end

  @impl true
  def handle_event("lf:delete_selected", _params, socket) do
    history = History.push(socket.assigns.history, socket.assigns.flow)
    flow = State.delete_selected(socket.assigns.flow)
    {:noreply, assign(socket, flow: flow, history: history)}
  end

  @impl true
  def handle_event("lf:edge_change", %{"changes" => changes}, socket) do
    has_removes = Enum.any?(changes, &(&1["type"] == "remove"))

    history =
      if has_removes,
        do: History.push(socket.assigns.history, socket.assigns.flow),
        else: socket.assigns.history

    flow =
      Enum.reduce(changes, socket.assigns.flow, fn
        %{"type" => "remove", "id" => id}, acc -> State.remove_edge(acc, id)
        _change, acc -> acc
      end)

    {:noreply, assign(socket, flow: flow, history: history)}
  end

  @impl true
  def handle_event("lf:copy", _params, socket) do
    clipboard = Clipboard.copy(socket.assigns.clipboard, socket.assigns.flow)
    {:noreply, assign(socket, clipboard: clipboard)}
  end

  @impl true
  def handle_event("lf:cut", _params, socket) do
    history = History.push(socket.assigns.history, socket.assigns.flow)
    {clipboard, flow} = Clipboard.cut(socket.assigns.clipboard, socket.assigns.flow)
    {:noreply, assign(socket, flow: flow, clipboard: clipboard, history: history)}
  end

  @impl true
  def handle_event("lf:paste", _params, socket) do
    case Clipboard.paste(socket.assigns.clipboard, socket.assigns.flow) do
      {:ok, flow, clipboard} ->
        history = History.push(socket.assigns.history, socket.assigns.flow)
        {:noreply, assign(socket, flow: flow, clipboard: clipboard, history: history)}

      :empty ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("lf:duplicate", _params, socket) do
    clipboard = Clipboard.copy(socket.assigns.clipboard, socket.assigns.flow)

    case Clipboard.paste(clipboard, socket.assigns.flow) do
      {:ok, flow, clipboard} ->
        history = History.push(socket.assigns.history, socket.assigns.flow)
        {:noreply, assign(socket, flow: flow, clipboard: clipboard, history: history)}

      :empty ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("lf:undo", _params, socket) do
    case History.undo(socket.assigns.history, socket.assigns.flow) do
      {:ok, flow, history} -> {:noreply, assign(socket, flow: flow, history: history)}
      :empty -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("lf:redo", _params, socket) do
    case History.redo(socket.assigns.history, socket.assigns.flow) do
      {:ok, flow, history} -> {:noreply, assign(socket, flow: flow, history: history)}
      :empty -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("lf:request_layout", params, socket) do
    history = History.push(socket.assigns.history, socket.assigns.flow)
    data = Layout.prepare_layout_data(socket.assigns.flow, params)
    {:noreply, socket |> assign(history: history) |> push_event("lf:layout_data", data)}
  end

  # Catch-all for any other lf: events (selection box, etc.)
  @impl true
  def handle_event("lf:" <> _event, _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:nodes_change, _changes}, socket) do
    # Changes are already applied in the Flow component
    {:noreply, socket}
  end

  @impl true
  def handle_info({:edges_change, _changes}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:connect, edge}, socket) do
    flow = State.add_edge(socket.assigns.flow, edge)
    {:noreply, assign(socket, flow: flow)}
  end

  @impl true
  def handle_info({:lf_node_click, node_id}, socket) do
    IO.inspect(node_id, label: "Node clicked")
    {:noreply, socket}
  end

  # Private helpers for node changes
  defp apply_node_change(flow, %{"type" => "position", "id" => id, "position" => pos} = change) do
    case Map.get(flow.nodes, id) do
      nil ->
        flow

      node ->
        updated_node = %{
          node
          | position: %{x: pos["x"] / 1, y: pos["y"] / 1},
            dragging: Map.get(change, "dragging", false)
        }

        %{flow | nodes: Map.put(flow.nodes, id, updated_node)}
    end
  end

  defp apply_node_change(flow, %{"type" => "dimensions", "id" => id} = change) do
    case Map.get(flow.nodes, id) do
      nil ->
        flow

      node ->
        updated_node = %{
          node
          | width: Map.get(change, "width"),
            height: Map.get(change, "height"),
            measured: true
        }

        %{flow | nodes: Map.put(flow.nodes, id, updated_node)}
    end
  end

  defp apply_node_change(flow, %{"type" => "remove", "id" => id}) do
    State.remove_node(flow, id)
  end

  defp apply_node_change(flow, _change), do: flow

  # Push history when a drag starts (not on every position update)
  defp maybe_push_history_for_drag(history, flow, %{"type" => "position", "id" => id} = change) do
    dragging = Map.get(change, "dragging", false)

    was_dragging =
      case Map.get(flow.nodes, id) do
        nil -> false
        node -> node.dragging
      end

    if dragging and not was_dragging do
      History.push(history, flow)
    else
      history
    end
  end

  defp maybe_push_history_for_drag(history, _flow, _change), do: history

  defp create_demo_flow do
    nodes = [
      Node.new("start", %{x: 50, y: 150}, %{label: "Start"},
        type: :default,
        handles: [Handle.source(:right)]
      ),
      Node.new("process-1", %{x: 250, y: 50}, %{label: "Process A"},
        handles: [Handle.target(:left), Handle.source(:right)]
      ),
      Node.new("process-2", %{x: 250, y: 250}, %{label: "Process B"},
        handles: [Handle.target(:left), Handle.source(:right)]
      ),
      Node.new("merge", %{x: 450, y: 150}, %{label: "Merge"},
        handles: [
          Handle.target(:left, id: "in-1"),
          Handle.target(:top, id: "in-2"),
          Handle.source(:right)
        ]
      ),
      Node.new("end", %{x: 650, y: 150}, %{label: "End"}, handles: [Handle.target(:left)])
    ]

    edges = [
      Edge.new("e1", "start", "process-1",
        style: %{"stroke" => "#ff0072", "stroke-dasharray" => "5 5"},
        marker_end: %{type: :arrow_closed, color: "#ff0072"},
        label: "dashed"
      ),
      Edge.new("e2", "start", "process-2",
        style: %{"stroke" => "#10b981", "stroke-width" => "3"},
        marker_end: %{type: :circle_filled, color: "#10b981"}
      ),
      Edge.new("e3", "process-1", "merge",
        target_handle: "in-1",
        style: %{"stroke" => "#f97316", "stroke-dasharray" => "8 4"},
        marker_end: %{type: :arrow, color: "#f97316"},
        type: :smoothstep,
        label: "smoothstep"
      ),
      Edge.new("e4", "process-2", "merge",
        target_handle: "in-2",
        style: %{"stroke" => "#8b5cf6", "stroke-width" => "3"},
        marker_end: %{type: :diamond_filled, color: "#8b5cf6"},
        marker_start: %{type: :circle, color: "#8b5cf6"}
      ),
      Edge.new("e5", "merge", "end", animated: true, label: "animated")
    ]

    State.new(nodes: nodes, edges: edges)
  end
end
