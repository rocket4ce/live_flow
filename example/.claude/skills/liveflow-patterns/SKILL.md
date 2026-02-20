---
name: liveflow-patterns
description: Patrones de arquitectura y mejores prácticas para LiveFlow. Usar cuando se implementan nuevas funcionalidades o se diseña la estructura del flow.
---

# LiveFlow Architecture Patterns

## Data Flow Architecture

```
User Action → JS Hook (optimistic UI) → pushEventTo → LiveComponent handle_event
    → State update → DOM patch → Hook.updated() → Re-measure
```

## Core Data Structures

### Node
```elixir
%LiveFlow.Node{
  id: "node-1",
  position: %{x: 100, y: 100},
  data: %{label: "My Node"},
  handles: [Handle.source(:right), Handle.target(:left)],
  width: nil,      # nil until measured
  height: nil,
  selected: false,
  dragging: false,
  measured: false
}
```

### Edge
```elixir
%LiveFlow.Edge{
  id: "edge-1",
  source: "node-1",
  target: "node-2",
  source_handle: "source",
  target_handle: "target",
  type: :bezier,   # :bezier | :straight | :step | :smoothstep
  animated: false,
  selected: false
}
```

### Handle
```elixir
%LiveFlow.Handle{
  id: "source",              # nil for auto-generated
  type: :source,             # :source | :target
  position: :right,          # :top | :bottom | :left | :right
  connectable: true
}
```

## Coordinate Transformation

```javascript
// Screen coordinates → Flow coordinates
screenToFlow(screenX, screenY) {
  return [
    (screenX - this.viewport.x) / this.viewport.zoom,
    (screenY - this.viewport.y) / this.viewport.zoom
  ];
}

// Flow coordinates → Screen coordinates
flowToScreen(flowX, flowY) {
  return [
    flowX * this.viewport.zoom + this.viewport.x,
    flowY * this.viewport.zoom + this.viewport.y
  ];
}
```

## Avoiding Re-render Loops

Durante drag, JS actualiza DOM directamente. Solo la posición final sincroniza con el servidor:

1. **Drag start**: `pushEventTo("lf:node_change", [{type: "position", dragging: true}])`
2. **Drag move**: JS actualiza `style.left/top` directamente (sin llamada al servidor)
3. **Drag end**: `pushEventTo("lf:node_change", [{type: "position", dragging: false}])`

## SVG Path Calculation

### Bezier Path
```elixir
def bezier_path(sx, sy, tx, ty, source_pos, target_pos) do
  dx = abs(tx - sx)
  curvature = 0.25

  {c1x, c1y} = control_point(sx, sy, source_pos, dx * curvature)
  {c2x, c2y} = control_point(tx, ty, target_pos, dx * curvature)

  "M #{sx},#{sy} C #{c1x},#{c1y} #{c2x},#{c2y} #{tx},#{ty}"
end
```

### Handle Position Calculation
```elixir
def calculate_handle_coords(node, handle_position) do
  case handle_position do
    :top    -> %{x: node.x + node.width/2, y: node.y}
    :bottom -> %{x: node.x + node.width/2, y: node.y + node.height}
    :left   -> %{x: node.x, y: node.y + node.height/2}
    :right  -> %{x: node.x + node.width, y: node.y + node.height/2}
  end
end
```

## Event Flow for Connections

```
1. User mousedown on handle
   → JS: connection.startConnection()
   → pushEventTo('lf:connect_start', {...})
   → Elixir: assign(socket, connecting: %{...})
   → Render: <Edge.connection_line ... />

2. User mousemove
   → JS: connection.moveConnection()
   → pushEventTo('lf:connect_move', {to_x, to_y})
   → Elixir: update connecting coordinates
   → Render: connection line updates

3. User mouseup on valid target
   → JS: connection.endConnection()
   → pushEventTo('lf:connect_end', {source, target, ...})
   → Elixir: State.add_edge() + assign(connecting: nil)
   → Render: new edge appears
```

## File Organization

```
lib/live_flow/
├── core/           # Structs: Node, Edge, Handle, Viewport
├── paths/          # Path calculations: Bezier, Straight, Step, Smoothstep
├── changes/        # Change application: NodeChange, EdgeChange
├── components/     # LiveComponents: Flow, NodeWrapper, Edge, Handle
└── state.ex        # State management with CRUD operations

assets/js/live_flow/
├── hooks/          # Phoenix hooks
├── interaction/    # Pan/zoom, drag, connection, selection managers
└── utils/          # Coordinate utilities
```
