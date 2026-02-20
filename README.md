# LiveFlow

Interactive node-based flow diagrams for Phoenix LiveView.

Build visual node editors, workflow builders, and interactive diagrams — similar to [React Flow](https://reactflow.dev), but for Phoenix LiveView.

## Features

- **Pan & Zoom** — Mouse wheel zoom, drag-to-pan, fit-to-view, minimap-style controls
- **Node Drag** — Drag nodes with grid snapping and helper lines (alignment guides)
- **Connections** — Source/target handles with live connection preview and validation
- **Selection** — Click, Shift+click, and selection box (lasso) for multi-select
- **Custom Nodes** — Function components or LiveComponents as custom node types
- **Edge Types** — Bezier, straight, step, and smoothstep paths with animated edges
- **Edge Labels** — Inline-editable labels on edges (double-click to edit)
- **Undo/Redo** — Snapshot-based history with configurable max entries
- **Copy/Paste** — Clipboard with copy, cut, paste, and duplicate
- **Serialization** — Export/import flow state as JSON
- **Collaboration** — Real-time multi-user editing via PubSub with cursor sharing
- **Validation** — Composable connection validators (no duplicates, no cycles, type compatibility, max connections)
- **Auto Layout** — ELK layered layout and tree layout algorithms
- **Themes** — 36 built-in themes with Tailwind v4 plugin for customization
- **Export** — Client-side SVG/PNG export
- **Touch Support** — Pinch-to-zoom, two-finger pan, long-press selection
- **Keyboard Shortcuts** — Built-in shortcuts panel (`?` key)

## Installation

Add `live_flow` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:live_flow, "~> 0.2.1"}
  ]
end
```

### JavaScript Setup

In your `assets/js/app.js`, import and register the hook:

```javascript
import { LiveFlowHook } from "live_flow"
// Optional: FileImport hook for JSON import
import { FileImportHook, setupDownloadHandler } from "live_flow"

let liveSocket = new LiveSocket("/live", Socket, {
  hooks: {
    LiveFlow: LiveFlowHook,
    FileImport: FileImportHook  // optional
  }
})

// Optional: enable JSON file download
setupDownloadHandler()
```

### CSS Setup

Import the LiveFlow stylesheet in your `assets/css/app.css`:

```css
@import "../../deps/live_flow/assets/css/live_flow.css";
```

### Theme Setup (Optional)

To use the built-in themes, add the Tailwind v4 plugin:

```css
@plugin "../../deps/live_flow/assets/js/live_flow/liveflow-theme" {
  name: "light";
  default: true;
}
@plugin "../../deps/live_flow/assets/js/live_flow/liveflow-theme" {
  name: "dark";
  prefersdark: true;
}
```

## Quick Start

```elixir
defmodule MyAppWeb.FlowLive do
  use MyAppWeb, :live_view

  alias LiveFlow.{State, Node, Edge}

  def mount(_params, _session, socket) do
    flow = State.new(
      nodes: [
        Node.new("1", %{x: 100, y: 100}, %{label: "Start"}),
        Node.new("2", %{x: 300, y: 200}, %{label: "Process"}),
        Node.new("3", %{x: 500, y: 100}, %{label: "End"})
      ],
      edges: [
        Edge.new("e1", "1", "2"),
        Edge.new("e2", "2", "3")
      ]
    )

    {:ok, assign(socket, flow: flow)}
  end

  def render(assigns) do
    ~H"""
    <.live_component
      module={LiveFlow.Components.Flow}
      id="my-flow"
      flow={@flow}
      opts={%{controls: true, background: :dots}}
    />
    """
  end

  # Handle node position changes
  def handle_event("lf:node_change", params, socket) do
    flow = LiveFlow.Changes.NodeChange.apply(socket.assigns.flow, params)
    {:noreply, assign(socket, flow: flow)}
  end

  # Handle edge changes (add/remove)
  def handle_event("lf:edge_change", params, socket) do
    flow = LiveFlow.Changes.EdgeChange.apply(socket.assigns.flow, params)
    {:noreply, assign(socket, flow: flow)}
  end

  # Handle new connections
  def handle_event("lf:connect_end", params, socket) do
    case LiveFlow.Validation.Connection.validate_and_create(
      socket.assigns.flow, params
    ) do
      {:ok, flow} -> {:noreply, assign(socket, flow: flow)}
      {:error, _reason} -> {:noreply, socket}
    end
  end

  # Handle viewport changes (pan/zoom)
  def handle_event("lf:viewport_change", params, socket) do
    viewport = LiveFlow.Viewport.from_params(params)
    flow = LiveFlow.State.update_viewport(socket.assigns.flow, viewport)
    {:noreply, assign(socket, flow: flow)}
  end

  # Handle selection changes
  def handle_event("lf:selection_change", params, socket) do
    flow = LiveFlow.State.update_selection(socket.assigns.flow, params)
    {:noreply, assign(socket, flow: flow)}
  end

  # Handle delete selected
  def handle_event("lf:delete_selected", _params, socket) do
    flow = LiveFlow.State.delete_selected(socket.assigns.flow)
    {:noreply, assign(socket, flow: flow)}
  end
end
```

## Flow Options

The `opts` map supports the following options:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `controls` | boolean | `false` | Show zoom controls (zoom in/out, fit view) |
| `background` | `:dots` \| `:lines` \| `:cross` \| `nil` | `nil` | Background pattern |
| `minimap` | boolean | `false` | Show minimap overlay |
| `snap_to_grid` | boolean | `false` | Snap node positions to grid |
| `grid_size` | integer | `20` | Grid size in pixels |
| `helper_lines` | boolean | `false` | Show alignment guides during drag |
| `cursors` | boolean | `false` | Show remote cursors (for collaboration) |
| `theme` | string | `nil` | Theme name (e.g., `"dark"`, `"ocean"`) |
| `fit_view` | boolean | `false` | Auto-fit all nodes on mount |
| `default_edge_type` | atom | `:bezier` | Default edge path type |

## Custom Node Types

You can define custom node types using function components:

```elixir
defp my_custom_node(assigns) do
  ~H"""
  <div class="bg-white rounded-lg shadow-lg p-4 border-2 border-blue-500">
    <LiveFlow.Components.Handle.handle type={:target} position={:top} />
    <div class="font-bold"><%= @node.data[:label] %></div>
    <div class="text-sm text-gray-500"><%= @node.data[:description] %></div>
    <LiveFlow.Components.Handle.handle type={:source} position={:bottom} />
  </div>
  """
end
```

Pass custom node types to the Flow component:

```elixir
<.live_component
  module={LiveFlow.Components.Flow}
  id="my-flow"
  flow={@flow}
  node_types={%{custom: &my_custom_node/1}}
/>
```

## Collaboration

Enable real-time collaboration with PubSub:

```elixir
def mount(_params, _session, socket) do
  socket =
    socket
    |> assign(flow: initial_flow())
    |> LiveFlow.Collaboration.join("flow:room-1",
      pubsub: MyApp.PubSub,
      presence: MyAppWeb.Presence  # optional
    )

  {:ok, socket}
end

# Add to your LiveView:
def handle_info(msg, socket) do
  LiveFlow.Collaboration.handle_info(msg, socket)
end
```

## Documentation

Full documentation is available at [HexDocs](https://hexdocs.pm/live_flow).

## License

MIT License. See [LICENSE.md](LICENSE.md) for details.
