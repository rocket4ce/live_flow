/**
 * CursorOverlay Hook
 *
 * Manages rendering of remote user cursors and broadcasting
 * the local user's cursor position in flow-space coordinates.
 */
export const CursorOverlayHook = {
  mounted() {
    this.userId = this.el.dataset.userId;
    this.cursors = {};
    this.lastCursorPush = 0;

    this.flowContainer = this.el.parentElement.querySelector('.lf-container');

    this.onMouseMove = (event) => {
      const now = Date.now();
      if (now - this.lastCursorPush < 100) return;
      this.lastCursorPush = now;

      const viewport = this.getViewport();
      if (!viewport) return;

      const rect = this.flowContainer.getBoundingClientRect();
      const screenX = event.clientX - rect.left;
      const screenY = event.clientY - rect.top;

      const flowX = (screenX - viewport.x) / viewport.zoom;
      const flowY = (screenY - viewport.y) / viewport.zoom;

      this.pushEvent("lf:cursor_move", { x: flowX, y: flowY });
    };

    if (this.flowContainer) {
      this.flowContainer.addEventListener('mousemove', this.onMouseMove);
    }

    this.viewportRAF = null;
    this.scheduleRepositionLoop();

    this.handleEvent("remote_cursor", (data) => {
      this.updateCursor(data.user_id, data.x, data.y, data.color, data.name);
    });

    this.handleEvent("cursor_leave", (data) => {
      this.removeCursor(data.user_id);
    });
  },

  destroyed() {
    if (this.flowContainer) {
      this.flowContainer.removeEventListener('mousemove', this.onMouseMove);
    }
    if (this.viewportRAF) cancelAnimationFrame(this.viewportRAF);
    Object.values(this.cursors).forEach(c => c.element?.remove());
  },

  getViewport() {
    const viewportEl = this.flowContainer?.querySelector('.lf-viewport');
    if (!viewportEl) return null;

    const transform = viewportEl.style.transform;
    const match = transform.match(/translate\(([-\d.]+)px,\s*([-\d.]+)px\)\s*scale\(([-\d.]+)\)/);
    if (!match) return { x: 0, y: 0, zoom: 1 };

    return {
      x: parseFloat(match[1]),
      y: parseFloat(match[2]),
      zoom: parseFloat(match[3])
    };
  },

  updateCursor(userId, flowX, flowY, color, name) {
    let cursor = this.cursors[userId];
    if (!cursor) {
      cursor = this.createCursorElement(userId, color, name);
      this.cursors[userId] = cursor;
    }
    cursor.flowX = flowX;
    cursor.flowY = flowY;
    this.positionCursor(cursor);
  },

  removeCursor(userId) {
    const cursor = this.cursors[userId];
    if (cursor) {
      cursor.element.remove();
      delete this.cursors[userId];
    }
  },

  createCursorElement(userId, color, name) {
    const el = document.createElement('div');
    el.className = 'lf-remote-cursor';
    el.dataset.userId = userId;
    el.innerHTML =
      '<svg width="16" height="20" viewBox="0 0 16 20" fill="none">' +
        '<path d="M0 0L16 12L8 12L6 20L0 0Z" fill="' + color + '" stroke="white" stroke-width="1"/>' +
      '</svg>' +
      '<span class="lf-remote-cursor-label" style="background:' + color + '">' + name + '</span>';
    this.el.appendChild(el);
    return { element: el, flowX: 0, flowY: 0, color, name };
  },

  positionCursor(cursor) {
    const vp = this.getViewport();
    if (!vp) return;

    const screenX = cursor.flowX * vp.zoom + vp.x;
    const screenY = cursor.flowY * vp.zoom + vp.y;

    cursor.element.style.transform = 'translate(' + screenX + 'px, ' + screenY + 'px)';
  },

  scheduleRepositionLoop() {
    let lastTransform = '';
    const check = () => {
      this.viewportRAF = requestAnimationFrame(check);
      const viewportEl = this.flowContainer?.querySelector('.lf-viewport');
      if (!viewportEl) return;
      const transform = viewportEl.style.transform;
      if (transform !== lastTransform) {
        lastTransform = transform;
        Object.values(this.cursors).forEach(c => this.positionCursor(c));
      }
    };
    check();
  }
};
