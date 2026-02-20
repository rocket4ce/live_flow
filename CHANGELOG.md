# Changelog

## v0.2.0 (2026-02-20)

### Breaking Changes

- **Node drag no longer sends intermediate positions to the server.** Previously, `lf:node_change` events with `dragging: true` were pushed every ~50ms during drag. This caused visible jitter on high-latency connections because the server re-render would overwrite client-side CSS positions. Now, only the final position is sent via `lf:node_change` when the drag ends.

- **New `lf:drag_start` event.** A lightweight `lf:drag_start` event (with `node_ids` payload) is pushed at the beginning of a drag to allow the parent LiveView to snapshot history before positions change. If you use `maybe_push_history_for_drag/3` in your `lf:node_change` handler, replace it with a `lf:drag_start` handler:

  ```elixir
  # Before (remove this from lf:node_change):
  # history = Enum.reduce(changes, socket.assigns.history, fn change, acc ->
  #   maybe_push_history_for_drag(acc, socket.assigns.flow, change)
  # end)

  # After (add new handler):
  def handle_event("lf:drag_start", %{"node_ids" => _node_ids}, socket) do
    history = History.push(socket.assigns.history, socket.assigns.flow)
    {:noreply, assign(socket, history: history)}
  end
  ```

### Performance

- Drag is now fully client-side with zero server round-trips during movement, eliminating jitter on production deployments with network latency

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
