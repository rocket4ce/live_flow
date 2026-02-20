---
name: xyflow-drag
description: Sistema de Drag de xyflow. Usar para implementar arrastre de nodos, seleccion multiple, snap-to-grid, y auto-pan.
---

# XYFlow Drag System

El modulo `xydrag` de `@xyflow/system` maneja el arrastre de nodos usando D3-drag.

## Arquitectura

```
Mouse/Touch Event
       |
       v
XYDrag (d3-drag wrapper)
       |
       +-> startDrag() -> Inicializa estado
       |       |
       |       +-> getDragItems() -> Recopila nodos a arrastrar
       |
       +-> updateNodes() -> Calcula nuevas posiciones
       |       |
       |       +-> Snap-to-grid (opcional)
       |       +-> Extent constraints
       |       +-> onNodeDrag callback
       |
       +-> autoPan() -> Desplaza viewport en bordes
       |
       +-> endDrag() -> Finaliza y dispara callbacks
```

## Tipos Principales

```typescript
// Item siendo arrastrado
type NodeDragItem = {
  id: string;
  position: XYPosition;           // Posicion actual
  distance: XYPosition;           // Distancia desde click inicial
  measured: { width: number; height: number };
  extent?: CoordinateExtent;
  parentId?: string;
}

// Parametros de configuracion
type DragUpdateParams = {
  noDragClassName?: string;       // Clase CSS que ignora drag
  handleSelector?: string;        // Selector del handle de drag
  domNode: HTMLElement;
  nodeId: string;
  isSelectable?: boolean;
  nodeDragThreshold?: number;     // Pixeles minimos para iniciar drag

  // Callbacks
  onNodeDrag?: OnDrag;
  onNodeDragStart?: OnDrag;
  onNodeDragStop?: OnDrag;
  onSelectionDrag?: OnDrag;
  onSelectionDragStart?: OnDrag;
  onSelectionDragStop?: OnDrag;
}
```

## Ciclo de Vida del Drag

### 1. Inicio (startDrag)
```javascript
// Se ejecuta en mousedown/touchstart
startDrag(event, nodeId) {
  // 1. Determinar que nodos se arrastran
  const dragItems = getDragItems(nodeId, selectedNodes);

  // 2. Calcular distancia inicial desde cada nodo
  dragItems.forEach(item => {
    item.distance = {
      x: event.x - item.position.x,
      y: event.y - item.position.y
    };
  });

  // 3. Obtener limites del contenedor para auto-pan
  containerBounds = container.getBoundingClientRect();

  // 4. Disparar callbacks
  onNodeDragStart?.(event, dragItems, nodes);
}
```

### 2. Movimiento (updateNodes)
```javascript
updateNodes(event) {
  dragItems.forEach(item => {
    // Calcular nueva posicion
    let newPosition = {
      x: event.x - item.distance.x,
      y: event.y - item.distance.y
    };

    // Aplicar snap-to-grid
    if (snapToGrid) {
      newPosition = {
        x: Math.round(newPosition.x / snapGrid[0]) * snapGrid[0],
        y: Math.round(newPosition.y / snapGrid[1]) * snapGrid[1]
      };
    }

    // Aplicar extent constraints
    if (item.extent) {
      newPosition = clampPosition(newPosition, item.extent);
    }

    item.position = newPosition;
  });

  onNodeDrag?.(event, dragItems, nodes);
}
```

### 3. Auto-Pan
```javascript
autoPan() {
  // Calcular si el cursor esta cerca del borde
  const [moveX, moveY] = calcAutoPan({
    pos: lastPos,
    bounds: containerBounds,
    speed: 15,
    distance: 40
  });

  if (moveX !== 0 || moveY !== 0) {
    // Mover viewport
    panBy({ x: moveX, y: moveY });

    // Actualizar posiciones de nodos
    dragItems.forEach(item => {
      item.position.x += moveX / zoom;
      item.position.y += moveY / zoom;
    });

    // Continuar auto-pan
    requestAnimationFrame(autoPan);
  }
}
```

### 4. Fin (endDrag)
```javascript
endDrag(event) {
  // Disparar callbacks finales
  onNodeDragStop?.(event, dragItems, nodes);

  // Limpiar estado
  dragItems = [];
  autoPanning = false;
}
```

## Optimizacion: Drag Optimistico

Durante el drag, el DOM se actualiza directamente sin pasar por el servidor:

```javascript
// xyflow actualiza el estilo directamente
node.style.transform = `translate(${x}px, ${y}px)`;

// Solo al finalizar se sincroniza con el servidor
onNodeDragStop: (event, items) => {
  const changes = items.map(item => ({
    id: item.id,
    type: 'position',
    position: item.position,
    dragging: false
  }));
  pushEventTo(el, 'lf:node_change', { changes });
}
```

## Configuracion D3-Drag

```javascript
import { drag } from 'd3-drag';
import { select } from 'd3-selection';

const d3Drag = drag()
  .on('start', (event) => startDrag(event))
  .on('drag', (event) => updateNodes(event))
  .on('end', (event) => endDrag(event))
  .filter((event) => {
    // No iniciar drag si:
    // - Tiene clase noDrag
    // - Es click derecho
    // - Es multi-touch
    return !event.target.closest('.nodrag')
           && event.button === 0
           && !event.touches?.length > 1;
  });

select(nodeElement).call(d3Drag);
```

## Seleccion Multiple

Cuando se arrastra un nodo seleccionado, todos los nodos seleccionados se mueven:

```javascript
function getDragItems(nodeId, selectedNodes) {
  const node = nodes.find(n => n.id === nodeId);

  // Si el nodo esta seleccionado, arrastrar todos los seleccionados
  if (node.selected && selectedNodes.length > 1) {
    return selectedNodes.map(n => ({
      id: n.id,
      position: { ...n.position },
      measured: { width: n.width, height: n.height }
    }));
  }

  // Si no, solo arrastrar el nodo clickeado
  return [{
    id: node.id,
    position: { ...node.position },
    measured: { width: node.width, height: node.height }
  }];
}
```

## Snap to Grid

```javascript
// Configuracion
const snapGrid = [15, 15];  // [x, y] en pixeles

// Aplicacion
function snapPosition(position, grid) {
  return {
    x: Math.round(position.x / grid[0]) * grid[0],
    y: Math.round(position.y / grid[1]) * grid[1]
  };
}
```

## Extent (Limites de Movimiento)

```typescript
type CoordinateExtent = [[number, number], [number, number]];
// [[minX, minY], [maxX, maxY]]

// Ejemplo: limitar nodo a area 500x500
const nodeExtent: CoordinateExtent = [[0, 0], [500, 500]];

// Ejemplo: limitar al viewport actual
const viewportExtent: CoordinateExtent = [
  [-viewport.x / viewport.zoom, -viewport.y / viewport.zoom],
  [
    (containerWidth - viewport.x) / viewport.zoom,
    (containerHeight - viewport.y) / viewport.zoom
  ]
];
```

## Implementacion en LiveFlow

### Elixir - Handle de cambios
```elixir
def handle_event("lf:node_change", %{"changes" => changes}, socket) do
  nodes = Enum.reduce(changes, socket.assigns.nodes, fn change, nodes ->
    case change["type"] do
      "position" ->
        update_node_position(nodes, change["id"], change["position"])
      "dimensions" ->
        update_node_dimensions(nodes, change["id"], change["width"], change["height"])
      _ ->
        nodes
    end
  end)

  {:noreply, assign(socket, nodes: nodes)}
end
```

### JavaScript Hook
```javascript
const FlowHook = {
  mounted() {
    this.initDrag();
  },

  initDrag() {
    this.nodeElements = this.el.querySelectorAll('[data-node-id]');

    this.nodeElements.forEach(el => {
      const nodeId = el.dataset.nodeId;

      this.drag = XYDrag();
      this.drag.update({
        domNode: el,
        nodeId,
        nodeDragThreshold: 1,
        onNodeDragStart: (_, items) => {
          this.pushEventTo(this.el, 'lf:node_change', {
            changes: items.map(i => ({ id: i.id, type: 'position', dragging: true }))
          });
        },
        onNodeDragStop: (_, items) => {
          this.pushEventTo(this.el, 'lf:node_change', {
            changes: items.map(i => ({
              id: i.id,
              type: 'position',
              position: i.position,
              dragging: false
            }))
          });
        }
      });
    });
  }
}
```

## Filtrado por Selectores

```javascript
// Solo permitir drag desde el header
handleSelector: '.node-header'

// Excluir elementos con clase nodrag
noDragClassName: 'nodrag'

// Uso en template
<div class="node">
  <div class="node-header">Arrastra aqui</div>
  <input class="nodrag" />  <!-- Este input no inicia drag -->
</div>
```

## Threshold de Drag

Evita drags accidentales requiriendo movimiento minimo:

```javascript
nodeDragThreshold: 5  // Requiere mover 5px antes de iniciar drag

// Implementacion interna
if (Math.abs(event.x - startX) > threshold ||
    Math.abs(event.y - startY) > threshold) {
  startDrag();
}
```
