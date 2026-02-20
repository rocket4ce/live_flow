---
name: xyflow-edges
description: Sistema de Edges y Paths SVG de xyflow. Usar para implementar diferentes tipos de conectores entre nodos, calcular paths bezier/step/smoothstep, y markers.
---

# XYFlow Edges & Path System

El sistema de edges en `@xyflow/system` maneja el calculo y renderizado de las conexiones visuales entre nodos.

## Arquitectura

```
Edge Data
    |
    v
Calculate Handle Positions
    |
    v
Path Algorithm (bezier/step/smoothstep/straight)
    |
    v
SVG Path String + Label Position
    |
    v
Render <path d="..." /> + Markers
```

## Tipos de Edge

```typescript
// Enumeracion de tipos de linea de conexion
enum ConnectionLineType {
  Bezier = 'default',      // Curva bezier cubica
  Straight = 'straight',   // Linea recta
  Step = 'step',           // Angulos de 90 grados
  SmoothStep = 'smoothstep', // Step con esquinas redondeadas
  SimpleBezier = 'simplebezier'  // Bezier simplificado
}
```

## Estructura de Edge

```typescript
type EdgeBase = {
  id: string;                    // Identificador unico
  source: string;                // ID del nodo origen
  target: string;                // ID del nodo destino
  sourceHandle?: string | null;  // ID del handle origen
  targetHandle?: string | null;  // ID del handle destino
  type?: string;                 // Tipo de edge (bezier, step, etc.)
  animated?: boolean;            // Animacion de flujo
  hidden?: boolean;              // Oculto
  deletable?: boolean;           // Puede ser eliminado
  selectable?: boolean;          // Puede ser seleccionado
  selected?: boolean;            // Estado de seleccion
  data?: Record<string, unknown>;
  markerStart?: EdgeMarkerType;
  markerEnd?: EdgeMarkerType;
  zIndex?: number;
  interactionWidth?: number;     // Ancho del area clickeable
}
```

## Calculo de Paths

### Parametros Comunes

```typescript
type EdgePosition = {
  sourceX: number;         // X del handle origen
  sourceY: number;         // Y del handle origen
  targetX: number;         // X del handle destino
  targetY: number;         // Y del handle destino
  sourcePosition: Position; // top | right | bottom | left
  targetPosition: Position;
}
```

### Bezier Path

Curva cubica de Bezier - la mas elegante para flujos.

```typescript
type GetBezierPathParams = {
  sourceX: number;
  sourceY: number;
  sourcePosition?: Position;  // default: Position.Bottom
  targetX: number;
  targetY: number;
  targetPosition?: Position;  // default: Position.Top
  curvature?: number;         // default: 0.25
}

// Retorna: [path, labelX, labelY, offsetX, offsetY]
function getBezierPath(params): [string, number, number, number, number];
```

**Algoritmo de Bezier:**
```javascript
// 1. Calcular puntos de control
function getControlWithCurvature({ pos, x, y, c }) {
  switch (pos) {
    case Position.Left:  return [x - distance * c, y];
    case Position.Right: return [x + distance * c, y];
    case Position.Top:   return [x, y - distance * c];
    case Position.Bottom: return [x, y + distance * c];
  }
}

// 2. Calcular offset del punto de control
function calculateControlOffset(distance, curvature) {
  if (distance >= 0) return 0.5 * distance;
  return curvature * 25 * Math.sqrt(-distance);
}

// 3. Generar path SVG
// M = MoveTo, C = Cubic Bezier
`M${sx},${sy} C${c1x},${c1y} ${c2x},${c2y} ${tx},${ty}`
```

**Centro del Bezier (para posicion de label):**
```javascript
// Ponderacion para t=0.5 en curva cubica
const centerX = sourceX * 0.125 + sourceControlX * 0.375 +
                targetControlX * 0.375 + targetX * 0.125;
const centerY = sourceY * 0.125 + sourceControlY * 0.375 +
                targetControlY * 0.375 + targetY * 0.125;
```

### SmoothStep Path

Conexiones con angulos de 90 grados pero esquinas redondeadas.

```typescript
type SmoothStepPathOptions = {
  offset?: number;        // Separacion del handle (default: 20)
  borderRadius?: number;  // Radio de esquinas (default: 5)
  stepPosition?: number;  // Donde ocurre el doblez (0-1, default: 0.5)
}

function getSmoothStepPath(params): [string, number, number, number, number];
```

**Algoritmo SmoothStep:**
```javascript
// 1. Calcular puntos intermedios
function getPoints({ source, target, sourcePosition, targetPosition, stepPosition }) {
  // Dos casos: handles opuestos o similares
  if (isOpposite(sourcePosition, targetPosition)) {
    // Un solo punto de doblez
    centerX = source.x + (target.x - source.x) * stepPosition;
  } else {
    // Multiples puntos para evitar solapamiento
    // ...calculos complejos
  }
}

// 2. Generar curvas en esquinas
function getBend(a, b, c, borderRadius) {
  const bendSize = Math.min(
    distance(a, b) / 2,
    distance(b, c) / 2,
    borderRadius
  );
  // Retorna comando Q (Quadratic Bezier) para la esquina
  return `L${...} Q${...} ${...}`;
}
```

### Step Path (sin redondeo)

```typescript
type StepPathOptions = {
  offset?: number;  // default: 20
}

// Similar a SmoothStep pero sin el borderRadius
function getStepPath(params): [string, number, number, number, number];
```

### Straight Path

Linea recta simple entre dos puntos.

```typescript
function getStraightPath({ sourceX, sourceY, targetX, targetY }):
  [string, number, number, number, number] {

  const [labelX, labelY] = [
    (sourceX + targetX) / 2,
    (sourceY + targetY) / 2
  ];

  return [
    `M${sourceX},${sourceY} L${targetX},${targetY}`,
    labelX, labelY, 0, 0
  ];
}
```

## Sistema de Markers

Los markers son flechas u otros simbolos en los extremos de las edges.

```typescript
enum MarkerType {
  Arrow = 'arrow',          // Flecha abierta >
  ArrowClosed = 'arrowclosed'  // Flecha cerrada |>
}

type EdgeMarker = {
  type: MarkerType;
  color?: string | null;
  width?: number;
  height?: number;
  markerUnits?: string;
  orient?: string;
  strokeWidth?: number;
}

type EdgeMarkerType = string | EdgeMarker;
```

**SVG Marker Definition:**
```html
<defs>
  <marker
    id="arrow-1"
    markerWidth="12.5"
    markerHeight="12.5"
    viewBox="-10 -10 20 20"
    orient="auto-start-reverse"
    refX="0"
    refY="0"
  >
    <polyline
      points="-5,-4 0,0 -5,4"
      style="stroke: #b1b1b7; stroke-width: 1; fill: none;"
    />
  </marker>
</defs>

<path d="M..." marker-end="url(#arrow-1)" />
```

## Implementacion en LiveFlow (Elixir)

### Modulo de Path Bezier
```elixir
defmodule LiveFlow.Paths.Bezier do
  @default_curvature 0.25

  def get_path(params) do
    sx = params[:source_x]
    sy = params[:source_y]
    tx = params[:target_x]
    ty = params[:target_y]
    source_pos = params[:source_position] || :bottom
    target_pos = params[:target_position] || :top
    curvature = params[:curvature] || @default_curvature

    # Calcular puntos de control
    {c1x, c1y} = control_point(sx, sy, source_pos, curvature, tx - sx)
    {c2x, c2y} = control_point(tx, ty, target_pos, curvature, sx - tx)

    # Calcular centro para label
    {label_x, label_y} = bezier_center(sx, sy, c1x, c1y, c2x, c2y, tx, ty)

    path = "M #{sx},#{sy} C #{c1x},#{c1y} #{c2x},#{c2y} #{tx},#{ty}"

    {path, label_x, label_y}
  end

  defp control_point(x, y, position, curvature, distance) do
    offset = calculate_offset(distance, curvature)

    case position do
      :left   -> {x - offset, y}
      :right  -> {x + offset, y}
      :top    -> {x, y - offset}
      :bottom -> {x, y + offset}
    end
  end

  defp calculate_offset(distance, curvature) when distance >= 0 do
    0.5 * distance
  end

  defp calculate_offset(distance, curvature) do
    curvature * 25 * :math.sqrt(-distance)
  end

  defp bezier_center(sx, sy, c1x, c1y, c2x, c2y, tx, ty) do
    {
      sx * 0.125 + c1x * 0.375 + c2x * 0.375 + tx * 0.125,
      sy * 0.125 + c1y * 0.375 + c2y * 0.375 + ty * 0.125
    }
  end
end
```

### Componente Edge
```elixir
defmodule LiveFlow.Components.Edge do
  use Phoenix.Component

  def edge(assigns) do
    {path, label_x, label_y} = calculate_path(assigns)

    assigns = assign(assigns, path: path, label_x: label_x, label_y: label_y)

    ~H"""
    <g class={["react-flow__edge", @selected && "selected"]}>
      <%!-- Path invisible para area de click mas grande --%>
      <path
        class="react-flow__edge-interaction"
        d={@path}
        fill="none"
        stroke="transparent"
        stroke-width={@interaction_width || 20}
      />

      <%!-- Path visible --%>
      <path
        class="react-flow__edge-path"
        d={@path}
        fill="none"
        stroke={@stroke || "#b1b1b7"}
        stroke-width={@stroke_width || 1}
        marker-end={@marker_end}
      />

      <%!-- Label opcional --%>
      <%= if @label do %>
        <foreignObject
          x={@label_x - 50}
          y={@label_y - 10}
          width="100"
          height="20"
        >
          <div class="react-flow__edge-label">{@label}</div>
        </foreignObject>
      <% end %>
    </g>
    """
  end

  defp calculate_path(assigns) do
    case assigns[:type] || :bezier do
      :bezier -> LiveFlow.Paths.Bezier.get_path(assigns)
      :straight -> LiveFlow.Paths.Straight.get_path(assigns)
      :step -> LiveFlow.Paths.Step.get_path(assigns)
      :smoothstep -> LiveFlow.Paths.SmoothStep.get_path(assigns)
    end
  end
end
```

## Edge Animado

```css
.react-flow__edge.animated path {
  stroke-dasharray: 5;
  animation: dashdraw 0.5s linear infinite;
}

@keyframes dashdraw {
  from {
    stroke-dashoffset: 10;
  }
}
```

## Posicion de Handles por Direccion

```elixir
def get_handle_position(node, handle) do
  case handle.position do
    :top ->
      %{x: node.x + node.width / 2, y: node.y}
    :bottom ->
      %{x: node.x + node.width / 2, y: node.y + node.height}
    :left ->
      %{x: node.x, y: node.y + node.height / 2}
    :right ->
      %{x: node.x + node.width, y: node.y + node.height / 2}
  end
end
```

## Edge Lookup

```typescript
type EdgeLookup<EdgeType extends EdgeBase = EdgeBase> =
  Map<string, EdgeType>;

// Uso eficiente para busquedas
const edgeLookup = new Map(edges.map(e => [e.id, e]));
const edge = edgeLookup.get('edge-1');
```
