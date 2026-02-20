/**
 * Node drag manager for LiveFlow
 *
 * Drag positions are applied client-side for instant visual feedback.
 * Throttled pushes to the server keep edges in sync.  After each server
 * re-render (DOM patch) we re-apply the latest client-side positions so
 * the nodes never "jump back" due to network latency.
 */
export class NodeDragManager {
  constructor(hook) {
    this.hook = hook;
    this.draggingNodes = new Map(); // nodeId -> { startMouseX, startMouseY, startPosX, startPosY, element }
    this.lastPushTime = 0;
    this.pendingChanges = [];
    // Track latest client-side positions during drag so we can re-apply after DOM patches
    this.clientPositions = new Map(); // nodeId -> { x, y }
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
      this.pushDragStart();
      return true;
    }
    return false;
  }

  /**
   * Handle drag movement
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

    // Pass 3: apply final positions
    // Guide alignment overrides grid snap per-axis
    const changes = [];
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

      // Track client positions for re-application after DOM patches
      this.clientPositions.set(nodeId, { x: newX, y: newY });

      changes.push({
        type: 'position',
        id: nodeId,
        position: { x: newX, y: newY },
        dragging: true
      });
    });

    // Throttled sync to server (for edge re-rendering)
    this.throttledPushChanges(changes);
  }

  /**
   * End dragging
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
    // Clear client positions — the final server render is now authoritative
    this.clientPositions.clear();

    // Clean up helper lines
    if (this.hook.helperLines) {
      this.hook.helperLines.endDrag();
    }

    // Final position push
    this.hook.pushNodeChange(changes);
    this.flushPendingChanges();
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

  /**
   * Throttled push of position changes — keeps edges in sync on the server
   * while avoiding excessive re-renders.
   */
  throttledPushChanges(changes) {
    const now = Date.now();
    if (now - this.lastPushTime > 80) {
      this.hook.pushNodeChange(changes);
      this.lastPushTime = now;
      this.pendingChanges = [];
    } else {
      this.pendingChanges = changes;
    }
  }

  /**
   * Flush any pending changes
   */
  flushPendingChanges() {
    if (this.pendingChanges.length > 0) {
      this.hook.pushNodeChange(this.pendingChanges);
      this.pendingChanges = [];
    }
  }

  destroy() {
    this.draggingNodes.clear();
    this.clientPositions.clear();
    this.pendingChanges = [];
  }
}
