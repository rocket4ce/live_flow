# Changelog

## v0.3.1 (2026-10-24)

### Bug Fixes

- **Edge label editing survives server updates.** A re-render of the flow while a label was being
  edited (for example the selection update that follows the double click) made morphdom remove
  the focused input. Chrome fires `blur` during that removal and the editor's blur handler
  detached the input first, so the patch aborted with `NotFoundError: Failed to execute
  'removeChild' on 'Node'` and the editor closed. The label wrapper is now `phx-update="ignore"`
  while editing: server changes to that label are applied by the next update after Enter, Escape
  or a click elsewhere ends the edit.

### Showcase

- `flow_example/` uses esbuild 0.25.12 and runs the dev watcher with `--watch-delay=200`, so it no
  longer fails with `Could not resolve "phoenix-colocated/flow_example"` while LiveView rewrites
  the colocated hook manifests after a recompile.

## v0.3.0 (2026-10-23)

First release since v0.2.3: sync with the latest xyflow releases (React Flow 12.10 → 12.12,
`@xyflow/system` 0.0.74 → 0.0.83), node resizing, server-side viewport culling, sub-flows,
server-side layouts, a client refactor, new guides and a showcase app (`flow_example/`) with every
React Flow example, including the Pro ones.

### Upgrading from 0.2.x

- ELK is no longer bundled: if you use `lf:layout_data` / `lf:auto-layout`, run
  `mix live_flow.gen.elk` (see "Changes" below).
- The hook reads its configuration from `data-config`. If you styled or queried the old `data-*`
  attributes of `.lf-container`, update those selectors.
- Background classes are now `.lf-background-pattern.{dots,lines,cross}`.
- `connection_mode` defaults to `:strict`.
- Library CSS lives in `@layer components`, so app rules override it without `!important`; drop
  `!important` overrides you added for LiveFlow.

### New Features (React Flow examples parity)

Added while porting every React Flow example (including the Pro ones) to the showcase app:

- **Sub-flows.** `parent_id` is now fully supported: child positions are relative to the parent,
  children move with it, `extent: :parent` (or a relative `{{x1, y1}, {x2, y2}}`) keeps them inside,
  parents render before their children, hidden parents hide their subtree and deleting a parent
  deletes its children. `type: :group` nodes get a see-through default style. New
  `State.absolute_position/2`, `absolute_nodes/1`, `children/2`, `descendant_ids/2`, `depth/2` and
  `set_parent/4` (re-parents keeping the absolute position).
- **Graph helpers** (xyflow utils): `State.incomers/2`, `outgoers/2`, `connected_edges/2`,
  `node_rect/2` and `intersecting_nodes/3`.
- **JS API**: `element.liveflow` on the flow container (React Flow's `useReactFlow()`):
  `screenToFlowPosition`, `flowToScreenPosition`, `getViewport`, `setViewport`, `fitView`,
  `zoomIn/zoomOut/zoomTo`, `getNodes`, `getNode`, `getIntersectingNodes`, `getSelection`,
  `setSelection`. The container dispatches `lf:ready` when mounted.
- **Drag & drop from outside**: dropping an element with `application/liveflow` drag data pushes
  `lf:drop` with the data and the flow position (snapped to the grid when enabled).
- **Opt-in events**: `context_menu` (`lf:node_context_menu`, `lf:edge_context_menu`,
  `lf:pane_context_menu`), `pane_click_events` (`lf:pane_click`, not fired after a connection ends
  on the pane) and `connection_events` (`lf:connect_start`).
- `lf:connect_cancel` now carries the source node/handle, the release position in flow
  coordinates and a `reason` (`"pane"`, `"invalid"`, `"abort"`) — e.g. to add a node where a
  connection is dropped.
- **`connect_on_click`** (default `true`): click a handle, then another one, to connect (touch).
- **`multi_connection`**: dragging from a selected node connects every selected node.
- **`connection_line_style` / `connection_line_class`** to customize the connection line.
- **`LiveFlow.Components.NodeToolbar`** (React Flow's `<NodeToolbar />`).
- **Server-side layouts** in `LiveFlow.Layout`: `tree/2` (layered, top-bottom or left-right),
  `force/2` (force-directed), `resolve_collisions/2` and `apply_positions/2`.
- **`LiveFlow.animate_positions/5`** animates nodes (and their edges/children) to new positions
  on the client, which then pushes the final positions back.
- Client-side ELK layout uses node handles as ports (fewer edge crossings).
- **`LiveFlow.Export.to_svg/2`**: SVG of a flow rendered in pure Elixir (no browser).
- `LiveFlow.Paths.Geometry`: public edge geometry (handle points, floating points, edge paths).
- Custom edge renderers also receive `source_position`, `target_position`, `path_type` and
  `path_options_json`.
- **Handle `offset`**: `Handle.source(:right, offset: 0.25)` places a handle along its side and
  edges attach exactly there (server, client and export) — several handles per side.
- `LiveFlow.animate_positions/5` accepts `fit_view: true` (fits the view to the final positions).
- Every viewport, layout and export event pushed to the client (`lf:fit_view`, `lf:zoom_to`,
  `lf:zoom_in`, `lf:zoom_out`, `lf:pan_to`, `lf:set_viewport`, `lf:layout_data`,
  `lf:tree_layout_data`, `lf:animate_positions`, `lf:export_svg`, `lf:export_png`) accepts a
  `flow_id`, so only that flow reacts when several share a LiveView; `lf:layout_data` accepts any
  ELK option (`"options"`) and `prepare_tree_layout_data/2` a `"flow_id"`.
- Export events take options: `JS.dispatch("lf:export-png", to: "#flow", detail: %{filename:, scale:, padding:})`.
- `Validation.max_connections/3` accepts `side: :source | :target | :both`.
- The Flow component accepts a `class` attribute.
- Reconnect handles of `reconnectable` edges are always grabbable (shown on hover/selection), and
  `lf:delete_reconnect_edge` carries the `end` and the drop `position`.
- Library CSS rules live in `@layer components` so app styles and Tailwind utilities override
  them without `!important` (theme variables stay in `@layer base`).
- `LiveFlow.Export.to_svg/2` draws markers in each edge's color and honors `stroke-width`.
- `minimap_node_color` (a color or `fn node -> color end`, React Flow's `nodeColor`); minimap
  nodes carry `data-node-id` / `data-node-type`.
- A drag cancelled with Escape ends with position changes flagged `"aborted" => true`, so apps
  can tell it apart from a drop.
- `registerEdgePath(type, fn)` (JS) lets the client redraw custom edge shapes while nodes are
  dragged; while dragging, only the built-in overlays (label, toolbar, buttons, or elements with
  `data-lf-label-anchor`) are moved to the label point.
- **`:panel` slot** on the Flow component (React Flow's `<Panel />`): `<:panel position={:top_right}>`
  with `top_left`, `top_center`, `top_right`, `center_left`, `center_right`, `bottom_left`,
  `bottom_center`, `bottom_right`; panels don't pan/zoom and are left out of exports.
- **Paste at the cursor**: `lf:paste` carries the pointer position (flow coordinates) when the
  pointer is over the flow, and `Clipboard.paste/3` accepts `position:`.
- `Collaboration.apply_remote_change/2` handles `{:node_add, node}`, `{:node_update, id, attrs}`,
  `{:node_remove, id}`, `{:edge_update, id, attrs}` and `{:edge_reconnect, params}`; node changes
  go through `NodeChange` (resize, add, replace) and remote selection changes are ignored.
- `lf:connect_cancel` includes `target_node_id` / `target_handle_id` when an invalid connection is
  dropped on a handle.
- `helper_lines` and `cursors` can be toggled at runtime.
- `element.liveflow.getNodes()` also returns `type`, `selectable`, `draggable` and `deletable`.

### New Features (xyflow parity)

- **Auto-pan** while dragging nodes, connecting and drawing a selection box close to the edge of the
  viewport (`auto_pan_on_node_drag`, `auto_pan_on_connect`, `auto_pan_on_selection`, `auto_pan_speed`).
  The selection box is anchored in flow coordinates so it follows the viewport (xyflow 12.11.0).
- **Panning**: middle mouse button panning from anywhere, including over nodes and selection boxes;
  `pan_activation_key` (`"Space"` by default, `"Control"` supported); `pan_on_drag` accepts a list of
  mouse buttons; `pan_on_scroll` (+ `pan_on_scroll_mode`, `pan_on_scroll_speed`); `zoom_on_pinch`
  (trackpad) and `zoom_on_double_click`.
- **Selection**: `selection_on_drag`, `selection_mode` (`:partial` / `:full`), configurable
  `selection_key` and `multi_selection_key`. Touch prefers panning over drag selection.
- **Keyboard**: `delete_key_code` is now honored and, like every key option, accepts combinations of
  any length (`"Meta+Shift+Backspace"`). Selected nodes move with the arrow keys (Shift = 4x,
  `disable_keyboard_a11y` to opt out). Escape cancels drags, resizes, connections and selections.
- **Node extent**: `node_extent` constrains both dragging and resizing.
- **Resizing**: a `resize` change with `resizing: true` is sent when a resize starts and it is always
  followed by a final `resizing: false` change, also when the resize is cancelled (xyflow 12.12.0).
  `NodeResizer` gains `max_width`, `max_height` and `keep_aspect_ratio`; sizes snap to the grid.
- **Smoothstep/step edges** are a port of xyflow's current `getSmoothStepPath`, including the new
  `step_position` option, `center_x`/`center_y` and the rounded-bend fix (xyflow 12.10.2). The Elixir
  and JavaScript implementations produce identical paths.
- **Connections**: `connection_line_type`, `connection_radius` (snap to the closest handle) and a
  working `connection_mode` (`:strict` by default, `:loose` allows source-to-source).
- **Custom edge IDs**: `Validation.Connection.validate_and_create/3` accepts `:edge_id`, and the new
  `State.reconnect_edge/3` handles `lf:reconnect_edge` (with `:replace_id` / `:edge_id`).
- **Bounds**: `State.bounds/2` accepts `nodes:` (unknown IDs are ignored instead of stretching the
  bounds to the origin) and `include_hidden:`. Fit view is computed on the server, so it also covers
  nodes culled by virtualization; `send_update(Flow, fit_view: %{nodes: [...], padding: ...})`.
- **Background**: SVG pattern with xyflow's (fixed) offset math, kept in sync during client-side
  pan/zoom. New `background_gap`, `background_size`, `background_offset`, `background_line_width`;
  `:cross` is now an actual cross pattern.
- **Minimap**: real container size for the viewport rectangle, hidden nodes ignored (shows the viewport
  when every node is hidden), `minimap_pannable`, `minimap_zoomable`.
- `Viewport.screen_to_flow/4` accepts `snap_to_grid:` / `snap_grid:`; new `Viewport.snap/2`.
- `LiveFlow.Node.new/4` accepts `:width`, `:height`, `:hidden` and `:drag_handle` (CSS selector the node can be
  dragged from). The serializer round-trips `hidden`, `resizable`, `drag_handle` and resizable sizes.
- `node_drag_threshold`, `z_index_mode`, `elevate_nodes_on_select`, `elevate_edges_on_select`.
- New JS exports: `getEdgePath`, `getSmoothStepPath`, `getStepPath`, `getBezierPath`,
  `getStraightPath`, `EdgeUpdater`, `calcAutoPan`, `parseKeys`, `matchesKeys`, `exportSVG`,
  `exportPNG`, `buildExportSvg`.

### Node Resizing

- **Node Resizing.** New `LiveFlow.Components.NodeResizer` component adds interactive resize handles to custom nodes. Users can drag corner and edge handles to resize nodes, with real-time edge path updates during resize. Supports configurable minimum dimensions and 8 resize handle positions (N, S, E, W, NE, NW, SE, SW).
  - New `NodeResizer.node_resizer/1` function component — drop it inside any custom node template
  - New `resizable: true` option on `LiveFlow.Node.new/4` to mark nodes as resizable
  - New `resize` change type in `NodeChange` for server-side dimension updates
  - Client-side resize with zero-latency feedback (same pattern as node drag)
  - Touch/mobile support with larger resize handles on coarse pointer devices
  - CSS variables: `--lf-resizer-color`, `--lf-resizer-size` for customization

### Server-Side Viewport Culling (Virtualization)

- **Server-Side Viewport Culling (Virtualization).** Pure Elixir server-side viewport culling dramatically reduces DOM size for large flows. Only nodes and edges visible in the current viewport are rendered, enabling smooth interaction with 10,000+ node flows.
  - New `LiveFlow.Viewport.Culling` module — pure Elixir culling logic with zero JS dependencies
  - Opt-in via `virtualization: true` in flow opts
  - 200px flow-space margin pre-renders nodes just outside the viewport for smooth panning
  - Unmeasured nodes use estimated size (200x100) for visibility — render near viewport, get measured by JS
  - Edge culling: edges with at least one visible endpoint are kept
  - `max_visible` cap (default 500) prevents browser crash on extreme zoom-out (e.g., fit-view with 10K nodes)
  - Nodes closest to viewport center are prioritized when cap is exceeded
  - Minimap always renders all nodes regardless of culling
  - Container dimensions sent from JS via `lf:container_resize` event (only change: ~15 lines of JS)

Performance:

| Node Count | DOM Without Culling | DOM With Culling | Reduction |
|-----------|--------------------|-----------------|-----------|
| 500 | 500 | ~108 | 78% |
| 1,000 | 1,000 | ~108 | 89% |
| 10,000 | 10,000 (crash) | ~180 | 98% |

### Documentation

- New guides: Edges, Interaction, Events & JavaScript API, Sub-flows & Grouping, Layout, Built-in
  Components and Saving, Import & Export. Getting Started, Custom Nodes, Collaboration and Themes
  were updated (the Themes guide listed CSS variables that don't exist; the README Quick Start
  called functions that don't exist).

### Bug Fixes

- Duplicate edges were not detected when the existing edge had no handle ids (`nil`) and the
  client sent its default ids (`"source"`/`"target"`): `State.edge_exists?/5`,
  `Validation.no_duplicate_edges/2` and `max_connections/3` now compare effective handle ids.
- A node removed and added back with the same size never reported its dimensions again.
- The vendored ELK bundle triggered esbuild's `equals-negative-zero` warning on every build of
  apps using LiveFlow (`b==-0.?0:b` replaced by the equivalent `b===0?0:b`).
- **SVG/PNG export now matches the screen.** Nodes and edge labels are cloned with their computed
  styles inlined, so Tailwind classes, theme variables, icons (CSS masks) and markers render as in the
  browser. The PNG rasterizes the same SVG instead of a text-only approximation (the previous pure-SVG
  rendering remains as a fallback if the browser taints the canvas). Animated edges, which disappeared
  because their theme variable wasn't exported, are drawn. Editor chrome (delete buttons, resizers, edge
  toolbars) is left out; add `data-lf-export-ignore` to exclude other elements. The export includes the
  background pattern and the full edge extent. Web fonts and external images are not embedded.
- Default edge markers used the page text color (`currentColor` inside `<defs>`); they now follow the
  edge stroke like xyflow.
- Options and per-node flags set to `false` (`pan_on_drag`, `nodes_draggable`, node `draggable`,
  handle `connectable`, ...) had no effect: HEEx drops `false` attributes. The configuration is now
  sent as JSON (`data-config`).
- Custom nodes rendered by function components, custom edge labels and edge toolbars never re-rendered
  after the first render (`__changed__: %{}`).
- Step, smoothstep, straight and floating edges were redrawn as bezier curves while dragging,
  resizing or receiving remote drags; icons inside edge buttons were overwritten with the edge path.
- The selection box was never drawn (its events went to the parent LiveView).
- Edges pointing to a missing node crashed the Flow component; edges to hidden nodes are skipped.
- `fitView` counted handles and buttons as nodes at the origin.
- Typing Backspace/Ctrl+A/Ctrl+Z in an input inside a node triggered flow shortcuts; with several
  flows on a page, all of them reacted to the same keys.
- Touch: connections never completed, inputs inside nodes couldn't be focused, no `touchcancel`.
- Every click on a node sent position changes; `lf:node_click` fired after drags and connections.
- Releasing outside the canvas or pressing Escape while reconnecting deleted the edge.
- The local selection went stale after deletes, undo or paste.
- Zoom buttons used the (possibly stale) server zoom; viewport animations could overlap.
- Resize could leave node measuring disabled after a click on a resize handle.
- `destroyed()` leaked touch listeners, timers and the global export handle.
- Node stacking ignored the render order: a selected or recently dragged node could stay below
  the others. The CSS `z-index` now follows the sort order (parents below children, `z_index`,
  `elevate_nodes_on_select`).
- `State.delete_selected/1` (Backspace/Delete) removed nodes and edges marked `deletable: false`.

### Changes

- **ELK is no longer bundled.** elkjs added about 1.6 MB (minified) to every app's `app.js`, even
  without auto layout. Apps that use `lf:layout_data` / `lf:auto-layout` run
  `mix live_flow.gen.elk`, which vendors elkjs in `assets/vendor/` and registers it with the new
  `registerElk(ELK)` export (an elkjs instance, e.g. a web-worker one, works too). Without it the
  hook logs how to install it. The Elixir layouts (`Layout.tree/2`, `force/2`) don't need ELK.

- The hook reads its configuration from `data-config`; the old `data-*` attributes on `.lf-container`
  are gone. The container is focusable (`tabindex="0"`).
- Client-only UI (selection box, connection preview, shortcuts panel) lives in a
  `phx-update="ignore"` interaction layer. The unreachable `lf:connect_*` / `lf:selection_box_*`
  handlers were removed from the Flow component.
- `connection_mode` defaults to `:strict` (what the client already enforced).
- `lf:container_resize` is always sent to the Flow component (used by the minimap).
- Hot paths (wheel, drag, pinch) use a cached container rect instead of forcing layout.
- Background CSS classes changed from `.lf-background-{dots,lines,cross}` to
  `.lf-background-pattern.{dots,lines,cross}`.

## v0.2.3 (2026-02-20)

### Improvements

- **Clean JavaScript imports.** `package.json` now points directly to source files instead of requiring a build step. Phoenix 1.8+ apps with `NODE_PATH` configured can import with clean paths:
  ```javascript
  import { LiveFlowHook, FileImportHook, setupDownloadHandler } from "live_flow"
  ```
- **Export `FileImportHook` and `setupDownloadHandler` from main entry.** No longer need a separate import from `hooks/utility_hooks.js`.

## v0.2.2 (2026-02-20)

### Performance — Realtime Collaboration

- **`broadcast_from` instead of `broadcast`.** PubSub messages now skip the sender process entirely, eliminating self-filtering overhead and reducing message processing by ~N per broadcast (where N = number of connected users).
- **Live drag broadcasting.** Intermediate node positions are broadcast to remote users every 100ms during drag (via `lf:drag_move`), so other users see live movement instead of position jumps at drag end. Uses a lightweight DOM-only update path — no flow state change or LiveView re-render on receivers.
- **Smooth cursor interpolation.** Remote cursors now use lerp (linear interpolation) animation at 60fps instead of jumping between positions, providing fluid cursor movement.
- **Reduced cursor throttle.** Local cursor broadcast interval reduced from 100ms to 50ms for more responsive cursor tracking.
- **Server-side cursor throttle.** Added Process dictionary-based throttle in the example LiveView to prevent PubSub flooding with many concurrent users.
- **Client-side remote edge updates.** When receiving remote drag positions, edge SVG paths are recalculated client-side to stay visually connected to moving nodes.

## v0.2.1 (2026-02-20)

### Bug Fixes

- **Fix auto-layout node overlaps.** ELK and tree layout now measure actual DOM node dimensions (`offsetWidth`/`offsetHeight`) before computing positions, instead of relying on server-side dimensions that may still be at default fallback values (150x50). This prevents nodes from overlapping when their rendered size exceeds the defaults.

## v0.2.0 (2026-02-20)

### Performance

- **Fully client-side drag with instant edge updates.** Node positions AND edge SVG paths are now recalculated client-side during drag, eliminating all latency. Only the final position is sent to the server when the drag ends. After each LiveView DOM patch, client-side positions and viewport transforms are re-applied so nothing "jumps back" to stale server state. No changes required in your LiveView event handlers.
- **Viewport stability.** The client-side viewport transform is re-applied after every server DOM patch, preventing zoom/pan jumps when clicking nodes or during selection changes.

### Internal

- Edge `<g>` elements now include `data-source`, `data-target`, `data-source-handle`, and `data-target-handle` attributes for client-side path recalculation during drag.

## v0.1.0 (2025-xx-xx)

### Initial Release

- Flow diagram LiveComponent with pan, zoom, and viewport controls
- Node system: drag, select, resize, custom node types (function components + LiveComponents)
- Edge system: bezier, straight, step, smoothstep paths with animated edges and labels
- Handle system: source/target handles with connection validation
- Selection: click, shift-click, selection box (lasso)
- Undo/Redo history with configurable max entries
- Copy/Paste/Cut/Duplicate clipboard
- JSON serialization/deserialization
- Real-time collaboration via PubSub with cursor sharing
- Connection validation: composable validators (no_duplicate_edges, nodes_exist, no_cycles, types_compatible, max_connections)
- ELK auto-layout and tree layout algorithms
- Helper lines (alignment guides) during drag
- 36 built-in themes (12 hand-crafted + 24 auto-generated from daisyUI palettes)
- Tailwind v4 theme plugin
- SVG/PNG export
- Touch/mobile optimization (pinch-to-zoom, long-press selection)
- Keyboard shortcuts panel
- Edge label inline editing
