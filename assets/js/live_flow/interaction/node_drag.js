/**
 * Node drag manager for LiveFlow
 *
 * Both node positions AND edge paths are updated client-side during drag
 * for zero-latency feedback.  Only the final position is pushed to the
 * server in endDrag().  After each server DOM patch we re-apply the
 * client-side positions so nodes never "jump back".
 */
import { calculateBezierPath } from '../utils/paths.js';

export class NodeDragManager {
  constructor(hook) {
    this.hook = hook;
    this.draggingNodes = new Map(); // nodeId -> { startMouseX, startMouseY, startPosX, startPosY, element }
    // Track latest client-side positions during drag so we can re-apply after DOM patches
    this.clientPositions = new Map(); // nodeId -> { x, y }
    // Cache of edges connected to dragging nodes for client-side path updates
    this.affectedEdges = []; // [{ g, paths, sourceNodeId, targetNodeId, sourceHandlePos, targetHandlePos }]
  }

  /**
   * Check if we're currently dragging
   */
  isDragging() {
    return this.draggingNodes.size > 0;
  }

  /**
   * Re-apply client-side positions after a LiveView DOM patch.
   * Called from the hook's updated() callback to prevent jitter.
   */
  reapplyPositions() {
    if (this.clientPositions.size === 0) return;

    this.clientPositions.forEach(({ x, y }, nodeId) => {
      const el = this.hook.nodeLayer.querySelector(`[data-node-id="${nodeId}"]`);
      if (el) {
        el.style.left = `${x}px`;
        el.style.top = `${y}px`;
      }
    });

    // Also re-apply edge paths since the server render may have overwritten them
    this.updateEdgePaths();
  }

  /**
   * Start dragging a node
   */
  startDrag(nodeId, event) {
    if (!this.hook.config.nodesDraggable) return false;

    const nodeEl = this.hook.nodeLayer.querySelector(`[data-node-id="${nodeId}"]`);
    if (!nodeEl || nodeEl.dataset.draggable === 'false') return false;

    const [flowX, flowY] = this.hook.coords.eventToFlow(event);

    // If this node is selected, drag all selected nodes
    const nodesToDrag = this.hook.selectedNodes.has(nodeId)
      ? Array.from(this.hook.selectedNodes)
      : [nodeId];

    nodesToDrag.forEach(id => {
      const el = this.hook.nodeLayer.querySelector(`[data-node-id="${id}"]`);
      if (el && el.dataset.draggable !== 'false') {
        this.draggingNodes.set(id, {
          startMouseX: flowX,
          startMouseY: flowY,
          startPosX: parseFloat(el.style.left) || 0,
          startPosY: parseFloat(el.style.top) || 0,
          element: el
        });
        el.dataset.dragging = 'true';
      }
    });

    if (this.draggingNodes.size > 0) {
      // Initialize helper lines if enabled
      if (this.hook.helperLines) {
        this.hook.helperLines.startDrag(new Set(this.draggingNodes.keys()));
      }
      // Cache edges connected to dragging nodes
      this.cacheAffectedEdges();
      // Notify server for history snapshot
      this.pushDragStart();
      return true;
    }
    return false;
  }

  /**
   * Cache edges that are connected to any dragging node so we can
   * update their SVG paths client-side during drag.
   */
  cacheAffectedEdges() {
    this.affectedEdges = [];
    const draggingIds = new Set(this.draggingNodes.keys());
    const edgeGroups = this.hook.edgeLayer.querySelectorAll('g[data-edge-id]');

    edgeGroups.forEach(g => {
      const sourceId = g.dataset.source;
      const targetId = g.dataset.target;
      if (!sourceId || !targetId) return;

      // Only process edges connected to at least one dragging node
      if (!draggingIds.has(sourceId) && !draggingIds.has(targetId)) return;

      // Find the handle positions from the node DOM
      const sourceHandlePos = this.getHandlePosition(sourceId, g.dataset.sourceHandle, 'source');
      const targetHandlePos = this.getHandlePosition(targetId, g.dataset.targetHandle, 'target');

      // Collect all <path> elements in this edge group
      const paths = g.querySelectorAll('path');

      this.affectedEdges.push({
        g,
        paths,
        sourceNodeId: sourceId,
        targetNodeId: targetId,
        sourceHandlePos,
        targetHandlePos,
        // Cache source/target handle references for label update
        labelWrapper: g.querySelector('.lf-edge-label-wrapper'),
        insertWrapper: g.querySelector('.lf-edge-insert-wrapper'),
        deleteWrapper: g.querySelector('foreignObject:last-of-type'),
      });
    });
  }

  /**
   * Get the handle position (top/bottom/left/right) for a node.
   */
  getHandlePosition(nodeId, handleId, type) {
    const nodeEl = this.hook.nodeLayer.querySelector(`[data-node-id="${nodeId}"]`);
    if (!nodeEl) return type === 'source' ? 'right' : 'left';

    if (handleId) {
      const handleEl = nodeEl.querySelector(`[data-handle-id="${handleId}"]`);
      if (handleEl) return handleEl.dataset.handlePosition || (type === 'source' ? 'right' : 'left');
    }

    // Find first handle of matching type
    const handleEl = nodeEl.querySelector(`[data-handle-type="${type}"]`);
    if (handleEl) return handleEl.dataset.handlePosition || (type === 'source' ? 'right' : 'left');

    return type === 'source' ? 'right' : 'left';
  }

  /**
   * Calculate handle coordinates based on node position and dimensions.
   */
  getHandleCoords(nodeId, handlePosition) {
    const nodeEl = this.hook.nodeLayer.querySelector(`[data-node-id="${nodeId}"]`);
    if (!nodeEl) return null;

    // Use client positions if available (for dragging nodes), otherwise read from DOM
    const clientPos = this.clientPositions.get(nodeId);
    const x = clientPos ? clientPos.x : (parseFloat(nodeEl.style.left) || 0);
    const y = clientPos ? clientPos.y : (parseFloat(nodeEl.style.top) || 0);
    const w = nodeEl.offsetWidth || 100;
    const h = nodeEl.offsetHeight || 40;

    switch (handlePosition) {
      case 'top':    return { x: x + w / 2, y: y };
      case 'bottom': return { x: x + w / 2, y: y + h };
      case 'left':   return { x: x, y: y + h / 2 };
      case 'right':  return { x: x + w, y: y + h / 2 };
      default:       return { x: x + w, y: y + h / 2 };
    }
  }

  /**
   * Update SVG paths for all affected edges using current client-side positions.
   */
  updateEdgePaths() {
    for (const edge of this.affectedEdges) {
      const sourceCoords = this.getHandleCoords(edge.sourceNodeId, edge.sourceHandlePos);
      const targetCoords = this.getHandleCoords(edge.targetNodeId, edge.targetHandlePos);
      if (!sourceCoords || !targetCoords) continue;

      const pathD = calculateBezierPath(
        sourceCoords.x, sourceCoords.y, edge.sourceHandlePos,
        targetCoords.x, targetCoords.y, edge.targetHandlePos
      );

      // Update all path elements in this edge group
      edge.paths.forEach(p => { p.setAttribute('d', pathD); });

      // Update label/insert/delete button positions (midpoint)
      const midX = (sourceCoords.x + targetCoords.x) / 2;
      const midY = (sourceCoords.y + targetCoords.y) / 2;

      if (edge.labelWrapper) {
        edge.labelWrapper.setAttribute('x', midX - 50);
        edge.labelWrapper.setAttribute('y', midY - 10);
      }
      if (edge.insertWrapper) {
        edge.insertWrapper.setAttribute('x', midX - 12);
        edge.insertWrapper.setAttribute('y', midY - 12);
      }
    }
  }

  /**
   * Handle drag movement — node positions + edge paths updated client-side.
   */
  moveDrag(event) {
    if (this.draggingNodes.size === 0) return;

    const [flowX, flowY] = this.hook.coords.eventToFlow(event);

    // Pass 1: compute raw positions (no grid snap)
    this.draggingNodes.forEach((drag) => {
      drag._rawX = drag.startPosX + (flowX - drag.startMouseX);
      drag._rawY = drag.startPosY + (flowY - drag.startMouseY);
    });

    // Pass 2: check helper line alignment against raw positions
    let snapDx = 0, snapDy = 0;
    let hasVGuide = false, hasHGuide = false;
    if (this.hook.helperLines) {
      this.draggingNodes.forEach((drag) => {
        drag.element.style.left = `${drag._rawX}px`;
        drag.element.style.top = `${drag._rawY}px`;
      });
      const result = this.hook.helperLines.computeGuides(this.draggingNodes);
      snapDx = result.snapDx;
      snapDy = result.snapDy;
      hasVGuide = result.hasVGuide;
      hasHGuide = result.hasHGuide;
    }

    // Pass 3: apply final positions (CSS only, no server push)
    this.draggingNodes.forEach((drag, nodeId) => {
      let newX, newY;

      if (hasVGuide) {
        newX = drag._rawX + snapDx;
      } else if (this.hook.config.snapToGrid) {
        const [gx] = this.hook.coords.snapToGrid(
          drag._rawX, drag._rawY,
          this.hook.config.snapGridX, this.hook.config.snapGridY
        );
        newX = gx;
      } else {
        newX = drag._rawX;
      }

      if (hasHGuide) {
        newY = drag._rawY + snapDy;
      } else if (this.hook.config.snapToGrid) {
        const [, gy] = this.hook.coords.snapToGrid(
          drag._rawX, drag._rawY,
          this.hook.config.snapGridX, this.hook.config.snapGridY
        );
        newY = gy;
      } else {
        newY = drag._rawY;
      }

      // Apply CSS immediately (client-side, instant)
      drag.element.style.left = `${newX}px`;
      drag.element.style.top = `${newY}px`;

      // Track client positions for edge path calculation and DOM patch recovery
      this.clientPositions.set(nodeId, { x: newX, y: newY });
    });

    // Update edge SVG paths client-side (instant, no server round-trip)
    this.updateEdgePaths();

    // Broadcast intermediate positions to remote users (throttled)
    this._throttleDragBroadcast();
  }

  /**
   * Throttled broadcast of drag positions for remote collaboration.
   * Sends intermediate positions so other users see live movement.
   */
  _throttleDragBroadcast() {
    const now = Date.now();
    if (now - (this._lastDragBroadcast || 0) < 50) return;
    this._lastDragBroadcast = now;

    const changes = [];
    this.clientPositions.forEach(({ x, y }, nodeId) => {
      changes.push({
        type: 'position',
        id: nodeId,
        position: { x, y },
        dragging: true
      });
    });

    if (changes.length > 0) {
      this.hook.pushEvent('lf:drag_move', { changes });
    }
  }

  /**
   * End dragging — send final positions to server
   */
  endDrag() {
    if (this.draggingNodes.size === 0) return;

    const changes = [];

    this.draggingNodes.forEach((drag, nodeId) => {
      drag.element.dataset.dragging = 'false';

      changes.push({
        type: 'position',
        id: nodeId,
        position: {
          x: parseFloat(drag.element.style.left) || 0,
          y: parseFloat(drag.element.style.top) || 0
        },
        dragging: false
      });
    });

    this.draggingNodes.clear();
    this.clientPositions.clear();
    this.affectedEdges = [];

    // Clean up helper lines
    if (this.hook.helperLines) {
      this.hook.helperLines.endDrag();
    }

    // Send final position to server (single push)
    this.hook.pushNodeChange(changes);
  }

  /**
   * Push drag start event (for history snapshot on server)
   */
  pushDragStart() {
    const changes = Array.from(this.draggingNodes.entries()).map(([id, drag]) => ({
      type: 'position',
      id,
      position: { x: drag.startPosX, y: drag.startPosY },
      dragging: true
    }));
    this.hook.pushNodeChange(changes);
  }

  destroy() {
    this.draggingNodes.clear();
    this.clientPositions.clear();
    this.affectedEdges = [];
  }
}
