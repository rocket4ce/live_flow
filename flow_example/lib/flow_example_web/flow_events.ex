defmodule FlowExampleWeb.FlowEvents do
  @moduledoc """
  Standard handling for the `lf:*` events pushed by the LiveFlow hook.

  Every showcase LiveView keeps its flow in `@flow` (plus `@history` and
  `@clipboard`) and delegates the events it doesn't customize:

      def handle_event("lf:" <> _ = event, params, socket) do
        FlowEvents.handle_event(event, params, socket)
      end

  Every handled event is also appended to `@event_log` (when assigned) so the
  demos can show what the client sends.
  """

  import Phoenix.Component, only: [assign: 3, update: 3]
  import Phoenix.LiveView, only: [push_event: 3]

  alias LiveFlow.{Clipboard, History, Layout, State}
  alias LiveFlow.Changes.{EdgeChange, NodeChange}
  alias LiveFlow.Validation.Connection

  @log_size 30

  @doc """
  Assigns the flow plus history, clipboard and an empty event log.
  """
  def assign_flow(socket, %State{} = flow) do
    socket
    |> assign(:flow, flow)
    |> assign(:history, History.new())
    |> assign(:clipboard, Clipboard.new())
    |> assign(:event_log, [])
  end

  def handle_event("lf:node_change", %{"changes" => changes} = params, socket) do
    socket =
      if Enum.any?(changes, &history_change?/1),
        do: snapshot(socket),
        else: socket

    socket
    |> update_flow(&NodeChange.apply_changes(&1, changes))
    |> log("lf:node_change", params)
    |> noreply()
  end

  def handle_event("lf:edge_change", %{"changes" => changes} = params, socket) do
    socket
    |> snapshot()
    |> update_flow(&EdgeChange.apply_changes(&1, changes))
    |> log("lf:edge_change", params)
    |> noreply()
  end

  def handle_event("lf:connect_end", params, socket) do
    edge_opts = Map.get(socket.assigns, :edge_opts, [])

    case Connection.validate_and_create(socket.assigns.flow, params, edge_opts: edge_opts) do
      {:ok, edge} ->
        socket
        |> snapshot()
        |> update_flow(&State.add_edge(&1, edge))
        |> log("lf:connect_end", params)
        |> noreply()

      {:error, reason} ->
        socket |> log("lf:connect_end", Map.put(params, "rejected", reason)) |> noreply()
    end
  end

  def handle_event("lf:reconnect_edge", params, socket) do
    socket
    |> snapshot()
    |> update_flow(&State.reconnect_edge(&1, params))
    |> log("lf:reconnect_edge", params)
    |> noreply()
  end

  def handle_event("lf:delete_reconnect_edge", %{"edge_id" => id} = params, socket) do
    socket
    |> snapshot()
    |> update_flow(&State.remove_edge(&1, id))
    |> log("lf:delete_reconnect_edge", params)
    |> noreply()
  end

  def handle_event(
        "lf:selection_change",
        %{"nodes" => node_ids, "edges" => edge_ids} = params,
        socket
      ) do
    socket
    |> update_flow(&select(&1, node_ids, edge_ids))
    |> log("lf:selection_change", params)
    |> noreply()
  end

  def handle_event("lf:delete_selected", params, socket) do
    socket
    |> snapshot()
    |> update_flow(&State.delete_selected/1)
    |> log("lf:delete_selected", params)
    |> noreply()
  end

  def handle_event("lf:viewport_change", params, socket) do
    socket
    |> update_flow(&State.update_viewport(&1, params))
    |> noreply()
  end

  def handle_event("lf:edge_label_change", %{"id" => id, "label" => label} = params, socket) do
    socket
    |> snapshot()
    |> update_flow(&State.update_edge(&1, id, label: label))
    |> log("lf:edge_label_change", params)
    |> noreply()
  end

  def handle_event("lf:undo", params, socket) do
    case History.undo(socket.assigns.history, socket.assigns.flow) do
      {:ok, flow, history} ->
        socket
        |> assign(:flow, flow)
        |> assign(:history, history)
        |> log("lf:undo", params)
        |> noreply()

      :empty ->
        noreply(socket)
    end
  end

  def handle_event("lf:redo", params, socket) do
    case History.redo(socket.assigns.history, socket.assigns.flow) do
      {:ok, flow, history} ->
        socket
        |> assign(:flow, flow)
        |> assign(:history, history)
        |> log("lf:redo", params)
        |> noreply()

      :empty ->
        noreply(socket)
    end
  end

  def handle_event("lf:copy", params, socket) do
    socket
    |> assign(:clipboard, Clipboard.copy(socket.assigns.clipboard, socket.assigns.flow))
    |> log("lf:copy", params)
    |> noreply()
  end

  def handle_event("lf:cut", params, socket) do
    socket = snapshot(socket)
    {clipboard, flow} = Clipboard.cut(socket.assigns.clipboard, socket.assigns.flow)

    socket
    |> assign(:clipboard, clipboard)
    |> assign(:flow, flow)
    |> log("lf:cut", params)
    |> noreply()
  end

  def handle_event("lf:paste", params, socket) do
    case Clipboard.paste(socket.assigns.clipboard, socket.assigns.flow,
           position: params["position"]
         ) do
      {:ok, flow, clipboard} ->
        socket
        |> snapshot()
        |> assign(:flow, flow)
        |> assign(:clipboard, clipboard)
        |> log("lf:paste", params)
        |> noreply()

      :empty ->
        noreply(socket)
    end
  end

  def handle_event("lf:duplicate", params, socket) do
    clipboard = Clipboard.copy(Clipboard.new(), socket.assigns.flow)

    case Clipboard.paste(clipboard, socket.assigns.flow) do
      {:ok, flow, _clipboard} ->
        socket |> snapshot() |> assign(:flow, flow) |> log("lf:duplicate", params) |> noreply()

      :empty ->
        noreply(socket)
    end
  end

  def handle_event("lf:request_layout", params, socket) do
    data = Layout.prepare_layout_data(socket.assigns.flow, params)

    socket
    |> snapshot()
    |> push_event("lf:layout_data", data)
    |> log("lf:request_layout", params)
    |> noreply()
  end

  # lf:drag_move (collaboration), lf:connect_cancel, lf:cursor_move, ...
  def handle_event("lf:" <> _ = event, params, socket) do
    socket |> log(event, params) |> noreply()
  end

  @doc """
  Records a history snapshot before a mutation.
  """
  def snapshot(socket) do
    assign(socket, :history, History.push(socket.assigns.history, socket.assigns.flow))
  end

  @doc """
  Appends an entry to the event log shown by the demos.
  """
  def log(socket, event, params) do
    if Map.has_key?(socket.assigns, :event_log) do
      entry = %{
        id: System.unique_integer([:positive]),
        event: event,
        summary: summarize(event, params),
        at: Time.utc_now() |> Time.truncate(:second)
      }

      update(socket, :event_log, &Enum.take([entry | &1], @log_size))
    else
      socket
    end
  end

  # Drag start (dragging: true) and resize start (resizing: true) are the
  # points to snapshot for undo; dimension measurements are not.
  defp history_change?(%{"type" => "position", "dragging" => true}), do: true
  defp history_change?(%{"type" => "resize", "resizing" => true}), do: true
  defp history_change?(%{"type" => "remove"}), do: true
  defp history_change?(_), do: false

  defp select(flow, node_ids, edge_ids) do
    node_set = MapSet.new(node_ids)
    edge_set = MapSet.new(edge_ids)

    %{
      flow
      | nodes:
          Map.new(flow.nodes, fn {id, n} ->
            {id, %{n | selected: MapSet.member?(node_set, id)}}
          end),
        edges:
          Map.new(flow.edges, fn {id, e} ->
            {id, %{e | selected: MapSet.member?(edge_set, id)}}
          end),
        selected_nodes: node_set,
        selected_edges: edge_set
    }
  end

  defp update_flow(socket, fun), do: assign(socket, :flow, fun.(socket.assigns.flow))

  defp summarize("lf:node_change", %{"changes" => changes}) do
    changes
    |> Enum.map(fn change ->
      flags =
        [change["dragging"] && "dragging", change["resizing"] && "resizing"]
        |> Enum.filter(& &1)
        |> Enum.join(", ")

      String.trim("#{change["type"]} #{change["id"]} #{flags}")
    end)
    |> Enum.uniq()
    |> Enum.take(3)
    |> Enum.join(" · ")
  end

  defp summarize("lf:selection_change", %{"nodes" => nodes, "edges" => edges}) do
    "#{length(nodes)} nodes, #{length(edges)} edges"
  end

  defp summarize("lf:connect_end", params) do
    base = "#{params["source"]} → #{params["target"]}"
    if params["rejected"], do: "#{base} (rejected: #{params["rejected"]})", else: base
  end

  defp summarize("lf:reconnect_edge", params) do
    "#{params["edge_id"]} #{params["end"]} → #{params["node_id"]}"
  end

  defp summarize(_event, params) when map_size(params) == 0, do: ""

  defp summarize(_event, params) do
    params |> Map.drop(["changes"]) |> inspect(limit: 4, printable_limit: 60)
  end

  defp noreply(socket), do: {:noreply, socket}
end
