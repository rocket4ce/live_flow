# Getting Started with LiveFlow

LiveFlow is a flow diagram library for Phoenix LiveView. It provides interactive,
node-based diagrams with dragging, connecting, zooming, and panning -- all powered
by LiveView with a thin JavaScript hook layer.

## Installation

Add `live_flow` to your dependencies in `mix.exs`:

```elixir
defp deps do
  [
    {:live_flow, "~> 0.2.3"}
  ]
end
```

Then fetch and compile:

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

## CSS Import

Import the LiveFlow stylesheet in your CSS:

```css
/* assets/css/app.css */
@import "live_flow/live_flow.css";
```

If you want theme support via the Tailwind v4 plugin, see the [Themes Guide](themes.md).

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

LiveFlow sends events to the parent LiveView via `pushEvent`. You need handlers
for each event type. Here is a minimal set:

```elixir
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
  case LiveFlow.Validation.Connection.validate_and_create(socket.assigns.flow, params) do
    {:ok, edge} ->
      flow = State.add_edge(socket.assigns.flow, edge)
      {:noreply, assign(socket, flow: flow)}

    {:error, _reason} ->
      {:noreply, socket}
  end
end

@impl true
def handle_event("lf:viewport_change", params, socket) do
  flow = State.update_viewport(socket.assigns.flow, params)
  {:noreply, assign(socket, flow: flow)}
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

# Catch-all for other lf: events (connect_start, connect_move, connect_cancel, etc.)
@impl true
def handle_event("lf:" <> _event, _params, socket) do
  {:noreply, socket}
end

# Private helper for applying node changes
defp apply_node_change(flow, %{"type" => "position", "id" => id, "position" => pos} = change) do
  case Map.get(flow.nodes, id) do
    nil -> flow
    node ->
      updated = %{node | position: %{x: pos["x"] / 1, y: pos["y"] / 1},
                         dragging: Map.get(change, "dragging", false)}
      %{flow | nodes: Map.put(flow.nodes, id, updated)}
  end
end

defp apply_node_change(flow, %{"type" => "dimensions", "id" => id} = change) do
  case Map.get(flow.nodes, id) do
    nil -> flow
    node ->
      updated = %{node | width: Map.get(change, "width"),
                         height: Map.get(change, "height"),
                         measured: true}
      %{flow | nodes: Map.put(flow.nodes, id, updated)}
  end
end

defp apply_node_change(flow, %{"type" => "remove", "id" => id}) do
  State.remove_node(flow, id)
end

defp apply_node_change(flow, _change), do: flow
```

## Event Reference

| Event | Payload | Description |
|-------|---------|-------------|
| `lf:node_change` | `%{"changes" => [change]}` | Node position, dimensions, or removal |
| `lf:edge_change` | `%{"changes" => [change]}` | Edge selection or removal |
| `lf:connect_end` | `%{"source" => id, "target" => id, ...}` | A connection was completed |
| `lf:connect_start` | `%{"node_id" => id, "handle_id" => id}` | User started dragging a connection |
| `lf:connect_cancel` | `%{}` | Connection was cancelled |
| `lf:viewport_change` | `%{"x" => x, "y" => y, "zoom" => z}` | Pan or zoom changed |
| `lf:selection_change` | `%{"nodes" => [ids], "edges" => [ids]}` | Selection changed |
| `lf:delete_selected` | `%{}` | User pressed delete key |
| `lf:edge_label_change` | `%{"id" => id, "label" => text}` | Edge label was edited |

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
4. Client-side-only interactions (connection preview line, selection box) are
   handled entirely in JavaScript without server roundtrips.

## Component Options

Pass options via the `opts` map:

```elixir
<.live_component
  module={LiveFlow.Components.Flow}
  id="my-flow"
  flow={@flow}
  opts={%{
    pan_on_drag: true,          # Pan by dragging the canvas
    zoom_on_scroll: true,       # Zoom with scroll wheel
    min_zoom: 0.1,              # Minimum zoom level
    max_zoom: 4.0,              # Maximum zoom level
    snap_to_grid: false,        # Snap node positions to grid
    snap_grid: {15, 15},        # Grid size {x, y}
    fit_view_on_init: false,    # Fit view to content on mount
    background: :dots,          # Background: :dots, :lines, :cross, or nil
    minimap: false,             # Show minimap overlay
    controls: false,            # Show zoom +/- controls
    helper_lines: false,        # Show alignment guides on drag
    theme: "dark",              # LiveFlow theme name
    cursors: false,             # Show remote cursors (collaboration)
    nodes_draggable: true,      # Allow dragging nodes
    nodes_connectable: true,    # Allow creating connections
    elements_selectable: true,  # Allow selecting nodes/edges
    delete_key_code: "Backspace" # Key to delete selected elements
  }}
/>
```

## Nodes and Edges

### Creating Nodes

```elixir
# Basic node
Node.new("id", %{x: 100, y: 200}, %{label: "My Node"})

# Node with handles and options
Node.new("id", %{x: 100, y: 200}, %{label: "My Node"},
  type: :custom,
  handles: [
    Handle.new(:target, :top),
    Handle.new(:source, :bottom, id: "output-1"),
    Handle.source(:right),   # Shorthand
    Handle.target(:left)     # Shorthand
  ]
)
```

### Creating Edges

```elixir
# Basic edge
Edge.new("e1", "source-node-id", "target-node-id")

# Edge with options
Edge.new("e2", "node-a", "node-b",
  type: :straight,       # :bezier (default), :straight, :step, :smoothstep
  animated: true,
  label: "connects to",
  marker_end: %{type: :arrow}
)
```

## Programmatic Actions

Trigger actions from the server by pushing events to the client:

```elixir
# Fit view to content
push_event(socket, "lf:fit_view", %{padding: 0.1, duration: 200})

# Download file
push_event(socket, "lf:download_file", %{
  content: json_string,
  filename: "flow.json",
  type: "application/json"
})
```

Trigger actions from HEEx with `JS.dispatch`:

```heex
<button phx-click={JS.dispatch("lf:auto-layout", to: "#my-flow")}>
  Auto Layout
</button>
<button phx-click={JS.dispatch("lf:export-svg", to: "#my-flow")}>
  Export SVG
</button>
```

## Next Steps

- [Custom Nodes](custom-nodes.md) -- Render nodes with your own components
- [Collaboration](collaboration.md) -- Add real-time multi-user editing
- [Themes](themes.md) -- Customize the look and feel
