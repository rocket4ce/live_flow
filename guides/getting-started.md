# Getting Started with LiveFlow

LiveFlow is a flow diagram library for Phoenix LiveView. It provides interactive,
node-based diagrams with dragging, connecting, zooming, and panning -- all powered
by LiveView with a thin JavaScript hook layer.

## Installation

Add `live_flow` to your dependencies in `mix.exs`:

```elixir
defp deps do
  [
    {:live_flow, "~> 0.3.1"}
  ]
end
```

Then fetch the dependency:

```bash
mix deps.get
```

## JavaScript Hook Setup

LiveFlow requires a JavaScript hook to handle client-side interactions (pan, zoom,
drag, connections). Import and register it in your `app.js`:

```javascript
// assets/js/app.js
import { LiveFlowHook, FileImportHook, setupDownloadHandler } from "live_flow"

let liveSocket = new LiveSocket("/live", Socket, {
  hooks: {
    LiveFlow: LiveFlowHook,
    FileImport: FileImportHook,
    // ...your other hooks
  },
  // ...
})

// Enable file download support (for JSON export)
setupDownloadHandler()
```

The client-side ELK auto layout is optional (elkjs adds about 1.6 MB to the bundle).
Run `mix live_flow.gen.elk` if you need it; it vendors elkjs and registers it in `app.js`.
The Elixir layouts in `LiveFlow.Layout` don't need it (see [Layout](layout.md)).

## CSS Import

Import the LiveFlow stylesheet in your `assets/css/app.css`:

```css
/* assets/css/app.css */
@import "../../deps/live_flow/assets/css/live_flow.css";
```

The library rules live in `@layer components`, so your own CSS and Tailwind
utilities override them without `!important`. For the 36 built-in themes (Tailwind v4
plugin), see the [Themes Guide](themes.md).

## Creating Your First Flow

### 1. Set Up the LiveView

Create a LiveView that initializes the flow state in `mount/3`:

```elixir
defmodule MyAppWeb.FlowLive do
  use MyAppWeb, :live_view

  alias LiveFlow.{State, Node, Edge, Handle}

  @impl true
  def mount(_params, _session, socket) do
    nodes = [
      Node.new("node-1", %{x: 100, y: 100}, %{label: "Start"},
        handles: [Handle.source(:right)]
      ),
      Node.new("node-2", %{x: 400, y: 100}, %{label: "Process"},
        handles: [Handle.target(:left), Handle.source(:right)]
      ),
      Node.new("node-3", %{x: 700, y: 100}, %{label: "End"},
        handles: [Handle.target(:left)]
      )
    ]

    edges = [
      Edge.new("e1", "node-1", "node-2"),
      Edge.new("e2", "node-2", "node-3")
    ]

    flow = State.new(nodes: nodes, edges: edges)

    {:ok, assign(socket, flow: flow)}
  end
end
```

### 2. Render the Flow Component

Use `LiveFlow.Components.Flow` as a LiveComponent in your template:

```elixir
@impl true
def render(assigns) do
  ~H"""
  <div class="h-screen">
    <.live_component
      module={LiveFlow.Components.Flow}
      id="my-flow"
      flow={@flow}
      opts={%{
        controls: true,
        minimap: true,
        background: :dots,
        fit_view_on_init: true
      }}
    />
  </div>
  """
end
```

The Flow component must be wrapped in a container with a defined height.

### 3. Handle Events

The hook sends events to the parent LiveView with `pushEvent`. The
`LiveFlow.Changes.NodeChange` and `LiveFlow.Changes.EdgeChange` helpers apply the
change lists for you. Here is a minimal set of handlers:

```elixir
alias LiveFlow.Changes.{EdgeChange, NodeChange}
alias LiveFlow.Validation.Connection

@impl true
def handle_event("lf:node_change", %{"changes" => changes}, socket) do
  # position, dimensions, resize and remove changes
  flow = NodeChange.apply_changes(socket.assigns.flow, changes)
  {:noreply, assign(socket, flow: flow)}
end

def handle_event("lf:edge_change", %{"changes" => changes}, socket) do
  flow = EdgeChange.apply_changes(socket.assigns.flow, changes)
  {:noreply, assign(socket, flow: flow)}
end

def handle_event("lf:connect_end", params, socket) do
  case Connection.validate_and_create(socket.assigns.flow, params) do
    {:ok, edge} ->
      {:noreply, assign(socket, flow: State.add_edge(socket.assigns.flow, edge))}

    {:error, _reason} ->
      {:noreply, socket}
  end
end

def handle_event("lf:selection_change", %{"nodes" => node_ids, "edges" => edge_ids}, socket) do
  flow =
    socket.assigns.flow
    |> State.clear_selection()
    |> State.select_nodes(node_ids)

  flow = Enum.reduce(edge_ids, flow, &State.select_edge(&2, &1, multi: true))
  {:noreply, assign(socket, flow: flow)}
end

def handle_event("lf:delete_selected", _params, socket) do
  # Nodes and edges with deletable: false are kept
  {:noreply, assign(socket, flow: State.delete_selected(socket.assigns.flow))}
end

def handle_event("lf:viewport_change", params, socket) do
  {:noreply, assign(socket, flow: State.update_viewport(socket.assigns.flow, params))}
end

def handle_event("lf:edge_label_change", %{"id" => id, "label" => label}, socket) do
  {:noreply, assign(socket, flow: State.update_edge(socket.assigns.flow, id, label: label))}
end

# Catch-all for the other lf: events (lf:drag_move, lf:connect_cancel,
# lf:undo, lf:copy, lf:paste, ...)
def handle_event("lf:" <> _event, _params, socket) do
  {:noreply, socket}
end

# Node clicks arrive as a message, not as an event
@impl true
def handle_info({:lf_node_click, _node_id}, socket) do
  {:noreply, socket}
end
```

If your LiveView defines other `handle_info/2` clauses, keep one for
`{:lf_node_click, node_id}`: it is sent on every node click.

## Common Events

| Event | Payload | Description |
|-------|---------|-------------|
| `lf:node_change` | `%{"changes" => [change]}` | `position` (with `"dragging"`), `dimensions`, `resize` (with `"resizing"`) or `remove` |
| `lf:edge_change` | `%{"changes" => [change]}` | Edge removed with its delete button |
| `lf:connect_end` | `%{"source", "source_handle", "target", "target_handle"}` | A connection was completed |
| `lf:connect_cancel` | `%{"node_id", "handle_id", "handle_type", "position", "reason"}` | A connection was dropped on the pane or an invalid handle |
| `lf:selection_change` | `%{"nodes" => [id], "edges" => [id]}` | The selection changed |
| `lf:delete_selected` | `%{}` | The delete key was pressed with a selection |
| `lf:viewport_change` | `%{"x", "y", "zoom"}` | Pan or zoom changed (throttled, final value always sent) |
| `lf:edge_label_change` | `%{"id", "label"}` | An edge label was edited (double click) |
| `{:lf_node_click, node_id}` | `handle_info/2` message | A node was clicked |

See the [Events](events.md) reference for every event, including the opt-in ones
(context menu, pane click, connection start), reconnection, drag and drop,
clipboard and undo/redo.

## State Management Pattern

LiveFlow follows a strict pattern: **the parent LiveView is the single source of
truth** for all flow state.

```
User interaction (JS)
    |
    v
pushEvent to parent LiveView
    |
    v
handle_event updates @flow
    |
    v
assign(socket, flow: flow)
    |
    v
Flow LiveComponent re-renders with new state
```

Key rules:

1. All state-modifying events go to the parent LiveView via `pushEvent`.
2. The parent updates the `@flow` assign and the Flow component re-renders.
3. Never create authoritative state inside the LiveComponent -- it will be
   overwritten on the next `update/2` from the parent.
4. Client-side-only interactions (connection preview line, selection box,
   in-progress drags) are handled entirely in JavaScript without server roundtrips.

## Component Options

Pass options via the `opts` map. The most common ones:

| Option | Default | Description |
|--------|---------|-------------|
| `controls` | `false` | Zoom in/out and fit view buttons |
| `minimap` | `false` | Minimap overlay |
| `background` | `nil` | `:dots`, `:lines`, `:cross` or `nil` |
| `fit_view_on_init` | `false` | Fit the view to the nodes on mount |
| `min_zoom` / `max_zoom` | `0.1` / `4.0` | Zoom limits |
| `snap_to_grid` / `snap_grid` | `false` / `{15, 15}` | Snap positions to a grid |
| `nodes_draggable` / `nodes_connectable` / `elements_selectable` | `true` | Global interaction switches |
| `connection_mode` | `:strict` | `:loose` also connects source to source |
| `delete_key_code` | `["Backspace", "Delete"]` | Keys deleting the selection (`nil` disables) |
| `helper_lines` | `false` | Alignment guides while dragging |
| `theme` | `nil` | LiveFlow theme name (see [Themes](themes.md)) |
| `virtualization` | `false` | Server-side viewport culling for large flows |

```heex
<.live_component
  module={LiveFlow.Components.Flow}
  id="my-flow"
  flow={@flow}
  class="rounded-xl border"
  opts={%{controls: true, background: :dots, snap_to_grid: true, connection_mode: :loose}}
>
  <:panel position={:top_right}>
    <button phx-click="add_node">Add node</button>
  </:panel>
</.live_component>
```

The `class` attribute adds classes to the flow container, and the `:panel` slot
renders your own UI on top of the flow. See [Components](components.md) for every
attribute, slot and option, and [Interaction](interaction.md) for panning, zooming,
selection, keyboard and connection options.

## Nodes and Edges

### Creating Nodes

```elixir
# Basic node
Node.new("id", %{x: 100, y: 200}, %{label: "My Node"})

# Node with handles and options
Node.new("id", %{x: 100, y: 200}, %{label: "My Node"},
  type: :custom,                 # Renderer from node_types (see Custom Nodes)
  width: 180,                    # Initial size, replaced by the measured one
  height: 60,
  deletable: false,              # No delete button, kept by delete_selected
  drag_handle: ".drag-handle",   # Only draggable from matching elements
  handles: [
    Handle.target(:left),
    Handle.source(:right, id: "yes", offset: 0.3),  # Several handles per side
    Handle.source(:right, id: "no", offset: 0.7)
  ]
)
```

Nodes without `handles` get a target handle on the left and a source handle on the
right. Other options include `hidden`, `draggable`, `selectable`, `connectable`,
`resizable`, `class`, `style`, `z_index` and `parent_id` (see [Sub-flows](subflows.md)).

### Creating Edges

```elixir
# Basic edge
Edge.new("e1", "source-node-id", "target-node-id")

# Edge with options
Edge.new("e2", "node-a", "node-b",
  source_handle: "yes",
  type: :smoothstep,     # :bezier (default), :straight, :step, :smoothstep
  animated: true,
  label: "connects to",
  marker_end: %{type: :arrow}
)
```

See [Edges](edges.md) for markers, labels, custom edges and reconnection.

## Programmatic Actions

Fit the view from the server with `send_update/2` (the bounds are computed on the
server, so nodes culled by virtualization are included):

```elixir
send_update(LiveFlow.Components.Flow, id: "my-flow", fit_view: true)
send_update(LiveFlow.Components.Flow, id: "my-flow", fit_view: %{nodes: ["a", "b"], padding: 0.2})
```

Download a file built on the server (requires `setupDownloadHandler()`):

```elixir
push_event(socket, "lf:download_file", %{
  content: LiveFlow.Serializer.to_json(socket.assigns.flow),
  filename: "flow.json",
  type: "application/json"
})
```

Trigger client actions from HEEx with `JS.dispatch`:

```heex
<button phx-click={JS.dispatch("lf:fit-view", to: "#my-flow")}>Fit view</button>
<button phx-click={JS.dispatch("lf:export-svg", to: "#my-flow")}>Export SVG</button>
<button phx-click={JS.dispatch("lf:export-png", to: "#my-flow", detail: %{scale: 2})}>
  Export PNG
</button>
```

`JS.dispatch("lf:auto-layout", to: "#my-flow")` pushes `lf:request_layout` to your
LiveView, which answers with `push_event(socket, "lf:layout_data",
LiveFlow.Layout.prepare_layout_data(flow, params))`. It needs ELK
(`mix live_flow.gen.elk`); see [Layout](layout.md) and [Export](export.md).

## Next Steps

- [Custom Nodes](custom-nodes.md) -- Render nodes with your own components
- [Edges](edges.md) -- Edge types, markers, labels and custom edges
- [Interaction](interaction.md) -- Panning, zooming, selection, keyboard and connections
- [Events](events.md) -- Every event the hook sends and accepts
- [Sub-flows](subflows.md) -- Parent/child nodes and groups
- [Layout](layout.md) -- Tree, force, collision and ELK layouts
- [Components](components.md) -- Flow, NodeToolbar, NodeResizer, Handle and panels
- [Export](export.md) -- JSON, SVG and PNG export
- [Collaboration](collaboration.md) -- Add real-time multi-user editing
- [Themes](themes.md) -- Customize the look and feel
