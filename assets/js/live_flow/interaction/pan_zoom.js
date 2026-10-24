/**
 * Pan and Zoom manager for LiveFlow
 *
 * The client owns the viewport while the user interacts with it. Changes are
 * pushed to the server throttled (lf:viewport_change), and always once more
 * after the interaction ends so the server never keeps a stale viewport.
 */

const PUSH_INTERVAL = 200;
const TRAILING_DELAY = 250;
// Movement (px) under which a pane mousedown/mouseup counts as a click
const CLICK_DISTANCE = 3;

export class PanZoomManager {
  constructor(hook) {
    this.hook = hook;
    this.isPanning = false;
    this.startX = 0;
    this.startY = 0;
    this.startViewport = null;
    this.moved = false;
    this.lastPushTime = 0;
    this.trailingTimer = null;
    this.animationFrame = null;
  }

  get config() {
    return this.hook.config;
  }

  // ===== Drag panning =====

  startPan(event) {
    this.isPanning = true;
    this.moved = false;
    this.startX = event.clientX;
    this.startY = event.clientY;
    this.startViewport = { ...this.hook.viewport };
    this.cancelAnimation();
    this.hook.container.dataset.panning = 'true';
    return true;
  }

  movePan(event) {
    if (!this.isPanning) return;

    const dx = event.clientX - this.startX;
    const dy = event.clientY - this.startY;
    if (!this.moved && Math.hypot(dx, dy) < CLICK_DISTANCE) return;
    this.moved = true;

    this.setViewport({
      x: this.startViewport.x + dx,
      y: this.startViewport.y + dy,
      zoom: this.hook.viewport.zoom,
    });
    // Keep the server informed during long pans (virtualization needs it)
    this.throttledPushViewport();
  }

  /**
   * @returns {boolean} whether the pointer actually moved (false = it was a click)
   */
  endPan() {
    if (!this.isPanning) return false;

    this.isPanning = false;
    this.hook.container.dataset.panning = 'false';
    if (this.moved) this.flushViewport();
    return this.moved;
  }

  /**
   * Move the viewport by a screen-space delta. Used by auto-pan.
   * @returns {boolean} whether the viewport moved
   */
  panBy(dx, dy) {
    if (dx === 0 && dy === 0) return false;
    const { x, y, zoom } = this.hook.viewport;
    this.setViewport({ x: x + dx, y: y + dy, zoom });
    this.throttledPushViewport();
    return true;
  }

  // ===== Wheel =====

  /**
   * Handle a wheel event. Returns true when the event was consumed.
   */
  onWheel(event) {
    const config = this.config;
    // Trackpad pinch gestures arrive as ctrl+wheel
    const isPinch = event.ctrlKey;

    if (isPinch) {
      if (!config.zoomOnPinch) return false;
      this.wheelZoom(event);
      return true;
    }

    if (config.panOnScroll) {
      this.wheelPan(event);
      return true;
    }

    if (config.zoomOnScroll) {
      this.wheelZoom(event);
      return true;
    }

    return false;
  }

  wheelZoom(event) {
    // Same normalization as d3-zoom (used by xyflow)
    const factor = event.deltaMode === 1 ? 0.05 : event.deltaMode ? 1 : 0.002;
    const delta = -event.deltaY * factor * (event.ctrlKey ? 10 : 1);
    const [cx, cy] = this.hook.coords.eventToScreen(event);
    this.zoomAt(this.hook.viewport.zoom * Math.pow(2, delta), cx, cy);
  }

  wheelPan(event) {
    const config = this.config;
    const speed = config.panOnScrollSpeed;
    const deltaNormalize = event.deltaMode === 1 ? 20 : 1;
    let dx = -event.deltaX * deltaNormalize * speed;
    let dy = -event.deltaY * deltaNormalize * speed;

    // Shift+wheel scrolls horizontally on most platforms
    if (event.shiftKey && event.deltaX === 0) {
      dx = dy;
      dy = 0;
    }

    if (config.panOnScrollMode === 'vertical') dx = 0;
    if (config.panOnScrollMode === 'horizontal') dy = 0;

    this.panBy(dx, dy);
  }

  /**
   * Zoom to `zoom`, keeping the screen point (cx, cy) fixed.
   */
  zoomAt(zoom, cx, cy) {
    const newZoom = this.clampZoom(zoom);
    const { x, y, zoom: current } = this.hook.viewport;
    if (newZoom === current) return;

    const scale = newZoom / current;
    this.cancelAnimation();
    this.setViewport({
      x: cx - (cx - x) * scale,
      y: cy - (cy - y) * scale,
      zoom: newZoom,
    });
    this.throttledPushViewport();
  }

  zoomIn(duration = 200) {
    this.zoomTo(this.hook.viewport.zoom * 1.2, duration);
  }

  zoomOut(duration = 200) {
    this.zoomTo(this.hook.viewport.zoom / 1.2, duration);
  }

  /**
   * Zoom to a specific level around the center of the container.
   */
  zoomTo(targetZoom, duration = 200) {
    const zoom = this.clampZoom(targetZoom);
    const rect = this.hook.getContainerRect();
    const centerX = rect.width / 2;
    const centerY = rect.height / 2;

    const start = { ...this.hook.viewport };
    const scale = zoom / start.zoom;
    const target = {
      x: centerX - (centerX - start.x) * scale,
      y: centerY - (centerY - start.y) * scale,
      zoom,
    };

    this.animateViewport(start, target, duration);
  }

  clampZoom(zoom) {
    return Math.max(this.config.minZoom, Math.min(this.config.maxZoom, zoom));
  }

  // ===== Fit view =====

  /**
   * Fit the viewport to nodes.
   *
   * @param {Object} [options]
   * @param {number} [options.padding=0.1]
   * @param {number} [options.duration=200]
   * @param {{x, y, width, height}} [options.bounds] - precomputed flow bounds (from the server)
   * @param {string[]} [options.nodes] - only fit these node ids
   * @param {number} [options.minZoom] / [options.maxZoom]
   */
  fitView(options = {}) {
    const padding = options.padding ?? 0.1;
    const duration = options.duration ?? 200;
    const bounds = options.bounds || this.domBounds(options.nodes);
    if (!bounds) return;

    const rect = this.hook.getContainerRect();
    if (rect.width === 0 || rect.height === 0) return;

    const width = Math.max(bounds.width, 1);
    const height = Math.max(bounds.height, 1);
    const minZoom = Math.max(options.minZoom ?? this.config.minZoom, this.config.minZoom);
    const maxZoom = Math.min(options.maxZoom ?? this.config.maxZoom, this.config.maxZoom);

    const zoom = Math.max(
      minZoom,
      Math.min(
        (rect.width * (1 - padding * 2)) / width,
        (rect.height * (1 - padding * 2)) / height,
        maxZoom
      )
    );

    const centerX = bounds.x + width / 2;
    const centerY = bounds.y + height / 2;

    this.animateViewport(
      this.hook.viewport,
      { x: rect.width / 2 - centerX * zoom, y: rect.height / 2 - centerY * zoom, zoom },
      duration
    );
  }

  /**
   * Bounds of the rendered nodes. Only `.lf-node` wrappers count: handles,
   * resizers and buttons also carry data-node-id but have no position, and
   * would drag the bounds to the origin.
   */
  domBounds(nodeIds) {
    const filter = nodeIds && nodeIds.length > 0 ? new Set(nodeIds) : null;
    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;

    this.hook.nodeLayer?.querySelectorAll('.lf-node[data-node-id]').forEach(el => {
      if (filter && !filter.has(el.dataset.nodeId)) return;
      const x = parseFloat(el.style.left) || 0;
      const y = parseFloat(el.style.top) || 0;
      minX = Math.min(minX, x);
      minY = Math.min(minY, y);
      maxX = Math.max(maxX, x + (el.offsetWidth || 100));
      maxY = Math.max(maxY, y + (el.offsetHeight || 40));
    });

    if (minX === Infinity) return null;
    return { x: minX, y: minY, width: maxX - minX, height: maxY - minY };
  }

  // ===== Viewport updates =====

  setViewport(viewport) {
    this.hook.viewport = viewport;
    this.hook.applyViewportTransform();
  }

  animateViewport(start, target, duration = 200) {
    this.cancelAnimation();

    if (!duration) {
      this.setViewport(target);
      this.flushViewport();
      return;
    }

    const startTime = performance.now();
    const animate = (now) => {
      const progress = Math.min((now - startTime) / duration, 1);
      const eased = easeOutCubic(progress);

      this.setViewport({
        x: start.x + (target.x - start.x) * eased,
        y: start.y + (target.y - start.y) * eased,
        zoom: start.zoom + (target.zoom - start.zoom) * eased,
      });

      if (progress < 1) {
        this.animationFrame = requestAnimationFrame(animate);
      } else {
        this.animationFrame = null;
        this.flushViewport();
      }
    };

    this.animationFrame = requestAnimationFrame(animate);
  }

  cancelAnimation() {
    if (this.animationFrame) {
      cancelAnimationFrame(this.animationFrame);
      this.animationFrame = null;
    }
  }

  /**
   * Throttled viewport push with trailing debounce. Pushes at most every
   * 200ms during continuous interaction and always sends the final state
   * once the interaction stops.
   */
  throttledPushViewport() {
    const now = Date.now();

    if (this.trailingTimer) clearTimeout(this.trailingTimer);

    if (now - this.lastPushTime >= PUSH_INTERVAL) {
      this.lastPushTime = now;
      this.hook.pushViewportChange();
    }

    this.trailingTimer = setTimeout(() => this.flushViewport(), TRAILING_DELAY);
  }

  /**
   * Push the current viewport right away and drop any pending trailing push.
   */
  flushViewport() {
    if (this.trailingTimer) {
      clearTimeout(this.trailingTimer);
      this.trailingTimer = null;
    }
    this.lastPushTime = Date.now();
    this.hook.pushViewportChange();
  }

  destroy() {
    this.isPanning = false;
    this.cancelAnimation();
    if (this.trailingTimer) {
      clearTimeout(this.trailingTimer);
      this.trailingTimer = null;
    }
  }
}

function easeOutCubic(t) {
  return 1 - Math.pow(1 - t, 3);
}
