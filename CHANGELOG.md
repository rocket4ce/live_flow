# Changelog

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
