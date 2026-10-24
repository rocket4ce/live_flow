# Edges

Edges connect a handle on a source node to a handle on a target node. LiveFlow
draws them as SVG paths on the server. While nodes are dragged or resized, the
client redraws them with the same algorithms, so no server round-trip is needed.
This guide covers edge options, path types, handles, markers, labels, custom
edge renderers, reconnecting and styling.

## Creating Edges

`LiveFlow.Edge.new/4` takes an ID, the source node ID, the target node ID and options:

```elixir
alias LiveFlow.{Edge, Handle, Node, State}

Edge.new("e1", "a", "b")

Edge.new("e2", "a", "b",
  type: :smoothstep,
  source_handle: "out",
  target_handle: "in",
  label: "on success",
  animated: true,
  marker_end: %{type: :arrow_closed, color: "#10b981"},
  style: %{stroke: "#10b981"},
  path_options: %{border_radius: 12, offset: 30},
  data: %{weight: 3}
)
```

| Option | Default | Description |
|--------|---------|-------------|
| `:source_handle` / `:target_handle` | `nil` | Handle IDs on the source/target node (see [Handles](#handles)) |
| `:type` | `:bezier` | `:bezier`, `:straight`, `:step`, `:smoothstep` or a custom type |
| `:path_options` | `%{}` | Options for the path algorithm (see [Edge Types](#edge-types-and-path-options)) |
| `:animated` | `false` | Dashed stroke that moves toward the target |
| `:label` | `nil` | Label text shown at the middle of the edge |
| `:label_style` | `%{}` | Inline styles for the built-in label |
| `:marker_start` | `nil` | Marker at the source end |
| `:marker_end` | `%{type: :arrow}` | Marker at the target end (`nil` or `%{type: :none}` removes it) |
| `:style` | `%{}` | Inline styles for the visible path, e.g. `%{stroke: "#ff0072", "stroke-width": 3}` |
| `:class` | `nil` | Extra CSS classes on the edge's `<g class="lf-edge-group">` |
| `:z_index` | `0` | Stacking order among edges |
| `:deletable` | `true` | `false` hides the delete button and makes `LiveFlow.State.delete_selected/1` skip the edge |
| `:reconnectable` | `false` | Adds grab handles at both ends (see [Reconnecting Edges](#reconnecting-edges)) |
| `:source_floating` / `:target_floating` | `false` | Attach that end to the closest point of the node border instead of a handle |
| `:data` | `%{}` | Your own data. LiveFlow also reads `:insertable` and `:label_renderer` from it |
| `:selectable` | `true` | Stored and serialized, but the client does not check it for edges yet. Use the `elements_selectable: false` option to turn off selection for the whole flow |
| `:label_position` | `0.5` | Stored and serialized. The built-in renderer always puts the label at the label point of the path |

`hidden` and `selected` are struct fields without a `new/4` option. Change them,
or any other field, with `LiveFlow.State.update_edge/3`:

```elixir
flow = State.update_edge(flow, "e1", hidden: true, label: "paused")
```

LiveFlow skips edges that are hidden and edges whose source or target node is
missing or hidden. Other helpers: `LiveFlow.State.add_edge/2`, `add_edges/2`,
`get_edge/2`, `remove_edge/2`, `remove_edges/2`, `edges_for_node/2` and
`connected_edges/2`, plus `LiveFlow.Edge.animate/2`, `set_label/2`,
`connects_to?/2` and `connects_same_nodes?/2`.

Edges sit in an SVG layer below the nodes. Edges with a higher `z_index` are drawn
on top of the others. A selected edge is raised above the rest while
`elevate_edges_on_select` is `true` (the default), unless `z_index_mode: :manual`
is set.

## Edge Types and Path Options

| Type | Module | Path options (defaults) |
|------|--------|-------------------------|
| `:bezier` | `LiveFlow.Paths.Bezier` | `curvature` (`0.25`) |
| `:straight` | `LiveFlow.Paths.Straight` | none |
| `:step` | `LiveFlow.Paths.Step` | `offset` (`20`), `step_position` (`0.5`), `center_x` / `center_y` |
| `:smoothstep` | `LiveFlow.Paths.Smoothstep` | `border_radius` (`5`), `offset` (`20`), `step_position` (`0.5`), `center_x` / `center_y` |

- `curvature`: how far the control points sit from the handles, as a fraction of the
  distance between the two endpoints (never less than 50px).
- `offset`: how far the path runs straight out of a handle before it turns.
- `step_position`: where the bend falls, from `0.0` (at the source) to `1.0` (at the target).
- `center_x` / `center_y`: force the bend through this coordinate.
- `border_radius`: corner radius. `:step` is `:smoothstep` with a radius of `0`.

`:step` and `:smoothstep` port xyflow's `getSmoothStepPath`. The Elixir and
JavaScript versions produce the same path. The client gets the options through the
edge's `data-path-options` attribute, so a dragged edge keeps its shape. Any other
`type` is treated as a custom type. Without a renderer for it, the edge is drawn as
a bezier.

```elixir
Edge.new("e3", "a", "b", type: :smoothstep, path_options: %{border_radius: 0, step_position: 0.2})
Edge.new("e4", "a", "b", type: :bezier, path_options: %{curvature: 0.5})
```

To give connections made by dragging a type and other options, pass `:edge_opts`
to `LiveFlow.Validation.Connection.validate_and_create/3` in your `lf:connect_end`
handler:

```elixir
Connection.validate_and_create(flow, params, edge_opts: [type: :smoothstep, reconnectable: true])
```

The preview line drawn while connecting is set separately with the
`connection_line_type` option in `opts`. The `/edges` page of the showcase app lets
you try every type and option.

### Floating Edges

With `source_floating: true` and/or `target_floating: true`, that end ignores its
handle. It attaches to the point of the node border that faces the other node's
center, on whichever side that is. Both ends floating gives React Flow's "floating
edges" (see `/examples/edges/floating-edges`).

### Computing Paths in Elixir

The path modules are public, which is handy in custom edge renderers and for
server-side drawings:

```elixir
alias LiveFlow.Paths.{Bezier, Geometry, Smoothstep, Straight}

Smoothstep.path(0, 0, :right, 200, 100, :left, border_radius: 10)
#=> %{path: "M0 0L 90,0Q 100,0 100,10L 100,90Q 100,100 110,100L200 100",
#     label_x: 100.0, label_y: 50.0}

Bezier.path(0, 0, :right, 200, 100, :left, curvature: 0.5)
Straight.path(0, 0, 200, 100)
```

`LiveFlow.Paths.Geometry` computes a whole edge from its nodes. It finds the
handle points (fixed or floating) and builds the path. Nodes must have absolute
positions:

```elixir
nodes = State.absolute_nodes(flow)
edge = State.get_edge(flow, "e2")

%{path: d, label_x: lx, label_y: ly, source: s, target: t, path_type: type} =
  Geometry.edge_path(edge, nodes[edge.source], nodes[edge.target])
# s and t are %{x: ..., y: ..., position: :right | :left | :top | :bottom}
```

`Geometry.handle_point/5`, `side_point/3` and `floating_point/2` expose the
individual steps. `LiveFlow.Paths.Path.calculate/4` and `module_for_type/1`
dispatch by type. You can implement the `LiveFlow.Paths.Path` behaviour for your
own path module and call it from a custom renderer. `module_for_type/1` only knows
the four built-in types.

## Handles

Handles are the connection points of a node. They are declared on the node with
`LiveFlow.Handle.source/2`, `LiveFlow.Handle.target/2` or `LiveFlow.Handle.new/3`:

```elixir
Node.new("router", %{x: 0, y: 0}, %{label: "Router"},
  handles: [
    Handle.target(:left, id: "in"),
    Handle.source(:right, id: "ok", offset: 0.3),
    Handle.source(:right, id: "error", offset: 0.7),
    Handle.source(:bottom, id: "audit", connectable: false)
  ]
)

Edge.new("e-ok", "router", "billing", source_handle: "ok", target_handle: "in")
Edge.new("e-error", "router", "alerts", source_handle: "error", target_handle: "in")
```

| Option | Default | Description |
|--------|---------|-------------|
| `:id` | `nil` | Handle ID within the node. Without one, the ID is `"source"` or `"target"` |
| `:offset` | `nil` (center) | Position along its side, from `0.0` (top/left) to `1.0` (bottom/right) |
| `:connectable` | `true` | `false`: connections can't start or end on this handle |
| `:connect_type` | `nil` | Type hint: the client refuses to connect handles whose types differ (server side: `LiveFlow.Validation.types_compatible/2`) |
| `:style` / `:class` | `%{}` / `nil` | Inline styles and CSS classes for the handle element |

The position is the side of the node: `:top`, `:right`, `:bottom` or `:left`. Use
`:offset` to put several handles on one side. Edges attach exactly at the offset,
both on the server and while dragging.

An edge finds its handles like this:

- `source_handle` / `target_handle` is compared with `LiveFlow.Handle.effective_id/1`:
  the handle's `id`, or `"source"` / `"target"` when it has none.
- `nil` picks the node's first handle of that type. A node without any handles
  draws a target handle on the left and a source handle on the right. Edges attach
  to the centers of those sides.
- Connections made by dragging always include the handle IDs in `lf:connect_end`,
  so `validate_and_create/3` stores them on the new edge.

Give handles explicit IDs whenever a node has more than one handle of the same
type. Otherwise they all share the ID `"source"` or `"target"`.

## Markers

`marker_start` and `marker_end` take a map:

```elixir
Edge.new("e5", "a", "b",
  marker_start: %{type: :circle_filled},
  marker_end: %{type: :arrow_closed, color: "#ff0072", width: 20, height: 20, stroke_width: 1.5}
)
```

| Key | Default | Description |
|-----|---------|-------------|
| `:type` | `:arrow` | `:arrow`, `:arrow_closed`, `:circle`, `:circle_filled`, `:diamond`, `:diamond_filled` or `:none` |
| `:color` | `currentColor` | Fill/stroke color |
| `:width` / `:height` | `12` | Marker size |
| `:stroke_width` | `1` | Outline width |

Every distinct config becomes one shared SVG `<marker>` definition. Edges with the
same config reuse it. The color is part of the marker's ID, so use hex colors
(`"#ff0072"`).

Without a `:color`, markers follow the theme's edge color (`--lf-edge-stroke`).
They don't pick up the hover, selected or animated colors, or a per-edge `style`
stroke. To color an edge and its arrow, set both:

```elixir
color = "#ff0072"
State.update_edge(flow, "e5", style: %{stroke: color}, marker_end: %{type: :arrow_closed, color: color})
```

## Labels

An edge with a `:label` shows it in a small box at the middle of its path. The box
uses the node colors (`--lf-node-bg`, `--lf-node-border`, `--lf-text-primary`) plus
any `:label_style` you set. Double-click a label to edit it in place. Enter or
clicking away saves the change, Escape cancels it. While you edit, server updates leave
that label alone; the next update after the edit ends brings it up to date. Saving pushes
`lf:edge_label_change` with `%{"id" => id, "label" => text}`. The label is `nil`
when the text is empty:

```elixir
def handle_event("lf:edge_label_change", %{"id" => id, "label" => label}, socket) do
  {:noreply, assign(socket, flow: State.update_edge(socket.assigns.flow, id, label: label))}
end
```

### Rich Labels

Pass `edge_label_renderer` to the Flow component to render labels as HTML. It gets
`@edge`, `@x` and `@y` and is drawn in a 150x40 `foreignObject` centered on the
label point. It applies to every edge that has a label. A single edge can override
it with `data: %{label_renderer: &other/1}`.

```heex
<.live_component
  module={LiveFlow.Components.Flow}
  id="my-flow"
  flow={@flow}
  edge_label_renderer={&rich_label/1}
/>
```

```elixir
defp rich_label(assigns) do
  ~H"""
  <div class="flex h-full items-center justify-center">
    <span id={"label-#{@edge.id}"} class="rounded-full border bg-white px-2 text-xs font-semibold">
      {@edge.label}
    </span>
  </div>
  """
end
```

Rich labels are not editable by double-click. Buttons inside them (`phx-click`)
send their events to the parent LiveView. See `/examples/edges/edge-label-renderer`.

## Delete Button, Toolbar and Insert Button

- **Delete button.** A selected edge with `deletable: true` shows a trash button at
  its label point. Clicking it pushes `lf:edge_change` with
  `%{"changes" => [%{"type" => "remove", "id" => id}]}`, which
  `LiveFlow.Changes.EdgeChange.apply_changes/2` applies. Pressing the delete key
  pushes `lf:delete_selected` instead.
- **Toolbar.** `edge_toolbar={&edge_toolbar/1}` replaces the delete button on the
  selected edge. The function gets `@edge`, `@x` and `@y` and renders in a 120x36
  `foreignObject` at the label point (see `/examples/edges/edge-toolbar`).
- **Insert button.** Edges with `data: %{insertable: true}` show a "+" button at
  their label point on hover, when they are not selected. Clicking it pushes
  `lf:insert_on_edge` with `%{"edge_id" => id}`.

```elixir
defp edge_toolbar(assigns) do
  ~H"""
  <div class="flex h-full items-center justify-center gap-1">
    <button id={"toolbar-#{@edge.id}-animate"} type="button"
            phx-click="toggle_animated" phx-value-id={@edge.id}>Animate</button>
    <button id={"toolbar-#{@edge.id}-delete"} type="button"
            phx-click="delete_edge" phx-value-id={@edge.id}>Delete</button>
  </div>
  """
end

def handle_event("toggle_animated", %{"id" => id}, socket) do
  edge = State.get_edge(socket.assigns.flow, id)
  {:noreply, assign(socket, flow: State.update_edge(socket.assigns.flow, id, animated: !edge.animated))}
end

# Split an edge with a new node (from /examples/layout/dynamic-layouting)
def handle_event("lf:insert_on_edge", %{"edge_id" => edge_id}, socket) do
  flow = socket.assigns.flow
  %Edge{source: source, target: target} = State.get_edge(flow, edge_id)
  id = "step-#{System.unique_integer([:positive])}"
  position = State.get_node(flow, source).position

  flow =
    flow
    |> State.remove_edge(edge_id)
    |> State.add_node(Node.new(id, %{x: position.x, y: position.y + 120}, %{label: "New step"}))
    |> State.add_edge(Edge.new("#{source}->#{id}", source, id, data: %{insertable: true}))
    |> State.add_edge(Edge.new("#{id}->#{target}", id, target, data: %{insertable: true}))

  {:noreply, assign(socket, flow: flow)}
end
```

## Custom Edges

Register edge renderers with the `edge_types` attribute of the Flow component.
Keys are edge types, values are 1-arity function components. LiveComponent modules
are not supported here, unlike `node_types`:

```heex
<.live_component
  module={LiveFlow.Components.Flow}
  id="my-flow"
  flow={@flow}
  edge_types={%{bidirectional: &bidirectional_edge/1}}
/>
```

The renderer gets these assigns and renders the edge's whole SVG `<g>`:

| Assign | Description |
|--------|-------------|
| `@edge` | The `LiveFlow.Edge` struct |
| `@path`, `@label_x`, `@label_y` | Path and label point computed with `@path_type` |
| `@path_type` | `path_options.base_type` if set, otherwise `:bezier` for custom types |
| `@source_pos`, `@target_pos` | Endpoints, `%{x: ..., y: ...}` |
| `@source_position`, `@target_position` | Sides of the endpoints, `:top`, `:right`, `:bottom` or `:left` |
| `@path_options_json` | `path_options` (minus `base_type`) as JSON, or `nil` |
| `@marker_start_id`, `@marker_end_id` | `"url(#...)"` references for `marker-start` / `marker-end`, or `nil` |

A custom renderer replaces the built-in label, toolbar, buttons and reconnect
handles. Render the parts you need yourself. If a custom type only needs a built-in
shape with extra SVG on top, set `path_options: %{base_type: :smoothstep}` and use
`@path`.

### Example: Bidirectional Edges

This example is adapted from `/examples/edges/custom-edges`. Two edges between the
same pair of nodes curve away from each other:

```elixir
def mount(_params, _session, socket) do
  nodes = [
    Node.new("client", %{x: 0, y: 100}, %{label: "Client"},
      handles: [Handle.source(:right, id: "out", offset: 0.3), Handle.target(:right, id: "in", offset: 0.7)]
    ),
    Node.new("api", %{x: 400, y: 100}, %{label: "API"},
      handles: [Handle.target(:left, id: "in", offset: 0.3), Handle.source(:left, id: "out", offset: 0.7)]
    )
  ]

  edges = [
    Edge.new("request", "client", "api",
      type: :bidirectional, source_handle: "out", target_handle: "in", label: "request"),
    Edge.new("response", "api", "client",
      type: :bidirectional, source_handle: "out", target_handle: "in", label: "response",
      path_options: %{bend: 48})
  ]

  {:ok, assign(socket, flow: State.new(nodes: nodes, edges: edges))}
end

defp bidirectional_edge(assigns) do
  bend = Map.get(assigns.edge.path_options, :bend, 32)
  assigns = assign(assigns, :geo, curve(assigns.source_pos, assigns.target_pos, bend))

  ~H"""
  <g
    class="lf-edge-group"
    data-edge-id={@edge.id}
    data-source={@edge.source}
    data-target={@edge.target}
    data-source-handle={@edge.source_handle}
    data-target-handle={@edge.target_handle}
    data-path-type="bidirectional"
    data-path-options={@path_options_json}
  >
    <path class="lf-edge-interaction" d={@geo.d} data-edge-id={@edge.id} />
    <path
      class="lf-edge"
      d={@geo.d}
      data-edge-id={@edge.id}
      data-selected={to_string(@edge.selected)}
      data-animated={to_string(@edge.animated)}
      marker-end={@marker_end_id}
    />
    <foreignObject
      :if={@edge.label}
      data-lf-label-anchor
      x={@geo.x - 40}
      y={@geo.y - 12}
      width="80"
      height="24"
      class="lf-edge-label-custom"
    >
      <div class="text-center text-xs font-semibold">{@edge.label}</div>
    </foreignObject>
  </g>
  """
end

# Quadratic curve bending up when going right, down when going left
defp curve(%{x: sx, y: sy}, %{x: tx, y: ty}, bend) do
  offset = if sx < tx, do: -bend, else: bend
  cx = (sx + tx) / 2
  cy = (sy + ty) / 2

  %{d: "M #{n(sx)},#{n(sy)} Q #{n(cx)},#{n(cy + offset)} #{n(tx)},#{n(ty)}", x: cx, y: cy + offset / 2}
end

defp n(v) when is_float(v), do: :erlang.float_to_binary(v, decimals: 2)
defp n(v), do: to_string(v)
```

### Redrawing Custom Shapes While Dragging

While nodes move, the client recomputes every edge whose root `<g>` has
`data-source` and `data-target`. It looks up the path function by
`data-path-type`. Built-in types work out of the box. Unknown types fall back to
bezier. For your own shape, register the same formula in `app.js` with
`registerEdgePath(type, fn)`. The function gets `source` and `target` as
`{x, y, position}` and the parsed `data-path-options` (snake_case keys). It returns
`{path, labelX, labelY}`:

```javascript
// assets/js/app.js
import { LiveFlowHook, registerEdgePath } from "live_flow"

// Same formula as curve/3 in the LiveView
registerEdgePath("bidirectional", (source, target, options) => {
  const bend = options.bend ?? 32
  const offset = source.x < target.x ? -bend : bend
  const cx = (source.x + target.x) / 2
  const cy = (source.y + target.y) / 2

  return {
    path: `M ${source.x},${source.y} Q ${cx},${cy + offset} ${target.x},${target.y}`,
    labelX: cx,
    labelY: cy + offset / 2,
  }
})
```

What the client expects from a custom edge:

| Markup | Used for |
|--------|----------|
| `class="lf-edge-group"` and `data-edge-id` on the root `<g>` | Hover styles, reconnecting |
| `<path class="lf-edge-interaction">` and `<path class="lf-edge">` with `data-edge-id`, as direct children | Click selection (wide hit area and visible stroke). Both get the new `d` during drags |
| `data-selected` / `data-animated` on `.lf-edge` | Selected and animated styles |
| `data-source`, `data-target`, `data-source-handle`, `data-target-handle` | Redrawing during drags. Without them the edge only updates when the server re-renders |
| `data-path-type`, `data-path-options` | Which path function to use, and its options |
| `data-source-floating="true"` / `data-target-floating="true"` | Floating ends |
| A direct-child `foreignObject` with `data-lf-label-anchor` | Kept centered on the label point during drags (like the built-in label, toolbar and button wrappers) |

To make a custom edge reconnectable, also render the endpoint circles yourself:
`<circle class="lf-edge-reconnect-handle" data-edge-id={@edge.id} data-reconnect-end="source" ... />`
at `@source_pos`, and the same with `"target"` at `@target_pos`.

## Reconnecting Edges

Edges with `reconnectable: true` get a small circle at each end. The circles show
on hover and when the edge is selected, and they can always be grabbed (the
`nodes_connectable` option must be on). Dragging an end moves that end while the
other one stays put:

- Dropped on a valid handle, it pushes `lf:reconnect_edge` with `"edge_id"`,
  `"end"` (`"source"` or `"target"`), `"node_id"` and `"handle_id"`.
- Dropped on the pane or on an incompatible handle, it pushes
  `lf:delete_reconnect_edge` with `"edge_id"`, `"end"` and `"position"` (the drop
  point in flow coordinates).
- Released outside the flow or cancelled with Escape, it pushes nothing.

```elixir
def handle_event("lf:reconnect_edge", params, socket) do
  {:noreply, assign(socket, flow: State.reconnect_edge(socket.assigns.flow, params))}
end

# Delete the edge when it's dropped on empty space (or ignore the event to keep it)
def handle_event("lf:delete_reconnect_edge", %{"edge_id" => id}, socket) do
  {:noreply, assign(socket, flow: State.remove_edge(socket.assigns.flow, id))}
end
```

`LiveFlow.State.reconnect_edge/3` updates the edge's `source`/`source_handle` or
`target`/`target_handle`. If the edge or node doesn't exist, it returns the flow
unchanged. It doesn't run connection validators, so check the params yourself if
needed. Pass `replace_id: true` to give the edge a new ID (handy when IDs encode
their endpoints). `edge_id:` sets the new ID, either as a string or as a function
that receives the updated edge:

```elixir
State.reconnect_edge(flow, params, replace_id: true, edge_id: &"#{&1.source}->#{&1.target}")
```

To allow only one end to move, hide the other circle with a class on the edge,
e.g. `class: "target-only"` and
`.target-only .lf-edge-reconnect-handle[data-reconnect-end="source"] { display: none; }`.
See `/examples/edges/reconnect-edge` and `/examples/edges/delete-edge-on-drop`.

## Animation and Styling

`animated: true` sets `data-animated="true"` on the path. The edge gets a dashed
stroke (`stroke-dasharray: 5`) in `--lf-edge-stroke-animated`, and a keyframe
animation moves the dashes. Toggle it with
`State.update_edge(flow, id, animated: true)` or `LiveFlow.Edge.animate/2`. For
effects like dots traveling along the path (`<animateMotion>`), use a custom edge
(see `/examples/edges/animating-edges`).

Edge colors come from these CSS variables, set on `.lf-container` by the theme:

| Variable | Default | Used for |
|----------|---------|----------|
| `--lf-edge-stroke` | `#b1b1b7` | Edge color, markers without `:color`, connection line |
| `--lf-edge-stroke-width` | `2` | Stroke width (selected edges add 1) |
| `--lf-edge-stroke-selected` | `#3b82f6` | Hovered and selected edges, reconnect handles |
| `--lf-edge-stroke-animated` | `#ff0072` | Animated edges |

LiveFlow's rules live in `@layer components`, so your own CSS overrides them
without `!important`. Use the edge's `:class` (on `.lf-edge-group`) to style
groups of edges:

```css
/* Every edge of one flow */
#my-flow {
  --lf-edge-stroke: #94a3b8;
  --lf-edge-stroke-selected: #6366f1;
}

/* Edges created with class: "critical" */
.critical .lf-edge {
  stroke: #ef4444;
  stroke-dasharray: 6 3;
}
```

An inline `:style` stroke, or a rule like the one above, also overrides the hover,
selected and animated colors. Other classes you can target: `.lf-edge-interaction`
(the 20px wide invisible hit area), `.lf-edge-label`, `.lf-edge-delete-btn`,
`.lf-edge-insert-btn`, `.lf-edge-reconnect-handle` and `.lf-connection-line`. See
[Themes](themes.md) for the full list of variables.

## Edge Events

| Event | Payload | Sent when |
|-------|---------|-----------|
| `lf:connect_end` | `"source"`, `"source_handle"`, `"target"`, `"target_handle"` | A new connection is dropped on a valid handle |
| `lf:edge_change` | `%{"changes" => [%{"type" => "remove", "id" => id}]}` | The delete button is clicked |
| `lf:delete_selected` | `%{}` | The delete key is pressed with a selection |
| `lf:edge_label_change` | `"id"`, `"label"` | A label is edited |
| `lf:insert_on_edge` | `"edge_id"` | The "+" button of an insertable edge is clicked |
| `lf:reconnect_edge` | `"edge_id"`, `"end"`, `"node_id"`, `"handle_id"` | An edge end is dropped on a handle |
| `lf:delete_reconnect_edge` | `"edge_id"`, `"end"`, `"position"` | An edge end is dropped on the pane |
| `lf:edge_context_menu` | `"id"`, `"x"`, `"y"`, `"position"` | An edge is right-clicked (`context_menu: true`) |

See [Events](events.md) for the complete event reference.
