# Built-in Components

This guide covers the Flow component and the pieces that come with it: background,
controls, minimap, panels, and the components you use inside custom nodes
(`LiveFlow.Components.Handle`, `LiveFlow.Components.NodeToolbar` and
`LiveFlow.Components.NodeResizer`).

## The Flow Component

`LiveFlow.Components.Flow` is a LiveComponent. Give it a fixed-height container:

```heex
<div class="h-[600px]">
  <.live_component
    module={LiveFlow.Components.Flow}
    id="my-flow"
    flow={@flow}
    opts={%{background: :dots, controls: true, minimap: true, fit_view_on_init: true}}
    node_types={%{card: &card_node/1}}
  />
</div>
```

| Attribute | Description |
|-----------|-------------|
| `id` | DOM id of the flow container (required). Also the `flow_id` used by events and `LiveFlow.animate_positions/5` |
| `flow` | The `LiveFlow.State` (required) |
| `opts` | Options map, merged over the defaults (see below) |
| `node_types` | `%{type => renderer}`: function components or LiveComponent modules ([Custom Nodes](custom-nodes.md)) |
| `node_renderer` | Fallback renderer for node types missing from `node_types` |
| `edge_types` | `%{type => renderer}` for custom edges ([Edges](edges.md)) |
| `edge_label_renderer` | Function component rendering edge labels as HTML ([Edges](edges.md)) |
| `edge_toolbar` | Function component rendered as the toolbar of selected edges ([Edges](edges.md)) |
| `class` | Extra classes for the `.lf-container` element |
| `:panel` slot | Your own UI inside the flow (see [Panels](#panels)) |

The parent LiveView owns the state: the hook sends `lf:*` events to it and it passes
the updated `@flow` back (see [Events](events.md)).

### Options

Defaults in parentheses. Behavior options are explained in
[Interaction](interaction.md).

| Group | Options |
|-------|---------|
| Viewport | `min_zoom` (`0.1`), `max_zoom` (`4.0`), `fit_view_on_init` (`false`), `fit_view_options` (`%{}`) |
| Pan & zoom | `pan_on_drag` (`true`), `pan_on_scroll` (`false`), `pan_on_scroll_speed` (`0.5`), `pan_on_scroll_mode` (`:free`), `zoom_on_scroll` (`true`), `zoom_on_pinch` (`true`), `zoom_on_double_click` (`true`), `prevent_scrolling` (`true`), `pan_activation_key` (`"Space"`) |
| Nodes & edges | `nodes_draggable` (`true`), `nodes_connectable` (`true`), `elements_selectable` (`true`), `node_drag_threshold` (`1`), `node_extent` (`nil`), `snap_to_grid` (`false`), `snap_grid` (`{15, 15}`), `elevate_nodes_on_select` (`true`), `elevate_edges_on_select` (`true`), `z_index_mode` (`:basic`) |
| Connections | `connection_mode` (`:strict`), `connection_line_type` (`:bezier`), `connection_radius` (`20`), `connect_on_click` (`true`), `multi_connection` (`false`), `connection_line_style` (`nil`), `connection_line_class` (`nil`) |
| Selection & keys | `selection_on_drag` (`false`), `selection_mode` (`:partial`), `selection_key` (`"Shift"`), `multi_selection_key` (`["Meta", "Control", "Shift"]`), `delete_key_code` (`["Backspace", "Delete"]`), `disable_keyboard_a11y` (`false`) |
| Opt-in events | `context_menu` (`false`), `pane_click_events` (`false`), `connection_events` (`false`) |
| Auto-pan | `auto_pan_on_node_drag` (`true`), `auto_pan_on_connect` (`true`), `auto_pan_on_selection` (`true`), `auto_pan_speed` (`15`) |
| Overlays | `background` (`nil`) and `background_*`, `controls` (`false`), `minimap` (`false`) and `minimap_*`, `helper_lines` (`false`), `cursors` (`false`), `theme` (`nil`) |
| Performance | `virtualization` (`false`) |

Options can change at any time: re-render with a new `opts` map and the client picks
them up (including `helper_lines` and `cursors`).

### Fitting the View

`fit_view_on_init: true` fits the content once mounted. Later, ask the component to fit
the view from the parent LiveView; the bounds are computed on the server, so it works
with virtualization:

```elixir
send_update(LiveFlow.Components.Flow, id: "my-flow", fit_view: true)
send_update(LiveFlow.Components.Flow, id: "my-flow", fit_view: %{nodes: ["a", "b"], padding: 0.2})
```

## Background

```elixir
opts = %{
  background: :dots,          # :dots, :lines, :cross or nil
  background_gap: 24,         # number or {x, y}
  background_size: 1.5,       # dot radius / cross size (default 1, cross 6)
  background_offset: 0,       # number or {x, y}
  background_line_width: 1    # :lines and :cross
}
```

The pattern is an SVG that follows the viewport and is included in exports. Its colors
come from the theme variables `--lf-background`, `--lf-background-dots-color`,
`--lf-background-lines-color` and `--lf-background-cross-color`.

## Controls

`controls: true` adds zoom in, zoom out and fit view buttons in the bottom-left corner.
They run in the browser (`JS.dispatch`), so you can build your own buttons the same way:

```heex
<button phx-click={JS.dispatch("lf:zoom-in", to: "#my-flow")}>+</button>
<button phx-click={JS.dispatch("lf:fit-view", to: "#my-flow", detail: %{padding: 0.2})}>Fit</button>
```

Style them with `--lf-controls-bg`, `--lf-controls-border`, `--lf-controls-color` and
`--lf-controls-button-hover`.

## MiniMap

```elixir
opts = %{
  minimap: true,
  minimap_pannable: true,   # click/drag the minimap to move the viewport
  minimap_zoomable: true,   # scroll over the minimap to zoom
  minimap_node_color: fn node -> if node.type == :group, do: "#f1f5f9", else: "#6366f1" end
}
```

`minimap_node_color` is a CSS color or a function receiving the `LiveFlow.Node`
(React Flow's `nodeColor`). Minimap nodes also carry `data-node-id` and
`data-node-type` for CSS. The minimap always shows every node, even with
virtualization. Theme variables: `--lf-minimap-bg`, `--lf-minimap-border`,
`--lf-minimap-node-bg`, `--lf-minimap-viewport-border`.

## Panels

The `:panel` slot renders your own UI on top of the flow (React Flow's `<Panel />`).
Panels don't move with the viewport, don't start pans, drags or zooms, and are left out
of exports. Events inside them go to the parent LiveView.

```heex
<.live_component module={LiveFlow.Components.Flow} id="my-flow" flow={@flow}>
  <:panel position={:top_right} class="flex gap-2">
    <button phx-click="add_node">Add node</button>
    <button phx-click={JS.dispatch("lf:export-png", to: "#my-flow")}>PNG</button>
  </:panel>
  <:panel position={:bottom_center}>
    {map_size(@flow.nodes)} nodes
  </:panel>
</.live_component>
```

Positions: `:top_left` (default), `:top_center`, `:top_right`, `:center_left`,
`:center_right`, `:bottom_left`, `:bottom_center`, `:bottom_right`.

## Handles

Handles are declared on the node, not in its template: the node wrapper renders the
node's `handles` list (with `LiveFlow.Components.Handle`) for every node type,
built-in or custom. A connectable node without handles gets a target on the left and
a source on the right.

```elixir
Node.new("filter", %{x: 0, y: 0}, %{label: "Filter"},
  type: :card,
  handles: [
    Handle.target(:left),
    Handle.source(:right, id: "pass", offset: 0.3),
    Handle.source(:right, id: "reject", offset: 0.7)
  ]
)
```

Declaring them on the node lets the server use them too (validation, edge geometry,
export). See [Edges](edges.md#handles) for the handle options. Use
`connectable: false` on the node for a node without handles.

## NodeToolbar

`LiveFlow.Components.NodeToolbar.node_toolbar/1` renders a toolbar outside the node box,
shown while the node is selected:

```elixir
defp card_node(assigns) do
  ~H"""
  <LiveFlow.Components.NodeToolbar.node_toolbar node={@node} position={:top} align={:end}>
    <button phx-click="duplicate" phx-value-id={@node.id}>Duplicate</button>
    <button phx-click="delete" phx-value-id={@node.id}>Delete</button>
  </LiveFlow.Components.NodeToolbar.node_toolbar>
  <div class="px-4 py-2">{@node.data.label}</div>
  """
end
```

| Attribute | Default | Description |
|-----------|---------|-------------|
| `node` | required | The node |
| `position` | `:top` | `:top`, `:bottom`, `:left` or `:right` |
| `align` | `:center` | `:start`, `:center` or `:end` |
| `offset` | `10` | Gap in pixels |
| `is_visible` | `node.selected` | Force the toolbar open or closed |
| `class` | `nil` | Extra classes |

Clicks inside the toolbar don't start drags or pans, and the toolbar is left out of
exports.

## NodeResizer

`LiveFlow.Components.NodeResizer.node_resizer/1` adds resize handles to a custom node.
Mark the node `resizable: true` so its size survives re-measuring:

```elixir
Node.new("note", %{x: 0, y: 0}, %{text: "Resize me"}, type: :note, resizable: true, width: 200, height: 120)
```

```elixir
defp note_node(assigns) do
  ~H"""
  <div class="h-full w-full p-3">
    <LiveFlow.Components.NodeResizer.node_resizer
      node_id={@node.id}
      min_width={120}
      min_height={60}
      max_width={480}
      is_visible={@node.selected}
    />
    {@node.data.text}
  </div>
  """
end
```

| Attribute | Default | Description |
|-----------|---------|-------------|
| `node_id` | required | The node ID |
| `min_width` / `min_height` | `50` / `30` | Minimum size |
| `max_width` / `max_height` | `nil` | Maximum size |
| `keep_aspect_ratio` | `false` | Keep the width/height ratio |
| `handles` | all 8 | Any of `:n`, `:s`, `:e`, `:w`, `:ne`, `:nw`, `:se`, `:sw` |
| `color` | theme | Color of the handles |
| `is_visible` | `true` | Render the handles |

Edges follow the node while it is resized. The server receives `resize` changes in
`lf:node_change` (`"resizing" => true` at the start, `false` at the end, also when
aborted with Escape); `LiveFlow.Changes.NodeChange.apply_changes/2` applies them.
Resizing respects the flow's `node_extent` (not a child's `extent: :parent`).

## Large Flows: Virtualization

With `virtualization: true`, flows with 200 nodes or more only render the nodes and
edges in (or near) the viewport. Culling runs on the server
(`LiveFlow.Viewport.Culling`) as the viewport changes:

- a 200 px margin around the viewport is pre-rendered so panning stays smooth;
- edges are kept when at least one end is visible;
- at most 500 nodes are rendered, the ones closest to the center first (for extreme
  zoom-outs);
- the minimap still shows every node.

Your LiveView must handle `lf:viewport_change` and store the viewport in the state
(`LiveFlow.State.update_viewport/2`), since culling uses it. The JS API and client-side
features that read the DOM (`getNodes()`, exports, helper lines) only see rendered
nodes.
