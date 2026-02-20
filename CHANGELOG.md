# Changelog

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
