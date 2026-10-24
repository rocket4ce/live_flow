/**
 * Connection manager for LiveFlow
 * Handles creating edges by dragging from handles and reconnecting existing
 * edges. The preview line is drawn client-side in the interaction layer
 * (phx-update="ignore") for instant feedback.
 */
import { getEdgePath, oppositePosition } from '../utils/paths.js';

const SVG_NS = 'http://www.w3.org/2000/svg';

export class ConnectionManager {
  constructor(hook) {
    this.hook = hook;
    this.connecting = null;
    this.previewSvg = null;
    this.lastEvent = null;
    this.hoveredHandle = null;
  }

  isConnecting() {
    return this.connecting !== null;
  }

  isReconnecting() {
    return this.connecting !== null && this.connecting.reconnecting === true;
  }

  /**
   * Start a connection from a handle
   */
  startConnection(nodeId, handleId, handleType, handlePosition, event) {
    if (!this.hook.config.nodesConnectable) return false;

    const handleEl = this.findHandleEl(nodeId, handleId, handleType);
    if (!handleEl || handleEl.dataset.handleConnectable === 'false') return false;

    const [flowX, flowY] = this.handleCenter(handleEl);

    this.connecting = {
      nodeId,
      handleId,
      handleType,
      handlePosition: handlePosition || 'right',
      connectType: handleEl.dataset.handleConnectType || null,
      startX: flowX,
      startY: flowY,
      currentX: flowX,
      currentY: flowY,
      extraSources: this.extraSources(nodeId, handleId, handleType),
    };

    this.begin(event);
    if (this.hook.config.connectionEvents) {
      this.hook.pushEvent('lf:connect_start', { node_id: nodeId, handle_id: handleId, handle_type: handleType });
    }
    return true;
  }

  /**
   * multi_connection: dragging from a selected node also drags a line from
   * every other selected node (same handle id, or the first handle of the type).
   */
  extraSources(nodeId, handleId, handleType) {
    if (!this.hook.config.multiConnection || !this.hook.selectedNodes.has(nodeId)) return [];

    const sources = [];
    this.hook.selectedNodes.forEach(id => {
      if (id === nodeId) return;
      const el = this.findHandleEl(id, handleId, handleType);
      if (!el || el.dataset.handleConnectable === 'false' || el.dataset.handleType !== handleType) return;
      const [x, y] = this.handleCenter(el);
      sources.push({ nodeId: id, handleId: el.dataset.handleId, handlePosition: el.dataset.handlePosition, startX: x, startY: y });
    });
    return sources;
  }

  /**
   * Start reconnecting an existing edge by dragging one of its endpoints.
   * @param {string} edgeId - The edge being reconnected
   * @param {string} end - 'source' or 'target' — which end is being dragged
   */
  startReconnect(edgeId, end, event) {
    if (!this.hook.config.nodesConnectable) return false;

    const edgeGroup = this.hook.edgeLayer?.querySelector(`g.lf-edge-group[data-edge-id="${CSS.escape(edgeId)}"]`);
    if (!edgeGroup) return false;

    const { source, target } = edgeGroup.dataset;
    const sourceHandle = edgeGroup.dataset.sourceHandle || null;
    const targetHandle = edgeGroup.dataset.targetHandle || null;

    // The anchor end stays fixed, the other one follows the pointer
    const anchorNodeId = end === 'source' ? target : source;
    const anchorHandleId = end === 'source' ? targetHandle : sourceHandle;
    const anchorType = end === 'source' ? 'target' : 'source';

    const anchorHandleEl = this.findHandleEl(anchorNodeId, anchorHandleId, anchorType);
    if (!anchorHandleEl) return false;

    const [flowX, flowY] = this.handleCenter(anchorHandleEl);

    this.connecting = {
      nodeId: anchorNodeId,
      handleId: anchorHandleEl.dataset.handleId || anchorHandleId,
      handleType: anchorType,
      handlePosition: anchorHandleEl.dataset.handlePosition || (end === 'source' ? 'left' : 'right'),
      connectType: anchorHandleEl.dataset.handleConnectType || null,
      startX: flowX,
      startY: flowY,
      currentX: flowX,
      currentY: flowY,
      reconnecting: true,
      reconnectEdgeId: edgeId,
      reconnectEnd: end,
    };

    this.begin(event);
    return true;
  }

  begin(event) {
    this.lastEvent = event;
    this.startClient = { x: event.clientX, y: event.clientY };
    this.moved = false;
    this.createPreviewOverlay();
    this.updatePreviewLine();

    if (this.hook.config.autoPanOnConnect) {
      this.hook.autoPan.start(() => this.moveConnection(this.lastEvent));
    }
  }

  /**
   * Move the connection preview — client-side only, no server event
   */
  moveConnection(event) {
    if (!this.connecting || !event) return;
    this.lastEvent = event;
    if (!this.moved && Math.hypot(event.clientX - this.startClient.x, event.clientY - this.startClient.y) > 3) {
      this.moved = true;
    }
    if (!this.connecting.clickMode) this.hook.autoPan.update(event);

    const [flowX, flowY] = this.hook.coords.eventToFlow(event);
    this.connecting.currentX = flowX;
    this.connecting.currentY = flowY;

    this.updateHoveredHandle(event);
    this.updatePreviewLine();
  }

  /**
   * Finish the connection attempt.
   */
  endConnection(event) {
    if (!this.connecting) return;

    // Releasing outside of the flow cancels, it never deletes a reconnected edge
    if (!this.isInsideContainer(event)) {
      this.abortConnection();
      return;
    }

    const target = this.findTargetHandle(event);
    const valid = target && this.isValidConnection(this.connecting, target);

    if (this.connecting.reconnecting) {
      const { reconnectEdgeId, reconnectEnd } = this.connecting;
      if (valid) {
        this.hook.pushEvent('lf:reconnect_edge', {
          edge_id: reconnectEdgeId,
          end: reconnectEnd,
          node_id: target.nodeId,
          handle_id: target.handleId,
        });
      } else {
        // Dropped on empty space — delete the edge (or e.g. move a temporary edge there)
        this.hook.pushEvent('lf:delete_reconnect_edge', {
          edge_id: reconnectEdgeId,
          end: reconnectEnd,
          position: { x: this.connecting.currentX, y: this.connecting.currentY },
        });
      }
    } else if (valid) {
      const fromSource = this.connecting.handleType === 'source';
      const sources = [this.connecting, ...this.connecting.extraSources];
      sources.forEach(source => {
        if (source.nodeId === target.nodeId) return;
        this.hook.pushEvent('lf:connect_end', {
          source: fromSource ? source.nodeId : target.nodeId,
          source_handle: fromSource ? source.handleId : target.handleId,
          target: fromSource ? target.nodeId : source.nodeId,
          target_handle: fromSource ? target.handleId : source.handleId,
        });
      });
    } else {
      this.pushCancel(target ? 'invalid' : 'pane', target);
    }

    this.cleanup();
  }

  /**
   * Cancel without creating, reconnecting or deleting anything (Escape, blur).
   */
  abortConnection() {
    if (!this.connecting) return;
    if (!this.connecting.reconnecting) this.pushCancel('abort');
    this.cleanup();
  }

  /**
   * lf:connect_cancel tells where the line was released (flow coordinates),
   * e.g. to add a node where a connection is dropped on the pane.
   */
  pushCancel(reason, target = null) {
    const { nodeId, handleId, handleType, currentX, currentY } = this.connecting;
    this.hook.pushEvent('lf:connect_cancel', {
      node_id: nodeId,
      handle_id: handleId,
      handle_type: handleType,
      position: { x: currentX, y: currentY },
      reason,
      // the handle that refused the connection (reason "invalid")
      ...(target && { target_node_id: target.nodeId, target_handle_id: target.handleId }),
    });
  }

  // ===== Connect on click (connect_on_click) =====

  hasMoved() {
    return this.moved;
  }

  isClickConnecting() {
    return this.connecting?.clickMode === true;
  }

  /**
   * The handle was clicked without dragging: keep the line attached to the
   * pointer until another handle (or the pane) is clicked.
   */
  startClickMode() {
    if (!this.connecting) return;
    this.connecting.clickMode = true;
    this.hook.autoPan.stop();
    const handleEl = this.findHandleEl(this.connecting.nodeId, this.connecting.handleId, this.connecting.handleType);
    if (handleEl) handleEl.dataset.connectingSource = 'true';
  }

  cleanup() {
    this.hook.autoPan.stop();
    this.removePreviewOverlay();
    this.clearHandleHighlights();
    this.hook.container.querySelectorAll('[data-connecting-source]').forEach(el => {
      delete el.dataset.connectingSource;
    });
    this.connecting = null;
    this.lastEvent = null;
    this.hoveredHandle = null;
  }

  /**
   * Recompute the start point from the handle element (its node may have
   * moved, e.g. with arrow keys or a remote drag).
   */
  refreshStart() {
    if (!this.connecting) return;
    const { nodeId, handleId, handleType } = this.connecting;
    const handleEl = this.findHandleEl(nodeId, handleId, handleType);
    if (!handleEl) return;

    [this.connecting.startX, this.connecting.startY] = this.handleCenter(handleEl);
    this.updatePreviewLine();
  }

  // ===== SVG preview =====

  createPreviewOverlay() {
    this.removePreviewOverlay();

    const svg = document.createElementNS(SVG_NS, 'svg');
    svg.setAttribute('class', 'lf-connection-preview');

    const g = document.createElementNS(SVG_NS, 'g');
    const { connectionLineClass, connectionLineStyle } = this.hook.config;
    const count = 1 + (this.connecting?.extraSources?.length || 0);

    for (let i = 0; i < count; i++) {
      const path = document.createElementNS(SVG_NS, 'path');
      path.setAttribute('class', ['lf-connection-line', connectionLineClass].filter(Boolean).join(' '));
      if (connectionLineStyle) path.setAttribute('style', connectionLineStyle);
      g.appendChild(path);
    }

    svg.appendChild(g);
    this.hook.interactionLayer.appendChild(svg);
    this.previewSvg = svg;
  }

  updatePreviewLine() {
    if (!this.previewSvg || !this.connecting) return;

    const g = this.previewSvg.firstChild;

    // Keep the transform in sync with the viewport (auto-pan, zoom while connecting)
    const { x, y, zoom } = this.hook.viewport;
    g.setAttribute('transform', `translate(${x}, ${y}) scale(${zoom})`);

    const { currentX, currentY, handlePosition } = this.connecting;
    // Snap the end of the line to the hovered handle
    const end = this.hoveredHandle
      ? { x: this.hoveredHandle.x, y: this.hoveredHandle.y, position: this.hoveredHandle.handlePosition }
      : { x: currentX, y: currentY, position: oppositePosition(handlePosition) };

    const sources = [this.connecting, ...(this.connecting.extraSources || [])];
    sources.forEach((source, i) => {
      const { path } = getEdgePath(
        this.hook.config.connectionLineType,
        { x: source.startX, y: source.startY, position: source.handlePosition || handlePosition },
        end
      );
      g.children[i]?.setAttribute('d', path);
    });
  }

  removePreviewOverlay() {
    if (this.previewSvg) {
      this.previewSvg.remove();
      this.previewSvg = null;
    }
  }

  // ===== Target detection =====

  /**
   * Handle under the pointer, or the closest one within `connection_radius`.
   */
  findTargetHandle(event) {
    if (event.clientX === undefined) return null;

    for (const el of document.elementsFromPoint(event.clientX, event.clientY)) {
      if (el.dataset?.handleType && this.hook.container.contains(el)) {
        const candidate = this.toCandidate(el);
        if (candidate) return candidate;
      }
    }

    const radius = this.hook.config.connectionRadius;
    if (!radius) return null;

    let closest = null;
    let closestDistance = radius;
    this.hook.nodeLayer?.querySelectorAll('[data-handle-type]').forEach(el => {
      const rect = el.getBoundingClientRect();
      const distance = Math.hypot(
        rect.left + rect.width / 2 - event.clientX,
        rect.top + rect.height / 2 - event.clientY
      );
      if (distance < closestDistance) {
        const candidate = this.toCandidate(el);
        if (candidate && this.isValidConnection(this.connecting, candidate)) {
          closest = candidate;
          closestDistance = distance;
        }
      }
    });

    return closest;
  }

  toCandidate(handleEl) {
    if (handleEl.dataset.handleConnectable === 'false') return null;
    const nodeEl = handleEl.closest('.lf-node[data-node-id]');
    if (!nodeEl || nodeEl.dataset.nodeId === this.connecting.nodeId) return null;

    const [x, y] = this.handleCenter(handleEl);
    return {
      el: handleEl,
      nodeId: nodeEl.dataset.nodeId,
      handleId: handleEl.dataset.handleId,
      handleType: handleEl.dataset.handleType,
      handlePosition: handleEl.dataset.handlePosition,
      connectType: handleEl.dataset.handleConnectType || null,
      x,
      y,
    };
  }

  isValidConnection(source, target) {
    if (source.nodeId === target.nodeId) return false;
    // Strict mode (default) only connects source <-> target handles
    if (this.hook.config.connectionMode !== 'loose' && source.handleType === target.handleType) return false;
    // Client-side type hint: if both handles have a connect_type, they must match
    if (source.connectType && target.connectType && source.connectType !== target.connectType) {
      return false;
    }
    return true;
  }

  updateHoveredHandle(event) {
    const target = this.findTargetHandle(event);
    if (target?.el === this.hoveredHandle?.el) return;

    this.clearHandleHighlights();
    this.hoveredHandle = null;

    if (target) {
      const valid = this.isValidConnection(this.connecting, target);
      target.el.dataset.connecting = valid ? 'valid' : 'invalid';
      if (valid) this.hoveredHandle = target;
    }
  }

  clearHandleHighlights() {
    this.hook.container.querySelectorAll('[data-connecting]').forEach(el => {
      delete el.dataset.connecting;
    });
  }

  // ===== Helpers =====

  findHandleEl(nodeId, handleId, handleType) {
    const nodeEl = this.hook.nodeEl(nodeId);
    if (!nodeEl) return null;
    if (handleId) {
      const el = nodeEl.querySelector(`[data-handle-id="${CSS.escape(handleId)}"]`);
      if (el) return el;
    }
    return handleType ? nodeEl.querySelector(`[data-handle-type="${handleType}"]`) : null;
  }

  handleCenter(handleEl) {
    const rect = handleEl.getBoundingClientRect();
    const containerRect = this.hook.getContainerRect();
    return this.hook.coords.screenToFlow(
      rect.left + rect.width / 2 - containerRect.left,
      rect.top + rect.height / 2 - containerRect.top
    );
  }

  isInsideContainer(event) {
    if (event.clientX === undefined) return true;
    const rect = this.hook.getContainerRect();
    return (
      event.clientX >= rect.left &&
      event.clientX <= rect.left + rect.width &&
      event.clientY >= rect.top &&
      event.clientY <= rect.top + rect.height
    );
  }

  destroy() {
    this.cleanup();
  }
}
