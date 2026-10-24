# Sub-flows & Grouping

A node can live inside another node. Child nodes set `parent_id`, store their
position relative to the parent, move with it when it is dragged and can be kept
inside of it. This is how you build group nodes, nested graphs, swimlanes or
containers that nodes are dragged into and out of. This guide covers the
parent/child model, group nodes and the `LiveFlow.State` helpers used to work
with the hierarchy and the graph.

## Parent and Child Nodes

Pass `:parent_id` when creating a node. Its `position` is then relative to the
top-left corner of the parent:

```elixir
alias LiveFlow.{Edge, Node, State}

nodes = [
  Node.new("1", %{x: 0, y: 160}, %{label: "Node 1"}),

  # A group at (220, 40) in flow coordinates
  Node.new("A", %{x: 220, y: 40}, %{label: "Group A"},
    type: :group,
    resizable: true,
    connectable: false,
    width: 420,
    height: 320
  ),

  # Drawn at (240, 90): 20/50 from the group's corner
  Node.new("A-1", %{x: 20, y: 50}, %{label: "A-1"}, parent_id: "A", extent: :parent),
  Node.new("A-2", %{x: 20, y: 240}, %{label: "A-2"}, parent_id: "A"),

  # Groups nest: B lives inside A, B-1 inside B
  Node.new("B", %{x: 200, y: 30}, %{label: "Group B"},
    type: :group,
    resizable: true,
    connectable: false,
    width: 190,
    height: 180,
    parent_id: "A",
    extent: :parent
  ),
  Node.new("B-1", %{x: 25, y: 60}, %{label: "B-1"}, parent_id: "B", extent: :parent)
]

edges = [
  Edge.new("e1", "1", "A-1"),
  Edge.new("e2", "A-1", "B-1", animated: true)
]

flow = State.new(nodes: nodes, edges: edges)
```

What the hierarchy gives you:

- **Relative positions.** The Flow component draws every node at its absolute
  position (the sum of its own and its ancestors' positions), so moving a parent
  moves the whole subtree without touching the children.
- **Children move with their parent.** Dragging a parent (with the mouse or the
  arrow keys) moves all of its descendants on the client. Only the parent's new
  position is pushed: the children's relative positions stay the same. If a
  parent and one of its children are selected together, only the parent is
  dragged.
- **Edges work across levels.** Edges can connect any two nodes, whatever their
  parents are.
- **The order of the node list doesn't matter.** Parents always render before
  their children (see [Render Order](#render-order-and-stacking)).

The showcase app demonstrates this at `/examples/grouping/sub-flows`.

## Group Nodes

`type: :group` is a regular node type with a default see-through style, so edges
between child nodes stay visible:

```css
.lf-node[data-node-type="group"] {
  background: color-mix(in oklab, var(--lf-node-bg) 40%, transparent);
  border-style: dashed;
  box-shadow: none;
}

.lf-node[data-node-type="group"] > .lf-node-content {
  height: 100%;
  padding: 0;
}
```

A few things to keep in mind:

- **Give the group a size.** Explicit `width`/`height` are only written to the
  node's style for `resizable: true` nodes; other nodes are sized by their
  content. Use `resizable: true` with `width`/`height` (as above), or a `style`
  map such as `style: %{"width" => "420px", "height" => "320px"}`.
- **Hide the default handles.** A node without `handles` gets a default target
  and source handle. Pass `connectable: false` if the group itself shouldn't be
  connected.
- **Render it yourself if you want.** Without a `:group` entry in `node_types`
  the default renderer shows `data.label` at the top of the group. A custom
  renderer can place a title in a corner and add a
  `LiveFlow.Components.NodeResizer`:

```heex
<.live_component
  module={LiveFlow.Components.Flow}
  id="sub-flows"
  flow={@flow}
  node_types={%{group: &group_node/1}}
  opts={%{background: :dots, controls: true, fit_view_on_init: true}}
/>
```

```elixir
attr :node, :map, required: true

defp group_node(assigns) do
  ~H"""
  <LiveFlow.Components.NodeResizer.node_resizer
    node_id={@node.id}
    min_width={160}
    min_height={120}
    is_visible={@node.selected}
  />
  <span class="pointer-events-none absolute top-2 left-3 text-xs font-semibold uppercase">
    {@node.data.label}
  </span>
  """
end
```

Style groups with the `data-node-type` attribute, e.g.
`#sub-flows .lf-node[data-node-type="group"][data-selected="true"] { ... }`.
See [Custom Nodes](custom-nodes.md) for renderers and [Themes](themes.md) for the
CSS variables.

## Keeping Children Inside: `extent`

The `:extent` of a child node limits where it can be dragged:

| Value | Effect |
|-------|--------|
| `nil` (default) | The child can be dragged anywhere, also outside of its parent (it stays a child) |
| `:parent` | The child's box stays inside its parent's box |
| `{{x1, y1}, {x2, y2}}` | The child's box stays inside this rectangle, relative to the parent's top-left corner |

```elixir
# Keep the node inside a band of the group, below a 30px title
Node.new("A-3", %{x: 20, y: 40}, %{label: "A-3"},
  parent_id: "A",
  extent: {{0, 30}, {420, 320}}
)
```

The extent is enforced by the client while dragging and when moving nodes with
the arrow keys. It only applies to nodes with a `parent_id`; to constrain
top-level nodes use the `:node_extent` option of the Flow component. Positions
you set on the server (`LiveFlow.State.update_node/3`, layouts,
`LiveFlow.State.set_parent/4`) are not clamped.

There is no automatic "expand parent" behavior: a group doesn't grow when a child
reaches its border. If you need it, resize the group from your
`lf:node_change` handler when a drag ends, like `fit_group/2` in the showcase's
`/examples/grouping/selection-grouping` page.

## Relative vs Absolute Positions

Most APIs use the stored (relative) position; the geometry helpers use absolute
flow coordinates:

| Where | Coordinates |
|-------|-------------|
| `node.position`, `LiveFlow.Node.new/4` | Relative to the parent (absolute for top-level nodes) |
| `position` changes in `lf:node_change` (drag end, arrow keys) | Relative to the parent |
| `lf:drag_move` (pushed every 50 ms while dragging) | Absolute, for every moving node including descendants |
| `LiveFlow.State.absolute_position/2`, `absolute_nodes/1` | Absolute |
| `LiveFlow.State.node_rect/2`, `intersecting_nodes/3`, `bounds/2` | Absolute |
| `LiveFlow.animate_positions/5`, `LiveFlow.Layout.apply_positions/2` | Relative to the parent |

```elixir
State.absolute_position(flow, "B-1")
#=> %{x: 445.0, y: 130.0}

# Every node with its absolute position (and inherited `hidden`), e.g. for
# geometry computations
abs_nodes = State.absolute_nodes(flow)
```

## Render Order and Stacking

Nodes are sorted by the chain of z-indexes from their root ancestor down to
themselves, and the CSS `z-index` follows that order:

- A child always renders above its parent.
- `z_index` orders siblings. A top-level node and a group are compared by their
  own `z_index`; with equal values the node may end up below the group's
  children.
- Selecting a node (with `elevate_nodes_on_select`, the default, unless
  `z_index_mode: :manual`) or dragging it elevates its whole subtree.

Two practical tips taken from the showcase pages:

- Give regular nodes a higher `z_index` than groups (e.g. `z_index: 1`), so a
  top-level node dropped over a group stays on top of it.
- Set `elevate_nodes_on_select: false` if a selected group shouldn't cover the
  nodes around it.

## Hiding and Deleting

- **Hiding a parent hides its subtree.** Set `hidden: true` on a group and its
  descendants are not rendered either, together with every edge connected to
  them.

  ```elixir
  flow = State.update_node(flow, "A", hidden: true)
  ```

- **Deleting a parent deletes its descendants.** `LiveFlow.State.remove_node/2`
  (also used by `remove_nodes/2`, `delete_selected/1` and `remove` node changes)
  removes the node, every descendant and every edge connected to any of them.
  Descendants are removed even when they are `deletable: false`. To remove a
  group but keep its children, detach them first (see
  [Ungrouping](#example-group-and-ungroup-the-selection)).

## Hierarchy Helpers

| Function | Returns |
|----------|---------|
| `LiveFlow.State.children/2` | Direct children of a node (nodes whose `parent_id` is the ID) |
| `LiveFlow.State.descendant_ids/2` | IDs of all descendants (children, grandchildren, ...) |
| `LiveFlow.State.depth/2` | Number of ancestors of a node struct (`0` for top-level nodes) |
| `LiveFlow.State.absolute_position/2` | Absolute position of a node (struct or ID), `nil` for unknown IDs |
| `LiveFlow.State.absolute_nodes/1` | Map of all nodes with absolute positions and inherited `hidden` |
| `LiveFlow.State.set_parent/4` | Moves a node into a parent, or out with `nil`, keeping its place on screen |
| `LiveFlow.State.node_rect/2` | Absolute `%{x, y, width, height}` of a node (unmeasured nodes count as `100 x 40`) |
| `LiveFlow.State.intersecting_nodes/3` | Nodes overlapping a node (by ID) or a rect `%{x, y, width, height}` |

```elixir
State.children(flow, "A") |> Enum.map(& &1.id)
#=> ["A-1", "A-2", "B"]  (in no particular order)

State.descendant_ids(flow, "A")
#=> ["A-1", "A-2", "B", "B-1"]  (breadth first)

State.depth(flow, State.get_node(flow, "B-1"))
#=> 2
```

`LiveFlow.State.intersecting_nodes/3` takes a `:partial` option (default
`true`); with `partial: false` only nodes fully inside the rect are returned.
When you pass a node ID, the node and its descendants are excluded from the
result, but its ancestors are not (a child always overlaps its parent). Nodes
with `hidden: true` are skipped.

## Re-parenting with `set_parent/4`

`LiveFlow.State.set_parent/4` attaches a node to a new parent, or detaches it
with `nil`, and converts its position so it stays at the same place on screen:

```elixir
# Attach: the position becomes relative to "A"
flow = State.set_parent(flow, "2", "A")

# Attach and keep it inside the group from now on
flow = State.set_parent(flow, "2", "A", extent: :parent)

# Detach: the position becomes absolute again
flow = State.set_parent(flow, "2", nil)
```

The only option is `:extent`. When it is not given, the node keeps its current
extent while attached and loses it when detached. The call is a no-op for
unknown nodes and for moves that would create a cycle (a node into itself or
into one of its descendants). The parent must already be in the flow, so add a
new group before re-parenting nodes into it.

## Example: Drop a Node Into a Group

When a drag ends, the client pushes a `position` change with `dragging: false`
(an aborted drag, e.g. with Escape, carries `"aborted" => true`). Apply the
change, then look for the group under the node's center and re-parent it:

```elixir
alias LiveFlow.{Node, State}
alias LiveFlow.Changes.NodeChange

def handle_event("lf:node_change", %{"changes" => changes}, socket) do
  flow = NodeChange.apply_changes(socket.assigns.flow, changes)

  dropped =
    for %{"type" => "position", "dragging" => false, "id" => id} = change <- changes,
        !change["aborted"],
        do: id

  {:noreply, assign(socket, flow: Enum.reduce(dropped, flow, &relink(&2, &1)))}
end

# Attach the node to the smallest group under its center, or detach it when it
# was dropped outside of any group
defp relink(flow, id) do
  case State.get_node(flow, id) do
    %Node{type: type} = node when type != :group ->
      target = drop_target(flow, id)
      if target == node.parent_id, do: flow, else: State.set_parent(flow, id, target)

    _group_or_missing ->
      flow
  end
end

defp drop_target(flow, id) do
  rect = State.node_rect(flow, id)
  center = %{x: rect.x + rect.width / 2, y: rect.y + rect.height / 2, width: 1, height: 1}
  exclude = [id | State.descendant_ids(flow, id)]

  flow
  |> State.intersecting_nodes(center)
  |> Enum.filter(&(&1.type == :group and &1.id not in exclude))
  |> Enum.min_by(&((&1.width || 0) * (&1.height || 0)), fn -> nil end)
  |> case do
    %Node{id: group_id} -> group_id
    nil -> nil
  end
end
```

Notes:

- `dragging: false` position changes are also pushed for the arrow keys and at
  the end of layouts and animations. To react to real drags only, remember the
  IDs of the `dragging: true` changes (the drag start) and relink just those, as
  the showcase does.
- Leave the children's `extent` unset so they can be dragged out again.
- To highlight the group under the pointer while dragging, handle
  `lf:drag_move`: its changes carry the absolute positions of the moving nodes,
  so you can build a rect from them, find the target group the same way and set
  a class on it at render time.

The full version is at `/examples/grouping/parent-child-relation` in the
showcase app.

## Example: Group and Ungroup the Selection

Grouping adds a `:group` node around the bounds of the selected top-level nodes
and re-parents them. Ungrouping detaches the children before removing the group,
because `LiveFlow.State.remove_node/2` would delete them too:

```elixir
@padding 24

def handle_event("group", _params, socket) do
  flow = socket.assigns.flow
  ids = for node <- State.selected_nodes_list(flow), is_nil(node.parent_id), do: node.id

  case State.bounds(flow, nodes: ids) do
    nil ->
      {:noreply, socket}

    rect ->
      group_id = "group-#{System.unique_integer([:positive])}"

      group =
        Node.new(group_id, %{x: rect.x - @padding, y: rect.y - @padding}, %{label: "Group"},
          type: :group,
          resizable: true,
          connectable: false,
          width: rect.width + @padding * 2,
          height: rect.height + @padding * 2
        )

      # The group must exist before the nodes are re-parented
      flow =
        ids
        |> Enum.reduce(State.add_node(flow, group), fn id, acc ->
          State.set_parent(acc, id, group_id, extent: :parent)
        end)
        |> State.select_nodes([group_id])

      {:noreply, assign(socket, flow: flow)}
  end
end

def handle_event("ungroup", %{"id" => group_id}, socket) do
  flow = socket.assigns.flow

  flow =
    flow
    |> State.children(group_id)
    |> Enum.reduce(flow, &State.set_parent(&2, &1.id, nil))
    |> State.remove_node(group_id)

  {:noreply, assign(socket, flow: flow)}
end
```

`/examples/grouping/selection-grouping` in the showcase adds a toolbar button
with `LiveFlow.Components.NodeToolbar` and grows the group back to fit its
children after a resize or a drag.

## Graph Helpers

These mirror xyflow's `getIncomers`, `getOutgoers` and `getConnectedEdges`.
They follow edges, not the parent/child hierarchy:

| Function | Returns |
|----------|---------|
| `LiveFlow.State.incomers/2` | Nodes with an edge pointing to the given node ID (unique) |
| `LiveFlow.State.outgoers/2` | Nodes the given node ID has an edge to (unique) |
| `LiveFlow.State.connected_edges/2` | Edges connected to any of the given node IDs (a list) |

Deleting a node in the middle of a chain without breaking it (from
`/examples/nodes/delete-middle-node`):

```elixir
defp delete_and_bridge(flow, id) do
  bridges =
    for %Node{id: source} <- State.incomers(flow, id),
        %Node{id: target} <- State.outgoers(flow, id),
        source != target,
        do: {source, target}

  flow = State.remove_node(flow, id)

  Enum.reduce(bridges, flow, fn {source, target}, acc ->
    if State.edge_exists?(acc, source, target),
      do: acc,
      else: State.add_edge(acc, Edge.new("#{source}->#{target}", source, target))
  end)
end
```

Other uses: collapsing a tree hides every node reachable through
`LiveFlow.State.outgoers/2` (see `/examples/layout/expand-collapse` and the
[Layout](layout.md) guide), and
`State.connected_edges(flow, [id | State.descendant_ids(flow, id)])` lists the edges
that would disappear together with a subtree.

## Next Steps

- [Layout](layout.md) -- Arrange nodes automatically (layouts skip child nodes by default)
- [Events](events.md) -- Every `lf:*` event and its payload
- [Components](components.md) -- `NodeResizer`, `NodeToolbar` and the Flow options
