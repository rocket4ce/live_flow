# LiveFlow

Interactive node-based flow diagrams for Phoenix LiveView.

Build visual node editors, workflow builders, and interactive diagrams — similar to [React Flow](https://reactflow.dev), but for Phoenix LiveView.

## Features

- **Pan & Zoom** — Mouse wheel zoom, drag-to-pan, fit-to-view, minimap-style controls
- **Node Drag** — Drag nodes with grid snapping and helper lines (alignment guides)
- **Connections** — Source/target handles with live connection preview and validation
- **Selection** — Click, Shift+click, and selection box (lasso) for multi-select
- **Custom Nodes** — Function components or LiveComponents as custom node types
- **Node Resizing** — Built-in `NodeResizer` component for interactive node resize with handles
- **Edge Types** — Bezier, straight, step, and smoothstep paths with animated edges
- **Edge Labels** — Inline-editable labels on edges (double-click to edit)
- **Undo/Redo** — Snapshot-based history with configurable max entries
- **Copy/Paste** — Clipboard with copy, cut, paste, and duplicate
- **Serialization** — Export/import flow state as JSON
- **Collaboration** — Real-time multi-user editing via PubSub with cursor sharing
- **Validation** — Composable connection validators (no duplicates, no cycles, type compatibility, max connections)
- **Auto Layout** — Tree, force-directed and collision layouts in Elixir, plus optional ELK (`mix live_flow.gen.elk`)
- **Themes** — 36 built-in themes with Tailwind v4 plugin for customization
- **Virtualization** — Server-side viewport culling for 10K+ node flows (pure Elixir)
- **Export** — Client-side SVG/PNG export
- **Touch Support** — Pinch-to-zoom, two-finger pan, long-press selection
- **Keyboard Shortcuts** — Built-in shortcuts panel (`?` key)

## Installation

Add `live_flow` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:live_flow, "~> 0.3.0"}
  ]
end
```

### JavaScript Setup

In your `assets/js/app.js`, import and register the hook:

```javascript
import { LiveFlowHook, FileImportHook, setupDownloadHandler } from "live_flow"

let liveSocket = new LiveSocket("/live", Socket, {
  hooks: {
    LiveFlow: LiveFlowHook,
    FileImport: FileImportHook  // optional
  }
})

// Optional: enable JSON file download
setupDownloadHandler()
```

### Auto Layout with ELK (Optional)

The client-side [ELK](https://eclipse.dev/elk/) layout (`lf:layout_data`, `lf:auto-layout`) is not
bundled by default because elkjs adds about 1.6 MB to `app.js`. Add it with:

```bash
mix live_flow.gen.elk
```

It copies elkjs to `assets/vendor/elk.bundled.cjs` and registers it in `assets/js/app.js`
(`registerElk(ELK)`). The layouts in `LiveFlow.Layout` (`tree/2`, `force/2`,
`resolve_collisions/2`) run on the server and don't need it.

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
    <div class="h-[600px]">
      <.live_component
        module={LiveFlow.Components.Flow}
        id="my-flow"
        flow={@flow}
        opts={%{controls: true, background: :dots, fit_view_on_init: true}}
      />
    </div>
    """
  end

  # Node moves, measured sizes, resizes and removals
  def handle_event("lf:node_change", %{"changes" => changes}, socket) do
    flow = LiveFlow.Changes.NodeChange.apply_changes(socket.assigns.flow, changes)
    {:noreply, assign(socket, flow: flow)}
  end

  # Edges removed with their delete button
  def handle_event("lf:edge_change", %{"changes" => changes}, socket) do
    flow = LiveFlow.Changes.EdgeChange.apply_changes(socket.assigns.flow, changes)
    {:noreply, assign(socket, flow: flow)}
  end

  # New connections: validate, then add the edge
  def handle_event("lf:connect_end", params, socket) do
    case LiveFlow.Validation.Connection.validate_and_create(socket.assigns.flow, params) do
      {:ok, edge} -> {:noreply, assign(socket, flow: State.add_edge(socket.assigns.flow, edge))}
      {:error, _reason} -> {:noreply, socket}
    end
  end

  # Pan and zoom
  def handle_event("lf:viewport_change", params, socket) do
    {:noreply, assign(socket, flow: State.update_viewport(socket.assigns.flow, params))}
  end

  # Selection
  def handle_event("lf:selection_change", %{"nodes" => nodes, "edges" => edges}, socket) do
    flow = socket.assigns.flow |> State.clear_selection() |> State.select_nodes(nodes)
    flow = Enum.reduce(edges, flow, &State.select_edge(&2, &1, multi: true))
    {:noreply, assign(socket, flow: flow)}
  end

  # Backspace/Delete with a selection (deletable: false elements are kept)
  def handle_event("lf:delete_selected", _params, socket) do
    {:noreply, assign(socket, flow: State.delete_selected(socket.assigns.flow))}
  end

  # The other lf: events (see the Events guide)
  def handle_event("lf:" <> _event, _params, socket), do: {:noreply, socket}

  # Node clicks arrive as a message
  def handle_info({:lf_node_click, _node_id}, socket), do: {:noreply, socket}
end
```

## Flow Options

The `opts` map supports the following options (see `LiveFlow.Components.Flow`
for the full reference):

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `controls` | boolean | `false` | Show zoom controls (zoom in/out, fit view) |
| `background` | `:dots` \| `:lines` \| `:cross` \| `nil` | `nil` | Background pattern |
| `background_gap` / `background_size` | number \| `{x, y}` | `20` / `1` | Pattern gap and dot/cross size |
| `minimap` | boolean | `false` | Show minimap overlay |
| `minimap_pannable` / `minimap_zoomable` | boolean | `false` | Drag / scroll the minimap to move the viewport |
| `theme` | string | `nil` | Theme name (e.g., `"dark"`, `"ocean"`) |
| `fit_view_on_init` | boolean | `false` | Fit all nodes on mount |
| `fit_view_options` | map | `%{}` | `padding`, `duration`, `min_zoom`, `max_zoom`, `nodes`, `include_hidden_nodes` |
| `min_zoom` / `max_zoom` | number | `0.1` / `4.0` | Zoom limits |
| `pan_on_drag` | boolean \| `[button]` | `true` | Pan by dragging the pane (`true` = left + middle button) |
| `pan_on_scroll` | boolean | `false` | Scroll pans instead of zooming (`pan_on_scroll_mode`, `pan_on_scroll_speed`) |
| `pan_activation_key` | key | `"Space"` | Hold to pan from anywhere (e.g. `"Control"`) |
| `zoom_on_scroll` / `zoom_on_pinch` / `zoom_on_double_click` | boolean | `true` | Zoom gestures |
| `snap_to_grid` / `snap_grid` | boolean / `{x, y}` | `false` / `{15, 15}` | Snap positions (and resizing) to a grid |
| `node_extent` | `{{x1, y1}, {x2, y2}}` | `nil` | Area nodes can't be dragged or resized out of |
| `node_drag_threshold` | integer | `1` | Pixels before a drag starts |
| `nodes_draggable` / `nodes_connectable` / `elements_selectable` | boolean | `true` | Global interaction switches |
| `selection_on_drag` | boolean | `false` | Dragging the pane draws a selection box |
| `selection_mode` | `:partial` \| `:full` | `:partial` | Select nodes touched by / fully inside the box |
| `selection_key` / `multi_selection_key` | key | `"Shift"` / `["Meta", "Control", "Shift"]` | Box selection / additive selection keys |
| `delete_key_code` | key | `["Backspace", "Delete"]` | Keys deleting the selection (`nil` disables) |
| `disable_keyboard_a11y` | boolean | `false` | Disable moving selected nodes with the arrow keys |
| `auto_pan_on_node_drag` / `auto_pan_on_connect` / `auto_pan_on_selection` | boolean | `true` | Pan when dragging close to the edge |
| `connection_mode` | `:strict` \| `:loose` | `:strict` | `:loose` also connects source to source |
| `connection_line_type` | edge type | `:bezier` | Path of the connection preview |
| `connection_radius` | number | `20` | Snap to the closest handle within this radius |
| `elevate_nodes_on_select` / `elevate_edges_on_select` | boolean | `true` | Render selected elements on top (`z_index_mode: :manual` disables it) |
| `helper_lines` | boolean | `false` | Show alignment guides during drag |
| `cursors` | boolean | `false` | Show remote cursors (for collaboration) |
| `virtualization` | boolean | `false` | Server-side viewport culling for large flows |

Key options accept a single key, a combination of any length (`"Meta+Shift+s"`)
or a list of them.

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

## Node Resizing

Add resize handles to custom nodes with the `NodeResizer` component:

```elixir
defp my_resizable_node(assigns) do
  ~H"""
  <div style="width: 100%; height: 100%; min-height: 80px; padding: 16px;">
    <LiveFlow.Components.NodeResizer.node_resizer node_id={@node.id} min_width={120} min_height={60} />
    <LiveFlow.Components.Handle.handle handle={LiveFlow.Handle.target(:left)} node_id={@node.id} />
    <div>Resize me!</div>
    <LiveFlow.Components.Handle.handle handle={LiveFlow.Handle.source(:right)} node_id={@node.id} />
  </div>
  """
end
```

Create resizable nodes with the `resizable: true` option:

```elixir
Node.new("r1", %{x: 100, y: 100}, %{label: "Resizable"},
  type: :resizable,
  resizable: true,
  handles: [Handle.target(:left), Handle.source(:right)]
)
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

## Virtualization (Large Flows)

For flows with hundreds or thousands of nodes, enable server-side viewport culling:

```elixir
<.live_component
  module={LiveFlow.Components.Flow}
  id="my-flow"
  flow={@flow}
  opts={%{virtualization: true, controls: true}}
/>
```

With virtualization enabled, only nodes visible in the current viewport are rendered to the DOM. This is pure Elixir logic — the server computes which nodes overlap the visible rectangle and filters the render list. Results:

- **500 nodes**: ~108 in DOM (78% reduction)
- **1,000 nodes**: ~108 in DOM (89% reduction)
- **10,000 nodes**: ~180 in DOM (98% reduction, no browser crash)

A `max_visible` cap (default 500) prevents browser freezes when zoomed out to show all nodes at once.

## Showcase App

The `flow_example/` directory contains a Phoenix 1.8 application that
showcases every feature: a playground, the interaction options and all the
[React Flow examples](https://reactflow.dev/examples) — including the Pro
ones — rebuilt with LiveFlow (nodes, edges, interaction, sub-flows &
grouping, layouts, styling, whiteboard tools and exports). It depends on the library through a
path dependency, so library changes are picked up live:

```bash
cd flow_example
mix setup
mix phx.server
```

Then visit [localhost:4000](http://localhost:4000).

## Documentation

Full documentation is available at [HexDocs](https://hexdocs.pm/live_flow). Guides:

- [Getting Started](guides/getting-started.md)
- [Custom Nodes](guides/custom-nodes.md) and [Edges](guides/edges.md)
- [Interaction](guides/interaction.md) and [Events & JavaScript API](guides/events.md)
- [Sub-flows & Grouping](guides/subflows.md) and [Layout](guides/layout.md)
- [Built-in Components](guides/components.md) and [Saving, Import & Export](guides/export.md)
- [Real-Time Collaboration](guides/collaboration.md) and [Themes](guides/themes.md)

## License

MIT License. See [LICENSE.md](LICENSE.md) for details.
