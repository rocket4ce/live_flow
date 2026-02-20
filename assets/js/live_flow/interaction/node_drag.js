/**
 * Node drag manager for LiveFlow
 *
 * Drag is fully client-side: CSS left/top are updated directly in the browser
 * so the interaction feels instant.  Only the final position is sent to the
 * server (in endDrag) to avoid re-render jitter caused by network latency.
 */
export class NodeDragManager {
  constructor(hook) {
    this.hook = hook;
    this.draggingNodes = new Map(); // nodeId -> { startMouseX, startMouseY, startPosX, startPosY, element }
  }

  /**
   * Check if we're currently dragging
   */
  isDragging() {
    return this.draggingNodes.size > 0;
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
      // Notify server of drag start (for history snapshot) without position —
      // we send a lightweight event so the server can push history before
      // positions change, but we do NOT send position data that would trigger
      // a re-render with stale coordinates.
      this.hook.pushEvent('lf:drag_start', {
        node_ids: Array.from(this.draggingNodes.keys())
      });
      return true;
    }
    return false;
  }

  /**
   * Handle drag movement — purely client-side, no server communication.
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

    // Pass 3: apply final positions visually (CSS only, no server push)
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

      drag.element.style.left = `${newX}px`;
      drag.element.style.top = `${newY}px`;
    });
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

    // Clean up helper lines
    if (this.hook.helperLines) {
      this.hook.helperLines.endDrag();
    }

    // Send final position to server (single push, no intermediate jitter)
    this.hook.pushNodeChange(changes);
  }

  destroy() {
    this.draggingNodes.clear();
  }
}
