/**
 * Pan and Zoom manager for LiveFlow
 */
export class PanZoomManager {
  constructor(hook) {
    this.hook = hook;
    this.isPanning = false;
    this.startX = 0;
    this.startY = 0;
    this.startViewport = null;
    this.lastPushTime = 0;
  }

  /**
   * Start panning
   */
  startPan(event) {
    if (!this.hook.config.panOnDrag) return false;

    this.isPanning = true;
    this.startX = event.clientX;
    this.startY = event.clientY;
    this.startViewport = { ...this.hook.viewport };
    this.hook.container.dataset.panning = 'true';
    return true;
  }

  /**
   * Handle pan movement
   */
  movePan(event) {
    if (!this.isPanning) return;

    const dx = event.clientX - this.startX;
    const dy = event.clientY - this.startY;

    this.hook.viewport.x = this.startViewport.x + dx;
    this.hook.viewport.y = this.startViewport.y + dy;
    this.hook.applyViewportTransform();
  }

  /**
   * End panning
   */
  endPan() {
    if (!this.isPanning) return;

    this.isPanning = false;
    this.hook.container.dataset.panning = 'false';
    this.hook.pushViewportChange();
  }

  /**
   * Handle wheel zoom
   */
  zoom(delta, centerX, centerY) {
    if (!this.hook.config.zoomOnScroll) return;

    const factor = 1 - delta * 0.001;
    const newZoom = Math.max(
      this.hook.config.minZoom,
      Math.min(this.hook.config.maxZoom, this.hook.viewport.zoom * factor)
    );

    // Zoom towards cursor position
    const { x, y, zoom } = this.hook.viewport;
    const scale = newZoom / zoom;

    this.hook.viewport = {
      x: centerX - (centerX - x) * scale,
      y: centerY - (centerY - y) * scale,
      zoom: newZoom
    };

    this.hook.applyViewportTransform();
    this.throttledPushViewport();
  }

  /**
   * Zoom to a specific level
   */
  zoomTo(targetZoom, duration = 200) {
    const zoom = Math.max(
      this.hook.config.minZoom,
      Math.min(this.hook.config.maxZoom, targetZoom)
    );

    if (duration === 0) {
      this.hook.viewport.zoom = zoom;
      this.hook.applyViewportTransform();
      this.hook.pushViewportChange();
      return;
    }

    const containerRect = this.hook.containerRect;
    const centerX = containerRect.width / 2;
    const centerY = containerRect.height / 2;

    const start = { ...this.hook.viewport };
    const scale = zoom / start.zoom;
    const target = {
      x: centerX - (centerX - start.x) * scale,
      y: centerY - (centerY - start.y) * scale,
      zoom: zoom
    };

    this.animateViewport(start, target, duration);
  }

  /**
   * Fit view to content
   */
  fitView(padding = 0.1, duration = 200) {
    const nodes = this.hook.nodeLayer.querySelectorAll('[data-node-id]');
    if (nodes.length === 0) return;

    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;

    nodes.forEach(nodeEl => {
      const x = parseFloat(nodeEl.style.left) || 0;
      const y = parseFloat(nodeEl.style.top) || 0;
      const width = nodeEl.offsetWidth || 100;
      const height = nodeEl.offsetHeight || 40;

      minX = Math.min(minX, x);
      minY = Math.min(minY, y);
      maxX = Math.max(maxX, x + width);
      maxY = Math.max(maxY, y + height);
    });

    const graphWidth = maxX - minX || 100;
    const graphHeight = maxY - minY || 100;

    const paddedWidth = this.hook.containerRect.width * (1 - padding * 2);
    const paddedHeight = this.hook.containerRect.height * (1 - padding * 2);

    const zoom = Math.min(
      paddedWidth / graphWidth,
      paddedHeight / graphHeight,
      this.hook.config.maxZoom
    );

    const centerX = minX + graphWidth / 2;
    const centerY = minY + graphHeight / 2;

    const x = this.hook.containerRect.width / 2 - centerX * zoom;
    const y = this.hook.containerRect.height / 2 - centerY * zoom;

    this.animateViewport(this.hook.viewport, { x, y, zoom }, duration);
  }

  /**
   * Animate viewport transition
   */
  animateViewport(start, target, duration) {
    const startTime = performance.now();

    const animate = (currentTime) => {
      const elapsed = currentTime - startTime;
      const progress = Math.min(elapsed / duration, 1);
      const eased = this.easeOutCubic(progress);

      this.hook.viewport = {
        x: start.x + (target.x - start.x) * eased,
        y: start.y + (target.y - start.y) * eased,
        zoom: start.zoom + (target.zoom - start.zoom) * eased
      };

      this.hook.applyViewportTransform();

      if (progress < 1) {
        requestAnimationFrame(animate);
      } else {
        this.hook.pushViewportChange();
      }
    };

    requestAnimationFrame(animate);
  }

  /**
   * Throttled viewport push
   */
  throttledPushViewport() {
    const now = Date.now();
    if (now - this.lastPushTime >= 100) {
      this.lastPushTime = now;
      this.hook.pushViewportChange();
    }
  }

  /**
   * Easing function
   */
  easeOutCubic(t) {
    return 1 - Math.pow(1 - t, 3);
  }

  destroy() {
    this.isPanning = false;
  }
}
