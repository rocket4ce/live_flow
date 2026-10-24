/**
 * Selection manager for LiveFlow
 *
 * The selection rectangle is drawn client-side in the interaction layer and
 * anchored in flow coordinates, so it stays attached to the graph while the
 * viewport auto-pans (xyflow's autoPanOnSelection). Nodes covered by the
 * rectangle are highlighted locally and the final selection is pushed once
 * as `lf:selection_change`.
 */
export class SelectionManager {
  constructor(hook) {
    this.hook = hook;
    this.selectionBox = null; // { startFlowX, startFlowY, currentX, currentY, nodes, boxEl }
    this.lastEvent = null;
  }

  isSelecting() {
    return this.selectionBox !== null;
  }

  /**
   * Start box selection
   */
  startSelection(event) {
    if (!this.hook.config.elementsSelectable) return false;

    const [x, y] = this.hook.coords.eventToScreen(event);
    const [startFlowX, startFlowY] = this.hook.coords.screenToFlow(x, y);

    const boxEl = document.createElement('div');
    boxEl.className = 'lf-selection-box';
    this.hook.interactionLayer.appendChild(boxEl);

    this.selectionBox = {
      startFlowX,
      startFlowY,
      currentX: x,
      currentY: y,
      boxEl,
      // Measure once; nodes don't move during a box selection
      nodes: this.measureSelectableNodes(),
      selected: new Set(),
    };
    this.lastEvent = event;
    this.render();

    if (this.hook.config.autoPanOnSelection) {
      this.hook.autoPan.start(() => this.moveSelection(this.lastEvent));
    }
    return true;
  }

  moveSelection(event) {
    if (!this.selectionBox || !event) return;
    this.lastEvent = event;
    this.hook.autoPan.update(event);

    const [x, y] = this.hook.coords.eventToScreen(event);
    this.selectionBox.currentX = x;
    this.selectionBox.currentY = y;

    this.render();
    this.highlight(this.nodesInBox());
  }

  endSelection() {
    if (!this.selectionBox) return;
    this.hook.autoPan.stop();

    const nodeIds = this.nodesInBox();
    this.highlight(new Set());
    this.selectionBox.boxEl.remove();
    this.selectionBox = null;
    this.lastEvent = null;

    this.hook.selectedNodes = nodeIds;
    this.hook.selectedEdges = this.connectedEdges(nodeIds);
    this.pushSelectionChange();
  }

  /**
   * Cancel the box selection without changing the current selection.
   */
  abortSelection() {
    if (!this.selectionBox) return;
    this.hook.autoPan.stop();
    this.highlight(new Set());
    this.selectionBox.boxEl.remove();
    this.selectionBox = null;
    this.lastEvent = null;
  }

  /**
   * Selection rectangle in screen coordinates (start point follows the viewport).
   */
  getSelectionRect() {
    if (!this.selectionBox) return null;

    const { startFlowX, startFlowY, currentX, currentY } = this.selectionBox;
    const [startX, startY] = this.hook.coords.flowToScreen(startFlowX, startFlowY);

    return {
      x: Math.min(startX, currentX),
      y: Math.min(startY, currentY),
      width: Math.abs(currentX - startX),
      height: Math.abs(currentY - startY),
    };
  }

  render() {
    const rect = this.getSelectionRect();
    const style = this.selectionBox.boxEl.style;
    style.left = `${rect.x}px`;
    style.top = `${rect.y}px`;
    style.width = `${rect.width}px`;
    style.height = `${rect.height}px`;
  }

  nodesInBox() {
    const rect = this.getSelectionRect();
    const [x1, y1] = this.hook.coords.screenToFlow(rect.x, rect.y);
    const [x2, y2] = this.hook.coords.screenToFlow(rect.x + rect.width, rect.y + rect.height);
    const box = { x: x1, y: y1, width: x2 - x1, height: y2 - y1 };
    const full = this.hook.config.selectionMode === 'full';

    const ids = new Set();
    for (const node of this.selectionBox.nodes) {
      const hit = full
        ? this.hook.coords.rectContains(box, node)
        : this.hook.coords.rectsIntersect(node, box);
      if (hit) ids.add(node.id);
    }
    return ids;
  }

  measureSelectableNodes() {
    const nodes = [];
    this.hook.nodeLayer?.querySelectorAll('.lf-node[data-node-id]').forEach(el => {
      if (el.dataset.selectable === 'false') return;
      nodes.push({
        id: el.dataset.nodeId,
        el,
        x: parseFloat(el.style.left) || 0,
        y: parseFloat(el.style.top) || 0,
        width: el.offsetWidth,
        height: el.offsetHeight,
      });
    });
    return nodes;
  }

  /**
   * Local visual feedback while the rectangle is being drawn.
   */
  highlight(ids) {
    if (!this.selectionBox) return;
    for (const node of this.selectionBox.nodes) {
      node.el.classList.toggle('lf-node-selecting', ids.has(node.id));
    }
  }

  connectedEdges(nodeIds) {
    const edges = new Set();
    if (nodeIds.size === 0) return edges;
    this.hook.edgeLayer?.querySelectorAll('g[data-edge-id][data-source]').forEach(g => {
      if (nodeIds.has(g.dataset.source) || nodeIds.has(g.dataset.target)) {
        edges.add(g.dataset.edgeId);
      }
    });
    return edges;
  }

  /**
   * Select a single node
   */
  selectNode(nodeId, options = {}) {
    if (!this.hook.config.elementsSelectable) return;
    const el = this.hook.nodeEl(nodeId);
    if (el?.dataset.selectable === 'false') return;

    const { multi = false, toggle = false } = options;

    if (toggle && this.hook.selectedNodes.has(nodeId)) {
      this.hook.selectedNodes.delete(nodeId);
    } else if (multi) {
      this.hook.selectedNodes.add(nodeId);
    } else if (this.hook.selectedNodes.size === 1 && this.hook.selectedNodes.has(nodeId) &&
               this.hook.selectedEdges.size === 0) {
      // Already the only selected element, nothing changes
      return;
    } else {
      this.hook.selectedNodes = new Set([nodeId]);
      this.hook.selectedEdges = new Set();
    }

    this.pushSelectionChange();
  }

  /**
   * Select a single edge
   */
  selectEdge(edgeId, options = {}) {
    if (!this.hook.config.elementsSelectable) return;
    const { multi = false, toggle = false } = options;

    if (toggle && this.hook.selectedEdges.has(edgeId)) {
      this.hook.selectedEdges.delete(edgeId);
    } else if (multi) {
      this.hook.selectedEdges.add(edgeId);
    } else {
      this.hook.selectedNodes = new Set();
      this.hook.selectedEdges = new Set([edgeId]);
    }

    this.pushSelectionChange();
  }

  /**
   * Clear all selection
   */
  clearSelection() {
    if (this.hook.selectedNodes.size === 0 && this.hook.selectedEdges.size === 0) return;
    this.hook.selectedNodes = new Set();
    this.hook.selectedEdges = new Set();
    this.pushSelectionChange();
  }

  /**
   * Select all elements
   */
  selectAll() {
    if (!this.hook.config.elementsSelectable) return;
    this.hook.nodeLayer?.querySelectorAll('.lf-node[data-node-id]').forEach(el => {
      if (el.dataset.selectable !== 'false') {
        this.hook.selectedNodes.add(el.dataset.nodeId);
      }
    });
    this.hook.edgeLayer?.querySelectorAll('g[data-edge-id]').forEach(g => {
      this.hook.selectedEdges.add(g.dataset.edgeId);
    });

    this.pushSelectionChange();
  }

  /**
   * Adopt the server-rendered selection whenever it changes. The server is
   * the source of truth: deletes, undo or paste change the selection without
   * going through this manager. Comparing against the previous render keeps
   * local selection working in apps that don't handle lf:selection_change.
   */
  syncFromDom() {
    if (this.selectionBox) return;
    const nodes = new Set();
    const edges = new Set();
    this.hook.nodeLayer?.querySelectorAll('.lf-node[data-node-id][data-selected="true"]').forEach(el => {
      nodes.add(el.dataset.nodeId);
    });
    this.hook.edgeLayer?.querySelectorAll('path.lf-edge[data-selected="true"]').forEach(p => {
      if (p.dataset.edgeId) edges.add(p.dataset.edgeId);
    });

    const signature = `${[...nodes].sort().join(',')}|${[...edges].sort().join(',')}`;
    if (signature === this.domSignature) return;

    this.domSignature = signature;
    this.hook.selectedNodes = nodes;
    this.hook.selectedEdges = edges;
  }

  /**
   * Push selection change to server
   */
  pushSelectionChange() {
    this.hook.pushEvent('lf:selection_change', {
      nodes: Array.from(this.hook.selectedNodes),
      edges: Array.from(this.hook.selectedEdges),
    });
  }

  destroy() {
    this.abortSelection();
  }
}
