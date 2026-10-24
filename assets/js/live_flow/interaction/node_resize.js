/**
 * Node resize manager for LiveFlow
 *
 * Handles interactive resizing of nodes via resize handles. Like drag,
 * width/height are updated client-side during resize for zero-latency
 * feedback.
 *
 * Server notifications mirror xyflow's onResizeStart/onResizeEnd: a `resize`
 * change with `resizing: true` is pushed when the pointer first moves, and
 * it is always followed by a final `resize` change with `resizing: false`
 * (on pointer up, and also when the resize is aborted).
 */

const clamp = (value, min, max) => Math.min(Math.max(value, min), max);

export class NodeResizeManager {
  constructor(hook) {
    this.hook = hook;
    this.resizingNode = null;
    this.clientDimensions = new Map(); // nodeId -> { width, height, x, y }
    this.affectedEdges = [];
    this._pendingClear = false;
  }

  isResizing() {
    return this.resizingNode !== null;
  }

  startResize(nodeId, handlePosition, event) {
    const nodeEl = this.hook.nodeEl(nodeId);
    if (!nodeEl) return false;

    const [flowX, flowY] = this.hook.coords.eventToFlow(event);
    const resizerEl = event.target.closest('.lf-node-resizer');
    const data = resizerEl?.dataset || {};

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
      minWidth: parseFloat(data.minWidth) || 10,
      minHeight: parseFloat(data.minHeight) || 10,
      maxWidth: parseFloat(data.maxWidth) || Infinity,
      maxHeight: parseFloat(data.maxHeight) || Infinity,
      keepAspectRatio: data.keepAspectRatio === 'true',
      started: false,
    };

    nodeEl.dataset.resizing = 'true';
    this.affectedEdges = this.hook.edges.collect(new Set([nodeId]));

    return true;
  }

  moveResize(event) {
    const r = this.resizingNode;
    if (!r) return;

    const { width, height, x, y } = this.computeDimensions(event);

    if (!r.started) {
      if (width === r.startWidth && height === r.startHeight) return;
      r.started = true;
      this.pushResize(r.startWidth, r.startHeight, r.startPosX, r.startPosY, true);
    }

    r.element.style.width = `${width}px`;
    r.element.style.height = `${height}px`;
    r.element.style.left = `${x}px`;
    r.element.style.top = `${y}px`;

    // Track for DOM patch recovery and edge updates
    this.clientDimensions.set(r.nodeId, { width, height, x, y });
    this.hook.edges.update(this.affectedEdges, this.clientDimensions);
  }

  computeDimensions(event) {
    const r = this.resizingNode;
    const [flowX, flowY] = this.hook.coords.eventToFlow(event);
    const dx = flowX - r.startMouseX;
    const dy = flowY - r.startMouseY;
    const pos = r.handlePosition;

    const east = pos.includes('e');
    const west = pos.includes('w');
    const south = pos.includes('s');
    const north = pos.includes('n');

    let width = r.startWidth + (east ? dx : west ? -dx : 0);
    let height = r.startHeight + (south ? dy : north ? -dy : 0);

    const { snapToGrid, snapGridX, snapGridY } = this.hook.config;
    if (snapToGrid) {
      const right = r.startPosX + r.startWidth;
      const bottom = r.startPosY + r.startHeight;
      if (east) width = Math.round((r.startPosX + width) / snapGridX) * snapGridX - r.startPosX;
      if (west) width = right - Math.round((right - width) / snapGridX) * snapGridX;
      if (south) height = Math.round((r.startPosY + height) / snapGridY) * snapGridY - r.startPosY;
      if (north) height = bottom - Math.round((bottom - height) / snapGridY) * snapGridY;
    }

    // Size constraints
    const ratio = r.startWidth / (r.startHeight || 1);
    if (r.keepAspectRatio) {
      const horizontal = east || west;
      const vertical = north || south;
      const followWidth = horizontal && (!vertical ||
        Math.abs(width - r.startWidth) / r.startWidth >= Math.abs(height - r.startHeight) / r.startHeight);
      if (followWidth) {
        height = width / ratio;
      } else {
        width = height * ratio;
      }
    }

    width = clamp(width, r.minWidth, r.maxWidth);
    height = clamp(height, r.minHeight, r.maxHeight);
    if (r.keepAspectRatio) {
      // Re-apply the ratio after clamping, without breaking the limits again
      if (width / height > ratio) width = clamp(height * ratio, r.minWidth, r.maxWidth);
      else height = clamp(width / ratio, r.minHeight, r.maxHeight);
    }

    let x = west ? r.startPosX + r.startWidth - width : r.startPosX;
    let y = north ? r.startPosY + r.startHeight - height : r.startPosY;

    // Never resize past the node extent
    const extent = this.hook.config.nodeExtent;
    if (extent) {
      const [[minX, minY], [maxX, maxY]] = extent;
      if (x < minX) {
        width -= minX - x;
        x = minX;
      }
      if (y < minY) {
        height -= minY - y;
        y = minY;
      }
      if (x + width > maxX) width = maxX - x;
      if (y + height > maxY) height = maxY - y;
    }

    return { width, height, x, y };
  }

  endResize() {
    const r = this.resizingNode;
    if (!r) return false;

    r.element.dataset.resizing = 'false';
    const dims = this.clientDimensions.get(r.nodeId);

    if (r.started && dims) {
      this.pushResize(dims.width, dims.height, dims.x, dims.y, false);

      // Update the measured nodes cache so ResizeObserver doesn't
      // send stale dimensions that would overwrite the resize
      this.hook._measuredNodes?.set(r.nodeId, { w: Math.round(dims.width), h: Math.round(dims.height) });

      // Keep clientDimensions until the server re-renders (see onUpdated)
      this._pendingClear = true;
    } else {
      this.clientDimensions.clear();
    }

    this.resizingNode = null;
    this.affectedEdges = [];
    return r.started;
  }

  /**
   * Abort the resize and restore the start dimensions.
   */
  abortResize() {
    const r = this.resizingNode;
    if (!r) return;

    r.element.dataset.resizing = 'false';
    r.element.style.width = r.started ? `${r.startWidth}px` : r.element.style.width;
    r.element.style.height = r.started ? `${r.startHeight}px` : r.element.style.height;
    r.element.style.left = `${r.startPosX}px`;
    r.element.style.top = `${r.startPosY}px`;

    if (r.started) {
      const start = { width: r.startWidth, height: r.startHeight, x: r.startPosX, y: r.startPosY };
      this.hook.edges.update(this.affectedEdges, new Map([[r.nodeId, start]]));
      this.pushResize(r.startWidth, r.startHeight, r.startPosX, r.startPosY, false);
    }

    this.clientDimensions.clear();
    this.resizingNode = null;
    this.affectedEdges = [];
  }

  pushResize(width, height, x, y, resizing) {
    this.hook.pushNodeChange([{
      type: 'resize',
      id: this.resizingNode.nodeId,
      width,
      height,
      position: { x, y },
      resizing,
    }]);
  }

  /**
   * Called from updated() after a server DOM patch.
   * Clears pending client dimensions once the server has
   * rendered the new width/height in the node style.
   */
  onUpdated() {
    if (!this._pendingClear) return;
    // Defer the clear to after measureNodes(), which runs in a rAF from updated()
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        this._pendingClear = false;
        this.clientDimensions.clear();
      });
    });
  }

  reapplyDimensions() {
    if (this.clientDimensions.size === 0) return;

    this.clientDimensions.forEach(({ width, height, x, y }, nodeId) => {
      const el = this.hook.nodeEl(nodeId);
      if (el) {
        el.style.width = `${width}px`;
        el.style.height = `${height}px`;
        el.style.left = `${x}px`;
        el.style.top = `${y}px`;
      }
    });

    this.hook.edges.updateForNodes(new Set(this.clientDimensions.keys()), this.clientDimensions);
    if (this.resizingNode) {
      this.affectedEdges = this.hook.edges.collect(new Set([this.resizingNode.nodeId]));
    }
  }

  destroy() {
    this.resizingNode = null;
    this.clientDimensions.clear();
    this.affectedEdges = [];
  }
}
