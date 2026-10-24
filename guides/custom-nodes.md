# Custom Node Types

LiveFlow renders nodes using a default style out of the box, but you can fully
customize how each node type looks using function components or LiveComponent modules.

## Default Node Behavior

Without any customization, LiveFlow renders every node with its built-in default
style: a rounded card showing the node's `data.label` text, with handles positioned
according to the node's `handles` list.

```elixir
# This node uses the default renderer
Node.new("node-1", %{x: 100, y: 100}, %{label: "Default Node"},
  handles: [Handle.target(:left), Handle.source(:right)]
)
```

## Assigning a Node Type

Set the `:type` option when creating a node. This atom is used to look up the
renderer in the `node_types` map:

```elixir
Node.new("node-2", %{x: 300, y: 100}, %{label: "Card", description: "A custom card"},
  type: :card,
  handles: [Handle.target(:left), Handle.source(:right)]
)
```

## Providing Custom Renderers

Pass a `node_types` map to the Flow component. Keys are type atoms, values are
either function component captures or LiveComponent module names:

```elixir
<.live_component
  module={LiveFlow.Components.Flow}
  id="my-flow"
  flow={@flow}
  node_types={%{
    card: &card_node/1,
    metric: &metric_node/1,
    dashboard: MyAppWeb.DashboardNodeLive
  }}
/>
```

### Resolution Order

When rendering a node, LiveFlow resolves the renderer in this order:

1. `node_types[node.type]` -- exact match (function or LiveComponent module)
2. `node_renderer` -- global fallback function (if assigned)
3. Built-in default node renderer

## Function Components

The simplest way to create custom nodes. Define a function that accepts assigns
with a `node` key:

```elixir
defmodule MyAppWeb.FlowLive do
  use MyAppWeb, :live_view

  # ...mount, render, event handlers...

  defp card_node(assigns) do
    label = Map.get(assigns.node.data, :label, "Card")
    description = Map.get(assigns.node.data, :description, "")
    color = Map.get(assigns.node.data, :color, "#3b82f6")

    assigns =
      assigns
      |> assign(:label, label)
      |> assign(:description, description)
      |> assign(:color, color)

    ~H"""
    <div style={"min-width: 200px; border-top: 3px solid #{@color}"}>
      <div style="padding: 2px 0 4px">
        <div style={"font-weight: 700; font-size: 14px; color: #{@color}"}>
          {@label}
        </div>
        <div
          :if={@description != ""}
          style="font-size: 12px; color: var(--lf-text-muted); margin-top: 4px"
        >
          {@description}
        </div>
      </div>
    </div>
    """
  end

  defp metric_node(assigns) do
    label = Map.get(assigns.node.data, :label, "Metric")
    value = Map.get(assigns.node.data, :value, "0")
    unit = Map.get(assigns.node.data, :unit, "")

    assigns =
      assigns
      |> assign(:label, label)
      |> assign(:value, value)
      |> assign(:unit, unit)

    ~H"""
    <div style="min-width: 160px; text-align: center; padding: 4px 0">
      <div style="font-size: 11px; text-transform: uppercase; color: var(--lf-text-muted); font-weight: 600">
        {@label}
      </div>
      <div style="font-size: 28px; font-weight: 800; color: var(--lf-text-primary); margin: 4px 0">
        {@value}
        <span :if={@unit != ""} style="font-size: 14px; font-weight: 400; color: var(--lf-text-muted)">
          {@unit}
        </span>
      </div>
    </div>
    """
  end
end
```

### What the Function Receives

The function component receives a single assign, `node`: the full `LiveFlow.Node`
struct, including:

- `node.id` -- the node ID
- `node.data` -- your custom data map
- `node.type` -- the type atom
- `node.position` -- `%{x, y}` (relative to the parent for child nodes)
- `node.selected`, `node.dragging`, `node.resizing` -- booleans
- `node.width` / `node.height` -- measured (or explicit) size, `nil` before the first measure
- `node.parent_id`, `node.hidden`, `node.handles`, ...

The function is called again whenever the node changes (data, selection, position),
so the content always reflects the current state.

### Important Notes for Function Components

- Access optional data with `Map.get/3`. If you load flows from JSON, atom values
  in `data` come back as strings (`:violet` becomes `"violet"`), see
  [Export](export.md#types-after-a-round-trip).
- Use `var(--lf-text-primary)`, `var(--lf-text-muted)`, etc. in inline styles
  for theme compatibility.
- LiveFlow wraps your component in a `NodeWrapper` that provides the outer card
  styling, handles, selection outline, and drag behavior. Your component renders
  the inner content only.

## LiveComponent Modules

For nodes that need their own state or lifecycle callbacks, use a LiveComponent:

```elixir
defmodule MyAppWeb.DashboardNodeLive do
  use Phoenix.LiveComponent

  @impl true
  def mount(socket) do
    {:ok, assign(socket, expanded: false)}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, node: assigns.node)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="min-width: 220px">
      <div style="font-weight: 700; font-size: 14px; color: var(--lf-text-primary)">
        {Map.get(@node.data, :label, "Dashboard")}
      </div>
      <button
        phx-click="toggle"
        phx-target={@myself}
        class="nodrag"
        style="font-size: 12px; margin-top: 6px; cursor: pointer"
      >
        {if @expanded, do: "Collapse", else: "Expand"}
      </button>
      <div :if={@expanded} style="margin-top: 8px; font-size: 12px; color: var(--lf-text-muted)">
        Detailed dashboard content here...
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("toggle", _params, socket) do
    {:noreply, assign(socket, expanded: !socket.assigns.expanded)}
  end
end
```

Register it in your `node_types`:

```elixir
node_types: %{
  dashboard: MyAppWeb.DashboardNodeLive
}
```

### Key Differences from Function Components

| | Function Component | LiveComponent |
|---|---|---|
| State | Stateless | Has its own state |
| Events | Must go to parent LiveView | Can handle with `phx-target={@myself}` |
| Lifecycle | Re-invoked on every render | Has `mount`, `update`, `render` |
| Registration | `&function/1` | `ModuleName` |

## Using Handles in Custom Nodes

Handles (connection points) are defined on the `Node` struct, not in the custom
renderer. LiveFlow's `NodeWrapper` renders handles automatically based on the
node's `handles` list (a connectable node without handles gets a target on the left
and a source on the right):

```elixir
Node.new("my-node", %{x: 0, y: 0}, %{label: "Multi-handle"},
  type: :card,
  handles: [
    Handle.new(:target, :top, id: "input-data"),
    Handle.new(:target, :left, id: "input-config"),
    Handle.new(:source, :bottom, id: "output-result"),
    Handle.new(:source, :right, id: "output-error")
  ]
)
```

### Handle Options

```elixir
Handle.new(:source, :right,
  id: "output-1",             # Unique ID within the node
  connectable: true,          # Whether connections can be made
  connect_type: :data,        # Type constraint for validation
  offset: 0.25,               # Position along the side, 0.0..1.0 (default 0.5)
  class: "my-custom-class",   # Additional CSS class
  style: %{}                  # Inline styles
)
```

### Handle Positions

Handles can be placed on the four sides of the node: `:top`, `:bottom`, `:left`
and `:right`. They are centered on their side unless `offset:` says otherwise, so
several handles can share a side:

```elixir
handles: [
  Handle.target(:left),
  Handle.source(:right, id: "yes", offset: 0.3),
  Handle.source(:right, id: "no", offset: 0.7)
]
```

Edges attach exactly at the handle, on the server, in the browser and in exports.
More in [Edges](edges.md#handles).

### Handle Shorthands

```elixir
Handle.source(:right)          # Source handle on the right
Handle.target(:left)           # Target handle on the left
Handle.new(:source, :bottom)   # Equivalent to Handle.source(:bottom)
```

## The `node_renderer` Fallback

If you want a single custom renderer for all node types that do not have an
entry in `node_types`, use `node_renderer`:

```elixir
<.live_component
  module={LiveFlow.Components.Flow}
  id="my-flow"
  flow={@flow}
  node_types={%{card: &card_node/1}}
  node_renderer={&generic_node/1}
/>
```

With this setup:
- Nodes with `type: :card` use `card_node/1`
- All other node types use `generic_node/1`
- If `node_renderer` is not set, unmatched types use the built-in default

## Interactive Elements Inside Nodes

Pressing on a node starts a drag. Buttons, links, inputs, selects, textareas and
`contenteditable` elements are excluded automatically, and keyboard shortcuts
(Backspace, Ctrl/Cmd+Z, ...) are ignored while typing in them. For other elements,
use these classes:

| Class | Effect |
|-------|--------|
| `nodrag` | Pressing the element doesn't drag the node |
| `nopan` | Dragging on the element doesn't pan the viewport |
| `nowheel` | The wheel scrolls the element instead of zooming the flow |

```heex
<div class="nodrag nowheel max-h-40 overflow-y-auto">
  <p :for={line <- @node.data.lines}>{line}</p>
</div>
```

### Drag Handles

To drag a node only from part of it (a title bar, a grip icon), set `drag_handle` to a
CSS selector:

```elixir
Node.new("panel", %{x: 0, y: 0}, %{title: "Settings"}, type: :panel, drag_handle: ".drag-grip")
```

```heex
<div class="drag-grip cursor-grab">{@node.data.title}</div>
<div class="p-3">... the rest doesn't start a drag ...</div>
```

## Toolbars, Resizing and Size

- `LiveFlow.Components.NodeToolbar` shows actions next to the selected node and
  `LiveFlow.Components.NodeResizer` adds resize handles; see
  [Components](components.md).
- Nodes are measured in the browser. To give a node a fixed size, pass `width:` and
  `height:` to `LiveFlow.Node.new/4` and render content that fills it (`h-full w-full`).
- The wrapper gets the `lf-node-selected` class and `data-selected="true"` while
  selected, and `data-node-type` with the node type, handy for CSS.

## Styling with Theme Variables

Use LiveFlow CSS custom properties in your custom nodes for automatic theme support:

| Variable | Description |
|----------|-------------|
| `--lf-text-primary` | Primary text color |
| `--lf-text-secondary` | Secondary text color |
| `--lf-text-muted` | Muted text color |
| `--lf-node-bg` | Node background color |
| `--lf-node-border` | Node border color |
| `--lf-node-border-radius` | Node border radius |
| `--lf-node-selected-border` | Border color of selected nodes (a good accent color) |
| `--lf-surface-secondary` | Secondary surface (e.g. a node header) |
| `--lf-border-secondary` | Secondary border color |

Example:

```heex
<div style="color: var(--lf-text-primary); border-bottom: 1px solid var(--lf-border-secondary)">
  Content
</div>
```

## Complete Example

Putting it all together:

```elixir
defmodule MyAppWeb.FlowLive do
  use MyAppWeb, :live_view

  alias LiveFlow.{State, Node, Edge, Handle}

  @impl true
  def mount(_params, _session, socket) do
    flow = State.new(
      nodes: [
        Node.new("1", %{x: 50, y: 100}, %{label: "Input", description: "Data source"},
          type: :card, handles: [Handle.source(:right)]),
        Node.new("2", %{x: 350, y: 100}, %{label: "Requests", value: "1,247", unit: "/s"},
          type: :metric, handles: [Handle.target(:left), Handle.source(:right)]),
        Node.new("3", %{x: 650, y: 100}, %{label: "Output"},
          handles: [Handle.target(:left)])
      ],
      edges: [
        Edge.new("e1", "1", "2"),
        Edge.new("e2", "2", "3")
      ]
    )

    {:ok, assign(socket,
      flow: flow,
      node_types: %{card: &card_node/1, metric: &metric_node/1}
    )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-screen">
      <.live_component
        module={LiveFlow.Components.Flow}
        id="my-flow"
        flow={@flow}
        node_types={@node_types}
        opts={%{controls: true, background: :dots, fit_view_on_init: true}}
      />
    </div>
    """
  end

  # ... event handlers (see Getting Started guide) ...
  # ... card_node/1 and metric_node/1 as shown above ...
end
```
