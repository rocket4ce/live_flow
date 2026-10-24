# Events & JavaScript API

LiveFlow splits the work between the browser and the server: the `LiveFlow` hook
handles every interaction on the client and reports the results to your LiveView as
`lf:*` events; your LiveView updates the `LiveFlow.State` and re-renders. This guide
lists every event in both directions, the DOM events you can dispatch from HEEx, and
the JavaScript API exposed on the flow element.

## How Events Reach Your LiveView

The hook calls `pushEvent`, so events go to the **LiveView that renders the Flow
component** (not to the component itself). Handle the ones you need and keep a
catch-all for the rest:

```elixir
alias LiveFlow.Changes.{EdgeChange, NodeChange}

def handle_event("lf:node_change", %{"changes" => changes}, socket) do
  {:noreply, assign(socket, flow: NodeChange.apply_changes(socket.assigns.flow, changes))}
end

def handle_event("lf:edge_change", %{"changes" => changes}, socket) do
  {:noreply, assign(socket, flow: EdgeChange.apply_changes(socket.assigns.flow, changes))}
end

# Events you don't use (lf:drag_move, lf:cursor_move, ...)
def handle_event("lf:" <> _event, _params, socket), do: {:noreply, socket}

# Node clicks arrive as a message
def handle_info({:lf_node_click, _node_id}, socket), do: {:noreply, socket}
```

[Getting Started](getting-started.md) shows a complete set of handlers. All payload
keys are strings, positions are in flow coordinates (`%{"x" => x, "y" => y}`) unless
noted otherwise.

## Events Sent to Your LiveView

### Nodes

| Event | Payload | When |
|-------|---------|------|
| `lf:node_change` | `%{"changes" => [change]}` | Nodes moved, measured, resized or deleted with their delete button |
| `lf:drag_move` | `%{"changes" => [position change]}` | While dragging, throttled (~50 ms). Meant for collaboration; don't store it |
| `{:lf_node_click, id}` | `handle_info/2` message | A node was clicked (not after a drag or a connection) |

Change maps in `lf:node_change`:

| `"type"` | Keys | Notes |
|----------|------|-------|
| `"position"` | `"id"`, `"position"`, `"dragging"` | `"dragging" => true` when a drag starts, `false` on drop. A drag cancelled with Escape sends the start positions with `"aborted" => true`. Child nodes report positions relative to their parent |
| `"dimensions"` | `"id"`, `"width"`, `"height"` | Measured size of a node (first render and every size change) |
| `"resize"` | `"id"`, `"width"`, `"height"`, `"position"`, `"resizing"` | From `LiveFlow.Components.NodeResizer` |
| `"remove"` | `"id"` | A node's delete button was clicked |

`LiveFlow.Changes.NodeChange.apply_changes/2` handles all of them.

### Edges

| Event | Payload | When |
|-------|---------|------|
| `lf:edge_change` | `%{"changes" => [%{"type" => "remove", "id" => id}]}` | An edge's delete button was clicked |
| `lf:edge_label_change` | `%{"id", "label"}` | A label was edited (double click); `"label"` is `nil` when cleared |
| `lf:insert_on_edge` | `%{"edge_id"}` | The "+" button of an edge with `data: %{insertable: true}` was clicked |
| `lf:reconnect_edge` | `%{"edge_id", "end", "node_id", "handle_id"}` | An end (`"source"` or `"target"`) of a `reconnectable` edge was dropped on a valid handle |
| `lf:delete_reconnect_edge` | `%{"edge_id", "end", "position"}` | That end was dropped on the pane |

`LiveFlow.State.reconnect_edge/3` accepts the `lf:reconnect_edge` params as they come.

### Connections

| Event | Payload | When |
|-------|---------|------|
| `lf:connect_end` | `%{"source", "source_handle", "target", "target_handle"}` | A connection was completed (one event per source with `multi_connection`) |
| `lf:connect_cancel` | `%{"node_id", "handle_id", "handle_type", "position", "reason"}` | A connection ended without connecting: `"reason"` is `"pane"`, `"invalid"` (also sends `"target_node_id"` / `"target_handle_id"`) or `"abort"` (Escape) |
| `lf:connect_start` | `%{"node_id", "handle_id", "handle_type"}` | A connection started. Opt-in: `connection_events: true` |

`lf:connect_end` is a request: nothing is added until you add the edge, usually after
validating it with `LiveFlow.Validation.Connection.validate_and_create/3`. See
[Interaction](interaction.md#connections).

### Selection, Deletion and Viewport

| Event | Payload | When |
|-------|---------|------|
| `lf:selection_change` | `%{"nodes" => [id], "edges" => [id]}` | The selection changed (click, selection box, Ctrl/Cmd+A, Escape, `setSelection`) |
| `lf:delete_selected` | `%{}` | A delete key (`delete_key_code`) was pressed with a selection |
| `lf:viewport_change` | `%{"x", "y", "zoom"}` | The viewport moved (throttled; the final value is always sent) |

### Keyboard Commands

The hook only sends these; the behavior is yours to implement (for example with
`LiveFlow.History` and `LiveFlow.Clipboard`, see [Interaction](interaction.md)).

| Event | Keys | Payload |
|-------|------|---------|
| `lf:undo` | Ctrl/Cmd+Z | `%{}` |
| `lf:redo` | Ctrl/Cmd+Shift+Z, Ctrl/Cmd+Y | `%{}` |
| `lf:copy` / `lf:cut` / `lf:duplicate` | Ctrl/Cmd+C / X / D (with a selection) | `%{}` |
| `lf:paste` | Ctrl/Cmd+V | `%{"position" => %{"x", "y"}}` when the pointer is over the flow, `%{}` otherwise |

Keys typed in inputs, textareas and content-editable elements are ignored, and with
several flows on a page only the focused (or last used) flow reacts.

### Pane, Drag & Drop and Context Menus

| Event | Payload | When |
|-------|---------|------|
| `lf:drop` | `%{"data", "position"}` | An element with `application/liveflow` drag data was dropped on the flow. `"data"` is the parsed JSON (or the raw string); the position is snapped when `snap_to_grid` is on |
| `lf:pane_click` | `%{"position"}` | The pane was clicked without dragging. Opt-in: `pane_click_events: true` |
| `lf:node_context_menu` | `%{"id", "x", "y", "position", "selection"}` | Right click on a node. Opt-in: `context_menu: true` |
| `lf:edge_context_menu` | `%{"id", "x", "y", "position"}` | Right click on an edge. Opt-in: `context_menu: true` |
| `lf:pane_context_menu` | `%{"x", "y", "position"}` | Right click on the pane. Opt-in: `context_menu: true` |

In the context menu events `"x"`/`"y"` are pixels relative to the flow container (to
position a menu inside it) and `"position"` is in flow coordinates.

### Layout and Collaboration

| Event | Payload | When |
|-------|---------|------|
| `lf:request_layout` | `%{"direction"}` | `JS.dispatch("lf:auto-layout")` was triggered; answer with `lf:layout_data` |
| `lf:cursor_move` | `%{"x", "y"}` | The pointer moved over the flow (throttled). Only with `cursors: true` |

`lf:container_resize` is sent to the Flow component itself (minimap and
virtualization) and never reaches your LiveView.

## Events You Push to the Client

Send these with `Phoenix.LiveView.push_event/3`. Events marked with `flow_id` accept
an optional `flow_id` (the Flow component `id`): with several flows on the page, only
that one reacts.

| Event | Payload | Effect |
|-------|---------|--------|
| `lf:fit_view` | `%{padding, duration, nodes: [id], bounds, min_zoom, max_zoom, flow_id}` | Fit the view to all nodes, some nodes or a rect |
| `lf:zoom_in` / `lf:zoom_out` | `%{duration, flow_id}` | Zoom one step around the center |
| `lf:zoom_to` | `%{zoom, duration, flow_id}` | Zoom to a level |
| `lf:pan_to` | `%{x, y, duration, flow_id}` | Animate the viewport translation to `x`/`y` (screen pixels, like `viewport.x`/`y`) |
| `lf:set_viewport` | `%{x, y, zoom, flow_id}` | Set the viewport immediately |
| `lf:animate_positions` | built by `LiveFlow.animate_positions/5` | Animate nodes to new positions, then push them back as `lf:node_change` |
| `lf:layout_data` | built by `LiveFlow.Layout.prepare_layout_data/2` | Run the ELK layout (needs `mix live_flow.gen.elk`, see [Layout](layout.md)) |
| `lf:tree_layout_data` | built by `LiveFlow.Layout.prepare_tree_layout_data/2` | Run the built-in JS tree layout |
| `lf:export_svg` / `lf:export_png` | `%{filename, padding, scale, flow_id}` | Download an SVG/PNG of the flow (see [Export](export.md)) |
| `lf:download_file` | `%{content, filename, type}` | Download a text file; requires `setupDownloadHandler()` |

Prefer the Elixir helpers where they exist:

```elixir
# Fit the view, computing the bounds on the server (works with virtualization)
send_update(LiveFlow.Components.Flow, id: "my-flow", fit_view: %{nodes: ["a", "b"], padding: 0.2})

# Animate to a server-side layout
positions = LiveFlow.Layout.tree(flow, direction: :lr)
socket = LiveFlow.animate_positions(socket, "my-flow", flow, positions, fit_view: true)
```

`LiveFlow.Collaboration` pushes `lf:remote_cursor`, `lf:cursor_leave` and
`lf:remote_drag` for you; see [Collaboration](collaboration.md).

## DOM Events

Some actions must run in the browser (they read the current client viewport or start a
download, which needs the user's click). Dispatch them on the flow element with
`Phoenix.LiveView.JS.dispatch/2`:

| Event | `detail` | Effect |
|-------|----------|--------|
| `lf:zoom-in` / `lf:zoom-out` | - | Zoom one step |
| `lf:fit-view` | fit view options (`padding`, `duration`, `nodes`, ...) | Fit the view |
| `lf:export-svg` | `%{filename:, padding:}` | Download an SVG |
| `lf:export-png` | `%{filename:, padding:, scale:}` | Download a PNG |
| `lf:auto-layout` | `%{direction: "RIGHT"}` | Push `lf:request_layout` to your LiveView |

```heex
<button phx-click={JS.dispatch("lf:fit-view", to: "#my-flow", detail: %{padding: 0.2})}>
  Fit view
</button>
<button phx-click={JS.dispatch("lf:export-png", to: "#my-flow", detail: %{scale: 2})}>
  Download PNG
</button>
```

## JavaScript API

When the hook mounts, the flow element gets a `liveflow` property (the equivalent of
React Flow's `useReactFlow()`), and the element dispatches an `lf:ready` event whose
`detail` is the same object. `lf:ready` doesn't bubble: listen on the flow element.

| Method | Returns |
|--------|---------|
| `getViewport()` | `{x, y, zoom}` |
| `setViewport({x, y, zoom}, {duration})` | Moves the viewport (missing keys keep their value) |
| `fitView(options)` | Fits the view (same options as `fit_view_options`) |
| `zoomIn({duration})` / `zoomOut({duration})` | Zooms one step |
| `zoomTo(zoom, {duration})` | Zooms to a level |
| `screenToFlowPosition({x, y}, {snapToGrid})` | Flow position of a client (viewport) point |
| `flowToScreenPosition({x, y})` | Client position of a flow point |
| `getNodes()` | Rendered nodes: `{id, x, y, width, height, selected, selectable, draggable, deletable, type, parentId}` with absolute positions |
| `getNode(id)` | One of those, or `null` |
| `getIntersectingNodes({x, y, width, height}, {partial})` | Rendered nodes overlapping a flow rect (`partial: false` requires full containment) |
| `getSelection()` | `{nodes: [id], edges: [id]}` |
| `setSelection({nodes, edges})` | Replaces the selection and pushes `lf:selection_change` |
| `element` | The flow element |

The API reads the browser state, so it only sees rendered nodes (with
`virtualization: true`, nodes outside the viewport are not rendered). Use it from a
hook, for example to turn a pointer position into flow coordinates:

```heex
<div id="stamp" phx-hook=".Stamp" data-flow="#my-flow">Click the flow</div>
<script :type={Phoenix.LiveView.ColocatedHook} name=".Stamp">
  export default {
    mounted() {
      const flow = document.querySelector(this.el.dataset.flow)
      flow.addEventListener("dblclick", (event) => {
        const position = flow.liveflow.screenToFlowPosition({x: event.clientX, y: event.clientY})
        this.pushEvent("add_note", {position})
      })
    }
  }
</script>
```

If the hook may mount after yours, wait for `lf:ready`:

```javascript
const flow = document.getElementById("my-flow")
if (flow.liveflow) init(flow.liveflow)
else flow.addEventListener("lf:ready", (event) => init(event.detail), {once: true})
```

## JavaScript Exports

Besides the hook, the `live_flow` package exports:

| Export | Purpose |
|--------|---------|
| `LiveFlowHook`, `FileImportHook`, `setupDownloadHandler` | Hooks and the download listener ([Getting Started](getting-started.md), [Export](export.md)) |
| `registerEdgePath(type, fn)` | Redraw custom edge shapes while dragging ([Edges](edges.md)) |
| `getEdgePath`, `getBezierPath`, `getStraightPath`, `getStepPath`, `getSmoothStepPath`, `calculateBezierPath` | Edge path math, identical to `LiveFlow.Paths` on the server |
| `registerElk(ELK)`, `hasElk()`, `getLayoutedElements` | Optional ELK layout ([Layout](layout.md)) |
| `exportSVG`, `exportPNG`, `buildExportSvg` | Programmatic export ([Export](export.md)) |
| `CoordinateUtils`, `EdgeUpdater`, `PanZoomManager`, `NodeDragManager`, `ConnectionManager`, `SelectionManager`, `calcAutoPan`, `parseKeys`, `matchesKeys` | Internals, for advanced customization |
