defmodule LiveFlow.Collaboration do
  @moduledoc """
  Real-time collaboration support for LiveFlow.

  This module provides functions to add multi-user collaboration to any
  LiveFlow-powered LiveView. It handles PubSub messaging, cursor broadcasting,
  and optional Presence tracking.

  ## Setup

  1. Call `join/4` in your LiveView's `mount/3` to subscribe to collaboration topics.
  2. Delegate `handle_info/2` messages to `Collaboration.handle_info/2`.
  3. Call `broadcast_change/3` when the local user modifies the flow.
  4. Call `broadcast_cursor/3` when the local user moves their cursor.

  ## Example

      defmodule MyAppWeb.CollabFlowLive do
        use MyAppWeb, :live_view

        alias LiveFlow.Collaboration
        alias LiveFlow.Collaboration.User

        def mount(_params, _session, socket) do
          user = User.new("user_123", name: "Alice")
          flow = MyStore.get_flow()

          socket =
            socket
            |> assign(flow: flow)
            |> Collaboration.join("flow:room-1", user, pubsub: MyApp.PubSub)

          {:ok, socket}
        end

        def handle_info(msg, socket) do
          case Collaboration.handle_info(msg, socket) do
            {:ok, socket} -> {:noreply, socket}
            :ignore -> {:noreply, socket}
          end
        end

        def handle_event("lf:node_change", %{"changes" => changes}, socket) do
          flow = apply_node_changes(socket.assigns.flow, changes)
          socket = Collaboration.broadcast_change(socket, {:node_changes, changes})
          {:noreply, assign(socket, flow: flow)}
        end
      end

  ## Options for `join/4`

    * `:pubsub` - (required) The PubSub module to use (e.g., `MyApp.PubSub`)
    * `:presence` - (optional) A Phoenix.Presence module for tracking online users
    * `:presence_topic` - (optional) Custom presence topic. Defaults to `"\#{topic}:presence"`
  """

  use Phoenix.Component

  alias LiveFlow.{State, Edge}
  alias LiveFlow.Collaboration.User

  @doc """
  Joins a collaborative flow session.

  Subscribes to PubSub topics and optionally tracks Presence.
  Sets the following assigns on the socket:

    * `:lf_user` - The `User` struct for the current user
    * `:lf_topic` - The base collaboration topic
    * `:lf_pubsub` - The PubSub module
    * `:lf_presences` - Map of tracked presences (empty if Presence is not configured)
    * `:lf_presence_mod` - The Presence module (nil if not configured)
    * `:lf_presence_topic` - The presence topic
  """
  @spec join(Phoenix.LiveView.Socket.t(), String.t(), User.t(), keyword()) ::
          Phoenix.LiveView.Socket.t()
  def join(socket, topic, %User{} = user, opts) do
    pubsub = Keyword.fetch!(opts, :pubsub)
    presence_mod = Keyword.get(opts, :presence)
    presence_topic = Keyword.get(opts, :presence_topic, "#{topic}:presence")
    cursor_topic = "#{topic}:cursors"

    if Phoenix.LiveView.connected?(socket) do
      Phoenix.PubSub.subscribe(pubsub, topic)
      Phoenix.PubSub.subscribe(pubsub, cursor_topic)

      if presence_mod do
        Phoenix.PubSub.subscribe(pubsub, presence_topic)

        presence_mod.track(self(), presence_topic, user.id, User.to_presence_meta(user))
      end
    end

    presences =
      if presence_mod && Phoenix.LiveView.connected?(socket) do
        presence_mod.list(presence_topic)
      else
        %{}
      end

    Phoenix.Component.assign(socket,
      lf_user: user,
      lf_topic: topic,
      lf_pubsub: pubsub,
      lf_presences: presences,
      lf_presence_mod: presence_mod,
      lf_presence_topic: presence_topic
    )
  end

  @doc """
  Leaves the collaborative session.

  Unsubscribes from PubSub topics and untracks Presence.
  """
  @spec leave(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def leave(socket) do
    assigns = socket.assigns
    pubsub = assigns[:lf_pubsub]
    topic = assigns[:lf_topic]

    if pubsub && topic do
      Phoenix.PubSub.unsubscribe(pubsub, topic)
      Phoenix.PubSub.unsubscribe(pubsub, "#{topic}:cursors")

      if assigns[:lf_presence_mod] do
        Phoenix.PubSub.unsubscribe(pubsub, assigns.lf_presence_topic)
      end
    end

    socket
  end

  @doc """
  Broadcasts a flow change to all other users in the session.

  The change is a tuple describing what changed. Supported change types:

    * `{:node_changes, changes}` - Node position/dimension/remove changes
    * `{:edge_add, edge}` - A new edge was added
    * `{:edge_remove, id}` - An edge was removed
    * `{:delete_selected, node_ids, edge_ids}` - Bulk deletion
    * `{:flow_reset, flow}` - The entire flow was replaced
  """
  @spec broadcast_change(Phoenix.LiveView.Socket.t(), tuple()) ::
          Phoenix.LiveView.Socket.t()
  def broadcast_change(socket, change) do
    assigns = socket.assigns

    Phoenix.PubSub.broadcast(
      assigns.lf_pubsub,
      assigns.lf_topic,
      {:lf_flow_change, assigns.lf_user.id, change}
    )

    socket
  end

  @doc """
  Broadcasts the local user's cursor position to other users.

  Coordinates should be in flow-space (not screen-space).
  """
  @spec broadcast_cursor(Phoenix.LiveView.Socket.t(), number(), number()) ::
          Phoenix.LiveView.Socket.t()
  def broadcast_cursor(socket, x, y) do
    assigns = socket.assigns
    user = assigns.lf_user

    Phoenix.PubSub.broadcast(
      assigns.lf_pubsub,
      "#{assigns.lf_topic}:cursors",
      {:lf_cursor_move, user.id, %{x: x, y: y, name: user.name, color: user.color}}
    )

    socket
  end

  @doc """
  Handles incoming PubSub and Presence messages for collaboration.

  Returns `{:ok, socket}` if the message was handled, or `:ignore` if
  the message is not a collaboration message.

  Delegates to your LiveView's `handle_info/2`:

      def handle_info(msg, socket) do
        case Collaboration.handle_info(msg, socket) do
          {:ok, socket} -> {:noreply, socket}
          :ignore -> {:noreply, socket}
        end
      end
  """
  @spec handle_info(term(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()} | :ignore
  def handle_info({:lf_flow_change, sender_id, _change}, %{assigns: %{lf_user: %{id: sender_id}}} = _socket) do
    # Skip changes from self — we already applied them locally
    # Return :ignore so the LiveView can handle it if needed
    :ignore
  end

  def handle_info({:lf_flow_change, _sender_id, change}, socket) do
    flow = apply_remote_change(socket.assigns.flow, change)
    {:ok, Phoenix.Component.assign(socket, flow: flow)}
  end

  def handle_info({:lf_cursor_move, sender_id, _cursor}, %{assigns: %{lf_user: %{id: sender_id}}} = _socket) do
    :ignore
  end

  def handle_info({:lf_cursor_move, sender_id, cursor}, socket) do
    socket =
      Phoenix.LiveView.push_event(socket, "lf:remote_cursor", %{
        user_id: sender_id,
        x: cursor.x,
        y: cursor.y,
        name: cursor.name,
        color: cursor.color
      })

    {:ok, socket}
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{event: "presence_diff", payload: diff},
        socket
      ) do
    assigns = socket.assigns

    if assigns[:lf_presence_mod] do
      presences = assigns.lf_presence_mod.list(assigns.lf_presence_topic)

      # Push cursor_leave for users who left
      left_ids = Map.keys(diff.leaves)

      socket =
        Enum.reduce(left_ids, socket, fn id, acc ->
          Phoenix.LiveView.push_event(acc, "lf:cursor_leave", %{user_id: id})
        end)

      {:ok, Phoenix.Component.assign(socket, lf_presences: presences)}
    else
      :ignore
    end
  end

  def handle_info(_msg, _socket), do: :ignore

  @doc """
  Applies a remote change to the local flow state.

  This is a pure function — it takes a flow and a change tuple,
  and returns the updated flow.
  """
  @spec apply_remote_change(State.t(), tuple()) :: State.t()
  def apply_remote_change(flow, {:node_changes, changes}) do
    Enum.reduce(changes, flow, fn change, acc ->
      apply_node_change(acc, change)
    end)
  end

  def apply_remote_change(flow, {:edge_add, %Edge{} = edge}) do
    State.add_edge(flow, edge)
  end

  def apply_remote_change(flow, {:edge_remove, id}) do
    State.remove_edge(flow, id)
  end

  def apply_remote_change(flow, {:delete_selected, node_ids, edge_ids}) do
    flow
    |> State.remove_nodes(node_ids)
    |> State.remove_edges(edge_ids)
  end

  def apply_remote_change(_flow, {:flow_reset, new_flow}) do
    new_flow
  end

  def apply_remote_change(flow, _unknown), do: flow

  # Function component for rendering a presence list

  @doc """
  Renders a list of online users with colored badges.

  ## Attributes

    * `:presences` - Map of presences from `Presence.list/1` (required)
    * `:current_user` - The current `User` struct to highlight/exclude (required)
  """
  attr :presences, :map, required: true
  attr :current_user, User, required: true

  def presence_list(assigns) do
    ~H"""
    <div class="flex items-center gap-3">
      <div class="flex items-center gap-2 text-sm font-medium">
        <div class="w-3 h-3 rounded-full" style={"background: #{@current_user.color}"}></div>
        <span>{@current_user.name} (you)</span>
      </div>
      <div class="text-base-content/30">|</div>
      <div class="flex items-center gap-2">
        <.presence_badge
          :for={{id, meta} <- @presences}
          :if={id != @current_user.id}
          meta={meta}
        />
      </div>
      <span class="text-xs text-base-content/50">
        {map_size(@presences)} online
      </span>
    </div>
    """
  end

  attr :meta, :map, required: true

  defp presence_badge(assigns) do
    first_meta = hd(Map.get(assigns.meta, :metas, [%{}]))

    assigns =
      assigns
      |> assign(:name, Map.get(first_meta, :name, "?"))
      |> assign(:color, Map.get(first_meta, :color, "#888"))

    ~H"""
    <span class="flex items-center gap-1 text-xs">
      <div class="w-2 h-2 rounded-full" style={"background: #{@color}"}></div>
      <span>{@name}</span>
    </span>
    """
  end

  # Private helpers

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
end
