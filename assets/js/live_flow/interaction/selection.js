/**
 * Selection manager for LiveFlow
 */
export class SelectionManager {
  constructor(hook) {
    this.hook = hook;
    this.selectionBox = null; // { startX, startY, currentX, currentY }
  }

  /**
   * Check if box selection is active
   */
  isSelecting() {
    return this.selectionBox !== null;
  }

  /**
   * Start box selection
   */
  startSelection(event) {
    if (!this.hook.config.elementsSelectable) return false;

    const [x, y] = this.hook.coords.eventToScreen(event);

    this.selectionBox = {
      startX: x,
      startY: y,
      currentX: x,
      currentY: y
    };

    this.hook.pushEvent('lf:selection_box_start', { x, y });
    return true;
  }

  /**
   * Move box selection
   */
  moveSelection(event) {
    if (!this.selectionBox) return;

    const [x, y] = this.hook.coords.eventToScreen(event);
    this.selectionBox.currentX = x;
    this.selectionBox.currentY = y;

    this.hook.pushEvent('lf:selection_box_move', { x, y });

    // Find nodes inside the selection box
    this.updateBoxSelection();
  }

  /**
   * End box selection
   */
  endSelection() {
    if (!this.selectionBox) return;

    // Final selection update
    this.updateBoxSelection(true);

    this.selectionBox = null;
    this.hook.pushEvent('lf:selection_box_end', {});
  }

  /**
   * Update selection based on box
   */
  updateBoxSelection(final = false) {
    if (!this.selectionBox) return;

    const box = this.getSelectionRect();
    const selectedNodes = [];
    const selectedEdges = [];

    // Check nodes
    this.hook.nodeLayer.querySelectorAll('[data-node-id]').forEach(nodeEl => {
      if (nodeEl.dataset.selectable === 'false') return;

      const nodeRect = {
        x: parseFloat(nodeEl.style.left) || 0,
        y: parseFloat(nodeEl.style.top) || 0,
        width: nodeEl.offsetWidth,
        height: nodeEl.offsetHeight
      };

      // Convert box to flow coordinates
      const [boxFlowX1, boxFlowY1] = this.hook.coords.screenToFlow(box.x, box.y);
      const [boxFlowX2, boxFlowY2] = this.hook.coords.screenToFlow(box.x + box.width, box.y + box.height);

      const boxFlow = {
        x: Math.min(boxFlowX1, boxFlowX2),
        y: Math.min(boxFlowY1, boxFlowY2),
        width: Math.abs(boxFlowX2 - boxFlowX1),
        height: Math.abs(boxFlowY2 - boxFlowY1)
      };

      if (this.hook.coords.rectsIntersect(nodeRect, boxFlow)) {
        selectedNodes.push(nodeEl.dataset.nodeId);
      }
    });

    if (final && selectedNodes.length > 0) {
      this.hook.pushEvent('lf:selection_change', {
        nodes: selectedNodes,
        edges: selectedEdges
      });

      // Update local state
      this.hook.selectedNodes = new Set(selectedNodes);
      this.hook.selectedEdges = new Set(selectedEdges);
    }
  }

  /**
   * Get selection rectangle from start/current points
   */
  getSelectionRect() {
    if (!this.selectionBox) return null;

    const { startX, startY, currentX, currentY } = this.selectionBox;

    return {
      x: Math.min(startX, currentX),
      y: Math.min(startY, currentY),
      width: Math.abs(currentX - startX),
      height: Math.abs(currentY - startY)
    };
  }

  /**
   * Select a single node
   */
  selectNode(nodeId, options = {}) {
    const { multi = false, toggle = false } = options;

    if (toggle && this.hook.selectedNodes.has(nodeId)) {
      // Deselect
      this.hook.selectedNodes.delete(nodeId);
    } else if (multi) {
      // Add to selection
      this.hook.selectedNodes.add(nodeId);
    } else {
      // Replace selection
      this.hook.selectedNodes = new Set([nodeId]);
      this.hook.selectedEdges = new Set();
    }

    this.pushSelectionChange();
  }

  /**
   * Select a single edge
   */
  selectEdge(edgeId, options = {}) {
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
    this.hook.selectedNodes = new Set();
    this.hook.selectedEdges = new Set();
    this.pushSelectionChange();
  }

  /**
   * Select all elements
   */
  selectAll() {
    this.hook.nodeLayer.querySelectorAll('[data-node-id]').forEach(el => {
      if (el.dataset.selectable !== 'false') {
        this.hook.selectedNodes.add(el.dataset.nodeId);
      }
    });

    this.pushSelectionChange();
  }

  /**
   * Push selection change to server
   */
  pushSelectionChange() {
    this.hook.pushEvent('lf:selection_change', {
      nodes: Array.from(this.hook.selectedNodes),
      edges: Array.from(this.hook.selectedEdges)
    });
  }

  destroy() {
    this.selectionBox = null;
  }
}
