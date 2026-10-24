/**
 * Node drag manager for LiveFlow
 *
 * Both node positions AND edge paths are updated client-side during drag
 * for zero-latency feedback. Only the final position is pushed to the
 * server in endDrag(). After each server DOM patch we re-apply the
 * client-side positions so nodes never "jump back".
 *
 * A drag only starts once the pointer moved more than `node_drag_threshold`
 * pixels, so plain clicks on nodes don't produce position changes.
 */

const BROADCAST_INTERVAL = 50;

export class NodeDragManager {
  constructor(hook) {
    this.hook = hook;
    // Pointer down on a node, waiting for the drag threshold
    this.pending = null; // { nodeId, startScreenX, startScreenY, startFlow }
    this.draggingNodes = new Map(); // nodeId -> { startPosX, startPosY, width, height, element }
    // Latest client-side geometry, re-applied after DOM patches and used for edge updates
    this.clientPositions = new Map(); // nodeId -> { x, y, width, height }
    this.affectedEdges = [];
    this.lastEvent = null;
    this.startFlow = null;
  }

  isDragging() {
    return this.draggingNodes.size > 0;
  }

  /**
   * Pointer went down on a node. Returns false if the node can't be dragged.
   */
  startDrag(nodeId, event) {
    if (!this.hook.config.nodesDraggable) return false;

    const nodeEl = this.hook.nodeEl(nodeId);
    if (!nodeEl || nodeEl.dataset.draggable === 'false') return false;

    // Nodes with a drag handle can only be dragged from it
    const dragHandle = nodeEl.dataset.dragHandle;
    if (dragHandle && !event.target.closest(dragHandle)) return false;

    const [screenX, screenY] = this.hook.coords.eventToScreen(event);
    this.pending = {
      nodeId,
      startScreenX: screenX,
      startScreenY: screenY,
      startFlow: this.hook.coords.eventToFlow(event),
    };
    this.lastEvent = event;

    if (this.hook.config.nodeDragThreshold <= 0) {
      this.beginDrag();
    }
    return true;
  }

  beginDrag() {
    const { nodeId, startFlow } = this.pending;
    this.startFlow = startFlow;

    // If this node is selected, drag all selected nodes
    const candidates = this.hook.selectedNodes.has(nodeId)
      ? Array.from(this.hook.selectedNodes)
      : [nodeId];

    const draggable = new Set(candidates.filter(id => {
      const el = this.hook.nodeEl(id);
      return el && el.dataset.draggable !== 'false';
    }));

    // Children of a dragged node move with it (sub-flows)
    const index = this.childrenIndex();
    draggable.forEach(id => {
      if (this.hasAncestorIn(id, draggable)) return;
      const el = this.hook.nodeEl(id);

      this.draggingNodes.set(id, {
        ...this.geometry(el),
        startPosX: parseFloat(el.style.left) || 0,
        startPosY: parseFloat(el.style.top) || 0,
        element: el,
        parentId: el.dataset.parentId || null,
        extent: el.dataset.extent || null,
        descendants: this.descendantsOf(id, index),
      });
      el.dataset.dragging = 'true';
    });

    if (this.draggingNodes.size === 0) return;

    const ids = this.movingIds();
    this.hook.helperLines?.startDrag(ids);
    this.affectedEdges = this.hook.edges.collect(ids);

    // Notify server (history snapshot, dragging flag)
    this.pushPositions(true, true);

    if (this.hook.config.autoPanOnNodeDrag) {
      this.hook.autoPan.start(() => this.moveDrag(this.lastEvent));
    }
  }

  /**
   * Handle drag movement — node positions + edge paths updated client-side.
   */
  moveDrag(event) {
    if (!event) return;
    this.lastEvent = event;

    if (this.pending && !this.isDragging()) {
      const [x, y] = this.hook.coords.eventToScreen(event);
      const distance = Math.hypot(x - this.pending.startScreenX, y - this.pending.startScreenY);
      if (distance <= this.hook.config.nodeDragThreshold) return;
      this.beginDrag();
    }

    if (!this.isDragging()) return;

    this.hook.autoPan.update(event);

    const [flowX, flowY] = this.hook.coords.eventToFlow(event);
    const dx = flowX - this.startFlow[0];
    const dy = flowY - this.startFlow[1];

    this.draggingNodes.forEach(drag => {
      drag._rawX = drag.startPosX + dx;
      drag._rawY = drag.startPosY + dy;
    });

    // Helper line alignment against the raw (unsnapped) positions
    let guides = { snapDx: 0, snapDy: 0, hasVGuide: false, hasHGuide: false };
    if (this.hook.helperLines) {
      guides = this.hook.helperLines.computeGuides(this.draggingNodes);
    }

    const { snapToGrid, snapGridX, snapGridY } = this.hook.config;

    this.draggingNodes.forEach((drag, nodeId) => {
      let x = drag._rawX;
      let y = drag._rawY;

      if (guides.hasVGuide) {
        x += guides.snapDx;
      } else if (snapToGrid) {
        x = Math.round(x / snapGridX) * snapGridX;
      }

      if (guides.hasHGuide) {
        y += guides.snapDy;
      } else if (snapToGrid) {
        y = Math.round(y / snapGridY) * snapGridY;
      }

      [x, y] = this.clampToExtent(x, y, drag.width, drag.height);
      [x, y] = this.clampToParent(drag, x, y);

      drag.element.style.left = `${x}px`;
      drag.element.style.top = `${y}px`;
      this.clientPositions.set(nodeId, { x, y, width: drag.width, height: drag.height });
      this.moveDescendants(drag, x - drag.startPosX, y - drag.startPosY);
    });

    this.hook.edges.update(this.affectedEdges, this.clientPositions);
    this.throttleDragBroadcast();
  }

  /**
   * End dragging — send final positions to server.
   * @returns {boolean} whether a drag actually happened
   */
  endDrag() {
    this.hook.autoPan.stop();
    this.pending = null;
    if (!this.isDragging()) return false;

    this.pushPositions(false, false);
    this.cleanup();
    return true;
  }

  /**
   * Abort the drag (Escape, window blur, touch cancel) and restore the start positions.
   */
  abortDrag() {
    this.hook.autoPan.stop();
    this.pending = null;
    if (!this.isDragging()) return;

    this.draggingNodes.forEach((drag, nodeId) => {
      drag.element.style.left = `${drag.startPosX}px`;
      drag.element.style.top = `${drag.startPosY}px`;
      this.clientPositions.set(nodeId, { x: drag.startPosX, y: drag.startPosY, width: drag.width, height: drag.height });
      this.moveDescendants(drag, 0, 0);
    });
    this.hook.edges.update(this.affectedEdges, this.clientPositions);

    // The server marked the nodes as dragging on start: reset it, flagging
    // the change so apps can tell a cancelled drag from a drop
    this.pushPositions(true, false, { aborted: true });
    this.cleanup();
  }

  cleanup() {
    this.draggingNodes.forEach(drag => {
      drag.element.dataset.dragging = 'false';
    });
    this.draggingNodes.clear();
    this.clientPositions.clear();
    this.affectedEdges = [];
    this.lastEvent = null;
    this.hook.helperLines?.endDrag();
  }

  /**
   * Move the selected nodes with the keyboard (arrow keys).
   */
  nudge(dx, dy) {
    if (!this.hook.config.nodesDraggable || this.isDragging()) return false;

    const changes = [];
    const moved = new Map();
    const selected = new Set(this.hook.selectedNodes);
    const index = this.childrenIndex();

    selected.forEach(id => {
      const el = this.hook.nodeEl(id);
      if (!el || el.dataset.draggable === 'false' || this.hasAncestorIn(id, selected)) return;

      const drag = {
        ...this.geometry(el),
        startPosX: parseFloat(el.style.left) || 0,
        startPosY: parseFloat(el.style.top) || 0,
        parentId: el.dataset.parentId || null,
        extent: el.dataset.extent || null,
        descendants: this.descendantsOf(id, index),
      };
      let [x, y] = this.clampToExtent(drag.startPosX + dx, drag.startPosY + dy, drag.width, drag.height);
      [x, y] = this.clampToParent(drag, x, y);

      el.style.left = `${x}px`;
      el.style.top = `${y}px`;
      moved.set(id, { x, y, width: drag.width, height: drag.height });
      drag.descendants.forEach(d => {
        d.el.style.left = `${d.startX + x - drag.startPosX}px`;
        d.el.style.top = `${d.startY + y - drag.startPosY}px`;
        moved.set(d.id, { x: d.startX + x - drag.startPosX, y: d.startY + y - drag.startPosY, width: d.width, height: d.height });
      });
      changes.push({ type: 'position', id, position: this.relativePosition(drag.parentId, x, y), dragging: false });
    });

    if (changes.length === 0) return false;

    this.hook.edges.updateForNodes(new Set(moved.keys()), moved);
    this.hook.connection.refreshStart();
    this.hook.pushNodeChange(changes);
    return true;
  }

  // ===== Sub-flows =====

  geometry(el) {
    return { width: el.offsetWidth, height: el.offsetHeight };
  }

  /** parentId -> [child elements], built from the DOM */
  childrenIndex() {
    const index = new Map();
    this.hook.nodeLayer?.querySelectorAll('.lf-node[data-parent-id]').forEach(el => {
      const list = index.get(el.dataset.parentId) || [];
      list.push(el);
      index.set(el.dataset.parentId, list);
    });
    return index;
  }

  descendantsOf(id, index) {
    const result = [];
    const queue = [...(index.get(id) || [])];
    while (queue.length > 0) {
      const el = queue.shift();
      result.push({
        id: el.dataset.nodeId,
        el,
        startX: parseFloat(el.style.left) || 0,
        startY: parseFloat(el.style.top) || 0,
        width: el.offsetWidth,
        height: el.offsetHeight,
      });
      queue.push(...(index.get(el.dataset.nodeId) || []));
    }
    return result;
  }

  hasAncestorIn(id, ids) {
    let el = this.hook.nodeEl(id);
    const seen = new Set();
    while (el?.dataset.parentId && !seen.has(el.dataset.parentId)) {
      if (ids.has(el.dataset.parentId)) return true;
      seen.add(el.dataset.parentId);
      el = this.hook.nodeEl(el.dataset.parentId);
    }
    return false;
  }

  /** Ids of every node moving: dragged roots plus their descendants */
  movingIds() {
    const ids = new Set();
    this.draggingNodes.forEach((drag, id) => {
      ids.add(id);
      drag.descendants.forEach(d => ids.add(d.id));
    });
    return ids;
  }

  moveDescendants(drag, dx, dy) {
    drag.descendants.forEach(d => {
      const x = d.startX + dx;
      const y = d.startY + dy;
      d.el.style.left = `${x}px`;
      d.el.style.top = `${y}px`;
      this.clientPositions.set(d.id, { x, y, width: d.width, height: d.height });
    });
  }

  parentRect(parentId) {
    const el = parentId && this.hook.nodeEl(parentId);
    if (!el) return null;
    return {
      x: parseFloat(el.style.left) || 0,
      y: parseFloat(el.style.top) || 0,
      width: el.offsetWidth,
      height: el.offsetHeight,
    };
  }

  /** extent: 'parent' keeps the node inside its parent; [[x1, y1], [x2, y2]] is relative to it */
  clampToParent(drag, x, y) {
    if (!drag.extent || !drag.parentId) return [x, y];
    const parent = this.parentRect(drag.parentId);
    if (!parent) return [x, y];

    let [[minX, minY], [maxX, maxY]] = [[0, 0], [parent.width, parent.height]];
    if (drag.extent !== 'parent') {
      try {
        [[minX, minY], [maxX, maxY]] = JSON.parse(drag.extent);
      } catch (_e) {
        return [x, y];
      }
    }

    return [
      Math.min(Math.max(x, parent.x + minX), Math.max(parent.x + minX, parent.x + maxX - drag.width)),
      Math.min(Math.max(y, parent.y + minY), Math.max(parent.y + minY, parent.y + maxY - drag.height)),
    ];
  }

  /** Child nodes store positions relative to their parent */
  relativePosition(parentId, x, y) {
    const parent = this.parentRect(parentId);
    return parent ? { x: x - parent.x, y: y - parent.y } : { x, y };
  }

  clampToExtent(x, y, width, height) {
    const extent = this.hook.config.nodeExtent;
    if (!extent) return [x, y];

    const [[minX, minY], [maxX, maxY]] = extent;
    return [
      Math.min(Math.max(x, minX), Math.max(minX, maxX - (width || 0))),
      Math.min(Math.max(y, minY), Math.max(minY, maxY - (height || 0))),
    ];
  }

  /**
   * Re-apply client-side positions after a LiveView DOM patch.
   */
  reapplyPositions() {
    if (this.clientPositions.size === 0) return;

    this.clientPositions.forEach(({ x, y }, nodeId) => {
      const el = this.hook.nodeEl(nodeId);
      if (el) {
        el.style.left = `${x}px`;
        el.style.top = `${y}px`;
      }
    });

    // The patch may have replaced edge elements; collect them again
    this.affectedEdges = this.hook.edges.collect(new Set(this.clientPositions.keys()));
    this.hook.edges.update(this.affectedEdges, this.clientPositions);
  }

  /**
   * Throttled broadcast of drag positions for remote collaboration.
   */
  throttleDragBroadcast() {
    const now = Date.now();
    if (now - (this.lastBroadcast || 0) < BROADCAST_INTERVAL) return;
    this.lastBroadcast = now;

    const changes = [];
    this.clientPositions.forEach(({ x, y }, nodeId) => {
      changes.push({ type: 'position', id: nodeId, position: { x, y }, dragging: true });
    });

    if (changes.length > 0) {
      this.hook.pushEvent('lf:drag_move', { changes });
    }
  }

  /**
   * Push position changes for the dragged nodes.
   * @param {boolean} useStart - send the start positions instead of the current ones
   * @param {boolean} dragging
   */
  pushPositions(useStart, dragging, extra = {}) {
    const changes = [];
    this.draggingNodes.forEach((drag, id) => {
      const x = useStart ? drag.startPosX : parseFloat(drag.element.style.left) || 0;
      const y = useStart ? drag.startPosY : parseFloat(drag.element.style.top) || 0;
      changes.push({ type: 'position', id, position: this.relativePosition(drag.parentId, x, y), dragging, ...extra });
    });
    this.hook.pushNodeChange(changes);
  }

  destroy() {
    this.pending = null;
    this.draggingNodes.clear();
    this.clientPositions.clear();
    this.affectedEdges = [];
  }
}
