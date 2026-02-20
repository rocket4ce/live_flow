---
name: liveflow-debug
description: Debug y solución de problemas en LiveFlow. Usar cuando hay errores de eventos, conexiones, o rendering en la librería de diagramas de flujo.
---

# LiveFlow Debug Skill

Cuando encuentres errores en LiveFlow, sigue estos patrones de solución:

## Errores comunes y soluciones

### 1. FunctionClauseError en handle_event

**Síntoma**: `no function clause matching in FlowDemoLive.handle_event/3`

**Causa**: El JS hook envía un evento que no tiene handler en el LiveView.

**Solución**: Agregar el handler faltante en `flow_demo_live.ex`:

```elixir
@impl true
def handle_event("lf:<event_name>", params, socket) do
  {:noreply, socket}
end
```

**Eventos conocidos de LiveFlow**:
- `lf:selection_change` - Cambio de selección de nodos/edges
- `lf:node_change` - Cambios de posición/dimensiones
- `lf:connect_start` - Inicio de conexión
- `lf:connect_move` - Movimiento de línea de conexión
- `lf:connect_end` - Conexión completada
- `lf:connect_cancel` - Conexión cancelada
- `lf:viewport_change` - Cambio de pan/zoom
- `lf:selection_box_start/move/end` - Selección por caja
- `lf:delete_selected` - Eliminar elementos seleccionados

### 2. Eventos no llegan al LiveComponent

**Síntoma**: El estado del componente no se actualiza (ej: línea de conexión no se dibuja)

**Causa**: `pushEvent` envía al LiveView padre, no al LiveComponent.

**Solución**: Usar `pushEventTo(this.hook.el, ...)` en JavaScript:

```javascript
// INCORRECTO - va al LiveView padre
this.hook.pushEvent('lf:connect_start', data);

// CORRECTO - va al LiveComponent
this.hook.pushEventTo(this.hook.el, 'lf:connect_start', data);
```

### 3. MatchError en path calculations

**Síntoma**: `(MatchError) no match of right hand side value`

**Causa**: Pattern matching incorrecto al parsear datos de path.

**Solución**: Trackear coordenadas directamente en el acumulador del reduce en lugar de parsear strings:

```elixir
# INCORRECTO - intenta parsear strings como tuplas
[{_, prev_part} | _] = Enum.reverse(acc)

# CORRECTO - trackear coordenadas en el acumulador
{path_segments, {px, py}} = Enum.reduce(...)
```

### 4. Edge no se renderiza

**Síntoma**: Las conexiones existen en el state pero no se ven.

**Verificar**:
1. El nodo tiene `measured: true` o dimensiones definidas
2. Los handles tienen IDs únicos
3. El path module retorna un path válido

## Archivos clave

- `lib/live_flow/components/flow.ex` - Componente principal
- `lib/live_flow/components/edge.ex` - Renderizado de edges
- `lib/live_flow/paths/` - Cálculo de paths SVG
- `assets/js/live_flow/hooks/flow_hook.js` - Hook principal
- `assets/js/live_flow/interaction/connection.js` - Manager de conexiones

## Debugging

Agregar `IO.inspect` para ver el flujo de datos:

```elixir
def handle_event("lf:connect_end", params, socket) do
  IO.inspect(params, label: "Connect end params")
  # ...
end
```

En JavaScript, usar console.log:

```javascript
console.log('Connect event:', data);
this.hook.pushEventTo(this.hook.el, 'lf:connect_end', data);
```
