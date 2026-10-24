defmodule FlowExampleWeb.Examples.Interaction.UndoRedoLive do
  @moduledoc """
  Undo and Redo: undo and redo moving, adding, and deleting nodes and edges.

  `LiveFlow.History` keeps snapshots of the nodes and edges.
  `FlowExampleWeb.FlowEvents` pushes one before every mutation (drag start,
  resize start, connect, delete, paste, …) and handles `lf:undo` / `lf:redo`,
  which the hook sends for ⌘Z / ⌘⇧Z / ⌘Y. The header buttons send the same
  events.

  History only stores snapshots, so this page keeps a parallel list of
  labels ("Move Node 2", "Connect A → B") to show the stacks: a label is
  pushed whenever the undo stack changes after an event.
  """
  use FlowExampleWeb, :live_view

  alias FlowExample.Samples
  alias FlowExampleWeb.{Examples, FlowEvents, FlowNodes}
  alias LiveFlow.{Edge, History, Node, State}

  @palette [
    {"Transform", "Map & filter fields", "hero-adjustments-horizontal", :violet},
    {"HTTP request", "GET api.example.com", "hero-globe-alt", :sky},
    {"Delay", "Wait 5 minutes", "hero-clock", :amber},
    {"Condition", "amount > 100", "hero-funnel", :rose},
    {"Database", "Insert into orders", "hero-circle-stack", :emerald}
  ]

  @shown 8

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title)
     |> assign(edge_opts: [type: :smoothstep], next_id: 1, undo_labels: [], redo_labels: [])
     |> FlowEvents.assign_flow(build_flow())}
  end

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns,
        undo_count: History.undo_count(assigns.history),
        redo_count: History.redo_count(assigns.history),
        shown: @shown
      )

    ~H"""
    <Layouts.example flash={@flash} example={@example}>
      <:actions>
        <.action id="add-node" icon="hero-plus" variant={:primary} phx-click="add_node">
          Add node
        </.action>
        <.action
          id="undo-btn"
          icon="hero-arrow-uturn-left"
          phx-click="lf:undo"
          disabled={@undo_count == 0}
          title="Undo (⌘Z)"
        >
          Undo
        </.action>
        <.action
          id="redo-btn"
          icon="hero-arrow-uturn-right"
          phx-click="lf:redo"
          disabled={@redo_count == 0}
          title="Redo (⌘⇧Z)"
        >
          Redo
        </.action>
      </:actions>

      <.live_component
        module={LiveFlow.Components.Flow}
        id="undo-redo-flow"
        flow={@flow}
        node_types={FlowNodes.types()}
        opts={
          %{
            background: :dots,
            controls: true,
            minimap: true,
            fit_view_on_init: true,
            fit_view_options: %{padding: 0.2},
            connection_line_type: :smoothstep
          }
        }
      />

      <:sidebar>
        <.option_group title="History">
          <div class="grid grid-cols-2 gap-2">
            <div class="rounded-xl border border-base-300 bg-base-200/50 px-3 py-2">
              <p class="text-[11px] font-medium text-base-content/50">Undo stack</p>
              <p id="undo-count" class="text-2xl font-semibold tabular-nums">{@undo_count}</p>
            </div>
            <div class="rounded-xl border border-base-300 bg-base-200/50 px-3 py-2">
              <p class="text-[11px] font-medium text-base-content/50">Redo stack</p>
              <p id="redo-count" class="text-2xl font-semibold tabular-nums">{@redo_count}</p>
            </div>
          </div>

          <ol id="history-timeline" class="mt-3 space-y-1 text-xs">
            <li
              :for={entry <- Enum.take(@redo_labels, @shown) |> Enum.reverse()}
              id={"redo-entry-#{entry.id}"}
              class="flex items-center gap-2 rounded-md px-2 py-1 text-base-content/40 line-through decoration-base-content/20"
            >
              <.icon name={entry.icon} class="size-3.5 shrink-0" />
              <span class="truncate">{entry.label}</span>
            </li>
            <li class="flex items-center gap-2 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wider text-primary">
              <span class="h-px flex-1 bg-primary/30"></span>
              now <span class="h-px flex-1 bg-primary/30"></span>
            </li>
            <li
              :for={entry <- Enum.take(@undo_labels, @shown)}
              id={"undo-entry-#{entry.id}"}
              class="flex items-center gap-2 rounded-md bg-base-200/70 px-2 py-1"
            >
              <.icon name={entry.icon} class="size-3.5 shrink-0 text-base-content/60" />
              <span class="truncate">{entry.label}</span>
            </li>
            <li :if={@undo_labels == [] and @redo_labels == []} class="px-2 text-base-content/40">
              Move, connect, add or delete something…
            </li>
            <li :if={length(@undo_labels) > @shown} class="px-2 text-base-content/40">
              + {length(@undo_labels) - @shown} older
            </li>
          </ol>
        </.option_group>

        <.option_group title="Shortcuts">
          <ul class="space-y-1.5 text-sm">
            <li :for={{keys, text} <- shortcuts()} class="flex items-center justify-between gap-2">
              <span class="text-base-content/70">{text}</span>
              <span class="flex gap-1"><.kbd :for={key <- keys}>{key}</.kbd></span>
            </li>
          </ul>
        </.option_group>

        <.option_group title="How it works">
          <.hint>
            Before a mutation, <code>History.push(history, flow)</code>
            stores the nodes and edges (selection and viewport are not part of the history).
            Dragging snapshots once, on <code>dragging: true</code>, so a whole drag undoes in one
            step.
          </.hint>
          <.hint>
            <code>History.undo/2</code>
            restores the previous snapshot and moves the current one to the redo stack; a new action
            clears the redo stack.
          </.hint>
        </.option_group>

        <.option_group title="Event log">
          <.event_log entries={@event_log} />
        </.option_group>
      </:sidebar>
    </Layouts.example>
    """
  end

  defp shortcuts do
    [
      {["⌘", "Z"], "Undo"},
      {["⌘", "⇧", "Z"], "Redo"},
      {["⌘", "Y"], "Redo"},
      {["⌫"], "Delete selection"}
    ]
  end

  # ===== Events =====

  @impl true
  def handle_event("add_node", _params, socket) do
    id = socket.assigns.next_id
    {title, subtitle, icon, color} = Enum.at(@palette, rem(id - 1, length(@palette)))
    flow = socket.assigns.flow

    {x, y} =
      case State.bounds(flow) do
        nil ->
          {0, 0}

        bounds ->
          {bounds.x + bounds.width + 80, bounds.y + rem(id * 70, max(round(bounds.height), 1))}
      end

    node = Samples.card("node-#{id}", x, y, "#{title} #{id}", subtitle, icon, color)

    {:noreply,
     socket
     |> FlowEvents.snapshot()
     |> assign(flow: State.add_node(flow, node), next_id: id + 1)
     |> push_label(%{label: "Add #{title} #{id}", icon: "hero-plus"})
     |> FlowEvents.log("add_node", %{"id" => node.id})}
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    before = socket.assigns
    {:noreply, socket} = FlowEvents.handle_event(event, params, socket)
    {:noreply, track(socket, event, params, before)}
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  # ===== History labels =====

  defp track(socket, "lf:undo", _params, before) do
    case {history_changed?(socket, before), socket.assigns.undo_labels} do
      {true, [entry | rest]} ->
        assign(socket, undo_labels: rest, redo_labels: [entry | socket.assigns.redo_labels])

      _other ->
        socket
    end
  end

  defp track(socket, "lf:redo", _params, before) do
    case {history_changed?(socket, before), socket.assigns.redo_labels} do
      {true, [entry | rest]} ->
        assign(socket, redo_labels: rest, undo_labels: [entry | socket.assigns.undo_labels])

      _other ->
        socket
    end
  end

  defp track(socket, event, params, before) do
    if history_changed?(socket, before),
      do: push_label(socket, describe(event, params, before.flow)),
      else: socket
  end

  # The history term is untouched by events that don't snapshot (the
  # comparison is a pointer check in that case)
  defp history_changed?(socket, before), do: socket.assigns.history != before.history

  defp push_label(socket, entry) do
    entry = Map.put(entry, :id, System.unique_integer([:positive]))
    max = socket.assigns.history.max_entries

    assign(socket,
      undo_labels: Enum.take([entry | socket.assigns.undo_labels], max),
      redo_labels: []
    )
  end

  defp describe("lf:node_change", %{"changes" => changes}, flow) do
    moved = for %{"type" => "position", "dragging" => true, "id" => id} <- changes, do: id
    removed = for %{"type" => "remove", "id" => id} <- changes, do: id

    cond do
      moved != [] -> %{label: "Move #{names(flow, moved)}", icon: "hero-arrows-pointing-out"}
      removed != [] -> %{label: "Delete #{names(flow, removed)}", icon: "hero-trash"}
      true -> %{label: "Resize", icon: "hero-arrows-pointing-out"}
    end
  end

  defp describe("lf:connect_end", params, flow) do
    %{
      label: "Connect #{names(flow, [params["source"]])} → #{names(flow, [params["target"]])}",
      icon: "hero-link"
    }
  end

  defp describe("lf:delete_selected", _params, flow) do
    nodes = MapSet.to_list(flow.selected_nodes)
    edges = MapSet.size(flow.selected_edges)

    label =
      case {nodes, edges} do
        {[], 1} -> "Delete edge"
        {[], n} -> "Delete #{n} edges"
        {ids, _} -> "Delete #{names(flow, ids)}"
      end

    %{label: label, icon: "hero-trash"}
  end

  defp describe("lf:edge_change", _params, _flow), do: %{label: "Delete edge", icon: "hero-trash"}
  defp describe("lf:cut", _params, _flow), do: %{label: "Cut", icon: "hero-scissors"}

  defp describe("lf:paste", _params, _flow),
    do: %{label: "Paste", icon: "hero-clipboard-document"}

  defp describe("lf:duplicate", _params, _flow),
    do: %{label: "Duplicate", icon: "hero-square-2-stack"}

  defp describe("lf:reconnect_edge", _params, _flow),
    do: %{label: "Reconnect edge", icon: "hero-arrows-right-left"}

  defp describe("lf:" <> event, _params, _flow),
    do: %{label: String.replace(event, "_", " "), icon: "hero-pencil-square"}

  defp names(flow, ids) do
    labels =
      Enum.map(ids, fn id ->
        case State.get_node(flow, id) do
          %Node{data: %{title: title}} -> title
          _other -> id
        end
      end)

    case labels do
      [one] -> one
      [first | rest] -> "#{first} +#{length(rest)}"
      [] -> "nodes"
    end
  end

  # ===== Initial graph =====

  defp build_flow do
    nodes = [
      Samples.card("start", 0, 120, "Order placed", "Webhook", "hero-shopping-cart", :amber,
        inputs: false
      ),
      Samples.card("pay", 300, 40, "Charge card", "Stripe", "hero-credit-card", :sky),
      Samples.card("stock", 300, 220, "Reserve stock", "Warehouse API", "hero-cube", :violet),
      Samples.card("ship", 600, 120, "Ship", "Print label", "hero-truck", :emerald,
        outputs: false
      )
    ]

    edges = [
      Edge.new("start-pay", "start", "pay", type: :smoothstep, animated: true),
      Edge.new("start-stock", "start", "stock", type: :smoothstep, animated: true),
      Edge.new("pay-ship", "pay", "ship", type: :smoothstep)
    ]

    State.new(nodes: nodes, edges: edges)
  end
end
