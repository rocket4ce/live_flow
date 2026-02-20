/**
 * Coordinate transformation utilities for LiveFlow
 */
export class CoordinateUtils {
  constructor(hook) {
    this.hook = hook;
  }

  /**
   * Convert screen coordinates to flow space coordinates
   */
  screenToFlow(screenX, screenY) {
    const { x, y, zoom } = this.hook.viewport;
    return [(screenX - x) / zoom, (screenY - y) / zoom];
  }

  /**
   * Convert flow space coordinates to screen coordinates
   */
  flowToScreen(flowX, flowY) {
    const { x, y, zoom } = this.hook.viewport;
    return [flowX * zoom + x, flowY * zoom + y];
  }

  /**
   * Get flow coordinates from a mouse/touch event
   */
  eventToFlow(event) {
    const rect = this.hook.container.getBoundingClientRect();
    const screenX = (event.clientX || event.touches?.[0]?.clientX || 0) - rect.left;
    const screenY = (event.clientY || event.touches?.[0]?.clientY || 0) - rect.top;
    return this.screenToFlow(screenX, screenY);
  }

  /**
   * Get screen coordinates relative to container from event
   */
  eventToScreen(event) {
    const rect = this.hook.container.getBoundingClientRect();
    return [
      (event.clientX || event.touches?.[0]?.clientX || 0) - rect.left,
      (event.clientY || event.touches?.[0]?.clientY || 0) - rect.top
    ];
  }

  /**
   * Snap position to grid
   */
  snapToGrid(x, y, gridX = 15, gridY = 15) {
    return [
      Math.round(x / gridX) * gridX,
      Math.round(y / gridY) * gridY
    ];
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
}
