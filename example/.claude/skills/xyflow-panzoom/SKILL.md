---
name: xyflow-panzoom
description: Sistema de Pan y Zoom de xyflow. Usar para implementar navegacion del viewport, zoom con rueda/pinch, y transformaciones de coordenadas.
---

# XYFlow Pan & Zoom System

El modulo `xypanzoom` de `@xyflow/system` proporciona la funcionalidad core de navegacion del viewport.

## Arquitectura

```
User Interaction
     |
     v
XYPanZoom (d3-zoom wrapper)
     |
     +-> setTransform() -> Animacion de viewport
     +-> update() -> Configura event handlers
     +-> scaleTo()/scaleBy() -> Control de zoom
     +-> setViewport() -> Establece viewport con constraints
     +-> syncViewport() -> Sincroniza DOM con estado
     +-> destroy() -> Limpia listeners
```

## Estado del PanZoom (ZoomPanValues)

```typescript
type ZoomPanValues = {
  isZoomingOrPanning: boolean;   // Indica si hay interaccion activa
  usedRightMouseButton: boolean; // Si se uso boton derecho
  prevViewport: { x: number; y: number; zoom: number };
  panScrollTimeout: Timeout | null;
  isPanScrolling: boolean;
}
```

## Funciones Principales

### setTransform()
Aplica una transformacion de zoom con interpolacion opcional.

```typescript
// Mover a coordenada especifica con animacion
setTransform({
  x: 100, y: 100, zoom: 1.5
}, {
  duration: 200,
  interpolate: 'linear' | 'zoom'  // 'zoom' mantiene el foco visual
})
```

### setViewport() / setViewportConstrained()
Establece la vista del usuario con o sin restricciones de limites.

```typescript
// Sin restricciones
setViewport({ x: 0, y: 0, zoom: 1 })

// Con restricciones (respeta minZoom, maxZoom, translateExtent)
setViewportConstrained({ x: 0, y: 0, zoom: 1 }, {
  minZoom: 0.5,
  maxZoom: 2,
  translateExtent: [[-Infinity, -Infinity], [Infinity, Infinity]]
})
```

### scaleTo() / scaleBy()
Control programatico del zoom.

```typescript
// Zoom a nivel absoluto
scaleTo(1.5)  // zoom: 1.5

// Zoom relativo
scaleBy(1.2)  // zoom actual * 1.2
```

## Transformacion de Coordenadas

### Screen -> Flow (Viewport a Canvas)
```javascript
function screenToFlow(screenX, screenY, viewport) {
  return {
    x: (screenX - viewport.x) / viewport.zoom,
    y: (screenY - viewport.y) / viewport.zoom
  };
}
```

### Flow -> Screen (Canvas a Viewport)
```javascript
function flowToScreen(flowX, flowY, viewport) {
  return {
    x: flowX * viewport.zoom + viewport.x,
    y: flowY * viewport.zoom + viewport.y
  };
}
```

## Configuracion de Eventos (update())

```typescript
update({
  noWheelClassName: 'nowheel',     // Clase CSS que ignora wheel
  noPanClassName: 'nodrag',        // Clase CSS que ignora pan

  // Control de interacciones
  panOnScroll: false,              // Pan con scroll (shift+wheel por defecto)
  panOnScrollSpeed: 0.5,
  panOnScrollMode: 'free',         // 'free' | 'vertical' | 'horizontal'

  zoomOnScroll: true,              // Zoom con wheel
  zoomOnPinch: true,               // Zoom con pinch (touch)
  zoomOnDoubleClick: true,         // Zoom con doble click

  panOnDrag: true,                 // Pan arrastrando el fondo

  // Limites
  minZoom: 0.5,
  maxZoom: 2,
  translateExtent: [[-1000, -1000], [1000, 1000]],

  // Callbacks
  onPanZoom: (event, viewport) => {},
  onPanZoomStart: (event, viewport) => {},
  onPanZoomEnd: (event, viewport) => {}
})
```

## Integracion con D3-Zoom

XYPanZoom usa `d3-zoom` internamente:

```typescript
import { zoom, zoomIdentity, zoomTransform } from 'd3-zoom';
import { select } from 'd3-selection';

// Crear instancia de zoom
const d3Zoom = zoom().scaleExtent([minZoom, maxZoom]);

// Aplicar a elemento DOM
select(domNode).call(d3Zoom);

// Obtener transform actual
const transform = zoomTransform(domNode);
// transform.x, transform.y, transform.k (scale)
```

## Patterns de Implementacion

### En LiveFlow (Elixir)
```elixir
# Viewport como assign
def mount(_params, _session, socket) do
  {:ok, assign(socket, viewport: %{x: 0, y: 0, zoom: 1})}
end

# Handler de evento desde JS
def handle_event("lf:viewport_change", %{"x" => x, "y" => y, "zoom" => zoom}, socket) do
  {:noreply, assign(socket, viewport: %{x: x, y: y, zoom: zoom})}
end
```

### En JavaScript Hook
```javascript
const FlowHook = {
  mounted() {
    this.panzoom = XYPanZoom({
      domNode: this.el.querySelector('.react-flow__viewport'),
      minZoom: 0.1,
      maxZoom: 4,
      onPanZoomEnd: (_, viewport) => {
        this.pushEventTo(this.el, 'lf:viewport_change', viewport);
      }
    });
  },

  destroyed() {
    this.panzoom.destroy();
  }
}
```

## Auto-Pan durante Drag/Connect

Cuando el usuario arrastra cerca del borde, el viewport se desplaza automaticamente:

```javascript
function calcAutoPan({ pos, bounds, speed = 15, distance = 40 }) {
  const xMovement = pos.x < bounds.left + distance ? -speed
                  : pos.x > bounds.right - distance ? speed : 0;
  const yMovement = pos.y < bounds.top + distance ? -speed
                  : pos.y > bounds.bottom - distance ? speed : 0;
  return [xMovement, yMovement];
}
```

## Filtros de Eventos

xyflow permite filtrar que eventos activan pan/zoom:

```javascript
// Filtro personalizado: solo pan con click izquierdo
const panFilter = (event) => {
  return event.button === 0 && !event.ctrlKey;
};

// Filtro de zoom: ignorar elementos con clase 'nowheel'
const zoomFilter = (event) => {
  return !event.target.closest('.nowheel');
};
```

## Referencia de Viewport

```typescript
type Viewport = {
  x: number;      // Offset horizontal del canvas
  y: number;      // Offset vertical del canvas
  zoom: number;   // Factor de escala (1 = 100%)
}
```

El viewport se aplica via CSS transform:
```css
.react-flow__viewport {
  transform: translate(${x}px, ${y}px) scale(${zoom});
  transform-origin: 0 0;
}
```
