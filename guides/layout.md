# Layout

LiveFlow doesn't position nodes for you: every node has the position you give it. When
you need automatic positions, `LiveFlow.Layout` offers layouts written in Elixir, and
the client can run a small JS tree layout or the optional [ELK](https://eclipse.dev/elk/)
engine.

## Choosing an Approach

| Approach | Runs on | Good for | Needs |
|----------|---------|----------|-------|
| `LiveFlow.Layout.tree/2` | Server | Trees and DAGs (like dagre / d3-hierarchy) | Nothing |
| `LiveFlow.Layout.force/2` | Server | Networks without a hierarchy (like d3-force) | Nothing |
| `LiveFlow.Layout.resolve_collisions/2` | Server | Pushing overlapping nodes apart | Nothing |
| JS tree layout (`lf:tree_layout_data`) | Browser | Simple trees, using the measured node sizes | Nothing |
| ELK (`lf:layout_data`) | Browser | Complex graphs, many handles per node, ELK algorithms | `mix live_flow.gen.elk` |

The server-side layouts are pure functions: they are easy to test, work before the
page is connected (on mount) and don't add JavaScript. They use each node's `width` and
`height` (known once the browser has measured the node, or set with
`LiveFlow.Node.new/4`), and 150×50 for nodes that haven't been measured yet.

## Server-Side Layouts

Every layout returns a map of node IDs to positions. Apply it with
`LiveFlow.Layout.apply_positions/2`:

```elixir
alias LiveFlow.Layout

def mount(_params, _session, socket) do
  flow = build_flow()
  flow = Layout.apply_positions(flow, Layout.tree(flow, direction: :lr))
  {:ok, assign(socket, flow: flow)}
end
```

By default layouts arrange the visible top-level nodes: child nodes keep their
position relative to their parent (see [Sub-flows](subflows.md)). Pass `nodes: ids` to
lay out a subset.

### Tree

`LiveFlow.Layout.tree/2` ranks nodes by their longest path from a root, orders each
rank to reduce crossings and centers nodes on their parents. Cycles are allowed (back
edges are ignored for ranking).

| Option | Default | Description |
|--------|---------|-------------|
| `:direction` | `:tb` | `:tb` (top to bottom) or `:lr` (left to right) |
| `:node_spacing` | `40` | Gap between nodes of the same rank |
| `:rank_spacing` | `80` | Gap between ranks |
| `:nodes` | top-level nodes | Only lay out these node IDs |
| `:origin` | `{0, 0}` | Top-left corner of the result |

The layout doesn't move handles. When switching direction, move them too so edges
leave from the right side:

```elixir
alias LiveFlow.Handle

defp set_direction(flow, direction) do
  handles =
    case direction do
      :lr -> [Handle.target(:left), Handle.source(:right)]
      :tb -> [Handle.target(:top), Handle.source(:bottom)]
    end

  nodes = Map.new(flow.nodes, fn {id, node} -> {id, %{node | handles: handles}} end)
  %{flow | nodes: nodes}
end
```

### Force

`LiveFlow.Layout.force/2` runs a force-directed simulation (Fruchterman-Reingold)
starting from the current positions. It is deterministic, and the center of the
graph stays where it was.

| Option | Default | Description |
|--------|---------|-------------|
| `:iterations` | `300` | Simulation steps |
| `:distance` | `200` | Ideal edge length |
| `:fixed` | `[]` | Node IDs that keep their position |
| `:nodes` | top-level nodes | Only lay out these node IDs |

### Collisions

`LiveFlow.Layout.resolve_collisions/2` pushes overlapping nodes apart along the axis
with the smallest overlap, and returns only the nodes that moved. Child nodes are only
compared with their siblings.

| Option | Default | Description |
|--------|---------|-------------|
| `:margin` | `10` | Minimum gap between nodes |
| `:fixed` | `[]` | Node IDs that never move (e.g. the node just dropped) |
| `:max_iterations` | `50` | Upper bound on the passes |

## Animating Layout Changes

Instead of applying positions, `LiveFlow.animate_positions/5` lets the browser move
the nodes (with their edges and children) to their new positions, then pushes the final
positions back as a regular `lf:node_change` event, which your handler applies:

```elixir
def handle_event("layout", _params, socket) do
  flow = socket.assigns.flow
  positions = LiveFlow.Layout.tree(flow, direction: :tb)

  {:noreply,
   LiveFlow.animate_positions(socket, "my-flow", flow, positions,
     duration: 400,
     fit_view: true
   )}
end
```

The second argument is the Flow component `id`. Options: `:duration` (ms, default
`300`) and `:fit_view` (`true` or `%{padding: 0.1}`), which fits the view to the final
positions.

### Resolving Collisions on Drop

Run the collision pass when a drag ends and keep the dropped node in place. Drag
starts arrive with `"dragging" => true` and drops with `"dragging" => false`:

```elixir
def handle_event("lf:node_change", %{"changes" => changes}, socket) do
  flow = NodeChange.apply_changes(socket.assigns.flow, changes)
  socket = assign(socket, flow: flow)

  dropped = for %{"type" => "position", "dragging" => false, "id" => id} <- changes, do: id

  if dropped == [] do
    {:noreply, socket}
  else
    positions = LiveFlow.Layout.resolve_collisions(flow, fixed: dropped, margin: 12)
    {:noreply, LiveFlow.animate_positions(socket, "my-flow", flow, positions, duration: 300)}
  end
end
```

Measured sizes and animation results also arrive as `dragging: false` position
changes; in a real app keep track of the IDs that started a drag (as the showcase page
`/examples/layout/node-collisions` does) and only resolve for those.

### Expand and Collapse

Hidden nodes are skipped by the layouts, so collapsing a subtree is: hide the
descendants, lay out what is left, animate.

```elixir
defp toggle(flow, id) do
  collapsed = flow.nodes[id].data[:collapsed] != true
  descendants = descendants(flow, id)

  flow =
    flow
    |> State.update_node(id, fn n -> %{n | data: Map.put(n.data, :collapsed, collapsed)} end)
    |> then(fn flow -> Enum.reduce(descendants, flow, &State.update_node(&2, &1, hidden: collapsed)) end)

  visible = for {id, node} <- flow.nodes, not node.hidden, do: id
  {flow, LiveFlow.Layout.tree(flow, nodes: visible)}
end

defp descendants(flow, id) do
  children = flow |> State.outgoers(id) |> Enum.map(& &1.id)
  children ++ Enum.flat_map(children, &descendants(flow, &1))
end
```

Edges to hidden nodes are not drawn. The showcase pages `/examples/layout/expand-collapse`
and `/examples/layout/dynamic-layouting` build on this, starting new nodes at their
parent's position so they grow out of it.

## Client-Side Tree Layout

`LiveFlow.Layout.prepare_tree_layout_data/2` sends the graph to a small tree layout
in the browser, which uses the measured DOM sizes, animates the nodes and fits the
view:

```elixir
data = LiveFlow.Layout.prepare_tree_layout_data(flow, %{"direction" => "LR", "flow_id" => "my-flow"})
{:noreply, push_event(socket, "lf:tree_layout_data", data)}
```

`"direction"` is `"TB"` (default) or `"LR"`. The new positions arrive as an
`lf:node_change` event.

## ELK

[ELK](https://eclipse.dev/elk/) (elkjs) is a powerful layout engine with many
algorithms (`layered`, `mrtree`, `force`, `stress`, `radial`, ...). It weighs about
1.6 MB minified, so LiveFlow doesn't bundle it.

### Installing

```bash
mix live_flow.gen.elk
```

The generator copies elkjs to `assets/vendor/elk.bundled.cjs` and registers it in
`assets/js/app.js`:

```javascript
// ELK auto-layout engine for LiveFlow (mix live_flow.gen.elk)
import ELK from "../vendor/elk.bundled.cjs"
import {registerElk} from "live_flow"
registerElk(ELK)
```

Running it again changes nothing. Options:

| Option | Description |
|--------|-------------|
| `--assets` | Assets directory (default: `assets`) |
| `--entry` | JS entry point relative to the assets directory (default: `js/app.js`) |
| `--force` | Overwrite an existing `vendor/elk.bundled.cjs` |
| `--no-import` | Only copy the file, leave the entry point untouched |

With npm instead, `npm install elkjs --prefix assets` and register
`import ELK from "elkjs/lib/elk.bundled.js"`. `registerElk/1` also accepts an ELK
instance, for example `new ELK({workerUrl: "/assets/elk-worker.min.js"})` to run the
layout in a web worker.

Without ELK, `lf:layout_data` logs an error in the browser console explaining how to
install it; nothing else breaks.

### Running a Layout

Build the payload with `LiveFlow.Layout.prepare_layout_data/2` and push it:

```elixir
def handle_event("elk_layout", _params, socket) do
  data =
    LiveFlow.Layout.prepare_layout_data(socket.assigns.flow, %{
      "flow_id" => "my-flow",
      "direction" => "RIGHT",
      "options" => %{"elk.algorithm" => "layered", "elk.spacing.nodeNode" => "40"}
    })

  {:noreply, push_event(socket, "lf:layout_data", data)}
end
```

| Key | Default | Description |
|-----|---------|-------------|
| `"direction"` | `"DOWN"` | `"DOWN"`, `"RIGHT"`, `"UP"` or `"LEFT"` (`elk.direction`) |
| `"options"` | `%{}` | Any ELK layout option, merged over LiveFlow's defaults (`layered`, `NETWORK_SIMPLEX` placement) |
| `"flow_id"` | `nil` | Only the flow with this DOM id runs the layout |

The browser measures the nodes, runs ELK, pushes the positions as `lf:node_change` and
fits the view. Handles are sent as ELK ports on their side, so nodes with several
handles get fewer crossings (see `/examples/layout/elkjs-multiple-handles`).

ELK positions every node as a top-level node; for [sub-flows](subflows.md), lay out
the top-level nodes with `LiveFlow.Layout.tree/2` instead.

### From a Button

`JS.dispatch("lf:auto-layout")` asks your LiveView for a layout with
`lf:request_layout`; answer it with `lf:layout_data`:

```heex
<button phx-click={JS.dispatch("lf:auto-layout", to: "#my-flow", detail: %{direction: "RIGHT"})}>
  Auto layout
</button>
```

```elixir
def handle_event("lf:request_layout", %{"direction" => direction}, socket) do
  data = LiveFlow.Layout.prepare_layout_data(socket.assigns.flow, %{"direction" => direction})
  {:noreply, push_event(socket, "lf:layout_data", data)}
end
```
