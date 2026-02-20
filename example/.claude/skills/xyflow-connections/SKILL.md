---
name: xyflow-connections
description: Sistema de Handles y Conexiones de xyflow. Usar para implementar puntos de conexion, validacion de conexiones, y el flujo de crear nuevas edges.
---

# XYFlow Handles & Connections System

El modulo `xyhandle` de `@xyflow/system` gestiona los puntos de conexion de los nodos y el proceso de crear nuevas edges.

## Arquitectura

```
User Click on Handle
        |
        v
XYHandle.onPointerDown()
        |
        +-> startConnection() -> Dispara onConnectStart
        |
        v
User Moves Mouse
        |
        v
onPointerMove()
        |
        +-> Track position
        +-> Find closest handle
        +-> Validate connection (isValidHandle)
        +-> autoPan() si cerca del borde
        |
        v
User Releases on Target
        |
        v
onPointerUp()
        |
        +-> isValidHandle() -> Validacion final
        +-> onConnect() o onConnectEnd()
        +-> Cleanup listeners
```

## Tipos de Handle

```typescript
type HandleType = 'source' | 'target';

type Handle = {
  id?: string | null;       // ID unico (opcional)
  nodeId: string;           // Nodo propietario
  type: HandleType;         // source o target
  position: Position;       // top | right | bottom | left
  x: number;                // Coordenada X
  y: number;                // Coordenada Y
  width: number;            // Ancho del handle
  height: number;           // Alto del handle
}

type HandleProps = {
  type?: HandleType;              // default: 'source'
  position?: Position;            // default: Position.Top
  id?: string | null;             // ID para multiples handles
  isConnectable?: boolean;        // Permite conexiones (default: true)
  isConnectableStart?: boolean;   // Puede iniciar conexiones
  isConnectableEnd?: boolean;     // Puede recibir conexiones
  isValidConnection?: IsValidConnection;  // Validacion custom
}
```

## Estado de Conexion

```typescript
// Mientras se esta creando una conexion
type ConnectionInProgress = {
  inProgress: true;
  isValid: boolean | null;
  from: XYPosition;          // Posicion del handle origen
  fromHandle: Handle | null;
  fromPosition: Position;
  fromNode: NodeBase;
  to: XYPosition;            // Posicion actual del cursor
  toHandle: Handle | null;
  toPosition: Position;
  toNode: NodeBase | null;
}

// Sin conexion activa
type NoConnection = {
  inProgress: false;
  isValid: null;
  from: null;
  fromHandle: null;
  fromPosition: null;
  fromNode: null;
  to: null;
  toHandle: null;
  toPosition: null;
  toNode: null;
}

type ConnectionState = ConnectionInProgress | NoConnection;
```

## Estructura de Connection

```typescript
type Connection = {
  source: string;           // ID del nodo origen
  target: string;           // ID del nodo destino
  sourceHandle?: string | null;
  targetHandle?: string | null;
}

type HandleConnection = Connection & {
  edgeId: string;           // ID de la edge resultante
}
```

## Modos de Conexion

```typescript
type ConnectionMode = 'strict' | 'loose';

// strict: Solo permite conexiones source -> target
// loose: Permite cualquier combinacion (source-source, target-target, etc.)
```

## Flujo de Eventos de Conexion

### 1. Inicio de Conexion (onPointerDown)
```javascript
XYHandle.onPointerDown(event, {
  connectionMode,
  connectionRadius,
  handleId,
  nodeId,
  handleType,
  isValidConnection,
  onConnectStart,
  onConnect,
  onConnectEnd
}) {
  // 1. Registrar listeners globales
  document.addEventListener('pointermove', onPointerMove);
  document.addEventListener('pointerup', onPointerUp);

  // 2. Calcular posicion inicial
  const fromPosition = getHandlePosition(nodeId, handleId);

  // 3. Iniciar estado de conexion
  startConnection({
    nodeId,
    handleId,
    handleType,
    fromPosition
  });

  // 4. Callback
  onConnectStart?.(event, { nodeId, handleId, handleType });
}
```

### 2. Movimiento (onPointerMove)
```javascript
onPointerMove(event) {
  // 1. Calcular posicion del cursor en coordenadas del flow
  const position = pointToRendererPoint(event, viewport);

  // 2. Buscar handle cercano
  const closestHandle = findClosestHandle(position, handles, {
    connectionRadius,
    handleType: inverseType(fromHandleType)  // Si source, buscar targets
  });

  // 3. Validar conexion potencial
  const isValid = closestHandle
    ? isValidHandle(closestHandle, fromNode, fromHandle, connectionMode)
    : null;

  // 4. Actualizar estado
  updateConnection({
    to: position,
    toHandle: closestHandle,
    toNode: closestHandle?.nodeId ? getNode(closestHandle.nodeId) : null,
    isValid
  });

  // 5. Auto-pan si cerca del borde
  autoPan(event);
}
```

### 3. Fin de Conexion (onPointerUp)
```javascript
onPointerUp(event) {
  // 1. Remover listeners
  document.removeEventListener('pointermove', onPointerMove);
  document.removeEventListener('pointerup', onPointerUp);

  // 2. Verificar si hay conexion valida
  if (connectionState.isValid && connectionState.toHandle) {
    const connection = {
      source: fromNode.id,
      target: connectionState.toNode.id,
      sourceHandle: fromHandle.id,
      targetHandle: connectionState.toHandle.id
    };

    // 3. Callback de conexion exitosa
    onConnect?.(connection);
  }

  // 4. Callback de fin (siempre se llama)
  onConnectEnd?.(event, connectionState);

  // 5. Resetear estado
  resetConnection();
}
```

## Validacion de Conexiones

```typescript
type IsValidConnection = (connection: Connection) => boolean;

// Validacion por defecto en modo strict
function isValidHandle(handle, fromNode, fromHandle, connectionMode) {
  // No conectar al mismo nodo
  if (handle.nodeId === fromNode.id) return false;

  // En modo strict, solo source -> target
  if (connectionMode === 'strict') {
    if (fromHandle.type === 'source' && handle.type !== 'target') return false;
    if (fromHandle.type === 'target' && handle.type !== 'source') return false;
  }

  // Verificar si ya existe la conexion
  const existingEdge = edges.find(e =>
    e.source === fromNode.id &&
    e.target === handle.nodeId &&
    e.sourceHandle === fromHandle.id &&
    e.targetHandle === handle.id
  );
  if (existingEdge) return false;

  return true;
}
```

**Validacion Personalizada:**
```elixir
# En Elixir
def is_valid_connection(%{source: source, target: target} = conn) do
  source_node = get_node(source)
  target_node = get_node(target)

  # Ejemplo: no permitir conexiones entre nodos del mismo tipo
  source_node.type != target_node.type
end
```

## Connection Radius

Radio de busqueda para snap a handles cercanos:

```javascript
const connectionRadius = 20;  // pixeles

function findClosestHandle(position, handles, { connectionRadius, handleType }) {
  return handles
    .filter(h => h.type === handleType)
    .map(h => ({
      ...h,
      distance: Math.hypot(h.x - position.x, h.y - position.y)
    }))
    .filter(h => h.distance <= connectionRadius)
    .sort((a, b) => a.distance - b.distance)[0];
}
```

## Implementacion en LiveFlow

### Componente Handle
```elixir
defmodule LiveFlow.Components.Handle do
  use Phoenix.Component

  def handle(assigns) do
    assigns = assign_new(assigns, :type, fn -> :source end)
    assigns = assign_new(assigns, :position, fn -> :right end)
    assigns = assign_new(assigns, :connectable, fn -> true end)

    ~H"""
    <div
      class={[
        "react-flow__handle",
        "react-flow__handle-#{@position}",
        @type == :source && "source",
        @type == :target && "target",
        !@connectable && "not-connectable"
      ]}
      data-handleid={@id}
      data-nodeid={@node_id}
      data-handlepos={@position}
      data-handletype={@type}
    />
    """
  end
end
```

### Estado de Conexion en LiveView
```elixir
def mount(_params, _session, socket) do
  {:ok, assign(socket,
    connecting: nil,  # nil cuando no hay conexion activa
    nodes: [],
    edges: []
  )}
end

# Inicio de conexion
def handle_event("lf:connect_start", params, socket) do
  connecting = %{
    source_node_id: params["nodeId"],
    source_handle_id: params["handleId"],
    source_handle_type: params["handleType"],
    from_x: params["x"],
    from_y: params["y"],
    to_x: params["x"],
    to_y: params["y"],
    is_valid: nil
  }

  {:noreply, assign(socket, connecting: connecting)}
end

# Movimiento durante conexion
def handle_event("lf:connect_move", %{"x" => x, "y" => y}, socket) do
  connecting = %{socket.assigns.connecting | to_x: x, to_y: y}
  {:noreply, assign(socket, connecting: connecting)}
end

# Fin de conexion
def handle_event("lf:connect_end", params, socket) do
  socket = if params["targetNodeId"] && params["isValid"] do
    # Crear nueva edge
    new_edge = %LiveFlow.Edge{
      id: "edge-#{System.unique_integer([:positive])}",
      source: params["sourceNodeId"],
      target: params["targetNodeId"],
      source_handle: params["sourceHandleId"],
      target_handle: params["targetHandleId"]
    }
    assign(socket, edges: socket.assigns.edges ++ [new_edge])
  else
    socket
  end

  {:noreply, assign(socket, connecting: nil)}
end
```

### Connection Line Temporal
```elixir
def connection_line(assigns) do
  ~H"""
  <%= if @connecting do %>
    <g class="react-flow__connection">
      <path
        class={[
          "react-flow__connection-path",
          @connecting.is_valid == true && "valid",
          @connecting.is_valid == false && "invalid"
        ]}
        d={get_connection_path(@connecting)}
        fill="none"
        stroke="#b1b1b7"
        stroke-width="1"
      />
    </g>
  <% end %>
  """
end

defp get_connection_path(connecting) do
  LiveFlow.Paths.Bezier.get_path(%{
    source_x: connecting.from_x,
    source_y: connecting.from_y,
    target_x: connecting.to_x,
    target_y: connecting.to_y
  })
  |> elem(0)  # Solo necesitamos el path, no label position
end
```

### JavaScript Hook para Conexiones
```javascript
// En connection.js
export class ConnectionManager {
  constructor(hook) {
    this.hook = hook;
    this.isConnecting = false;
  }

  startConnection(event, handleEl) {
    const handleId = handleEl.dataset.handleid;
    const nodeId = handleEl.dataset.nodeid;
    const handleType = handleEl.dataset.handletype;
    const rect = handleEl.getBoundingClientRect();

    this.isConnecting = true;
    this.fromHandle = { handleId, nodeId, handleType };

    const [x, y] = this.screenToFlow(
      rect.left + rect.width / 2,
      rect.top + rect.height / 2
    );

    this.hook.pushEventTo(this.hook.el, 'lf:connect_start', {
      nodeId, handleId, handleType, x, y
    });

    document.addEventListener('pointermove', this.onMove);
    document.addEventListener('pointerup', this.onEnd);
  }

  onMove = (event) => {
    const [x, y] = this.screenToFlow(event.clientX, event.clientY);

    // Buscar handle cercano
    const closestHandle = this.findClosestHandle(x, y, 20);

    this.hook.pushEventTo(this.hook.el, 'lf:connect_move', {
      x, y,
      targetNodeId: closestHandle?.nodeId,
      targetHandleId: closestHandle?.handleId,
      isValid: closestHandle ? this.validateConnection(closestHandle) : null
    });
  }

  onEnd = (event) => {
    document.removeEventListener('pointermove', this.onMove);
    document.removeEventListener('pointerup', this.onEnd);

    const [x, y] = this.screenToFlow(event.clientX, event.clientY);
    const closestHandle = this.findClosestHandle(x, y, 20);

    this.hook.pushEventTo(this.hook.el, 'lf:connect_end', {
      sourceNodeId: this.fromHandle.nodeId,
      sourceHandleId: this.fromHandle.handleId,
      targetNodeId: closestHandle?.nodeId,
      targetHandleId: closestHandle?.handleId,
      isValid: closestHandle ? this.validateConnection(closestHandle) : false
    });

    this.isConnecting = false;
  }
}
```

## Reconnect (Reconectar Edges)

```typescript
type OnReconnect = (
  oldEdge: EdgeBase,
  newConnection: Connection
) => void;

// Permite arrastrar el extremo de una edge existente
// para conectarlo a un handle diferente
```

## Estado Visual del Handle

```css
/* Handle base */
.react-flow__handle {
  width: 10px;
  height: 10px;
  background: #1a192b;
  border: 1px solid white;
  border-radius: 50%;
}

/* Durante conexion valida */
.react-flow__handle.connecting.valid {
  background: #55dd99;
}

/* Durante conexion invalida */
.react-flow__handle.connecting.invalid {
  background: #ff6b6b;
}

/* No conectable */
.react-flow__handle.not-connectable {
  opacity: 0.5;
  pointer-events: none;
}
```

## Connection Status Helper

```typescript
// Convierte boolean/null a string para CSS classes
function getConnectionStatus(isValid: boolean | null): string | null {
  if (isValid === null) return null;
  return isValid ? 'valid' : 'invalid';
}
```
