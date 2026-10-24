/**
 * Coordinate transformation utilities for LiveFlow
 *
 * Event conversions use the hook's cached container rect, so hot paths
 * (wheel, drag, connection moves) never force a synchronous layout.
 */
export class CoordinateUtils {
  constructor(hook) {
    this.hook = hook;
  }

  /**
   * Convert screen coordinates (relative to the container) to flow coordinates.
   *
   * @param {Object} [options]
   * @param {boolean} [options.snapToGrid=false]
   * @param {[number, number]} [options.snapGrid] - defaults to the flow's snap grid
   */
  screenToFlow(screenX, screenY, options = {}) {
    const { x, y, zoom } = this.hook.viewport;
    const flowX = (screenX - x) / zoom;
    const flowY = (screenY - y) / zoom;

    if (options.snapToGrid) {
      const [gridX, gridY] = options.snapGrid || [this.hook.config.snapGridX, this.hook.config.snapGridY];
      return this.snapToGrid(flowX, flowY, gridX, gridY);
    }

    return [flowX, flowY];
  }

  /**
   * Convert flow coordinates to screen coordinates (relative to the container).
   */
  flowToScreen(flowX, flowY) {
    const { x, y, zoom } = this.hook.viewport;
    return [flowX * zoom + x, flowY * zoom + y];
  }

  /**
   * Get flow coordinates from a mouse/touch event
   */
  eventToFlow(event, options) {
    const [screenX, screenY] = this.eventToScreen(event);
    return this.screenToFlow(screenX, screenY, options);
  }

  /**
   * Get screen coordinates relative to container from event
   */
  eventToScreen(event) {
    const rect = this.hook.getContainerRect();
    const point = event.touches?.[0] || event.changedTouches?.[0] || event;
    return [(point.clientX ?? 0) - rect.left, (point.clientY ?? 0) - rect.top];
  }

  /**
   * Snap position to grid
   */
  snapToGrid(x, y, gridX = 15, gridY = 15) {
    return [Math.round(x / gridX) * gridX, Math.round(y / gridY) * gridY];
  }

  /**
   * Calculate distance between two points
   */
  distance(x1, y1, x2, y2) {
    return Math.sqrt((x2 - x1) ** 2 + (y2 - y1) ** 2);
  }

  /**
   * Check if a point is inside a rectangle
   */
  pointInRect(px, py, rx, ry, rw, rh) {
    return px >= rx && px <= rx + rw && py >= ry && py <= ry + rh;
  }

  /**
   * Check if two rectangles intersect
   */
  rectsIntersect(r1, r2) {
    return !(
      r1.x + r1.width < r2.x ||
      r2.x + r2.width < r1.x ||
      r1.y + r1.height < r2.y ||
      r2.y + r2.height < r1.y
    );
  }

  /**
   * Check if r1 is fully inside r2
   */
  rectContains(r2, r1) {
    return (
      r1.x >= r2.x &&
      r1.y >= r2.y &&
      r1.x + r1.width <= r2.x + r2.width &&
      r1.y + r1.height <= r2.y + r2.height
    );
  }
}
