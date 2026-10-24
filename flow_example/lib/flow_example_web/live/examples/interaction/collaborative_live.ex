defmodule FlowExampleWeb.Examples.Interaction.CollaborativeLive do
  @moduledoc """
  Collaborative: a graph edited by several users at once, with live cursors.

  Every tab joins the same room with `LiveFlow.Collaboration.join/4`
  (PubSub + `FlowExampleWeb.Presence`). The shared flow lives in
  `FlowExample.FlowStore`, so new tabs start from the current state.

  Every local change is applied to the LiveView's flow, to the store, and
  broadcast to the other tabs with `Collaboration.broadcast_change/2`; the
  receivers apply it in `handle_info/2` (`Collaboration.handle_info/2`).
  While dragging, `lf:drag_move` is relayed with
  `Collaboration.broadcast_drag_move/2` and the receivers move the nodes in
  the browser only (`lf:remote_drag`), without touching their state.
  `cursors: true` renders the remote cursors sent with
  `Collaboration.broadcast_cursor/3`.
  """
  use FlowExampleWeb, :live_view

  alias FlowExample.FlowStore
  alias FlowExampleWeb.{Examples, FlowEvents}
  alias LiveFlow.Changes.{EdgeChange, NodeChange}
  alias LiveFlow.Collaboration
  alias LiveFlow.Collaboration.User
  alias LiveFlow.{Edge, Node, State}
  alias LiveFlow.Validation.Connection

  @room "showcase"
  @topic "liveflow:collaborative:showcase"
  @adjectives ~w(Swift Curious Brave Calm Clever Bright Lucky Gentle Bold Sunny)
  @animals ~w(Fox Otter Panda Falcon Lynx Koala Heron Badger Orca Gecko)
  @ideas ["Sketch", "Prototype", "User test", "Iterate", "Polish", "Ship it", "Measure"]

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)
    name = "#{Enum.random(@adjectives)} #{Enum.random(@animals)}"
    user = User.new("user-#{System.unique_integer([:positive])}", name: name)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title)
     |> FlowEvents.assign_flow(FlowStore.get(@room, &default_flow/0))
     |> Collaboration.join(@topic, user,
       pubsub: FlowExample.PubSub,
       presence: FlowExampleWeb.Presence
     )}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :users, online_users(assigns.lf_presences, assigns.lf_user))

    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      #collab-flow .lf-node[data-node-type="note"] {
        border-radius: 10px;
        box-shadow: inset 3px 0 0 var(--note-color), var(--lf-node-shadow);
      }
      #collab-flow .lf-node[data-node-type="note"].lf-node-selected {
        box-shadow: inset 3px 0 0 var(--note-color), var(--lf-node-selected-shadow);
      }
      #online-users > span {
        animation: collab-avatar-in 200ms cubic-bezier(0.2, 0.9, 0.3, 1.3);
      }
      @keyframes collab-avatar-in {
        from {
          opacity: 0;
          scale: 0.6;
        }
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <:actions>
        <div id="online-users" class="mr-1 flex -space-x-2" aria-label="Online users">
          <span
            :for={user <- Enum.take(@users, 5)}
            id={"avatar-#{user.id}"}
            title={if user.me, do: "#{user.name} (you)", else: user.name}
            class="grid size-7 place-items-center rounded-full text-[10px] font-semibold text-white ring-2 ring-base-100"
            style={"background: #{user.color}"}
          >
            {initials(user.name)}
          </span>
          <span
            :if={length(@users) > 5}
            class="grid size-7 place-items-center rounded-full bg-base-300 text-[10px] font-semibold ring-2 ring-base-100"
          >
            +{length(@users) - 5}
          </span>
        </div>
        <a
          id="open-tab"
          href={@example.path}
          target="_blank"
          rel="noopener"
          class="inline-flex items-center gap-1.5 rounded-lg border border-base-300 bg-base-100 px-3 py-1.5 text-sm font-medium transition-all duration-150 hover:border-base-content/20 hover:bg-base-200 active:scale-95"
        >
          <.icon name="hero-arrow-top-right-on-square" class="size-4" /> New tab
        </a>
        <.action id="add-note" icon="hero-plus" variant={:primary} phx-click="add_note">
          Add node
        </.action>
        <.action id="reset-flow" icon="hero-arrow-path" phx-click="reset">Reset</.action>
      </:actions>

      <.live_component
        module={LiveFlow.Components.Flow}
        id="collab-flow"
        flow={@flow}
        node_types={%{note: &note_node/1}}
        opts={
          %{
            background: :dots,
            controls: true,
            minimap: true,
            fit_view_on_init: true,
            fit_view_options: %{padding: 0.25},
            cursors: true,
            connection_line_type: :smoothstep
          }
        }
      />

      <:sidebar>
        <.option_group title="Online now" tag={"#{length(@users)}"}>
          <ul id="presence-list" class="space-y-1.5">
            <li
              :for={user <- @users}
              id={"presence-#{user.id}"}
              class="flex items-center gap-2 text-sm"
            >
              <span class="relative flex size-2.5">
                <span
                  :if={user.me}
                  class="absolute inline-flex size-full animate-ping rounded-full opacity-60"
                  style={"background: #{user.color}"}
                ></span>
                <span
                  class="relative inline-flex size-2.5 rounded-full"
                  style={"background: #{user.color}"}
                ></span>
              </span>
              <span id={if(user.me, do: "current-user")} class={[user.me && "font-medium"]}>
                {user.name}
              </span>
              <span :if={user.me} class="text-xs text-base-content/45">you</span>
            </li>
          </ul>
          <.hint>
            Open this page in another tab or browser (<b>New tab</b>
            above) and edit from both: moves, connections, new nodes and deletions show up everywhere,
            with the other users' cursors.
          </.hint>
        </.option_group>

        <.option_group title="How it works">
          <.hint>
            <code>Collaboration.join/4</code>
            subscribes the LiveView to the room and tracks the user with Presence. The flow is read
            from <code>FlowExample.FlowStore</code>, the room's shared state.
          </.hint>
          <.hint>
            Local changes update the store and go out with
            <code>Collaboration.broadcast_change/2</code>
            (<code>{"{:node_changes, …}"}</code>, <code>{"{:edge_add, edge}"}</code>, …); other tabs
            apply them in <code>handle_info/2</code>. Drags stream through
            <code>broadcast_drag_move/2</code>
            and only move DOM nodes on the receivers until the drop.
          </.hint>
          <.hint>
            Undo/redo and the clipboard are per-tab features, so they are turned off here: replaying a
            local snapshot would overwrite the other users' work.
          </.hint>
        </.option_group>

        <.option_group title="Event log">
          <.event_log entries={@event_log} />
        </.option_group>
      </:sidebar>
    </Layouts.example>
    """
  end

  attr :node, :map, required: true

  defp note_node(assigns) do
    ~H"""
    <div class="w-36">
      <p class="truncate text-[13px] font-semibold" style="color: var(--lf-text-primary)">
        {@node.data.label}
      </p>
      <p class="mt-1 flex items-center gap-1.5 text-[11px]" style="color: var(--lf-text-secondary)">
        <span class="size-2 shrink-0 rounded-full" style={"background: #{@node.data.color}"}></span>
        <span class="truncate">{@node.data.author}</span>
      </p>
    </div>
    """
  end

  # ===== Local changes =====

  @impl true
  def handle_event("lf:node_change", %{"changes" => changes} = params, socket) do
    # Every tab measures its own nodes: dimensions go to the store only
    stored =
      for %{"type" => type} = change <- changes,
          type in ~w(position dimensions remove),
          do: Map.put(change, "dragging", false)

    shared = Enum.filter(changes, &(&1["type"] in ~w(position remove)))

    if stored != [], do: FlowStore.update(@room, &NodeChange.apply_changes(&1, stored))

    socket = assign(socket, :flow, NodeChange.apply_changes(socket.assigns.flow, changes))

    if shared == [] do
      {:noreply, socket}
    else
      {:noreply,
       socket
       |> Collaboration.broadcast_change({:node_changes, shared})
       |> FlowEvents.log("lf:node_change", params)}
    end
  end

  def handle_event("lf:connect_end", params, socket) do
    case Connection.validate_and_create(socket.assigns.flow, params,
           edge_opts: [type: :smoothstep, reconnectable: true]
         ) do
      {:ok, edge} ->
        {:noreply,
         socket |> commit({:edge_add, edge}) |> FlowEvents.log("lf:connect_end", params)}

      {:error, reason} ->
        {:noreply, FlowEvents.log(socket, "lf:connect_end", Map.put(params, "rejected", reason))}
    end
  end

  def handle_event("lf:edge_change", %{"changes" => changes} = params, socket) do
    {removed, local} = Enum.split_with(changes, &(&1["type"] == "remove"))
    socket = assign(socket, :flow, EdgeChange.apply_changes(socket.assigns.flow, local))

    socket =
      Enum.reduce(removed, socket, fn %{"id" => id}, acc -> commit(acc, {:edge_remove, id}) end)

    {:noreply, FlowEvents.log(socket, "lf:edge_change", params)}
  end

  def handle_event("lf:delete_selected", params, socket) do
    flow = socket.assigns.flow
    node_ids = MapSet.to_list(flow.selected_nodes)
    edge_ids = MapSet.to_list(flow.selected_edges)

    if node_ids == [] and edge_ids == [] do
      {:noreply, socket}
    else
      {:noreply,
       socket
       |> commit({:delete_selected, node_ids, edge_ids})
       |> FlowEvents.log("lf:delete_selected", params)}
    end
  end

  def handle_event("lf:edge_label_change", %{"id" => id, "label" => label} = params, socket) do
    {:noreply,
     socket
     |> commit({:edge_update, id, [label: label]})
     |> FlowEvents.log("lf:edge_label_change", params)}
  end

  def handle_event("lf:reconnect_edge", params, socket) do
    {:noreply,
     socket |> commit({:edge_reconnect, params}) |> FlowEvents.log("lf:reconnect_edge", params)}
  end

  # Intermediate drag positions: DOM-only on the other tabs
  def handle_event("lf:drag_move", %{"changes" => changes}, socket) do
    {:noreply, Collaboration.broadcast_drag_move(socket, changes)}
  end

  def handle_event("lf:cursor_move", %{"x" => x, "y" => y}, socket) do
    {:noreply, Collaboration.broadcast_cursor(socket, x, y)}
  end

  def handle_event("lf:" <> _ = event, params, socket)
      when event in ["lf:selection_change", "lf:viewport_change"] do
    FlowEvents.handle_event(event, params, socket)
  end

  # Undo/redo, clipboard, …: not shared, so not applied in this demo
  def handle_event("lf:" <> _ = event, params, socket) do
    {:noreply, FlowEvents.log(socket, event, Map.put(params, "ignored", "per-tab feature"))}
  end

  def handle_event("add_note", _params, socket) do
    user = socket.assigns.lf_user
    flow = socket.assigns.flow

    {x, y} =
      case State.bounds(flow) do
        nil ->
          {0, 0}

        b ->
          {b.x + :rand.uniform(max(round(b.width), 1)), b.y + b.height + 40 + :rand.uniform(60)}
      end

    node =
      note(
        "note-#{System.unique_integer([:positive])}",
        x,
        y,
        Enum.random(@ideas),
        user.name,
        user.color
      )

    {:noreply,
     socket |> commit({:node_add, node}) |> FlowEvents.log("add_node", %{"id" => node.id})}
  end

  def handle_event("reset", _params, socket) do
    flow = default_flow()
    FlowStore.put(@room, flow)

    {:noreply,
     socket
     |> assign(:flow, flow)
     |> Collaboration.broadcast_change({:flow_reset, flow})
     |> FlowEvents.log("reset", %{})}
  end

  # ===== Remote changes =====

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  def handle_info({:lf_flow_change, sender_id, change} = message, socket) do
    socket |> log_remote(sender_id, change) |> then(&delegate(message, &1))
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{event: "presence_diff", payload: diff} = message,
        socket
      ) do
    socket =
      Enum.reduce(diff.joins, socket, fn {id, %{metas: [meta | _]}}, acc ->
        if id == acc.assigns.lf_user.id,
          do: acc,
          else: FlowEvents.log(acc, "presence", %{"joined" => meta.name})
      end)

    socket =
      Enum.reduce(diff.leaves, socket, fn {id, %{metas: [meta | _]}}, acc ->
        if Map.has_key?(diff.joins, id),
          do: acc,
          else: FlowEvents.log(acc, "presence", %{"left" => meta.name})
      end)

    delegate(message, socket)
  end

  def handle_info(message, socket), do: delegate(message, socket)

  defp delegate(message, socket) do
    case Collaboration.handle_info(message, socket) do
      {:ok, socket} -> {:noreply, socket}
      :ignore -> {:noreply, socket}
    end
  end

  # ===== Helpers =====

  # Applies a change locally, to the shared store, and sends it to the others
  defp commit(socket, change) do
    FlowStore.update(@room, &Collaboration.apply_remote_change(&1, change))

    socket
    |> assign(:flow, Collaboration.apply_remote_change(socket.assigns.flow, change))
    |> Collaboration.broadcast_change(change)
  end

  # Drag starts are noise in the log; drops and the rest are shown
  defp log_remote(socket, sender_id, {:node_changes, changes} = change) do
    if Enum.all?(changes, &(&1["type"] == "position" and &1["dragging"] == true)),
      do: socket,
      else: FlowEvents.log(socket, "remote", remote_summary(socket, sender_id, change))
  end

  defp log_remote(socket, sender_id, change) do
    FlowEvents.log(socket, "remote", remote_summary(socket, sender_id, change))
  end

  defp remote_summary(socket, sender_id, change) do
    %{"user" => user_name(socket, sender_id), "did" => describe(socket.assigns.flow, change)}
  end

  defp describe(flow, {:node_changes, changes}) do
    case Enum.filter(changes, &(&1["type"] == "remove")) do
      [] -> "moved #{labels(flow, Enum.map(changes, & &1["id"]))}"
      removed -> "deleted #{labels(flow, Enum.map(removed, & &1["id"]))}"
    end
  end

  defp describe(flow, {:edge_add, %Edge{source: source, target: target}}),
    do: "connected #{labels(flow, [source])} → #{labels(flow, [target])}"

  defp describe(_flow, {:edge_remove, _id}), do: "removed an edge"

  defp describe(_flow, {:delete_selected, nodes, edges}),
    do: "deleted #{length(nodes)} nodes, #{length(edges)} edges"

  defp describe(_flow, {:node_add, %Node{data: data}}), do: "added #{data.label}"
  defp describe(_flow, {:edge_update, _id, _attrs}), do: "renamed an edge"
  defp describe(_flow, {:edge_reconnect, _params}), do: "reconnected an edge"
  defp describe(_flow, {:flow_reset, _new_flow}), do: "reset the board"
  defp describe(_flow, _change), do: "changed the flow"

  defp labels(flow, ids) do
    ids
    |> Enum.uniq()
    |> Enum.map_join(", ", fn id ->
      case State.get_node(flow, id) do
        %Node{data: %{label: label}} -> label
        _other -> id
      end
    end)
  end

  defp user_name(socket, user_id) do
    case socket.assigns.lf_presences do
      %{^user_id => %{metas: [%{name: name} | _]}} -> name
      _other -> "someone"
    end
  end

  defp online_users(presences, me) do
    others =
      for {id, %{metas: [meta | _]}} <- presences, id != me.id do
        %{id: id, name: meta.name, color: meta.color, me: false}
      end

    [%{id: me.id, name: me.name, color: me.color, me: true} | Enum.sort_by(others, & &1.name)]
  end

  defp initials(name) do
    name |> String.split() |> Enum.map_join(&String.first/1) |> String.slice(0, 2)
  end

  defp note(id, x, y, label, author, color) do
    Node.new(id, %{x: x, y: y}, %{label: label, author: author, color: color},
      type: :note,
      style: %{"--note-color": color}
    )
  end

  @doc false
  def default_flow do
    color = "#64748b"

    nodes = [
      note("idea", 0, 120, "Idea", "LiveFlow", color),
      note("research", 240, 30, "Research", "LiveFlow", color),
      note("design", 240, 210, "Design", "LiveFlow", color),
      note("build", 480, 120, "Build", "LiveFlow", color),
      note("launch", 720, 120, "Launch", "LiveFlow", color)
    ]

    edges = [
      Edge.new("idea-research", "idea", "research",
        type: :smoothstep,
        animated: true,
        reconnectable: true
      ),
      Edge.new("idea-design", "idea", "design",
        type: :smoothstep,
        animated: true,
        reconnectable: true
      ),
      Edge.new("research-build", "research", "build", type: :smoothstep, reconnectable: true),
      Edge.new("design-build", "design", "build", type: :smoothstep, reconnectable: true),
      Edge.new("build-launch", "build", "launch", type: :smoothstep, reconnectable: true)
    ]

    State.new(nodes: nodes, edges: edges)
  end
end
