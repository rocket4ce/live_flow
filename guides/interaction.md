# Interaction

This guide covers how users interact with a flow (panning, zooming, selecting,
dragging, connecting, deleting, keyboard shortcuts, undo/redo, clipboard,
drag and drop, context menus and touch) and how to configure each of them.

All options go in the `opts` map of the Flow component
(`opts={%{snap_to_grid: true, context_menu: true}}`); every option you leave out
keeps its default. Interactions run in the browser for instant feedback; when the
user is done, the hook pushes `lf:*` events to the **parent LiveView**, which
updates `@flow`. Some of them may not interest you (`lf:undo`, `lf:copy`,
`lf:drag_move`, ...), so keep a catch-all clause:

```elixir
def handle_event("lf:" <> _event, _params, socket), do: {:noreply, socket}
```

See [Events](events.md) for the full list of events and payloads.

## Pan and zoom

| Option | Default | Description |
|--------|---------|-------------|
| `pan_on_drag` | `true` | Drag the pane to pan. `true` pans with the left and middle buttons, a list picks the buttons (`[0, 1, 2]`, where `2` is the right button), `false` disables it |
| `pan_activation_key` | `"Space"` | Hold it to pan with the left button from anywhere, including over nodes |
| `pan_on_scroll` | `false` | The wheel pans instead of zooming |
| `pan_on_scroll_mode` | `:free` | `:free`, `:vertical` or `:horizontal` |
| `pan_on_scroll_speed` | `0.5` | Pan speed for `pan_on_scroll` |
| `zoom_on_scroll` | `true` | Zoom with the wheel |
| `zoom_on_pinch` | `true` | Zoom with a trackpad pinch (Ctrl + wheel) |
| `zoom_on_double_click` | `true` | Double click the pane to zoom in, Shift + double click to zoom out |
| `prevent_scrolling` | `true` | Wheel events over the flow never scroll the page |
| `min_zoom` / `max_zoom` | `0.1` / `4.0` | Zoom limits, also applied to fit view |
| `fit_view_on_init` | `false` | Fit the view to the nodes when the flow mounts |
| `fit_view_options` | `%{}` | Defaults for every fit view (see below) |

There is no `translate_extent` option: the pane can be panned without limits.

Two CSS classes let your own markup opt out of these gestures: `nopan` (pressing
on the element never starts a pan or any other flow interaction) and `nowheel`
(the wheel scrolls the element instead of zooming the flow), handy for a
scrollable list inside a node.

### Viewport

The initial viewport comes from the state, e.g.
`LiveFlow.State.new(nodes: nodes, viewport: %LiveFlow.Viewport{x: 0, y: 0, zoom: 1})`.
After mount the browser owns the viewport: it pushes `lf:viewport_change`
(`%{"x", "y", "zoom"}`) while the user pans or zooms; store it with
`LiveFlow.State.update_viewport/2`.

Assigning a different `flow.viewport` later does not move the view. Push one of
these events instead (they act on every flow of the LiveView):

| Event | Payload |
|-------|---------|
| `lf:zoom_to` | `%{zoom: 1.5, duration: 200}` |
| `lf:zoom_in` / `lf:zoom_out` | `%{duration: 200}` |
| `lf:pan_to` | `%{x: 0, y: 0, duration: 200}` (viewport translation, current zoom) |
| `lf:set_viewport` | `%{x: 0, y: 0, zoom: 1}` (immediate, not reported back with `lf:viewport_change`) |

### Fit view

`fit_view_options` accepts `padding` (default `0.1`), `duration` (default `200` ms,
always `0` on init), `min_zoom`, `max_zoom`, `nodes` (only fit these node IDs)
and `include_hidden_nodes` (default `false`, used by the server-side fit below),
e.g. `opts={%{fit_view_on_init: true, fit_view_options: %{padding: 0.2, max_zoom: 1}}}`.

From the server, `send_update/2` computes the bounds with `LiveFlow.State.bounds/2`,
so nodes culled by virtualization are included:

```elixir
send_update(LiveFlow.Components.Flow, id: "my-flow", fit_view: true)
send_update(LiveFlow.Components.Flow, id: "my-flow", fit_view: %{nodes: ["a", "b"], padding: 0.2})
```

From the browser, dispatch DOM events on the flow container (the zoom buttons of
`controls: true` use the same ones):

```heex
<button phx-click={JS.dispatch("lf:fit-view", to: "#my-flow", detail: %{padding: 0.3})}>Fit</button>
<button phx-click={JS.dispatch("lf:zoom-in", to: "#my-flow")}>Zoom in</button>
<button phx-click={JS.dispatch("lf:zoom-out", to: "#my-flow")}>Zoom out</button>
```

Other hooks can also use the JavaScript API on the container element
(`el.liveflow.fitView()`, `zoomTo()`, `setViewport()`, `screenToFlowPosition()`, ...).

## Selection

- **Click** a node or an edge to select it; clicking the pane clears the selection.
- Hold a **multi selection key** (`Meta`, `Control` or `Shift` by default) and click
  to add or remove an element.
- Hold the **selection key** (`Shift`) and drag on the pane to draw a selection box,
  or set `selection_on_drag: true` to draw it without a key. The box replaces the
  selection with the nodes it covers plus their connected edges.
- **Ctrl/Cmd + A** selects everything, **Escape** clears the selection.

| Option | Default | Description |
|--------|---------|-------------|
| `elements_selectable` | `true` | Global switch for selection |
| `selection_on_drag` | `false` | Dragging the pane draws a selection box (instead of panning) |
| `selection_mode` | `:partial` | `:partial` selects nodes touched by the box, `:full` only nodes fully inside |
| `selection_key` | `"Shift"` | Hold to draw a selection box |
| `multi_selection_key` | `["Meta", "Control", "Shift"]` | Hold to add/remove elements |
| `elevate_nodes_on_select` | `true` | Render selected nodes (and their children) on top |
| `elevate_edges_on_select` | `true` | Render selected edges on top |
| `z_index_mode` | `:basic` | `:manual` ignores the two options above and only uses each element's `z_index` |

A node created with `selectable: false` is skipped by clicks, the selection box
and Ctrl/Cmd + A. (`LiveFlow.Edge` also has a `:selectable` field, but the client
doesn't enforce it yet.)

Every selection change is pushed as `lf:selection_change` with the full lists of
selected IDs. Keep the server state in sync: deleting, copying and the
`selected` flag your node components render all read it.

```elixir
def handle_event("lf:selection_change", %{"nodes" => node_ids, "edges" => edge_ids}, socket) do
  flow =
    socket.assigns.flow
    |> LiveFlow.State.clear_selection()
    |> LiveFlow.State.select_nodes(node_ids)

  flow = Enum.reduce(edge_ids, flow, &LiveFlow.State.select_edge(&2, &1, multi: true))

  {:noreply, assign(socket, flow: flow)}
end
```

The server is the source of truth: when a render changes the selection (delete,
undo, paste or your own code), the browser adopts it. To select from Elixir, use
`LiveFlow.State.select_node/3` (`multi: true` adds to the selection),
`LiveFlow.State.select_nodes/2`, `LiveFlow.State.deselect_node/2`,
`LiveFlow.State.select_edge/3`, `LiveFlow.State.select_all/1` and
`LiveFlow.State.clear_selection/1`; read it with
`LiveFlow.State.selected_nodes_list/1` and `LiveFlow.State.selected_edges_list/1`.

Clicking a node also sends `{:lf_node_click, node_id}` to the LiveView process,
so define a matching `handle_info/2` clause if your LiveView has other `handle_info/2` clauses.

## Dragging nodes

Dragging a selected node moves every selected node; children of a dragged node
move with it (see [Sub-flows](subflows.md)).

| Option | Default | Description |
|--------|---------|-------------|
| `nodes_draggable` | `true` | Global switch for dragging (also for the arrow keys) |
| `node_drag_threshold` | `1` | Pixels the pointer must move before a drag starts |
| `snap_to_grid` / `snap_grid` | `false` / `{15, 15}` | Snap positions to a grid |
| `helper_lines` | `false` | Show alignment guides and snap to them (within 5px) while dragging |
| `node_extent` | `nil` | `{{min_x, min_y}, {max_x, max_y}}`: area nodes can't be dragged or resized out of |
| `auto_pan_on_node_drag` | `true` | Pan when dragging close to the edge of the flow |
| `auto_pan_on_connect` / `auto_pan_on_selection` | `true` | Same while connecting / drawing a selection box |
| `auto_pan_speed` | `15` | Auto-pan speed in pixels per frame |

Per node:

- `draggable: false` keeps a node in place.
- `drag_handle: ".drag-handle"` only starts a drag from elements matching the CSS
  selector; the rest of the node keeps selectable text and working controls.
- `extent: :parent` (or `{{x1, y1}, {x2, y2}}`, relative to the parent) keeps a
  child node inside its parent. It only applies to nodes with a `parent_id`.
- Form elements (`input`, `select`, `textarea`, `button`, links, `contenteditable`)
  and anything with the `nodrag` class never start a drag.

```elixir
Node.new("card", %{x: 0, y: 0}, %{label: "Card"}, drag_handle: ".drag-handle")
# in the node component: <div class="drag-handle">...</div> <div class="nodrag">...</div>
```

A drag produces these events (positions of child nodes are relative to their parent):

1. `lf:node_change` with `"type" => "position"` and `"dragging" => true` when the drag starts.
2. `lf:drag_move` at most every 50 ms with the current positions (used by [Collaboration](collaboration.md)).
3. `lf:node_change` with the final positions and `"dragging" => false`.

Pressing **Escape** (or the window losing focus) aborts the drag: the nodes go back to
where they were and the last `lf:node_change` carries `"aborted" => true` along with
the start positions, so you can tell a cancelled drag from a drop:

```elixir
# In lf:node_change: a drop (or an arrow key move), not a cancelled drag
dropped? = Enum.any?(changes, &(&1["type"] == "position" and &1["dragging"] == false and !&1["aborted"]))
```

## Connections

Users connect nodes by dragging from one handle to another. The preview line is
drawn in the browser; nothing reaches the server until the line is released
(except the opt-in `lf:connect_start`).

| Option | Default | Description |
|--------|---------|-------------|
| `nodes_connectable` | `true` | Global switch for connections |
| `connection_mode` | `:strict` | `:strict` only connects source to target handles, `:loose` also source to source |
| `connection_radius` | `20` | Snap to the closest valid handle within this many pixels |
| `connect_on_click` | `true` | Click a handle, then another one, to connect them (Escape or a pane click cancels) |
| `multi_connection` | `false` | Dragging from a selected node draws a line from every selected node |
| `connection_line_type` | `:bezier` | Preview path: `:bezier`, `:straight`, `:step` or `:smoothstep` |
| `connection_line_style` | `nil` | Inline style for the preview, e.g. `%{stroke: "#ff0072", "stroke-width": 3}` |
| `connection_line_class` | `nil` | Extra CSS class for the preview (`.lf-connection-line`) |
| `connection_events` | `false` | Push `lf:connect_start` when a connection starts |

While dragging, the browser already refuses handles of the same node, handles with
`connectable: false` (`Handle.target(:left, connectable: false)`), same-type handles
in `:strict` mode, and handles whose `connect_type` differs from the source handle's
(when both have one). The hovered handle gets `data-connecting="valid"` or
`"invalid"` for styling. With
`multi_connection`, the other selected nodes use the handle with the same ID (or the
first handle of the same type) and one `lf:connect_end` is pushed per source.

| Event | Payload |
|-------|---------|
| `lf:connect_start` | `"node_id"`, `"handle_id"`, `"handle_type"` (only with `connection_events: true`) |
| `lf:connect_end` | `"source"`, `"source_handle"`, `"target"`, `"target_handle"` (always source to target, whichever end the user started from) |
| `lf:connect_cancel` | `"node_id"`, `"handle_id"`, `"handle_type"`, `"position"` (release point in flow coordinates), `"reason"`, plus `"target_node_id"` / `"target_handle_id"` for `"invalid"` |

The `reason` is `"pane"` (released on the empty pane), `"invalid"` (released on a
handle the browser refused) or `"abort"` (Escape, or released outside the flow).

### Validating connections

`lf:connect_end` is a request: the edge only exists once you add it.
`LiveFlow.Validation.Connection.validate_and_create/3` runs validators and builds
the edge:

```elixir
alias LiveFlow.{State, Validation}
alias LiveFlow.Validation.Connection

def handle_event("lf:connect_end", params, socket) do
  validators =
    Validation.preset(:strict) ++
      [
        &Validation.types_compatible/2,
        &Validation.no_cycles/2,
        fn flow, conn -> Validation.max_connections(flow, conn, max: 1, side: :target) end,
        &input_only_to_b/2
      ]

  case Connection.validate_and_create(socket.assigns.flow, params,
         validators: validators,
         edge_opts: [type: :smoothstep, animated: true]
       ) do
    {:ok, edge} ->
      {:noreply, update(socket, :flow, &State.add_edge(&1, edge))}

    {:error, reason} ->
      {:noreply, put_flash(socket, :error, reason)}
  end
end

# Custom validators receive the flow and %{source:, target:, source_handle:, target_handle:}
defp input_only_to_b(_flow, %{source: "input", target: target}) when target != "B",
  do: {:error, "Input can only connect to node B"}

defp input_only_to_b(_flow, _conn), do: :ok
```

Built-in validators in `LiveFlow.Validation`:

- `no_duplicate_edges/2` and `nodes_exist/2` (the `:default` preset, used when you pass no `:validators`)
- `handles_valid/2`: both handles exist and are connectable (`:strict` adds it)
- `types_compatible/2`: both handles have the same `connect_type` (or one has none)
- `no_cycles/2`: rejects connections that would close a loop
- `max_connections/3`: at most `max:` edges per handle; `side:` limits `:source`,
  `:target` or `:both` (default) ends

`validate_and_create/3` also accepts `:edge_id` (a string or a function receiving the
connection) to choose the edge ID. To show a full handle as unavailable, re-render it
with `connectable: false` so the browser refuses it too (see
`/examples/nodes/connection-limit` in the showcase app).

### Dropping a connection on the pane

`lf:connect_cancel` with `"reason" => "pane"` carries the release position, so you
can create a node there, already connected (`/examples/nodes/add-node-on-edge-drop`):

```elixir
alias LiveFlow.{Edge, Handle, Node, State}

def handle_event(
      "lf:connect_cancel",
      %{"reason" => "pane", "node_id" => from, "handle_type" => "source", "position" => pos} = params,
      socket
    ) do
  id = "node-#{System.unique_integer([:positive])}"
  node = Node.new(id, %{x: pos["x"], y: pos["y"]}, %{label: "New"}, handles: [Handle.target(:top)])
  edge = Edge.new("e-#{from}-#{id}", from, id, source_handle: params["handle_id"])

  {:noreply, update(socket, :flow, &(&1 |> State.add_node(node) |> State.add_edge(edge)))}
end
```

Reconnecting the end of an existing edge is covered in [Edges](edges.md).

## Deleting

The keys in `delete_key_code` (`["Backspace", "Delete"]` by default, `nil` disables
them) push `lf:delete_selected` when something is selected. Selected elements also
show a small delete button, which pushes a `"remove"` change in `lf:node_change` or
`lf:edge_change`.

`LiveFlow.State.delete_selected/1` removes the selected nodes and edges, skipping
the ones created with `deletable: false` (their delete button is not shown either).
Removing a node also removes its edges and its child nodes.

```elixir
def handle_event("lf:delete_selected", _params, socket) do
  {:noreply, update(socket, :flow, &LiveFlow.State.delete_selected/1)}
end
```

## Keyboard shortcuts

Press **?** in a flow to open the built-in shortcuts panel. Ctrl and Cmd are
interchangeable below.

| Keys | Action | Pushes |
|------|--------|--------|
| `?` | Toggle the shortcuts panel | |
| Escape | Cancel the current drag, resize, connection or selection box; otherwise close the panel or clear the selection | |
| `delete_key_code` | Delete the selection | `lf:delete_selected` |
| Ctrl/Cmd + A | Select all | `lf:selection_change` |
| Arrow keys | Move the selected nodes 5px, or one grid step with `snap_to_grid` (Shift = 4x) | `lf:node_change` |
| Ctrl/Cmd + Z | Undo | `lf:undo` |
| Ctrl/Cmd + Shift + Z, Ctrl/Cmd + Y | Redo | `lf:redo` |
| Ctrl/Cmd + C / X / D | Copy / cut / duplicate (only with a selection) | `lf:copy` / `lf:cut` / `lf:duplicate` |
| Ctrl/Cmd + V | Paste | `lf:paste` |
| `pan_activation_key` + drag | Pan from anywhere | |
| `selection_key` + drag | Selection box | |
| `multi_selection_key` + click | Add/remove from the selection | |

Set `disable_keyboard_a11y: true` to turn off moving nodes with the arrow keys.
The configurable key options (`delete_key_code`, `pan_activation_key`,
`selection_key`, `multi_selection_key`) accept a key, a combination of any length,
a list of them, or `nil` to disable the binding, e.g.
`delete_key_code: ["Delete", "Meta+Backspace"]`. Modifiers must match exactly, so
`"Backspace"` doesn't fire on Cmd + Backspace.

A flow handles shortcuts while the focus is inside it, or while nothing is focused and
it was the last flow the user clicked. Keys typed in an `input`, `select`, `textarea`
or `contenteditable` element (for example a form inside a node) never trigger
shortcuts; add the `nokey` class to exclude other elements.

## Undo and redo

`LiveFlow.History` stores snapshots of the nodes and edges (not the viewport or
the selection). Push a snapshot **before** every mutation you want to undo, and
handle `lf:undo` / `lf:redo`:

```elixir
alias LiveFlow.History
alias LiveFlow.Changes.NodeChange

# mount: assign(socket, flow: flow, history: History.new(max_entries: 100))

defp snapshot(socket) do
  assign(socket, :history, History.push(socket.assigns.history, socket.assigns.flow))
end

def handle_event("lf:node_change", %{"changes" => changes}, socket) do
  # Snapshot once per gesture: drag start, resize start or removal
  socket = if Enum.any?(changes, &undoable?/1), do: snapshot(socket), else: socket
  {:noreply, update(socket, :flow, &NodeChange.apply_changes(&1, changes))}
end

def handle_event("lf:undo", _params, socket) do
  case History.undo(socket.assigns.history, socket.assigns.flow) do
    {:ok, flow, history} -> {:noreply, assign(socket, flow: flow, history: history)}
    :empty -> {:noreply, socket}
  end
end

# lf:redo is the same with History.redo/2

defp undoable?(%{"type" => "position", "dragging" => true}), do: true
defp undoable?(%{"type" => "resize", "resizing" => true}), do: true
defp undoable?(%{"type" => "remove"}), do: true
defp undoable?(_change), do: false
```

Do the same in `lf:delete_selected`, `lf:edge_change`, before adding edges in
`lf:connect_end`, and on paste, cut and drop. Dimension changes are measurements, not user actions, so don't snapshot
them. Buttons can push the same events, and `LiveFlow.History.can_undo?/1` /
`LiveFlow.History.can_redo?/1` tell you whether to enable them:

```heex
<.live_component module={LiveFlow.Components.Flow} id="my-flow" flow={@flow}>
  <:panel position={:top_right}>
    <button phx-click="lf:undo" disabled={not LiveFlow.History.can_undo?(@history)}>Undo</button>
    <button phx-click="lf:redo" disabled={not LiveFlow.History.can_redo?(@history)}>Redo</button>
  </:panel>
</.live_component>
```

## Copy, cut and paste

`LiveFlow.Clipboard` lives in your LiveView assigns (it is not the system
clipboard). `LiveFlow.Clipboard.copy/2` stores the selected nodes and every edge
between them, `LiveFlow.Clipboard.cut/2` also deletes them, and
`LiveFlow.Clipboard.paste/3` adds copies with new IDs and selects them.

When the pointer is over the flow, `lf:paste` carries its position in flow
coordinates; pass it as `position:` to paste the nodes under the cursor (without it,
each paste is offset by 50px more than the previous one):

```elixir
# mount: assign(socket, clipboard: LiveFlow.Clipboard.new()), with alias LiveFlow.Clipboard
def handle_event("lf:copy", _params, socket) do
  {:noreply, update(socket, :clipboard, &Clipboard.copy(&1, socket.assigns.flow))}
end

def handle_event("lf:cut", _params, socket) do
  {clipboard, flow} = Clipboard.cut(socket.assigns.clipboard, socket.assigns.flow)
  {:noreply, assign(socket, clipboard: clipboard, flow: flow)}
end

def handle_event("lf:paste", params, socket) do
  case Clipboard.paste(socket.assigns.clipboard, socket.assigns.flow, position: params["position"]) do
    {:ok, flow, clipboard} -> {:noreply, assign(socket, flow: flow, clipboard: clipboard)}
    :empty -> {:noreply, socket}
  end
end

# Duplicate = copy into a fresh clipboard and paste, leaving the user's clipboard alone
def handle_event("lf:duplicate", _params, socket) do
  clipboard = Clipboard.copy(Clipboard.new(), socket.assigns.flow)

  case Clipboard.paste(clipboard, socket.assigns.flow) do
    {:ok, flow, _clipboard} -> {:noreply, assign(socket, flow: flow)}
    :empty -> {:noreply, socket}
  end
end
```

## Drag and drop from outside the flow

Any element dragged with HTML5 drag and drop can be dropped on the flow if it puts
data of type `application/liveflow` in the drag data. The hook pushes `lf:drop`
with that data (JSON-decoded when possible, otherwise the raw string) and the drop
`position` in flow coordinates, snapped to the grid when `snap_to_grid` is on.

A palette in a sidebar, adapted from `/examples/interaction/drag-and-drop`, with a
colocated hook (or a regular hook registered in `app.js`) setting the drag data:

```heex
<div class="flex h-screen">
  <aside id="palette" phx-hook=".Palette" class="w-48 space-y-2 p-3">
    <div :for={type <- ["trigger", "action", "output"]} id={"palette-#{type}"}
         draggable="true" data-type={type} class="cursor-grab rounded-lg border p-2">
      {String.capitalize(type)}
    </div>
  </aside>
  <script :type={Phoenix.LiveView.ColocatedHook} name=".Palette">
    export default {
      mounted() {
        this.el.addEventListener("dragstart", event => {
          const item = event.target.closest("[data-type]")
          if (!item) return
          event.dataTransfer.setData("application/liveflow", JSON.stringify({type: item.dataset.type}))
          event.dataTransfer.effectAllowed = "move"
        })
      }
    }
  </script>

  <div class="flex-1">
    <.live_component module={LiveFlow.Components.Flow} id="dnd-flow" flow={@flow}
      opts={%{snap_to_grid: true, snap_grid: {16, 16}}} />
  </div>
</div>
```

The data comes from the browser, so match it against known values (never turn it into an atom):

```elixir
alias LiveFlow.{Handle, Node, State}

@palette ["trigger", "action", "output"]

def handle_event("lf:drop", %{"data" => %{"type" => type}, "position" => %{"x" => x, "y" => y}}, socket)
    when type in @palette do
  node =
    Node.new("#{type}-#{System.unique_integer([:positive])}", %{x: x, y: y},
      %{label: String.capitalize(type)},
      handles: [Handle.target(:left), Handle.source(:right)]
    )

  {:noreply, update(socket, :flow, &State.add_node(&1, node))}
end

def handle_event("lf:drop", _params, socket), do: {:noreply, socket}
```

The position is the drop point: subtract half the node size to center the node on it.

## Context menus and pane clicks

With `context_menu: true` a right click pushes an event instead of opening the
browser menu (form elements, `nodrag` elements, the controls and the minimap keep the
native menu). `"x"`/`"y"` are pixels relative to the flow container, for placing your
menu; `"position"` is the point in flow coordinates, for adding a node there. A right
click doesn't change the selection: node menus receive the current `"selection"` so you
can act on all of it.

| Event | Payload |
|-------|---------|
| `lf:node_context_menu` | `"id"`, `"x"`, `"y"`, `"position"`, `"selection"` (selected node IDs) |
| `lf:edge_context_menu` | `"id"`, `"x"`, `"y"`, `"position"` |
| `lf:pane_context_menu` | `"x"`, `"y"`, `"position"` |
| `lf:pane_click` | `"position"` (with `pane_click_events: true`, a pane click without dragging) |

A pane click also clears the selection. With `selection_on_drag: true` (or the
selection key held) a press on the pane starts a selection box instead, so no
`lf:pane_click` is pushed.

```heex
<div class="relative h-full">
  <.live_component module={LiveFlow.Components.Flow} id="menu-flow" flow={@flow}
    opts={%{context_menu: true, pane_click_events: true}} />
  <div :if={@menu} id="context-menu" class="absolute z-50 rounded-lg border bg-white p-1 shadow-lg"
       style={"left: #{@menu.x}px; top: #{@menu.y}px"}>
    <button :if={@menu.kind == :pane} id="menu-add-node" phx-click="add_node_here">Add node here</button>
    <%!-- node actions use @menu.targets --%>
  </div>
</div>
```

```elixir
def handle_event("lf:node_context_menu", %{"id" => id, "x" => x, "y" => y} = params, socket) do
  selection = params["selection"] || []
  targets = if id in selection, do: selection, else: [id]
  {:noreply, assign(socket, menu: %{kind: :node, targets: targets, x: x, y: y})}
end

def handle_event("lf:pane_context_menu", %{"x" => x, "y" => y, "position" => position}, socket) do
  {:noreply, assign(socket, menu: %{kind: :pane, x: x, y: y, position: position})}
end

def handle_event("lf:pane_click", _params, socket), do: {:noreply, assign(socket, menu: nil)}

def handle_event("add_node_here", _params, socket) do
  %{"x" => x, "y" => y} = socket.assigns.menu.position
  node = LiveFlow.Node.new("node-#{System.unique_integer([:positive])}", %{x: x, y: y}, %{label: "New"})
  {:noreply, assign(socket, flow: LiveFlow.State.add_node(socket.assigns.flow, node), menu: nil)}
end
```

See `/examples/interaction/context-menu` in the showcase app for a complete menu that
stays inside the canvas.

## Touch devices

Touch input works without extra configuration:

- One finger behaves like the left mouse button: it pans the pane, drags nodes,
  draws connections and resizes nodes.
- Two fingers pinch-zoom (within `min_zoom`/`max_zoom`) and pan. Putting the second
  finger down finishes a node drag, resize or pan, and cancels a connection or a
  selection box.
- With `connect_on_click` (the default), tap a handle and then another one to connect
  them; tapping the pane cancels. Bigger handles help: set `--lf-handle-size` on the
  flow (see [Themes](themes.md) and `/examples/interaction/touch-device`).
- Touch prefers panning: `selection_on_drag` is ignored for touch while
  `pan_on_drag` allows the left button. Use `pan_on_drag: false` with
  `selection_on_drag: true` to draw selection boxes with one finger and pan with two
  (this also turns off drag panning with the mouse).
- Form elements inside nodes keep their native touch behaviour, and a cancelled touch
  aborts the current interaction like Escape.

Modifier keys don't exist on touch screens, so adding to the selection by tapping
and keyboard shortcuts are not available there; provide buttons (for example in a
`:panel`) for actions such as delete, undo or copy.
