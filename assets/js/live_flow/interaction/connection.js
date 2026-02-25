/**
 * Connection manager for LiveFlow
 * Handles creating edges by dragging from handles.
 * Draws the preview line client-side for instant feedback.
 */
import { calculateBezierPath } from '../utils/paths.js';

const SVG_NS = 'http://www.w3.org/2000/svg';

export class ConnectionManager {
  constructor(hook) {
    this.hook = hook;
    this.connecting = null;
    this.previewSvg = null;
  }

  /**
   * Check if currently connecting
   */
  isConnecting() {
    return this.connecting !== null;
  }

  /**
   * Start a connection from a handle
   */
  startConnection(nodeId, handleId, handleType, handlePosition, event) {
    if (!this.hook.config.nodesConnectable) return false;

    const handleEl = this.hook.container.querySelector(
      `[data-node-id="${nodeId}"] [data-handle-id="${handleId}"]`
    );
    if (!handleEl) return false;

    // Get handle center position in flow coordinates
    const rect = handleEl.getBoundingClientRect();
    const containerRect = this.hook.container.getBoundingClientRect();
    const screenX = rect.left + rect.width / 2 - containerRect.left;
    const screenY = rect.top + rect.height / 2 - containerRect.top;
    const [flowX, flowY] = this.hook.coords.screenToFlow(screenX, screenY);

    this.connecting = {
      nodeId,
      handleId,
      handleType,
      handlePosition: handlePosition || 'right',
      connectType: handleEl.dataset.handleConnectType || null,
      startX: flowX,
      startY: flowY,
      currentX: flowX,
      currentY: flowY
    };

    // Create SVG preview overlay (outside LiveView-managed DOM)
    this.createPreviewOverlay(flowX, flowY);

    return true;
  }

  /**
   * Move the connection preview — client-side only, no server event
   */
  moveConnection(event) {
    if (!this.connecting) return;

    const [flowX, flowY] = this.hook.coords.eventToFlow(event);
    this.connecting.currentX = flowX;
    this.connecting.currentY = flowY;

    // Update preview line in DOM directly
    this.updatePreviewLine(flowX, flowY);

    // Check for valid target handles
    this.checkHandleHover(event);
  }

  /**
   * End the connection attempt
   */
  endConnection(event) {
    if (!this.connecting) return;

    // If reconnecting, use the reconnect-specific handler
    if (this.connecting.reconnecting) {
      this.endReconnect(event);
      return;
    }

    // Remove preview
    this.removePreviewOverlay();

    // Find target handle under cursor
    const target = this.findTargetHandle(event);

    if (target && this.isValidConnection(this.connecting, target)) {
      const isSourceHandle = this.connecting.handleType === 'source';

      this.hook.pushEvent('lf:connect_end', {
        source: isSourceHandle ? this.connecting.nodeId : target.nodeId,
        source_handle: isSourceHandle ? this.connecting.handleId : target.handleId,
        target: isSourceHandle ? target.nodeId : this.connecting.nodeId,
        target_handle: isSourceHandle ? target.handleId : this.connecting.handleId
      });
    } else {
      this.hook.pushEvent('lf:connect_cancel', {});
    }

    this.connecting = null;
    this.clearHandleHighlights();
  }

  // ===== SVG Preview Overlay =====
  // Uses a dedicated SVG element outside the LiveView-managed edge layer,
  // so LiveView DOM patches won't remove it during the connection drag.

  createPreviewOverlay(startX, startY) {
    this.removePreviewOverlay();

    // Create an SVG that overlays the viewport with the same transform
    const svg = document.createElementNS(SVG_NS, 'svg');
    svg.setAttribute('class', 'lf-preview-overlay');
    svg.style.cssText = 'position:absolute;top:0;left:0;width:100%;height:100%;pointer-events:none;overflow:visible;z-index:1;';

    // Apply the same viewport transform as the main viewport
    const { x, y, zoom } = this.hook.viewport;
    const g = document.createElementNS(SVG_NS, 'g');
    g.setAttribute('transform', `translate(${x}, ${y}) scale(${zoom})`);

    const path = document.createElementNS(SVG_NS, 'path');
    path.setAttribute('class', 'lf-connection-line');
    path.setAttribute('d', `M ${startX},${startY} L ${startX},${startY}`);

    g.appendChild(path);
    svg.appendChild(g);

    // Append to container (the hook element) — not inside the LV-managed viewport
    this.hook.container.appendChild(svg);
    this.previewSvg = svg;
  }

  updatePreviewLine(toX, toY) {
    if (!this.previewSvg || !this.connecting) return;

    const g = this.previewSvg.querySelector('g');
    const pathEl = this.previewSvg.querySelector('path');
    if (!g || !pathEl) return;

    // Keep the transform in sync with the viewport
    const { x, y, zoom } = this.hook.viewport;
    g.setAttribute('transform', `translate(${x}, ${y}) scale(${zoom})`);

    const { startX, startY, handlePosition } = this.connecting;
    const d = calculateBezierPath(startX, startY, handlePosition, toX, toY);
    pathEl.setAttribute('d', d);
  }

  removePreviewOverlay() {
    if (this.previewSvg) {
      this.previewSvg.remove();
      this.previewSvg = null;
    }
  }

  // ===== Target Detection =====

  findTargetHandle(event) {
    const elements = document.elementsFromPoint(event.clientX, event.clientY);

    for (const el of elements) {
      if (el.dataset.handleId && el.dataset.handleConnectable !== 'false') {
        const nodeEl = el.closest('[data-node-id]');
        if (nodeEl && nodeEl.dataset.nodeId !== this.connecting.nodeId) {
          return {
            nodeId: nodeEl.dataset.nodeId,
            handleId: el.dataset.handleId,
            handleType: el.dataset.handleType,
            handlePosition: el.dataset.handlePosition,
            connectType: el.dataset.handleConnectType || null
          };
        }
      }
    }
    return null;
  }

  isValidConnection(source, target) {
    if (source.nodeId === target.nodeId) return false;
    if (source.handleType === target.handleType) return false;
    // Client-side type hint: if both handles have a connect_type, they must match
    if (source.connectType && target.connectType && source.connectType !== target.connectType) {
      return false;
    }
    return true;
  }

  isTypeCompatible(source, target) {
    if (!source.connectType || !target.connectType) return true;
    return source.connectType === target.connectType;
  }

  checkHandleHover(event) {
    const target = this.findTargetHandle(event);
    this.clearHandleHighlights();

    if (target) {
      const handleEl = this.hook.container.querySelector(
        `[data-node-id="${target.nodeId}"] [data-handle-id="${target.handleId}"]`
      );
      if (handleEl) {
        if (this.isValidConnection(this.connecting, target)) {
          handleEl.dataset.connecting = 'valid';
        } else {
          handleEl.dataset.connecting = 'invalid';
        }
      }
    }
  }

  clearHandleHighlights() {
    this.hook.container.querySelectorAll('[data-connecting]').forEach(el => {
      delete el.dataset.connecting;
    });
  }

  // ===== Reconnect Edge =====

  /**
   * Start reconnecting an existing edge by dragging one of its endpoints.
   * @param {string} edgeId - The edge being reconnected
   * @param {string} end - 'source' or 'target' — which end is being dragged
   * @param {Event} event - The mouse/touch event
   */
  startReconnect(edgeId, end, event) {
    // Find the edge group in SVG to get its endpoint positions
    const edgeGroup = this.hook.container.querySelector(`[data-edge-id="${edgeId}"].lf-edge-group`);
    if (!edgeGroup) return false;

    const source = edgeGroup.dataset.source;
    const target = edgeGroup.dataset.target;
    const sourceHandle = edgeGroup.dataset.sourceHandle || null;
    const targetHandle = edgeGroup.dataset.targetHandle || null;

    // The "anchor" end is the one that stays fixed
    // The "dragged" end is the one the user is moving
    const anchorNodeId = end === 'source' ? target : source;
    const anchorHandleId = end === 'source' ? targetHandle : sourceHandle;

    // Find the anchor handle's position
    const anchorHandleEl = anchorHandleId
      ? this.hook.container.querySelector(`[data-node-id="${anchorNodeId}"] [data-handle-id="${anchorHandleId}"]`)
      : this.hook.container.querySelector(`[data-node-id="${anchorNodeId}"] [data-handle-type="${end === 'source' ? 'target' : 'source'}"]`);

    if (!anchorHandleEl) return false;

    const rect = anchorHandleEl.getBoundingClientRect();
    const containerRect = this.hook.container.getBoundingClientRect();
    const screenX = rect.left + rect.width / 2 - containerRect.left;
    const screenY = rect.top + rect.height / 2 - containerRect.top;
    const [flowX, flowY] = this.hook.coords.screenToFlow(screenX, screenY);

    const handlePosition = anchorHandleEl.dataset.handlePosition || (end === 'source' ? 'left' : 'right');

    this.connecting = {
      nodeId: anchorNodeId,
      handleId: anchorHandleId,
      handleType: end === 'source' ? 'target' : 'source',
      handlePosition,
      connectType: anchorHandleEl.dataset.handleConnectType || null,
      startX: flowX,
      startY: flowY,
      currentX: flowX,
      currentY: flowY,
      reconnecting: true,
      reconnectEdgeId: edgeId,
      reconnectEnd: end
    };

    // Create preview overlay from the anchor point
    this.createPreviewOverlay(flowX, flowY);

    return true;
  }

  /**
   * End a reconnect attempt
   */
  endReconnect(event) {
    if (!this.connecting || !this.connecting.reconnecting) return;

    this.removePreviewOverlay();

    const target = this.findTargetHandle(event);
    const { reconnectEdgeId, reconnectEnd } = this.connecting;

    if (target && this.isValidConnection(this.connecting, target)) {
      // Reconnect to the new handle
      this.hook.pushEvent('lf:reconnect_edge', {
        edge_id: reconnectEdgeId,
        end: reconnectEnd,
        node_id: target.nodeId,
        handle_id: target.handleId
      });
    } else {
      // Dropped on empty space — delete the edge
      this.hook.pushEvent('lf:delete_reconnect_edge', {
        edge_id: reconnectEdgeId
      });
    }

    this.connecting = null;
    this.clearHandleHighlights();
  }

  /**
   * Check if we're in reconnect mode
   */
  isReconnecting() {
    return this.connecting !== null && this.connecting.reconnecting === true;
  }

  destroy() {
    this.removePreviewOverlay();
    this.connecting = null;
    this.clearHandleHighlights();
  }
}
