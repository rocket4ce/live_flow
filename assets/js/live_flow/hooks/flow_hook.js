/**
 * LiveFlow - Main Phoenix LiveView Hook
 *
 * This hook handles all client-side interactions for the flow diagram,
 * including pan/zoom, node dragging, connection creation, and selection.
 */

import { CoordinateUtils } from '../utils/coordinates.js';
import { PanZoomManager } from '../interaction/pan_zoom.js';
import { NodeDragManager } from '../interaction/node_drag.js';
import { ConnectionManager } from '../interaction/connection.js';
import { SelectionManager } from '../interaction/selection.js';
import { CursorManager } from '../interaction/cursor.js';
import { HelperLinesManager } from '../interaction/helper_lines.js';
import { exportSVG, exportPNG, downloadString, downloadBlob } from '../utils/export.js';
import { calculateBezierPath } from '../utils/paths.js';
import { getLayoutedElements } from '../utils/layout.js';

export const LiveFlowHook = {
  mounted() {
    // Parse configuration from data attributes
    this.config = {
      minZoom: parseFloat(this.el.dataset.minZoom) || 0.1,
      maxZoom: parseFloat(this.el.dataset.maxZoom) || 4.0,
      panOnDrag: this.el.dataset.panOnDrag !== 'false',
      zoomOnScroll: this.el.dataset.zoomOnScroll !== 'false',
      snapToGrid: this.el.hasAttribute('data-snap-to-grid'),
      snapGridX: parseFloat(this.el.dataset.snapGridX) || 15,
      snapGridY: parseFloat(this.el.dataset.snapGridY) || 15,
      nodesDraggable: this.el.dataset.nodesDraggable !== 'false',
      nodesConnectable: this.el.dataset.nodesConnectable !== 'false',
      elementsSelectable: this.el.dataset.elementsSelectable !== 'false',
      fitViewOnInit: this.el.hasAttribute('data-fit-view-on-init'),
      cursors: this.el.hasAttribute('data-cursors'),
      helperLines: this.el.hasAttribute('data-helper-lines')
    };

    // State
    this.viewport = { x: 0, y: 0, zoom: 1 };
    this.selectedNodes = new Set();
    this.selectedEdges = new Set();
    this.interactionMode = null; // 'pan' | 'drag' | 'connect' | 'select'

    // DOM references
    this.container = this.el;
    this.viewportEl = this.el.querySelector('.lf-viewport');
    this.nodeLayer = this.el.querySelector('[data-node-layer]');
    this.edgeLayer = this.el.querySelector('[data-edge-layer]');

    // Initialize managers
    this.coords = new CoordinateUtils(this);
    this.panZoom = new PanZoomManager(this);
    this.nodeDrag = new NodeDragManager(this);
    this.connection = new ConnectionManager(this);
    this.selection = new SelectionManager(this);

    // Initialize cursor manager if collaboration cursors are enabled
    if (this.config.cursors) {
      this.cursor = new CursorManager(this);
    }

    // Initialize helper lines manager if enabled
    if (this.config.helperLines) {
      this.helperLines = new HelperLinesManager(this);
    }

    // Initialize
    this.measureContainer();
    this.setupEventListeners();
    this.setupResizeObserver();
    this.setupNodeObserver();

    // Register server-pushed event handlers
    this.handleEvent('lf:fit_view', (payload) => {
      this.panZoom.fitView(payload.padding, payload.duration);
    });
    this.handleEvent('lf:zoom_to', (payload) => {
      this.panZoom.zoomTo(payload.zoom, payload.duration);
    });
    this.handleEvent('lf:pan_to', (payload) => {
      this.panZoom.animateViewport(this.viewport, {
        x: payload.x,
        y: payload.y,
        zoom: this.viewport.zoom
      }, payload.duration || 200);
    });
    this.handleEvent('lf:set_viewport', (payload) => {
      this.viewport = { x: payload.x, y: payload.y, zoom: payload.zoom };
      this.applyViewportTransform();
    });

    // Cursor collaboration events
    this.handleEvent('lf:remote_cursor', (data) => {
      if (this.cursor) {
        this.cursor.updateCursor(data.user_id, data.x, data.y, data.color, data.name);
      }
    });
    this.handleEvent('lf:cursor_leave', (data) => {
      if (this.cursor) {
        this.cursor.removeCursor(data.user_id);
      }
    });

    // Remote drag — update node positions and edge paths directly in DOM (no re-render)
    this.handleEvent('lf:remote_drag', (data) => {
      if (!data.changes) return;
      const movedIds = new Set();
      for (const change of data.changes) {
        const el = this.nodeLayer?.querySelector(`[data-node-id="${change.id}"]`);
        if (el && change.position) {
          el.style.left = `${change.position.x}px`;
          el.style.top = `${change.position.y}px`;
          movedIds.add(change.id);
        }
      }
      if (movedIds.size > 0) {
        this._updateEdgesForNodes(movedIds);
      }
    });

    // Export handlers — expose globally and listen for DOM events
    const self = this;
    window.LiveFlowExport = {
      exportSVG() {
        const svgString = exportSVG(self.container);
        if (svgString) {
          downloadString(svgString, 'flow.svg', 'image/svg+xml');
        }
      },
      exportPNG() {
        exportPNG(self.container).then(blob => {
          downloadBlob(blob, 'flow.png');
        }).catch(err => console.error('PNG export failed:', err));
      }
    };

    // Auto-layout via ELK
    this.el.addEventListener('lf:auto-layout', (e) => {
      const direction = e.detail?.direction || 'DOWN';
      this.pushEvent('lf:request_layout', { direction });
    });
    this.handleEvent('lf:layout_data', (data) => {
      const options = {};
      if (data.direction) {
        options['elk.direction'] = data.direction;
      }
      // Override server dimensions with actual DOM measurements to prevent overlaps
      const nodes = data.nodes.map(node => {
        const el = this.nodeLayer?.querySelector(`[data-node-id="${node.id}"]`);
        if (el) {
          return { ...node, width: el.offsetWidth || node.width, height: el.offsetHeight || node.height };
        }
        return node;
      });
      getLayoutedElements(nodes, data.edges, options).then(positioned => {
        const changes = positioned.map(n => ({
          type: 'position',
          id: n.id,
          position: { x: n.x, y: n.y },
          dragging: false,
        }));
        this.pushNodeChange(changes);
        requestAnimationFrame(() => this.panZoom.fitView());
      }).catch(err => console.error('Auto-layout failed:', err));
    });

    // Tree layout (pure JS, no ELK)
    this.handleEvent('lf:tree_layout_data', async (data) => {
      const { treeLayout } = await import('../utils/tree_layout.js');
      // Override server dimensions with actual DOM measurements to prevent overlaps
      const nodes = data.nodes.map(node => {
        const el = this.nodeLayer?.querySelector(`[data-node-id="${node.id}"]`);
        if (el) {
          return { ...node, width: el.offsetWidth || node.width, height: el.offsetHeight || node.height };
        }
        return node;
      });
      const positioned = treeLayout(nodes, data.edges, data.options);

      // Enable CSS transitions on all nodes
      const nodeEls = this.nodeLayer?.querySelectorAll('.lf-node[data-node-id]');
      nodeEls?.forEach(el => el.dataset.layoutAnimating = 'true');

      // Push new positions
      const changes = positioned.map(n => ({
        type: 'position',
        id: n.id,
        position: { x: n.x, y: n.y },
        dragging: false,
      }));
      this.pushNodeChange(changes);

      // Remove animation flag after transition, then fit view
      setTimeout(() => {
        nodeEls?.forEach(el => delete el.dataset.layoutAnimating);
        this.panZoom.fitView(0.1, 300);
      }, 450);
    });

    // Listen for DOM events dispatched via JS.dispatch (stays in user gesture context)
    this.el.addEventListener('lf:export-svg', () => window.LiveFlowExport.exportSVG());
    this.el.addEventListener('lf:export-png', () => window.LiveFlowExport.exportPNG());

    // Also support push_event from server
    this.handleEvent('lf:export_svg', () => window.LiveFlowExport.exportSVG());
    this.handleEvent('lf:export_png', () => window.LiveFlowExport.exportPNG());

    // Measure initial nodes after first render
    requestAnimationFrame(() => {
      this.measureNodes();
      // Fit view on init if configured
      if (this.config.fitViewOnInit) {
        requestAnimationFrame(() => this.panZoom.fitView());
      }
    });
  },

  destroyed() {
    this.panZoom.destroy();
    this.nodeDrag.destroy();
    this.connection.destroy();
    this.selection.destroy();
    this.cursor?.destroy();
    this.helperLines?.destroy();
    this.resizeObserver?.disconnect();
    this.nodeObserver?.disconnect();
    this.nodeResizeObserver?.disconnect();
    this.removeEventListeners();
  },

  updated() {
    // Re-measure container on updates
    this.measureContainer();
    // Re-apply client-side viewport transform after DOM patch — the server
    // may have an older viewport state, and its re-render would overwrite
    // the CSS transform causing a visible zoom/pan jump.
    this.applyViewportTransform();
    // Re-apply client-side drag positions after DOM patch to prevent jitter
    if (this.nodeDrag.isDragging()) {
      this.nodeDrag.reapplyPositions();
    }
    // Measure any new or changed nodes
    requestAnimationFrame(() => this.measureNodes());
  },

  // ===== Event Listeners Setup =====

  setupEventListeners() {
    // Bind event handlers
    this.onWheel = this.onWheel.bind(this);
    this.onMouseDown = this.onMouseDown.bind(this);
    this.onMouseMove = this.onMouseMove.bind(this);
    this.onMouseUp = this.onMouseUp.bind(this);
    this.onKeyDown = this.onKeyDown.bind(this);
    this.onKeyUp = this.onKeyUp.bind(this);

    // Container events
    this.container.addEventListener('wheel', this.onWheel, { passive: false });
    this.container.addEventListener('mousedown', this.onMouseDown);
    this.container.addEventListener('mousemove', this.onMouseMove);
    this.container.addEventListener('mouseup', this.onMouseUp);
    this.container.addEventListener('mouseleave', this.onMouseUp);

    // Touch support
    this.container.addEventListener('touchstart', this.onTouchStart.bind(this), { passive: false });
    this.container.addEventListener('touchmove', this.onTouchMove.bind(this), { passive: false });
    this.container.addEventListener('touchend', this.onTouchEnd.bind(this));

    // Edge label double-click editing
    this.onEdgeLabelDblClick = this.onEdgeLabelDblClick.bind(this);
    this.container.addEventListener('dblclick', this.onEdgeLabelDblClick);

    // Keyboard
    document.addEventListener('keydown', this.onKeyDown);
    document.addEventListener('keyup', this.onKeyUp);
  },

  removeEventListeners() {
    this.container.removeEventListener('wheel', this.onWheel);
    this.container.removeEventListener('mousedown', this.onMouseDown);
    this.container.removeEventListener('mousemove', this.onMouseMove);
    this.container.removeEventListener('mouseup', this.onMouseUp);
    this.container.removeEventListener('mouseleave', this.onMouseUp);
    this.container.removeEventListener('dblclick', this.onEdgeLabelDblClick);
    document.removeEventListener('keydown', this.onKeyDown);
    document.removeEventListener('keyup', this.onKeyUp);
  },

  setupResizeObserver() {
    this.resizeObserver = new ResizeObserver(() => {
      this.measureContainer();
    });
    this.resizeObserver.observe(this.container);
  },

  // ===== Measurement =====

  measureContainer() {
    const rect = this.container.getBoundingClientRect();
    this.containerRect = {
      width: rect.width,
      height: rect.height,
      left: rect.left,
      top: rect.top
    };
  },

  /**
   * Measure all node dimensions and send changes to server.
   * Only measures .lf-node elements (not handles or other children).
   */
  measureNodes() {
    const nodeEls = this.nodeLayer?.querySelectorAll('.lf-node[data-node-id]');
    if (!nodeEls) return;

    const changes = [];
    if (!this._measuredNodes) this._measuredNodes = new Map();

    nodeEls.forEach(el => {
      const nodeId = el.dataset.nodeId;
      const w = el.offsetWidth;
      const h = el.offsetHeight;
      if (w === 0 && h === 0) return;

      const prev = this._measuredNodes.get(nodeId);
      if (!prev || prev.w !== w || prev.h !== h) {
        this._measuredNodes.set(nodeId, { w, h });
        changes.push({ type: 'dimensions', id: nodeId, width: w, height: h });
      }
    });

    if (changes.length > 0) {
      this.pushNodeChange(changes);
    }

    // Observe new nodes for resize
    if (this.nodeResizeObserver) {
      nodeEls.forEach(el => {
        if (!el._lfObserved) {
          this.nodeResizeObserver.observe(el);
          el._lfObserved = true;
        }
      });
    }
  },

  /**
   * Set up observers to detect new/resized nodes
   */
  setupNodeObserver() {
    this._measuredNodes = new Map();

    // ResizeObserver for individual node elements
    this.nodeResizeObserver = new ResizeObserver(entries => {
      const changes = [];
      for (const entry of entries) {
        const el = entry.target;
        if (!el.classList.contains('lf-node')) continue;
        const nodeId = el.dataset?.nodeId;
        if (!nodeId) continue;

        const w = el.offsetWidth;
        const h = el.offsetHeight;
        if (w === 0 && h === 0) continue;

        const prev = this._measuredNodes.get(nodeId);
        if (!prev || prev.w !== w || prev.h !== h) {
          this._measuredNodes.set(nodeId, { w, h });
          changes.push({ type: 'dimensions', id: nodeId, width: w, height: h });
        }
      }
      if (changes.length > 0) {
        this.pushNodeChange(changes);
      }
    });

    // MutationObserver to detect new nodes added to the DOM (debounced)
    this._measureTimer = null;
    this.nodeObserver = new MutationObserver(() => {
      if (this._measureTimer) return;
      this._measureTimer = requestAnimationFrame(() => {
        this._measureTimer = null;
        this.measureNodes();
      });
    });

    if (this.nodeLayer) {
      this.nodeObserver.observe(this.nodeLayer, { childList: true });
    }
  },

  // ===== Event Handlers =====

  onWheel(event) {
    event.preventDefault();
    const rect = this.container.getBoundingClientRect();
    const centerX = event.clientX - rect.left;
    const centerY = event.clientY - rect.top;
    this.panZoom.zoom(event.deltaY, centerX, centerY);
  },

  onMouseDown(event) {
    // Check what was clicked
    const target = event.target;
    const nodeEl = target.closest('[data-node-id]');
    const handleEl = target.closest('[data-handle-id]');

    // Handle click
    if (handleEl && nodeEl) {
      // Start connection from handle
      event.preventDefault();
      this.interactionMode = 'connect';
      this.connection.startConnection(
        nodeEl.dataset.nodeId,
        handleEl.dataset.handleId,
        handleEl.dataset.handleType,
        handleEl.dataset.handlePosition,
        event
      );
      return;
    }

    // Node delete button click
    const nodeDeleteBtn = target.closest('.lf-node-delete-btn');
    if (nodeDeleteBtn) {
      event.preventDefault();
      event.stopPropagation();
      const nodeId = nodeDeleteBtn.dataset.nodeId;
      if (nodeId) {
        this.pushNodeChange([{ type: 'remove', id: nodeId }]);
      }
      return;
    }

    // Node click
    if (nodeEl) {
      // Allow interaction with form elements inside nodes (no drag, no preventDefault)
      const isInteractive = target.closest('input, select, textarea, button:not(.lf-node-delete-btn), [contenteditable], .nodrag');
      if (isInteractive) {
        const multi = event.shiftKey || event.ctrlKey || event.metaKey;
        this.selection.selectNode(nodeEl.dataset.nodeId, { multi, toggle: multi });
        return;
      }

      event.preventDefault();

      // Select node
      const multi = event.shiftKey || event.ctrlKey || event.metaKey;
      this.selection.selectNode(nodeEl.dataset.nodeId, { multi, toggle: multi });

      // Start drag
      if (this.nodeDrag.startDrag(nodeEl.dataset.nodeId, event)) {
        this.interactionMode = 'drag';
      }
      return;
    }

    // Edge insert "+" button click
    const insertBtn = target.closest('.lf-edge-insert-btn');
    if (insertBtn) {
      event.preventDefault();
      event.stopPropagation();
      this.pushEvent('lf:insert_on_edge', { edge_id: insertBtn.dataset.edgeId });
      return;
    }

    // Edge delete button click
    const deleteBtn = target.closest('.lf-edge-delete-btn');
    if (deleteBtn) {
      event.preventDefault();
      event.stopPropagation();
      const edgeId = deleteBtn.dataset.edgeId;
      if (edgeId) {
        this.pushEdgeChange([{ type: 'remove', id: edgeId }]);
      }
      return;
    }

    // Edge click
    const edgeEl = target.closest('[data-edge-id]');
    if (edgeEl && (target.classList.contains('lf-edge-interaction') || target.classList.contains('lf-edge'))) {
      event.preventDefault();
      const multi = event.shiftKey || event.ctrlKey || event.metaKey;
      this.selection.selectEdge(edgeEl.dataset.edgeId, { multi, toggle: multi });
      return;
    }

    // Background click
    if (event.button === 0) {
      // Left click - start pan or selection
      if (event.shiftKey) {
        // Shift + click = box selection
        this.interactionMode = 'select';
        this.selection.startSelection(event);
      } else {
        // Regular click - clear selection and start pan
        this.selection.clearSelection();
        this.interactionMode = 'pan';
        this.panZoom.startPan(event);
      }
    }
  },

  onMouseMove(event) {
    // Broadcast cursor position for collaboration (runs regardless of interaction mode)
    this.cursor?.handleMouseMove(event);

    switch (this.interactionMode) {
      case 'pan':
        this.panZoom.movePan(event);
        break;
      case 'drag':
        this.nodeDrag.moveDrag(event);
        break;
      case 'connect':
        this.connection.moveConnection(event);
        break;
      case 'select':
        this.selection.moveSelection(event);
        break;
    }
  },

  onMouseUp(event) {
    switch (this.interactionMode) {
      case 'pan':
        this.panZoom.endPan();
        break;
      case 'drag':
        this.nodeDrag.endDrag();
        break;
      case 'connect':
        this.connection.endConnection(event);
        break;
      case 'select':
        this.selection.endSelection();
        break;
    }
    this.interactionMode = null;
  },

  // ===== Touch Support =====

  _touchState: null,

  onTouchStart(event) {
    const touches = event.touches;

    if (touches.length === 2) {
      // Pinch-to-zoom / two-finger pan start
      event.preventDefault();
      this._cancelLongPress();
      // If single-touch was active, cancel it
      if (this.interactionMode === 'drag' || this.interactionMode === 'pan') {
        this.onMouseUp(event);
      }
      this._touchState = {
        type: 'pinch',
        startDist: this._touchDistance(touches),
        startZoom: this.viewport.zoom,
        startMidX: (touches[0].clientX + touches[1].clientX) / 2,
        startMidY: (touches[0].clientY + touches[1].clientY) / 2,
        lastMidX: (touches[0].clientX + touches[1].clientX) / 2,
        lastMidY: (touches[0].clientY + touches[1].clientY) / 2,
        startVpX: this.viewport.x,
        startVpY: this.viewport.y
      };
      return;
    }

    if (touches.length === 1) {
      event.preventDefault();
      const touch = touches[0];
      const target = touch.target;

      // Check if touching a node
      const nodeEl = target.closest('.lf-node-wrapper');
      if (nodeEl) {
        // Start long-press timer for selection
        this._longPressTimer = setTimeout(() => {
          this._longPressTimer = null;
          // Trigger a selection event (node already gets selected by mousedown)
        }, 500);
      }

      this._touchState = { type: 'single', startX: touch.clientX, startY: touch.clientY };
      this.onMouseDown(this._touchToMouse(event));
    }
  },

  onTouchMove(event) {
    const touches = event.touches;

    if (touches.length === 2 && this._touchState?.type === 'pinch') {
      event.preventDefault();
      const ts = this._touchState;
      const currentDist = this._touchDistance(touches);
      const midX = (touches[0].clientX + touches[1].clientX) / 2;
      const midY = (touches[0].clientY + touches[1].clientY) / 2;

      // Pinch zoom
      const scale = currentDist / ts.startDist;
      const newZoom = Math.max(
        this.config.minZoom,
        Math.min(this.config.maxZoom, ts.startZoom * scale)
      );

      // Pan (mid-point movement)
      const panDx = midX - ts.lastMidX;
      const panDy = midY - ts.lastMidY;

      // Zoom towards midpoint
      const zoomScale = newZoom / this.viewport.zoom;
      this.viewport = {
        x: midX - (midX - this.viewport.x) * zoomScale + panDx,
        y: midY - (midY - this.viewport.y) * zoomScale + panDy,
        zoom: newZoom
      };

      ts.lastMidX = midX;
      ts.lastMidY = midY;

      this.applyViewportTransform();
      this.panZoom.throttledPushViewport();
      return;
    }

    if (touches.length === 1 && this._touchState?.type === 'single') {
      event.preventDefault();
      // Cancel long-press if finger moved significantly
      const touch = touches[0];
      const dx = touch.clientX - this._touchState.startX;
      const dy = touch.clientY - this._touchState.startY;
      if (Math.abs(dx) > 10 || Math.abs(dy) > 10) {
        this._cancelLongPress();
      }
      this.onMouseMove(this._touchToMouse(event));
    }
  },

  onTouchEnd(event) {
    this._cancelLongPress();

    if (this._touchState?.type === 'pinch') {
      // End of pinch — don't trigger mouse events
      if (event.touches.length === 0) {
        this._touchState = null;
        this.pushViewportChange();
      } else if (event.touches.length === 1) {
        // Went from 2 fingers to 1 — transition to single touch pan
        this._touchState = {
          type: 'single',
          startX: event.touches[0].clientX,
          startY: event.touches[0].clientY
        };
      }
      return;
    }

    this._touchState = null;
    this.onMouseUp(event);
  },

  _touchToMouse(event) {
    const touch = event.touches[0] || event.changedTouches[0];
    return {
      clientX: touch.clientX,
      clientY: touch.clientY,
      target: event.target,
      button: 0,
      shiftKey: false,
      ctrlKey: false,
      metaKey: false
    };
  },

  _touchDistance(touches) {
    const dx = touches[0].clientX - touches[1].clientX;
    const dy = touches[0].clientY - touches[1].clientY;
    return Math.sqrt(dx * dx + dy * dy);
  },

  _cancelLongPress() {
    if (this._longPressTimer) {
      clearTimeout(this._longPressTimer);
      this._longPressTimer = null;
    }
  },

  onKeyDown(event) {
    // Only handle if this flow is focused
    if (!this.container.contains(document.activeElement) && document.activeElement !== document.body) {
      return;
    }

    const key = event.key;
    const ctrl = event.ctrlKey || event.metaKey;

    // Delete selected
    if (key === 'Backspace' || key === 'Delete') {
      if (this.selectedNodes.size > 0 || this.selectedEdges.size > 0) {
        event.preventDefault();
        this.pushEvent('lf:delete_selected', {});
      }
    }

    // Select all
    if (ctrl && key === 'a') {
      event.preventDefault();
      this.selection.selectAll();
    }

    // Undo (Ctrl+Z / Cmd+Z)
    if (ctrl && key === 'z' && !event.shiftKey) {
      event.preventDefault();
      this.pushEvent('lf:undo', {});
    }

    // Redo (Ctrl+Shift+Z / Cmd+Shift+Z or Ctrl+Y / Cmd+Y)
    if ((ctrl && key === 'z' && event.shiftKey) || (ctrl && key === 'y')) {
      event.preventDefault();
      this.pushEvent('lf:redo', {});
    }

    // Copy (Ctrl+C / Cmd+C)
    if (ctrl && key === 'c') {
      if (this.selectedNodes.size > 0 || this.selectedEdges.size > 0) {
        event.preventDefault();
        this.pushEvent('lf:copy', {});
      }
    }

    // Cut (Ctrl+X / Cmd+X)
    if (ctrl && key === 'x') {
      if (this.selectedNodes.size > 0 || this.selectedEdges.size > 0) {
        event.preventDefault();
        this.pushEvent('lf:cut', {});
      }
    }

    // Paste (Ctrl+V / Cmd+V)
    if (ctrl && key === 'v') {
      event.preventDefault();
      this.pushEvent('lf:paste', {});
    }

    // Duplicate (Ctrl+D / Cmd+D)
    if (ctrl && key === 'd') {
      if (this.selectedNodes.size > 0 || this.selectedEdges.size > 0) {
        event.preventDefault();
        this.pushEvent('lf:duplicate', {});
      }
    }

    // Keyboard shortcuts panel (? key)
    if (key === '?' && !ctrl && !event.shiftKey) {
      event.preventDefault();
      this.toggleShortcutsPanel();
      return;
    }

    // Escape - clear selection or close shortcuts panel
    if (key === 'Escape') {
      if (this.shortcutsPanelVisible) {
        this.toggleShortcutsPanel();
        return;
      }
      this.selection.clearSelection();
      if (this.connection.isConnecting()) {
        this.connection.endConnection({ clientX: 0, clientY: 0 });
      }
    }
  },

  onKeyUp(event) {
    // Handle key up events if needed
  },

  // ===== Edge Label Editing =====

  onEdgeLabelDblClick(event) {
    const labelEl = event.target.closest('.lf-edge-label');
    if (!labelEl) return;

    const edgeGroup = labelEl.closest('[data-edge-id]');
    if (!edgeGroup) return;

    const edgeId = edgeGroup.dataset.edgeId;
    const currentText = labelEl.textContent.trim();

    event.preventDefault();
    event.stopPropagation();

    const wrapper = labelEl.closest('.lf-edge-label-wrapper');
    if (!wrapper) return;

    wrapper.classList.add('lf-edge-label-editing');
    const originalHTML = labelEl.innerHTML;
    const input = document.createElement('input');
    input.type = 'text';
    input.className = 'lf-edge-label-input';
    input.value = currentText;

    labelEl.textContent = '';
    labelEl.style.padding = '0';
    labelEl.style.border = 'none';
    labelEl.style.background = 'none';
    labelEl.style.boxShadow = 'none';
    labelEl.appendChild(input);

    input.focus();
    input.select();

    const commit = () => {
      const newText = input.value.trim();
      wrapper.classList.remove('lf-edge-label-editing');
      labelEl.style.padding = '';
      labelEl.style.border = '';
      labelEl.style.background = '';
      labelEl.style.boxShadow = '';

      if (newText !== currentText) {
        this.pushEvent('lf:edge_label_change', { id: edgeId, label: newText || null });
      }

      labelEl.textContent = newText || currentText;
    };

    let committed = false;
    const safeCommit = () => {
      if (committed) return;
      committed = true;
      commit();
    };

    input.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') {
        e.preventDefault();
        safeCommit();
      }
      if (e.key === 'Escape') {
        e.preventDefault();
        committed = true;
        wrapper.classList.remove('lf-edge-label-editing');
        labelEl.style.padding = '';
        labelEl.style.border = '';
        labelEl.style.background = '';
        labelEl.style.boxShadow = '';
        labelEl.textContent = currentText;
      }
      e.stopPropagation();
    });

    input.addEventListener('blur', () => safeCommit());
    input.addEventListener('mousedown', (e) => e.stopPropagation());
  },

  // ===== Keyboard Shortcuts Panel =====

  shortcutsPanelVisible: false,

  toggleShortcutsPanel() {
    if (this.shortcutsPanelVisible) {
      this.hideShortcutsPanel();
    } else {
      this.showShortcutsPanel();
    }
  },

  showShortcutsPanel() {
    if (this.shortcutsPanelVisible) return;
    this.shortcutsPanelVisible = true;

    const isMac = navigator.platform.toUpperCase().indexOf('MAC') >= 0;
    const mod = isMac ? '\u2318' : 'Ctrl';

    const shortcuts = [
      { section: 'General' },
      { keys: '?', desc: 'Toggle shortcuts panel' },
      { keys: 'Escape', desc: 'Clear selection / Cancel' },
      { keys: 'Delete / Backspace', desc: 'Delete selected' },
      { keys: `${mod}+A`, desc: 'Select all' },
      { section: 'History' },
      { keys: `${mod}+Z`, desc: 'Undo' },
      { keys: `${mod}+Shift+Z`, desc: 'Redo' },
      { section: 'Clipboard' },
      { keys: `${mod}+C`, desc: 'Copy selected' },
      { keys: `${mod}+X`, desc: 'Cut selected' },
      { keys: `${mod}+V`, desc: 'Paste' },
      { keys: `${mod}+D`, desc: 'Duplicate selected' },
      { section: 'Navigation' },
      { keys: 'Scroll', desc: 'Zoom in/out' },
      { keys: 'Click + Drag', desc: 'Pan canvas' },
      { keys: 'Shift + Drag', desc: 'Box selection' },
    ];

    const overlay = document.createElement('div');
    overlay.className = 'lf-shortcuts-overlay';
    overlay.setAttribute('data-lf-shortcuts', '');

    const panel = document.createElement('div');
    panel.className = 'lf-shortcuts-panel';

    let html = '<div class="lf-shortcuts-header">' +
      '<span class="lf-shortcuts-title">Keyboard Shortcuts</span>' +
      '<button class="lf-shortcuts-close">\u00D7</button>' +
      '</div><div class="lf-shortcuts-body">';

    for (const item of shortcuts) {
      if (item.section) {
        html += `<div class="lf-shortcuts-section">${item.section}</div>`;
      } else {
        html += `<div class="lf-shortcuts-row">` +
          `<span class="lf-shortcuts-keys">${item.keys.split('+').map(k => `<kbd>${k.trim()}</kbd>`).join(' + ')}</span>` +
          `<span class="lf-shortcuts-desc">${item.desc}</span>` +
          `</div>`;
      }
    }

    html += '</div>';
    panel.innerHTML = html;
    overlay.appendChild(panel);
    this.container.appendChild(overlay);

    overlay.addEventListener('click', (e) => {
      if (e.target === overlay || e.target.closest('.lf-shortcuts-close')) {
        this.hideShortcutsPanel();
      }
    });
  },

  hideShortcutsPanel() {
    this.shortcutsPanelVisible = false;
    const overlay = this.container.querySelector('[data-lf-shortcuts]');
    if (overlay) overlay.remove();
  },

  // ===== Viewport Operations =====

  applyViewportTransform() {
    const { x, y, zoom } = this.viewport;
    this.viewportEl.style.transform = `translate(${x}px, ${y}px) scale(${zoom})`;
    this.cursor?.repositionAll();
  },

  // ===== Remote Edge Updates =====

  /**
   * Update edge SVG paths for edges connected to the given node IDs.
   * Used for remote drag updates to keep edges visually connected.
   */
  _updateEdgesForNodes(nodeIds) {
    const edgeGroups = this.edgeLayer?.querySelectorAll('g[data-edge-id]');
    if (!edgeGroups) return;

    edgeGroups.forEach(g => {
      const sourceId = g.dataset.source;
      const targetId = g.dataset.target;
      if (!sourceId || !targetId) return;
      if (!nodeIds.has(sourceId) && !nodeIds.has(targetId)) return;

      const sourceHandlePos = this.nodeDrag.getHandlePosition(sourceId, g.dataset.sourceHandle, 'source');
      const targetHandlePos = this.nodeDrag.getHandlePosition(targetId, g.dataset.targetHandle, 'target');
      const sourceCoords = this.nodeDrag.getHandleCoords(sourceId, sourceHandlePos);
      const targetCoords = this.nodeDrag.getHandleCoords(targetId, targetHandlePos);
      if (!sourceCoords || !targetCoords) return;

      const pathD = calculateBezierPath(
        sourceCoords.x, sourceCoords.y, sourceHandlePos,
        targetCoords.x, targetCoords.y, targetHandlePos
      );

      g.querySelectorAll('path').forEach(p => p.setAttribute('d', pathD));

      // Update label/insert button positions (midpoint)
      const midX = (sourceCoords.x + targetCoords.x) / 2;
      const midY = (sourceCoords.y + targetCoords.y) / 2;
      const label = g.querySelector('.lf-edge-label-wrapper');
      if (label) { label.setAttribute('x', midX - 50); label.setAttribute('y', midY - 10); }
      const insert = g.querySelector('.lf-edge-insert-wrapper');
      if (insert) { insert.setAttribute('x', midX - 12); insert.setAttribute('y', midY - 12); }
    });
  },

  // ===== Server Communication =====

  pushNodeChange(changes) {
    if (changes.length === 0) return;
    this.pushEvent('lf:node_change', { changes });
  },

  pushEdgeChange(changes) {
    if (changes.length === 0) return;
    this.pushEvent('lf:edge_change', { changes });
  },

  pushViewportChange() {
    this.pushEvent('lf:viewport_change', this.viewport);
  },
};
