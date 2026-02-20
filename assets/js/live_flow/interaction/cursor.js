/**
 * CursorManager - Built-in remote cursor rendering for LiveFlow
 *
 * Handles rendering remote user cursors within the flow container,
 * broadcasting local cursor position, and repositioning cursors
 * when the viewport changes. Uses lerp interpolation for smooth
 * remote cursor movement.
 */
export class CursorManager {
  constructor(hook) {
    this.hook = hook;
    this.cursors = {};
    this.lastCursorPush = 0;
    this.throttleMs = 50;
    this._animating = false;

    this.overlayEl = hook.container.querySelector('.lf-cursor-overlay');
  }

  /**
   * Handle local mouse movement — broadcast cursor position in flow-space.
   * Throttled to avoid flooding the server.
   */
  handleMouseMove(event) {
    const now = Date.now();
    if (now - this.lastCursorPush < this.throttleMs) return;
    this.lastCursorPush = now;

    const vp = this.hook.viewport;
    const rect = this.hook.container.getBoundingClientRect();
    const screenX = event.clientX - rect.left;
    const screenY = event.clientY - rect.top;

    const flowX = (screenX - vp.x) / vp.zoom;
    const flowY = (screenY - vp.y) / vp.zoom;

    this.hook.pushEvent('lf:cursor_move', { x: flowX, y: flowY });
  }

  /**
   * Update or create a remote cursor element.
   * Sets target position for smooth lerp interpolation.
   */
  updateCursor(userId, flowX, flowY, color, name) {
    let cursor = this.cursors[userId];
    if (!cursor) {
      cursor = this.createCursorElement(userId, color, name);
      this.cursors[userId] = cursor;
      // Initialize at target position (no lerp on first appearance)
      cursor.flowX = flowX;
      cursor.flowY = flowY;
    }
    cursor.targetX = flowX;
    cursor.targetY = flowY;
    this._startAnimation();
  }

  /**
   * Remove a remote cursor (user left).
   */
  removeCursor(userId) {
    const cursor = this.cursors[userId];
    if (cursor) {
      cursor.element.remove();
      delete this.cursors[userId];
    }
  }

  /**
   * Reposition all cursors after a viewport change.
   */
  repositionAll() {
    for (const cursor of Object.values(this.cursors)) {
      this.positionCursor(cursor);
    }
  }

  /**
   * Clean up all cursor elements and listeners.
   */
  destroy() {
    this._animating = false;
    for (const cursor of Object.values(this.cursors)) {
      cursor.element.remove();
    }
    this.cursors = {};
  }

  // Private

  _startAnimation() {
    if (this._animating) return;
    this._animating = true;
    this._animate();
  }

  _animate() {
    if (!this._animating) return;

    let needsMore = false;
    for (const cursor of Object.values(this.cursors)) {
      if (cursor.targetX === undefined) continue;
      const dx = cursor.targetX - cursor.flowX;
      const dy = cursor.targetY - cursor.flowY;
      if (Math.abs(dx) > 0.5 || Math.abs(dy) > 0.5) {
        cursor.flowX += dx * 0.35;
        cursor.flowY += dy * 0.35;
        needsMore = true;
      } else {
        cursor.flowX = cursor.targetX;
        cursor.flowY = cursor.targetY;
      }
      this.positionCursor(cursor);
    }

    if (needsMore) {
      requestAnimationFrame(() => this._animate());
    } else {
      this._animating = false;
    }
  }

  createCursorElement(userId, color, name) {
    const el = document.createElement('div');
    el.className = 'lf-remote-cursor';
    el.dataset.userId = userId;
    el.innerHTML =
      '<svg width="16" height="20" viewBox="0 0 16 20" fill="none">' +
        '<path d="M0 0L16 12L8 12L6 20L0 0Z" fill="' + color + '" stroke="white" stroke-width="1"/>' +
      '</svg>' +
      '<span class="lf-remote-cursor-label" style="background:' + color + '">' + name + '</span>';

    if (this.overlayEl) {
      this.overlayEl.appendChild(el);
    }

    return { element: el, flowX: 0, flowY: 0, targetX: undefined, targetY: undefined, color, name };
  }

  positionCursor(cursor) {
    const vp = this.hook.viewport;
    const screenX = cursor.flowX * vp.zoom + vp.x;
    const screenY = cursor.flowY * vp.zoom + vp.y;
    cursor.element.style.transform = 'translate(' + screenX + 'px, ' + screenY + 'px)';
  }
}
