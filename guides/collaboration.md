# Real-Time Collaboration

LiveFlow includes built-in support for real-time multi-user collaboration. Multiple
users can simultaneously edit the same flow diagram, see each other's cursors, and
track who is online.

## Prerequisites

- **Phoenix PubSub** -- required for broadcasting changes between users
- **Phoenix Presence** -- optional, for tracking online users

Both are included with Phoenix by default. Your application's PubSub module
(e.g., `MyApp.PubSub`) is already configured in your supervision tree.

If you want Presence tracking, create a Presence module:

```elixir
defmodule MyAppWeb.Presence do
  use Phoenix.Presence,
    otp_app: :my_app,
    pubsub_server: MyApp.PubSub
end
```

Add it to your application supervision tree in `lib/my_app/application.ex`:

```elixir
children = [
  # ...
  MyAppWeb.Presence,
  # ...
]
```

## Setting Up Collaboration

### 1. Join a Session in `mount/3`

Use `LiveFlow.Collaboration.join/4` to subscribe the user to a shared topic:

```elixir
defmodule MyAppWeb.CollabFlowLive do
  use MyAppWeb, :live_view

  alias LiveFlow.{State, Node, Edge, Handle}
  alias LiveFlow.Collaboration
  alias LiveFlow.Collaboration.User

  @impl true
  def mount(%{"room" => room_id}, _session, socket) do
    # Create or identify the user
    user_id = socket.assigns.current_user.id  # or generate one
    user = User.new(user_id, name: "Alice")

    # Load the shared flow state
    flow = load_flow(room_id)

    socket =
      socket
      |> assign(flow: flow, room_id: room_id)
      |> Collaboration.join("flow:#{room_id}", user,
        pubsub: MyApp.PubSub,
        presence: MyAppWeb.Presence  # optional
      )

    {:ok, socket}
  end
end
```

### What `join/4` Does

Calling `Collaboration.join/4` performs the following:

1. Subscribes to the collaboration PubSub topic
2. Subscribes to the cursor PubSub topic
3. If Presence is configured, tracks the user and subscribes to presence diffs
4. Sets these assigns on the socket:
   - `:lf_user` -- the `User` struct
   - `:lf_topic` -- the base collaboration topic
   - `:lf_pubsub` -- the PubSub module
   - `:lf_presences` -- map of tracked presences
   - `:lf_presence_mod` -- the Presence module (or `nil`)

### 2. Handle Incoming Messages

Delegate PubSub messages to `Collaboration.handle_info/2`:

```elixir
@impl true
def handle_info(msg, socket) do
  case Collaboration.handle_info(msg, socket) do
    {:ok, socket} -> {:noreply, socket}
    :ignore -> {:noreply, socket}
  end
end
```

`Collaboration.handle_info/2` handles these messages and returns `:ignore` for
anything else:

| Message | Description |
|---------|-------------|
| `{:lf_flow_change, sender_id, change}` | Another user modified the flow: applied with `apply_remote_change/2` and assigned to `:flow` |
| `{:lf_drag_move, sender_id, changes}` | Another user is dragging nodes: pushed to the browser as `lf:remote_drag` |
| `{:lf_cursor_move, sender_id, cursor_data}` | Another user moved their cursor: pushed as `lf:remote_cursor` |
| `%Phoenix.Socket.Broadcast{event: "presence_diff"}` | A user joined or left: updates `:lf_presences` |

Changes are broadcast with `Phoenix.PubSub.broadcast_from/4`, so a user never
receives their own changes.

### 3. Broadcast Changes

When the local user modifies the flow, broadcast the change so other users see it:

```elixir
alias LiveFlow.Changes.NodeChange

@impl true
def handle_event("lf:node_change", %{"changes" => changes}, socket) do
  flow = NodeChange.apply_changes(socket.assigns.flow, changes)

  # Every browser measures its own nodes: share moves, resizes and removals only
  shared = Enum.filter(changes, &(&1["type"] in ~w(position resize remove)))

  socket =
    if shared == [],
      do: socket,
      else: Collaboration.broadcast_change(socket, {:node_changes, shared})

  {:noreply, assign(socket, flow: flow)}
end

@impl true
def handle_event("lf:connect_end", params, socket) do
  case LiveFlow.Validation.Connection.validate_and_create(socket.assigns.flow, params) do
    {:ok, edge} ->
      flow = State.add_edge(socket.assigns.flow, edge)
      socket = Collaboration.broadcast_change(socket, {:edge_add, edge})
      {:noreply, assign(socket, flow: flow)}

    {:error, _reason} ->
      {:noreply, socket}
  end
end

@impl true
def handle_event("lf:delete_selected", _params, socket) do
  flow = socket.assigns.flow
  node_ids = MapSet.to_list(flow.selected_nodes)
  edge_ids = MapSet.to_list(flow.selected_edges)

  updated_flow = State.delete_selected(flow)
  socket = Collaboration.broadcast_change(socket, {:delete_selected, node_ids, edge_ids})

  {:noreply, assign(socket, flow: updated_flow)}
end
```

### Supported Change Types

`LiveFlow.Collaboration.apply_remote_change/2` understands these changes:

| Change Tuple | Description |
|-------------|-------------|
| `{:node_changes, changes}` | `lf:node_change` change maps (position, dimensions, resize, add, replace, remove). Selection changes are ignored: every user keeps their own selection |
| `{:node_add, %Node{}}` | A node was added |
| `{:node_update, id, attrs}` | A node was updated (`attrs` as in `LiveFlow.State.update_node/3`) |
| `{:node_remove, id}` | A node (and its children) was removed |
| `{:edge_add, %Edge{}}` | A new edge was created |
| `{:edge_update, id, attrs}` | An edge was updated, e.g. `[label: "next"]` |
| `{:edge_remove, edge_id}` | An edge was removed |
| `{:edge_reconnect, params}` | An edge was reconnected (the `lf:reconnect_edge` params) |
| `{:delete_selected, node_ids, edge_ids}` | Bulk deletion of selected elements |
| `{:flow_reset, %State{}}` | The entire flow was replaced |

Unknown changes leave the flow untouched. For your own change types, match
`{:lf_flow_change, _sender, {:my_change, ...}}` in `handle_info/2` before delegating
to `Collaboration.handle_info/2`.

A convenient pattern is a `commit/2` helper that applies a change locally and
broadcasts the same tuple, so both sides run the same code:

```elixir
defp commit(socket, change) do
  socket
  |> assign(:flow, Collaboration.apply_remote_change(socket.assigns.flow, change))
  |> Collaboration.broadcast_change(change)
end

def handle_event("lf:edge_label_change", %{"id" => id, "label" => label}, socket) do
  {:noreply, commit(socket, {:edge_update, id, [label: label]})}
end

def handle_event("lf:reconnect_edge", params, socket) do
  {:noreply, commit(socket, {:edge_reconnect, params})}
end
```

### Live Dragging

`lf:node_change` only reports where a drag starts and ends. To show other users the
nodes moving, relay the throttled `lf:drag_move` events:

```elixir
def handle_event("lf:drag_move", %{"changes" => changes}, socket) do
  {:noreply, Collaboration.broadcast_drag_move(socket, changes)}
end
```

Receivers move the nodes in the browser only (`lf:remote_drag`, interpolated for
smooth movement), without touching their state or re-rendering; the final position
arrives with the `{:node_changes, ...}` broadcast of the drop.

### Shared State

PubSub only carries changes. Users joining later need the current flow, so keep it
somewhere shared (a GenServer, an Agent, ETS or your database), update it on every
change and read it in `mount/3`. The showcase page `/examples/interaction/collaborative`
keeps it in an Agent.

## Cursor Sharing

### Enable the Cursor Overlay

Pass `cursors: true` in the Flow component options:

```elixir
<.live_component
  module={LiveFlow.Components.Flow}
  id="collab-flow"
  flow={@flow}
  opts={%{
    controls: true,
    background: :dots,
    cursors: true
  }}
/>
```

This renders an SVG overlay showing other users' cursors as colored arrows with
name labels.

### Broadcasting Cursor Position

With `cursors: true`, the hook sends `lf:cursor_move` (throttled, in flow
coordinates) while the pointer moves over the flow. Relay it:

```elixir
@impl true
def handle_event("lf:cursor_move", %{"x" => x, "y" => y}, socket) do
  {:noreply, Collaboration.broadcast_cursor(socket, x, y)}
end
```

Other users receive it through `Collaboration.handle_info/2`, which pushes
`lf:remote_cursor` to their browser. Each cursor displays as an SVG arrow in the
user's color, with their name, and disappears when the user leaves (with Presence).

## User Identity

`LiveFlow.Collaboration.User` generates deterministic display names and colors
from the user ID:

```elixir
# Auto-generated name and color (deterministic from ID hash)
user = User.new("user_abc123")
user.name   #=> "User 42"
user.color  #=> "#3b82f6"

# Explicit name and color
user = User.new("user_abc123", name: "Alice", color: "#ef4444")
user.name   #=> "Alice"
user.color  #=> "#ef4444"
```

The color is chosen from a palette of 10 visually distinct colors. The same user
ID always produces the same name and color across sessions.

## Displaying Online Users

LiveFlow provides a `presence_list` function component for showing who is online:

```elixir
@impl true
def render(assigns) do
  ~H"""
  <div class="h-screen flex flex-col">
    <div class="p-4 border-b">
      <Collaboration.presence_list
        presences={@lf_presences}
        current_user={@lf_user}
      />
    </div>

    <div class="flex-1">
      <.live_component
        module={LiveFlow.Components.Flow}
        id="collab-flow"
        flow={@flow}
        opts={%{cursors: true}}
      />
    </div>
  </div>
  """
end
```

This renders each user's name with a colored dot, the current user marked as
"(you)", and a count of online users.

## Leaving a Session

Call `Collaboration.leave/1` when the user disconnects or navigates away:

```elixir
@impl true
def terminate(_reason, socket) do
  Collaboration.leave(socket)
  :ok
end
```

This unsubscribes from PubSub topics and untracks Presence.

## Complete Example

```elixir
defmodule MyAppWeb.CollabFlowLive do
  use MyAppWeb, :live_view

  alias LiveFlow.State
  alias LiveFlow.Changes.NodeChange
  alias LiveFlow.Collaboration
  alias LiveFlow.Collaboration.User

  @impl true
  def mount(%{"room" => room_id}, session, socket) do
    user = User.new(session["user_id"] || "anon-#{System.unique_integer([:positive])}")
    flow = get_or_create_flow(room_id)

    socket =
      socket
      |> assign(flow: flow, room_id: room_id)
      |> Collaboration.join("flow:#{room_id}", user,
        pubsub: MyApp.PubSub,
        presence: MyAppWeb.Presence
      )

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-screen flex flex-col">
      <div class="p-3 bg-base-200 border-b flex items-center justify-between">
        <h1 class="font-bold">Room: {@room_id}</h1>
        <Collaboration.presence_list
          presences={@lf_presences}
          current_user={@lf_user}
        />
      </div>
      <div class="flex-1">
        <.live_component
          module={LiveFlow.Components.Flow}
          id="collab-flow"
          flow={@flow}
          opts={%{controls: true, background: :dots, cursors: true, fit_view_on_init: true}}
        />
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("lf:node_change", %{"changes" => changes}, socket) do
    flow = NodeChange.apply_changes(socket.assigns.flow, changes)
    shared = Enum.filter(changes, &(&1["type"] in ~w(position resize remove)))

    socket =
      if shared == [],
        do: socket,
        else: Collaboration.broadcast_change(socket, {:node_changes, shared})

    {:noreply, assign(socket, flow: flow)}
  end

  @impl true
  def handle_event("lf:drag_move", %{"changes" => changes}, socket) do
    {:noreply, Collaboration.broadcast_drag_move(socket, changes)}
  end

  @impl true
  def handle_event("lf:cursor_move", %{"x" => x, "y" => y}, socket) do
    {:noreply, Collaboration.broadcast_cursor(socket, x, y)}
  end

  @impl true
  def handle_event("lf:connect_end", params, socket) do
    case LiveFlow.Validation.Connection.validate_and_create(socket.assigns.flow, params) do
      {:ok, edge} ->
        flow = State.add_edge(socket.assigns.flow, edge)
        socket = Collaboration.broadcast_change(socket, {:edge_add, edge})
        {:noreply, assign(socket, flow: flow)}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("lf:delete_selected", _params, socket) do
    flow = socket.assigns.flow
    node_ids = MapSet.to_list(flow.selected_nodes)
    edge_ids = MapSet.to_list(flow.selected_edges)
    updated = State.delete_selected(flow)
    socket = Collaboration.broadcast_change(socket, {:delete_selected, node_ids, edge_ids})
    {:noreply, assign(socket, flow: updated)}
  end

  @impl true
  def handle_event("lf:viewport_change", params, socket) do
    flow = State.update_viewport(socket.assigns.flow, params)
    {:noreply, assign(socket, flow: flow)}
  end

  @impl true
  def handle_event("lf:selection_change", %{"nodes" => nodes, "edges" => edges}, socket) do
    flow =
      socket.assigns.flow
      |> State.clear_selection()
      |> State.select_nodes(nodes)

    flow = Enum.reduce(edges, flow, &State.select_edge(&2, &1, multi: true))
    {:noreply, assign(socket, flow: flow)}
  end

  @impl true
  def handle_event("lf:" <> _, _params, socket), do: {:noreply, socket}

  @impl true
  def handle_info(msg, socket) do
    case Collaboration.handle_info(msg, socket) do
      {:ok, socket} -> {:noreply, socket}
      :ignore -> {:noreply, socket}
    end
  end

  @impl true
  def terminate(_reason, socket) do
    Collaboration.leave(socket)
    :ok
  end

  # get_or_create_flow/1 reads the shared state (see "Shared State")
end
```

## Architecture Notes

- Collaboration is PubSub-based with no central server process. Each LiveView
  process subscribes to shared topics and broadcasts changes directly (keep the
  shared state for late joiners yourself, see "Shared State").
- Changes from the current user are applied locally first, then broadcast.
  `handle_info/2` skips messages from the current user to avoid double-applying.
- Undo/redo history is local only and not broadcast to other users.
- Cursor positions are broadcast on a separate PubSub topic (`"#{topic}:cursors"`)
  to allow independent throttling.
