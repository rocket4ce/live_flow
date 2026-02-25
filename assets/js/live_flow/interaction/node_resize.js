/**
 * Node resize manager for LiveFlow
 *
 * Handles interactive resizing of nodes via resize handles.
 * Like drag, width/height are updated client-side during resize
 * for zero-latency feedback. Only the final dimensions are pushed
 * to the server in endResize().
 */
import { calculateBezierPath } from '../utils/paths.js';

export class NodeResizeManager {
  constructor(hook) {
    this.hook = hook;
    this.resizingNode = null; // { nodeId, handlePosition, startMouseX, startMouseY, startWidth, startHeight, startPosX, startPosY, element, minWidth, minHeight }
    this.clientDimensions = new Map(); // nodeId -> { width, height, x, y }
    this.affectedEdges = [];
  }

  isResizing() {
    return this.resizingNode !== null;
  }

  startResize(nodeId, handlePosition, event) {
    const nodeEl = this.hook.nodeLayer.querySelector(`[data-node-id="${nodeId}"]`);
    if (!nodeEl) return false;

    const [flowX, flowY] = this.hook.coords.eventToFlow(event);

    const resizerEl = event.target.closest('.lf-node-resizer');
    const minWidth = parseFloat(resizerEl?.dataset.minWidth) || 50;
    const minHeight = parseFloat(resizerEl?.dataset.minHeight) || 30;

    this.resizingNode = {
      nodeId,
      handlePosition,
      startMouseX: flowX,
      startMouseY: flowY,
      startWidth: nodeEl.offsetWidth,
      startHeight: nodeEl.offsetHeight,
      startPosX: parseFloat(nodeEl.style.left) || 0,
      startPosY: parseFloat(nodeEl.style.top) || 0,
      element: nodeEl,
      minWidth,
      minHeight
    };

    nodeEl.dataset.resizing = 'true';

    this.cacheAffectedEdges();

    return true;
  }

  moveResize(event) {
    if (!this.resizingNode) return;

    const r = this.resizingNode;
    const [flowX, flowY] = this.hook.coords.eventToFlow(event);
    const dx = flowX - r.startMouseX;
    const dy = flowY - r.startMouseY;

    let newWidth = r.startWidth;
    let newHeight = r.startHeight;
    let newX = r.startPosX;
    let newY = r.startPosY;

    const pos = r.handlePosition;

    // East side: expand width
    if (pos === 'e' || pos === 'ne' || pos === 'se') {
      newWidth = Math.max(r.minWidth, r.startWidth + dx);
    }

    // West side: expand width, shift position
    if (pos === 'w' || pos === 'nw' || pos === 'sw') {
      const maxDx = r.startWidth - r.minWidth;
      const clampedDx = Math.min(dx, maxDx);
      newWidth = r.startWidth - clampedDx;
      newX = r.startPosX + clampedDx;
    }

    // South side: expand height
    if (pos === 's' || pos === 'se' || pos === 'sw') {
      newHeight = Math.max(r.minHeight, r.startHeight + dy);
    }

    // North side: expand height, shift position
    if (pos === 'n' || pos === 'ne' || pos === 'nw') {
      const maxDy = r.startHeight - r.minHeight;
      const clampedDy = Math.min(dy, maxDy);
      newHeight = r.startHeight - clampedDy;
      newY = r.startPosY + clampedDy;
    }

    // Apply CSS immediately
    r.element.style.width = `${newWidth}px`;
    r.element.style.height = `${newHeight}px`;
    r.element.style.left = `${newX}px`;
    r.element.style.top = `${newY}px`;

    // Track for DOM patch recovery
    this.clientDimensions.set(r.nodeId, { width: newWidth, height: newHeight, x: newX, y: newY });

    // Update connected edge paths
    this.updateEdgePaths();
  }

  endResize() {
    if (!this.resizingNode) return;

    const r = this.resizingNode;
    r.element.dataset.resizing = 'false';

    const dims = this.clientDimensions.get(r.nodeId);
    if (dims) {
      const changes = [{
        type: 'resize',
        id: r.nodeId,
        width: dims.width,
        height: dims.height,
        position: { x: dims.x, y: dims.y },
        resizing: false
      }];
      this.hook.pushNodeChange(changes);

      // Update the measured nodes cache so ResizeObserver doesn't
      // send stale dimensions that would overwrite the resize
      if (this.hook._measuredNodes) {
        this.hook._measuredNodes.set(r.nodeId, {
          w: Math.round(dims.width),
          h: Math.round(dims.height)
        });
      }
    }

    this.resizingNode = null;
    // Keep clientDimensions until the next server re-render (updated callback)
    // so the explicit CSS dimensions survive DOM patches
    this._pendingClear = true;
    this.affectedEdges = [];
  }

  /**
   * Called from updated() after a server DOM patch.
   * Clears pending client dimensions once the server has
   * rendered the new width/height in the node style.
   */
  onUpdated() {
    if (this._pendingClear) {
      // Defer clear to AFTER measureNodes() which runs in a rAF from updated().
      // Double-rAF ensures this runs in the next frame, after measureNodes.
      requestAnimationFrame(() => {
        requestAnimationFrame(() => {
          this._pendingClear = false;
          this.clientDimensions.clear();
        });
      });
    }
  }

  reapplyDimensions() {
    if (this.clientDimensions.size === 0) return;

    this.clientDimensions.forEach(({ width, height, x, y }, nodeId) => {
      const el = this.hook.nodeLayer.querySelector(`[data-node-id="${nodeId}"]`);
      if (el) {
        el.style.width = `${width}px`;
        el.style.height = `${height}px`;
        el.style.left = `${x}px`;
        el.style.top = `${y}px`;
      }
    });

    this.updateEdgePaths();
  }

  cacheAffectedEdges() {
    this.affectedEdges = [];
    if (!this.resizingNode) return;

    const nodeId = this.resizingNode.nodeId;
    const edgeGroups = this.hook.edgeLayer.querySelectorAll('g[data-edge-id]');

    edgeGroups.forEach(g => {
      const sourceId = g.dataset.source;
      const targetId = g.dataset.target;
      if (!sourceId || !targetId) return;
      if (sourceId !== nodeId && targetId !== nodeId) return;

      const sourceHandlePos = this.hook.nodeDrag.getHandlePosition(sourceId, g.dataset.sourceHandle, 'source');
      const targetHandlePos = this.hook.nodeDrag.getHandlePosition(targetId, g.dataset.targetHandle, 'target');

      const paths = g.querySelectorAll('path');

      this.affectedEdges.push({
        g,
        paths,
        sourceNodeId: sourceId,
        targetNodeId: targetId,
        sourceHandlePos,
        targetHandlePos,
        labelWrapper: g.querySelector('.lf-edge-label-wrapper'),
        insertWrapper: g.querySelector('.lf-edge-insert-wrapper'),
      });
    });
  }

  getHandleCoords(nodeId, handlePosition) {
    const nodeEl = this.hook.nodeLayer.querySelector(`[data-node-id="${nodeId}"]`);
    if (!nodeEl) return null;

    const dims = this.clientDimensions.get(nodeId);
    const x = dims ? dims.x : (parseFloat(nodeEl.style.left) || 0);
    const y = dims ? dims.y : (parseFloat(nodeEl.style.top) || 0);
    const w = dims ? dims.width : (nodeEl.offsetWidth || 100);
    const h = dims ? dims.height : (nodeEl.offsetHeight || 40);

    switch (handlePosition) {
      case 'top':    return { x: x + w / 2, y: y };
      case 'bottom': return { x: x + w / 2, y: y + h };
      case 'left':   return { x: x, y: y + h / 2 };
      case 'right':  return { x: x + w, y: y + h / 2 };
      default:       return { x: x + w, y: y + h / 2 };
    }
  }

  updateEdgePaths() {
    for (const edge of this.affectedEdges) {
      // Use our getHandleCoords for the resizing node, nodeDrag's for others
      const sourceCoords = this.clientDimensions.has(edge.sourceNodeId)
        ? this.getHandleCoords(edge.sourceNodeId, edge.sourceHandlePos)
        : this.hook.nodeDrag.getHandleCoords(edge.sourceNodeId, edge.sourceHandlePos);
      const targetCoords = this.clientDimensions.has(edge.targetNodeId)
        ? this.getHandleCoords(edge.targetNodeId, edge.targetHandlePos)
        : this.hook.nodeDrag.getHandleCoords(edge.targetNodeId, edge.targetHandlePos);

      if (!sourceCoords || !targetCoords) continue;

      const pathD = calculateBezierPath(
        sourceCoords.x, sourceCoords.y, edge.sourceHandlePos,
        targetCoords.x, targetCoords.y, edge.targetHandlePos
      );

      edge.paths.forEach(p => { p.setAttribute('d', pathD); });

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

  destroy() {
    this.resizingNode = null;
    this.clientDimensions.clear();
    this.affectedEdges = [];
  }
}
