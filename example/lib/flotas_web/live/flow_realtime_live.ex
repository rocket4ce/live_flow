defmodule FlotasWeb.FlowRealtimeLive do
  @moduledoc """
  Real-time collaborative flow editor demo.
  All connected users share and edit the same flow, with live cursor tracking.

  Uses `LiveFlow.Collaboration` for PubSub messaging, cursor broadcasting,
  and Presence tracking.
  """

  use FlotasWeb, :live_view

  alias LiveFlow.{State, History, Clipboard, Validation, Serializer, Layout}
  alias LiveFlow.Collaboration
  alias LiveFlow.Collaboration.User
  alias Flotas.FlowRealtimeStore

  @impl true
  def mount(_params, _session, socket) do
    user_id = "user_#{System.unique_integer([:positive])}"
    user = User.new(user_id)
    flow = FlowRealtimeStore.get_flow()

    socket =
      socket
      |> assign(page_title: "Realtime Flow", flow: flow, history: History.new(), clipboard: Clipboard.new(), node_types: %{})
      |> Collaboration.join("flow:realtime", user,
        pubsub: Flotas.PubSub,
        presence: FlotasWeb.Presence
      )

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="h-screen flex flex-col">
        <div class="p-4 bg-base-200 border-b border-base-300">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-2xl font-bold">Realtime Collaborative Flow</h1>
              <p class="text-sm text-base-content/70">
                Open this page in multiple tabs to collaborate
              </p>
            </div>
            <div class="flex items-center gap-3">
              <button class="btn btn-sm btn-secondary" phx-click="reset_flow">
                Reset
              </button>
              <button class="btn btn-sm" phx-click="fit_view">
                Fit View
              </button>
              <button class="btn btn-sm btn-accent" phx-click={JS.dispatch("lf:auto-layout", to: "#realtime-flow")}>
                Auto Layout
              </button>
              <button class="btn btn-sm btn-outline" phx-click="export_json">
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
              <button class="btn btn-sm btn-outline" phx-click={JS.dispatch("lf:export-svg", to: "#realtime-flow")}>
                SVG
              </button>
              <button class="btn btn-sm btn-outline" phx-click={JS.dispatch("lf:export-png", to: "#realtime-flow")}>
                PNG
              </button>
            </div>
          </div>

          <div class="mt-3">
            <Collaboration.presence_list
              presences={@lf_presences}
              current_user={@lf_user}
            />
          </div>
        </div>

        <div class="flex-1 relative">
          <.live_component
            module={LiveFlow.Components.Flow}
            id="realtime-flow"
            flow={@flow}
            opts={
              %{
                controls: true,
                minimap: true,
                background: :dots,
                fit_view_on_init: true,
                snap_to_grid: true,
                snap_grid: {20, 20},
                cursors: true
              }
            }
            node_types={@node_types}
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
            Ctrl+C copy | Ctrl+V paste | Ctrl+X cut | Ctrl+D duplicate | Undo/redo local only
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # Event handlers

  @impl true
  def handle_event("reset_flow", _params, socket) do
    flow = FlowRealtimeStore.reset_flow()

    socket = Collaboration.broadcast_change(socket, {:flow_reset, flow})

    {:noreply, assign(socket, flow: flow, history: History.new(), clipboard: Clipboard.new())}
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
  def handle_event("lf:node_change", %{"changes" => changes}, socket) do
    history =
      Enum.reduce(changes, socket.assigns.history, fn change, acc ->
        maybe_push_history_for_drag(acc, socket.assigns.flow, change)
      end)

    flow =
      Enum.reduce(changes, socket.assigns.flow, fn change, acc ->
        apply_and_store_node_change(acc, change)
      end)

    # Broadcast position and remove changes (not dimensions — each client measures their own)
    broadcast_changes =
      Enum.filter(changes, fn c -> c["type"] in ["position", "remove"] end)

    socket =
      if broadcast_changes != [] do
        Collaboration.broadcast_change(socket, {:node_changes, broadcast_changes})
      else
        socket
      end

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
        %{"type" => "remove", "id" => id}, acc ->
          FlowRealtimeStore.apply_change({:edge_remove, id})
          Collaboration.broadcast_change(socket, {:edge_remove, id})
          State.remove_edge(acc, id)

        _change, acc ->
          acc
      end)

    {:noreply, assign(socket, flow: flow, history: history)}
  end

  @impl true
  def handle_event("lf:connect_end", params, socket) do
    case Validation.Connection.validate_and_create(socket.assigns.flow, params) do
      {:ok, edge} ->
        history = History.push(socket.assigns.history, socket.assigns.flow)
        FlowRealtimeStore.apply_change({:edge_add, edge})
        socket = Collaboration.broadcast_change(socket, {:edge_add, edge})
        flow = State.add_edge(socket.assigns.flow, edge)
        {:noreply, assign(socket, flow: flow, history: history)}

      {:error, _reason} ->
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
    history = History.push(socket.assigns.history, socket.assigns.flow)
    node_ids = MapSet.to_list(socket.assigns.flow.selected_nodes)
    edge_ids = MapSet.to_list(socket.assigns.flow.selected_edges)

    if node_ids != [] or edge_ids != [] do
      FlowRealtimeStore.apply_change({:delete_selected, node_ids, edge_ids})
      Collaboration.broadcast_change(socket, {:delete_selected, node_ids, edge_ids})
    end

    flow = State.delete_selected(socket.assigns.flow)
    {:noreply, assign(socket, flow: flow, history: history)}
  end

  @impl true
  def handle_event("lf:cursor_move", %{"x" => x, "y" => y}, socket) do
    # Server-side throttle to prevent PubSub flooding with many concurrent users
    now = System.monotonic_time(:millisecond)
    last = Process.get(:lf_cursor_throttle, 0)

    if now - last >= 50 do
      Process.put(:lf_cursor_throttle, now)
      socket = Collaboration.broadcast_cursor(socket, x, y)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("lf:drag_move", %{"changes" => changes}, socket) do
    # Broadcast intermediate drag positions — DOM-only update on receivers (no re-render)
    Collaboration.broadcast_drag_move(socket, changes)
    {:noreply, socket}
  end

  @impl true
  def handle_event("lf:edge_label_change", %{"id" => id, "label" => label}, socket) do
    history = History.push(socket.assigns.history, socket.assigns.flow)
    flow = State.update_edge(socket.assigns.flow, id, label: label)
    Collaboration.broadcast_change(socket, {:edge_label, id, label})
    {:noreply, assign(socket, flow: flow, history: history)}
  end

  @impl true
  def handle_event("lf:viewport_change", params, socket) do
    flow = State.update_viewport(socket.assigns.flow, params)
    {:noreply, assign(socket, flow: flow)}
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

    # Broadcast the deletion
    node_ids = MapSet.to_list(socket.assigns.flow.selected_nodes)
    edge_ids = MapSet.to_list(socket.assigns.flow.selected_edges)

    if node_ids != [] or edge_ids != [] do
      FlowRealtimeStore.apply_change({:delete_selected, node_ids, edge_ids})
      Collaboration.broadcast_change(socket, {:delete_selected, node_ids, edge_ids})
    end

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

  # Catch-all for other lf: events
  @impl true
  def handle_event("lf:" <> _event, _params, socket) do
    {:noreply, socket}
  end

  # PubSub / Presence messages — delegate to Collaboration module
  @impl true
  def handle_info(msg, socket) do
    case Collaboration.handle_info(msg, socket) do
      {:ok, socket} ->
        {:noreply, socket}

      :ignore ->
        # Handle app-specific messages
        handle_app_info(msg, socket)
    end
  end

  defp handle_app_info({:lf_node_click, _node_id}, socket) do
    {:noreply, socket}
  end

  defp handle_app_info(_msg, socket) do
    {:noreply, socket}
  end

  # Private helpers

  defp apply_and_store_node_change(flow, %{"type" => "position", "id" => id, "position" => pos} = change) do
    dragging = Map.get(change, "dragging", false)
    FlowRealtimeStore.apply_change({:node_position, id, pos, dragging})

    case Map.get(flow.nodes, id) do
      nil ->
        flow

      node ->
        updated = %{
          node
          | position: %{x: pos["x"] / 1, y: pos["y"] / 1},
            dragging: dragging
        }

        %{flow | nodes: Map.put(flow.nodes, id, updated)}
    end
  end

  defp apply_and_store_node_change(flow, %{"type" => "dimensions", "id" => id} = change) do
    width = Map.get(change, "width")
    height = Map.get(change, "height")
    FlowRealtimeStore.apply_change({:node_dimensions, id, width, height})

    case Map.get(flow.nodes, id) do
      nil ->
        flow

      node ->
        updated = %{node | width: width, height: height, measured: true}
        %{flow | nodes: Map.put(flow.nodes, id, updated)}
    end
  end

  defp apply_and_store_node_change(flow, %{"type" => "remove", "id" => id}) do
    FlowRealtimeStore.apply_change({:node_remove, id})
    State.remove_node(flow, id)
  end

  defp apply_and_store_node_change(flow, _change), do: flow

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

end
