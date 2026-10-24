/**
 * LiveFlow - Main Phoenix LiveView Hook
 *
 * This hook handles all client-side interactions for the flow diagram,
 * including pan/zoom, node dragging, connection creation, and selection.
 *
 * Configuration is rendered by LiveFlow.Components.Flow as JSON in the
 * `data-config` attribute.
 */

import { CoordinateUtils } from '../utils/coordinates.js';
import { EdgeUpdater } from '../utils/edge_updater.js';
import { AutoPan } from '../utils/auto_pan.js';
import { HeldKeys, parseKeys, matchesKeys, isInputTarget } from '../utils/keys.js';
import { PanZoomManager } from '../interaction/pan_zoom.js';
import { NodeDragManager } from '../interaction/node_drag.js';
import { ConnectionManager } from '../interaction/connection.js';
import { SelectionManager } from '../interaction/selection.js';
import { NodeResizeManager } from '../interaction/node_resize.js';
import { CursorManager } from '../interaction/cursor.js';
import { HelperLinesManager } from '../interaction/helper_lines.js';
import { exportSVG, exportPNG, downloadString, downloadBlob } from '../utils/export.js';
import { getLayoutedElements, hasElk, ELK_MISSING } from '../utils/layout.js';

const DEFAULT_CONFIG = {
  viewport: { x: 0, y: 0, zoom: 1 },
  minZoom: 0.1,
  maxZoom: 4,
  panOnDrag: true,
  panOnScroll: false,
  panOnScrollSpeed: 0.5,
  panOnScrollMode: 'free',
  zoomOnScroll: true,
  zoomOnPinch: true,
  zoomOnDoubleClick: true,
  preventScrolling: true,
  snapToGrid: false,
  snapGrid: [15, 15],
  nodesDraggable: true,
  nodesConnectable: true,
  elementsSelectable: true,
  selectionOnDrag: false,
  selectionMode: 'partial',
  selectionKey: 'Shift',
  multiSelectionKey: ['Meta', 'Control', 'Shift'],
  panActivationKey: 'Space',
  deleteKeyCode: ['Backspace', 'Delete'],
  disableKeyboardA11y: false,
  autoPanOnNodeDrag: true,
  autoPanOnConnect: true,
  autoPanOnSelection: true,
  autoPanSpeed: 15,
  nodeDragThreshold: 1,
  nodeExtent: null,
  connectionMode: 'strict',
  connectionLineType: 'bezier',
  connectionRadius: 20,
  fitViewOnInit: false,
  fitViewOptions: {},
  cursors: false,
  helperLines: false,
  virtualization: false,
  background: null,
  minimapPannable: false,
  minimapZoomable: false,
  connectOnClick: true,
  multiConnection: false,
  connectionLineStyle: null,
  connectionLineClass: null,
  contextMenu: false,
  paneClickEvents: false,
  connectionEvents: false,
};

// Elements inside nodes that keep their native behaviour (no drag, no preventDefault)
const INTERACTIVE = 'input, select, textarea, button, a[href], [contenteditable], .nodrag';

// The flow that receives keyboard shortcuts while focus is on <body>
let activeFlow = null;
const mountedFlows = new Set();

function readConfig(el) {
  let raw = {};
  try {
    raw = JSON.parse(el.dataset.config || '{}');
  } catch (error) {
    console.error('[LiveFlow] invalid data-config', error);
  }

  const config = { ...DEFAULT_CONFIG, ...raw };
  [config.snapGridX, config.snapGridY] = config.snapGrid;
  config.selectionKey = parseKeys(config.selectionKey);
  config.multiSelectionKey = parseKeys(config.multiSelectionKey);
  config.panActivationKey = parseKeys(config.panActivationKey);
  config.deleteKeyCode = parseKeys(config.deleteKeyCode);
  return config;
}

// Backwards compatible global export API: acts on the active (or last mounted) flow
window.LiveFlowExport = {
  exportSVG() {
    (activeFlow || [...mountedFlows].pop())?.exportSVG();
  },
  exportPNG() {
    (activeFlow || [...mountedFlows].pop())?.exportPNG();
  },
};

/**
 * Public API exposed as `element.liveflow` on the .lf-container element, so
 * other hooks can work with the flow (the LiveFlow equivalent of
 * React Flow's useReactFlow()). Screen positions are client coordinates
 * (event.clientX / clientY).
 */
function createApi(hook) {
  const nodeInfo = el => ({
    id: el.dataset.nodeId,
    x: parseFloat(el.style.left) || 0,
    y: parseFloat(el.style.top) || 0,
    width: el.offsetWidth,
    height: el.offsetHeight,
    selected: el.dataset.selected === 'true',
    selectable: el.dataset.selectable !== 'false',
    draggable: el.dataset.draggable !== 'false',
    deletable: el.dataset.deletable !== 'false',
    type: el.dataset.nodeType || null,
    parentId: el.dataset.parentId || null,
  });

  return {
    element: hook.el,
    getViewport: () => ({ ...hook.viewport }),
    setViewport: (viewport, { duration = 0 } = {}) =>
      hook.panZoom.animateViewport(hook.viewport, { ...hook.viewport, ...viewport }, duration),
    fitView: (options = {}) => hook.panZoom.fitView({ ...hook.config.fitViewOptions, ...options }),
    zoomIn: ({ duration } = {}) => hook.panZoom.zoomIn(duration),
    zoomOut: ({ duration } = {}) => hook.panZoom.zoomOut(duration),
    zoomTo: (zoom, { duration } = {}) => hook.panZoom.zoomTo(zoom, duration),
    screenToFlowPosition: ({ x, y }, options = {}) => {
      const rect = hook.getContainerRect();
      const [fx, fy] = hook.coords.screenToFlow(x - rect.left, y - rect.top, options);
      return { x: fx, y: fy };
    },
    flowToScreenPosition: ({ x, y }) => {
      const rect = hook.getContainerRect();
      const [sx, sy] = hook.coords.flowToScreen(x, y);
      return { x: sx + rect.left, y: sy + rect.top };
    },
    getNodes: () => Array.from(hook.nodeLayer?.querySelectorAll('.lf-node[data-node-id]') || []).map(nodeInfo),
    getNode: id => {
      const el = hook.nodeEl(id);
      return el ? nodeInfo(el) : null;
    },
    getIntersectingNodes: (rect, { partial = true } = {}) =>
      Array.from(hook.nodeLayer?.querySelectorAll('.lf-node[data-node-id]') || [])
        .map(nodeInfo)
        .filter(n => (partial ? hook.coords.rectsIntersect(n, rect) : hook.coords.rectContains(rect, n))),
    getSelection: () => ({ nodes: [...hook.selectedNodes], edges: [...hook.selectedEdges] }),
    setSelection: ({ nodes = [], edges = [] } = {}) => {
      hook.selectedNodes = new Set(nodes);
      hook.selectedEdges = new Set(edges);
      hook.selection.pushSelectionChange();
    },
  };
}

export const LiveFlowHook = {
  mounted() {
    this.config = readConfig(this.el);

    // State
    this.viewport = { ...this.config.viewport };
    this.selectedNodes = new Set();
    this.selectedEdges = new Set();
    this.interactionMode = null; // 'pan' | 'drag' | 'connect' | 'select' | 'resize' | 'minimap'
    this.timers = new Set();

    // DOM references
    this.container = this.el;
    this.viewportEl = this.el.querySelector('.lf-viewport');
    this.nodeLayer = this.el.querySelector('[data-node-layer]');
    this.edgeLayer = this.el.querySelector('[data-edge-layer]');
    this.interactionLayer = this.el.querySelector('[data-interaction-layer]') || this.el;
    this.refreshDomRefs();

    // Managers
    this.keys = new HeldKeys();
    this.coords = new CoordinateUtils(this);
    this.edges = new EdgeUpdater(this);
    this.autoPan = new AutoPan(this);
    this.panZoom = new PanZoomManager(this);
    this.nodeDrag = new NodeDragManager(this);
    this.connection = new ConnectionManager(this);
    this.selection = new SelectionManager(this);
    this.nodeResize = new NodeResizeManager(this);
    if (this.config.cursors) this.cursor = new CursorManager(this);
    if (this.config.helperLines) this.helperLines = new HelperLinesManager(this);

    mountedFlows.add(this);
    this.el.liveflow = createApi(this);

    this.measureContainer(true);
    this.setupEventListeners();
    this.setupObservers();
    this.setupServerEvents();
    this.selection.syncFromDom();
    this.applyViewportTransform();

    this.el.dispatchEvent(new CustomEvent('lf:ready', { detail: this.el.liveflow }));

    // Measure initial nodes after first render
    requestAnimationFrame(() => {
      this.measureNodes();
      if (this.config.fitViewOnInit) {
        requestAnimationFrame(() => this.panZoom.fitView({ ...this.config.fitViewOptions, duration: 0 }));
      }
    });
  },

  updated() {
    // Options may change at runtime; the client keeps owning the viewport
    this.config = readConfig(this.el);
    this.refreshDomRefs();
    this._rectDirty = true;

    // Options with their own managers can be toggled at runtime
    if (this.config.helperLines && !this.helperLines) this.helperLines = new HelperLinesManager(this);
    if (!this.config.helperLines && this.helperLines) {
      this.helperLines.destroy();
      this.helperLines = null;
    }
    if (this.config.cursors && !this.cursor) this.cursor = new CursorManager(this);
    if (!this.config.cursors && this.cursor) {
      this.cursor.destroy();
      this.cursor = null;
    }

    // Re-apply the client-side viewport transform after the DOM patch — the
    // server may have an older viewport and its render would cause a jump.
    this.applyViewportTransform();

    if (this.nodeDrag.isDragging()) this.nodeDrag.reapplyPositions();
    if (this.nodeResize.isResizing() || this.nodeResize._pendingClear) this.nodeResize.reapplyDimensions();
    this.nodeResize.onUpdated();

    this.selection.syncFromDom();
  },

  destroyed() {
    this.abortInteraction();
    this.panZoom.destroy();
    this.nodeDrag.destroy();
    this.connection.destroy();
    this.selection.destroy();
    this.nodeResize.destroy();
    this.autoPan.stop();
    this.cursor?.destroy();
    this.helperLines?.destroy();
    this.resizeObserver?.disconnect();
    this.nodeObserver?.disconnect();
    this.nodeResizeObserver?.disconnect();
    if (this._measureFrame) cancelAnimationFrame(this._measureFrame);
    if (this._remoteDragFrame) cancelAnimationFrame(this._remoteDragFrame);
    this.timers.forEach(clearTimeout);
    this.removeEventListeners();

    if (this._animationFrame) cancelAnimationFrame(this._animationFrame);
    delete this.el.liveflow;
    mountedFlows.delete(this);
    if (activeFlow === this) activeFlow = null;
  },

  // ===== Helpers =====

  nodeEl(nodeId) {
    return this.nodeLayer?.querySelector(`.lf-node[data-node-id="${CSS.escape(nodeId)}"]`) || null;
  },

  refreshDomRefs() {
    this.backgroundEl = this.el.querySelector('[data-background]');
    this.minimapEl = this.el.querySelector('[data-minimap]');
  },

  setTimer(fn, delay) {
    const id = setTimeout(() => {
      this.timers.delete(id);
      fn();
    }, delay);
    this.timers.add(id);
    return id;
  },

  // ===== Event Listeners Setup =====

  setupEventListeners() {
    this.listeners = [];
    const on = (target, type, handler, options) => {
      const bound = handler.bind(this);
      target.addEventListener(type, bound, options);
      this.listeners.push([target, type, bound, options]);
    };

    on(this.container, 'wheel', this.onWheel, { passive: false });
    on(this.container, 'mousedown', this.onMouseDown);
    on(this.container, 'mousemove', this.onContainerMouseMove);
    on(this.container, 'mouseleave', () => { this._lastPointer = null; });
    on(this.container, 'dblclick', this.onDoubleClick);
    // Swallow the click that follows a drag/connection so phx-click handlers
    // (e.g. lf:node_click) don't fire for it
    on(this.container, 'click', this.onClickCapture, true);
    on(this.container, 'contextmenu', this.onContextMenu);

    // Drag & drop from outside the flow (data type application/liveflow)
    on(this.container, 'dragover', this.onDragOver);
    on(this.container, 'drop', this.onDrop);

    on(this.container, 'touchstart', this.onTouchStart, { passive: false });
    on(this.container, 'touchmove', this.onTouchMove, { passive: false });
    on(this.container, 'touchend', this.onTouchEnd);
    on(this.container, 'touchcancel', this.onTouchCancel);

    // DOM events dispatched with JS.dispatch (stay in the user gesture context)
    on(this.container, 'lf:zoom-in', () => this.panZoom.zoomIn());
    on(this.container, 'lf:zoom-out', () => this.panZoom.zoomOut());
    on(this.container, 'lf:fit-view', (e) => this.panZoom.fitView({ ...this.config.fitViewOptions, ...e.detail }));
    // detail: {filename, padding, scale (PNG)}
    on(this.container, 'lf:export-svg', (e) => this.exportSVG(e.detail || {}));
    on(this.container, 'lf:export-png', (e) => this.exportPNG(e.detail || {}));
    on(this.container, 'lf:auto-layout', (e) => {
      this.pushEvent('lf:request_layout', { direction: e.detail?.direction || 'DOWN' });
    });

    on(document, 'keydown', this.onKeyDown);
    on(document, 'keyup', this.onKeyUp);
    on(window, 'blur', this.onWindowBlur);
    // Any scroll may move the container; recompute its rect lazily
    on(window, 'scroll', () => { this._rectDirty = true; }, { capture: true, passive: true });
    on(window, 'resize', () => { this._rectDirty = true; }, { passive: true });

    this.onWindowMouseMove = this.onPointerMove.bind(this);
    this.onWindowMouseUp = this.onPointerUp.bind(this);
  },

  removeEventListeners() {
    this.listeners?.forEach(([target, type, handler, options]) => {
      target.removeEventListener(type, handler, options);
    });
    this.listeners = [];
    this.stopWindowTracking();
  },

  setupObservers() {
    this.resizeObserver = new ResizeObserver(() => this.measureContainer());
    this.resizeObserver.observe(this.container);

    this._measuredNodes = new Map();

    // ResizeObserver for individual node elements
    this.nodeResizeObserver = new ResizeObserver(entries => {
      // Skip during active resize or pending resize commit to avoid
      // dimension changes that would overwrite the resize
      if (this.nodeResize.isResizing() || this.nodeResize._pendingClear) return;

      const changes = [];
      for (const entry of entries) {
        const el = entry.target;
        const nodeId = el.dataset?.nodeId;
        if (!nodeId || !el.isConnected) continue;
        const change = this.measureNode(nodeId, el);
        if (change) changes.push(change);
      }
      this.pushNodeChange(changes);
    });

    // MutationObserver to detect new nodes added to the DOM (debounced)
    this.nodeObserver = new MutationObserver(() => {
      if (this._measureFrame) return;
      this._measureFrame = requestAnimationFrame(() => {
        this._measureFrame = null;
        this.measureNodes();
      });
    });

    if (this.nodeLayer) {
      this.nodeObserver.observe(this.nodeLayer, { childList: true });
    }
  },

  setupServerEvents() {
    // Viewport, layout and export events take an optional flow_id: with several
    // flows on the page, only that flow reacts
    const scoped = (event, handler) => this.handleEvent(event, (payload) => {
      if (payload?.flow_id && payload.flow_id !== this.el.id) return;
      return handler(payload || {});
    });

    scoped('lf:fit_view', (payload) => {
      this.panZoom.fitView({ ...this.config.fitViewOptions, ...normalizeFitViewPayload(payload) });
    });
    scoped('lf:zoom_to', (payload) => this.panZoom.zoomTo(payload.zoom, payload.duration));
    scoped('lf:zoom_in', (payload) => this.panZoom.zoomIn(payload.duration));
    scoped('lf:zoom_out', (payload) => this.panZoom.zoomOut(payload.duration));
    scoped('lf:pan_to', (payload) => {
      this.panZoom.animateViewport(this.viewport, {
        x: payload.x,
        y: payload.y,
        zoom: this.viewport.zoom,
      }, payload.duration ?? 200);
    });
    scoped('lf:set_viewport', (payload) => {
      this.panZoom.cancelAnimation();
      this.viewport = { x: payload.x, y: payload.y, zoom: payload.zoom };
      this.applyViewportTransform();
    });

    // Cursor collaboration events
    this.handleEvent('lf:remote_cursor', (data) => {
      this.cursor?.updateCursor(data.user_id, data.x, data.y, data.color, data.name);
    });
    this.handleEvent('lf:cursor_leave', (data) => this.cursor?.removeCursor(data.user_id));

    // Remote drag — lerp interpolate node positions for smooth movement
    this._remoteDragTargets = new Map();
    this.handleEvent('lf:remote_drag', (data) => this.onRemoteDrag(data));

    // Auto-layout via ELK (registered by the app, see registerElk)
    scoped('lf:layout_data', (data) => {
      if (!hasElk()) {
        console.error(ELK_MISSING);
        return;
      }
      // Any ELK layout option can be passed, e.g. {"elk.algorithm": "mrtree"}
      const options = { ...(data.options || {}) };
      if (data.direction) options['elk.direction'] = data.direction;
      getLayoutedElements(this.withDomSizes(data.nodes), data.edges, options)
        .then(positioned => {
          this.pushNodeChange(positioned.map(n => ({
            type: 'position', id: n.id, position: { x: n.x, y: n.y }, dragging: false,
          })));
          requestAnimationFrame(() => this.panZoom.fitView(this.config.fitViewOptions));
        })
        .catch(err => console.error('[LiveFlow] auto-layout failed:', err));
    });

    // Tree layout (pure JS, no ELK)
    scoped('lf:tree_layout_data', async (data) => {
      const { treeLayout } = await import('../utils/tree_layout.js');
      const positioned = treeLayout(this.withDomSizes(data.nodes), data.edges, data.options);

      // Enable CSS transitions on all nodes
      const nodeEls = this.nodeLayer?.querySelectorAll('.lf-node[data-node-id]');
      nodeEls?.forEach(el => { el.dataset.layoutAnimating = 'true'; });

      this.pushNodeChange(positioned.map(n => ({
        type: 'position', id: n.id, position: { x: n.x, y: n.y }, dragging: false,
      })));

      // Remove animation flag after the transition, then fit view
      this.setTimer(() => {
        nodeEls?.forEach(el => { delete el.dataset.layoutAnimating; });
        this.panZoom.fitView({ ...this.config.fitViewOptions, duration: 300 });
      }, 450);
    });

    // Animated transitions to new positions (LiveFlow.animate_positions/4)
    scoped('lf:animate_positions', (payload) => {
      this.animatePositions(payload.positions || [], payload.duration ?? 300);
    });

    // Export triggered from the server
    scoped('lf:export_svg', (payload) => this.exportSVG(payload));
    scoped('lf:export_png', (payload) => this.exportPNG(payload));
  },

  // ===== Measurement =====

  /**
   * Container rect, cached. Recomputed only after resize/scroll so hot paths
   * (wheel, drag, pinch) never force a synchronous layout.
   */
  getContainerRect() {
    if (this._rectDirty || !this.containerRect) {
      const rect = this.container.getBoundingClientRect();
      this.containerRect = { width: rect.width, height: rect.height, left: rect.left, top: rect.top };
      this._rectDirty = false;
    }
    return this.containerRect;
  },

  measureContainer(force = false) {
    const prev = this.containerRect;
    this._rectDirty = true;
    const rect = this.getContainerRect();

    if (rect.width > 0 && rect.height > 0 &&
        (force || rect.width !== prev?.width || rect.height !== prev?.height)) {
      // Used by the minimap and by server-side viewport culling
      this.pushEventTo(this.el, 'lf:container_resize', {
        width: Math.round(rect.width),
        height: Math.round(rect.height),
      });
      this.updateMinimapViewport();
    }
  },

  measureNode(nodeId, el) {
    const w = el.offsetWidth;
    const h = el.offsetHeight;
    if (w === 0 && h === 0) return null;

    const prev = this._measuredNodes.get(nodeId);
    if (prev && prev.w === w && prev.h === h) return null;

    this._measuredNodes.set(nodeId, { w, h });
    return { type: 'dimensions', id: nodeId, width: w, height: h };
  },

  /**
   * Measure all node dimensions and send changes to the server.
   */
  measureNodes() {
    // Skip during pending resize commit to avoid sending stale content-fit
    // dimensions that would overwrite the user's resize
    if (this.nodeResize._pendingClear) return;

    const nodeEls = this.nodeLayer?.querySelectorAll('.lf-node[data-node-id]');
    if (!nodeEls) return;

    const changes = [];
    nodeEls.forEach(el => {
      if (!el._lfObserved) {
        // A new element (also a node that was removed and added back): the
        // server may not know its size anymore, always report it
        this._measuredNodes.delete(el.dataset.nodeId);
        this.nodeResizeObserver.observe(el);
        el._lfObserved = true;
      }

      const change = this.measureNode(el.dataset.nodeId, el);
      if (change) changes.push(change);
    });

    this.pushNodeChange(changes);
  },

  withDomSizes(nodes) {
    // Actual DOM sizes prevent overlaps when server dimensions are stale
    return nodes.map(node => {
      const el = this.nodeEl(node.id);
      return el ? { ...node, width: el.offsetWidth || node.width, height: el.offsetHeight || node.height } : node;
    });
  },

  // ===== Pointer routing =====

  canPanWith(button) {
    const panOnDrag = this.config.panOnDrag;
    if (panOnDrag === true) return button === 0 || button === 1;
    if (Array.isArray(panOnDrag)) return panOnDrag.includes(button);
    return false;
  },

  startInteraction(mode, event) {
    this.interactionMode = mode;
    // Track on window so interactions continue (and auto-pan) outside the container
    if (!event?.isTouch) {
      window.addEventListener('mousemove', this.onWindowMouseMove);
      window.addEventListener('mouseup', this.onWindowMouseUp);
    }
  },

  stopWindowTracking() {
    window.removeEventListener('mousemove', this.onWindowMouseMove);
    window.removeEventListener('mouseup', this.onWindowMouseUp);
  },

  onMouseDown(event) {
    activeFlow = this;

    // connect_on_click: the second click completes (or cancels) the connection
    if (this.connection.isClickConnecting()) {
      event.preventDefault?.();
      this.connection.endConnection(event);
      this.suppressNextClick();
      return;
    }

    if (this.interactionMode) return;

    const target = event.target;
    const button = event.button ?? 0;
    const interactive = target.closest(INTERACTIVE);

    if (!interactive && !event.isTouch) {
      this.container.focus({ preventScroll: true });
    }

    // Pan from anywhere with a non-primary button (middle mouse) or while the
    // pan activation key (Space by default) is held — also over nodes and
    // selection rectangles
    const panKeyHeld = this.keys.isHeld(this.config.panActivationKey, event);
    if (!target.closest('.nopan') && (button !== 0 || panKeyHeld) && this.canPanWith(panKeyHeld ? 0 : button)) {
      event.preventDefault?.();
      this.startInteraction('pan', event);
      this.panZoom.startPan(event);
      this.paneClickCandidate = false;
      return;
    }

    if (button !== 0) return;

    // Minimap
    if (target.closest('.lf-minimap')) {
      if (this.config.minimapPannable) {
        event.preventDefault?.();
        this.startInteraction('minimap', event);
        this.panToMinimapPoint(event);
      }
      return;
    }

    // Overlay UI (controls, panels) never starts flow interactions
    if (target.closest('.nopan, .lf-controls, .lf-shortcuts-overlay')) return;

    const nodeEl = target.closest('.lf-node[data-node-id]');

    // Node resizer
    const resizerEl = target.closest('.lf-node-resizer');
    if (resizerEl && nodeEl) {
      event.preventDefault?.();
      event.stopPropagation?.();
      if (this.nodeResize.startResize(nodeEl.dataset.nodeId, resizerEl.dataset.resizerPosition, event)) {
        this.startInteraction('resize', event);
      }
      return;
    }

    // Handle: start connection
    const handleEl = target.closest('[data-handle-type]');
    if (handleEl && nodeEl) {
      event.preventDefault?.();
      if (this.connection.startConnection(
        nodeEl.dataset.nodeId,
        handleEl.dataset.handleId,
        handleEl.dataset.handleType,
        handleEl.dataset.handlePosition,
        event
      )) {
        this.startInteraction('connect', event);
      }
      return;
    }

    // Node delete button
    const nodeDeleteBtn = target.closest('.lf-node-delete-btn');
    if (nodeDeleteBtn) {
      event.preventDefault?.();
      event.stopPropagation?.();
      if (nodeDeleteBtn.dataset.nodeId) {
        this.pushNodeChange([{ type: 'remove', id: nodeDeleteBtn.dataset.nodeId }]);
      }
      return;
    }

    if (nodeEl) {
      const multi = this.keys.isHeld(this.config.multiSelectionKey, event);
      this.selection.selectNode(nodeEl.dataset.nodeId, { multi, toggle: multi });

      // Form elements inside nodes keep their native behaviour (no drag)
      if (interactive) return;

      // Only block text selection when a drag can actually start (drag
      // handles and non-draggable nodes keep selectable content)
      if (this.nodeDrag.startDrag(nodeEl.dataset.nodeId, event)) {
        event.preventDefault?.();
        this.startInteraction('drag', event);
      }
      return;
    }

    // Edge reconnect handle
    const reconnectHandle = target.closest('.lf-edge-reconnect-handle');
    if (reconnectHandle) {
      event.preventDefault?.();
      event.stopPropagation?.();
      if (this.connection.startReconnect(reconnectHandle.dataset.edgeId, reconnectHandle.dataset.reconnectEnd, event)) {
        this.startInteraction('connect', event);
      }
      return;
    }

    // Edge insert "+" button
    const insertBtn = target.closest('.lf-edge-insert-btn');
    if (insertBtn) {
      event.preventDefault?.();
      event.stopPropagation?.();
      this.pushEvent('lf:insert_on_edge', { edge_id: insertBtn.dataset.edgeId });
      return;
    }

    // Edge delete button
    const deleteBtn = target.closest('.lf-edge-delete-btn');
    if (deleteBtn) {
      event.preventDefault?.();
      event.stopPropagation?.();
      if (deleteBtn.dataset.edgeId) {
        this.pushEdgeChange([{ type: 'remove', id: deleteBtn.dataset.edgeId }]);
      }
      return;
    }

    // Edge click
    const edgeEl = target.closest('[data-edge-id]');
    if (edgeEl && (target.classList.contains('lf-edge-interaction') || target.classList.contains('lf-edge'))) {
      event.preventDefault?.();
      const multi = this.keys.isHeld(this.config.multiSelectionKey, event);
      this.selection.selectEdge(edgeEl.dataset.edgeId, { multi, toggle: multi });
      return;
    }

    // Pane
    if (interactive) return;
    const selectionKeyHeld = this.keys.isHeld(this.config.selectionKey, event);
    // Touch prefers panning over drag selection
    const selectionOnDrag = this.config.selectionOnDrag && !(event.isTouch && this.canPanWith(0));

    if (this.config.elementsSelectable && (selectionKeyHeld || selectionOnDrag)) {
      event.preventDefault?.();
      this.startInteraction('select', event);
      this.selection.startSelection(event);
      return;
    }

    if (this.canPanWith(0)) {
      this.startInteraction('pan', event);
      this.panZoom.startPan(event);
      // A pan without movement is a pane click
      this.paneClickCandidate = true;
    } else {
      this.onPaneClick(event);
    }
  },

  onPaneClick(event) {
    this.selection.clearSelection();
    if (this.config.paneClickEvents) {
      const [x, y] = this.coords.eventToFlow(event);
      this.pushEvent('lf:pane_click', { position: { x, y } });
    }
  },

  onPointerMove(event) {
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
      case 'resize':
        this.nodeResize.moveResize(event);
        break;
      case 'minimap':
        this.panToMinimapPoint(event);
        break;
    }
  },

  onPointerUp(event) {
    switch (this.interactionMode) {
      case 'pan': {
        const moved = this.panZoom.endPan();
        if (!moved && this.paneClickCandidate) this.onPaneClick(event);
        break;
      }
      case 'drag':
        if (this.nodeDrag.endDrag()) this.suppressNextClick();
        break;
      case 'connect':
        if (this.config.connectOnClick && !this.connection.hasMoved() && !this.connection.isReconnecting()) {
          // A click on a handle: wait for a click on the target handle
          this.connection.startClickMode();
        } else {
          this.connection.endConnection(event);
          this.suppressNextClick();
        }
        break;
      case 'select':
        this.selection.endSelection();
        break;
      case 'resize':
        if (this.nodeResize.endResize()) this.suppressNextClick();
        break;
      case 'minimap':
        this.panZoom.flushViewport();
        break;
    }

    this.interactionMode = null;
    this.paneClickCandidate = false;
    this.stopWindowTracking();
  },

  /**
   * Cancel the current interaction without committing it (Escape, blur, touchcancel).
   */
  abortInteraction() {
    switch (this.interactionMode) {
      case 'pan':
        this.panZoom.endPan();
        break;
      case 'drag':
        this.nodeDrag.abortDrag();
        break;
      case 'connect':
        this.connection.abortConnection();
        break;
      case 'select':
        this.selection.abortSelection();
        break;
      case 'resize':
        this.nodeResize.abortResize();
        break;
      case 'minimap':
        this.panZoom.flushViewport();
        break;
    }

    this.interactionMode = null;
    this.paneClickCandidate = false;
    this.stopWindowTracking();
  },

  onContainerMouseMove(event) {
    // Last pointer position, so paste can drop the nodes under the cursor
    this._lastPointer = { clientX: event.clientX, clientY: event.clientY };
    // Broadcast cursor position for collaboration (runs regardless of interaction mode)
    this.cursor?.handleMouseMove(event);
    if (this.connection.isClickConnecting()) this.connection.moveConnection(event);
  },

  // lf:paste payload: the pointer position (flow coords) when it's over the pane
  pastePayload() {
    const pointer = this._lastPointer;
    if (!pointer) return {};
    const [x, y] = this.coords.eventToFlow(pointer, { snapToGrid: this.config.snapToGrid });
    return { position: { x, y } };
  },

  suppressNextClick() {
    this._suppressClickUntil = performance.now() + 300;
  },

  onClickCapture(event) {
    if (this._suppressClickUntil && performance.now() < this._suppressClickUntil) {
      this._suppressClickUntil = null;
      event.stopPropagation();
      event.preventDefault();
    }
  },

  onContextMenu(event) {
    // Right-button panning needs the context menu out of the way
    if (Array.isArray(this.config.panOnDrag) && this.config.panOnDrag.includes(2)) {
      event.preventDefault();
    }

    if (!this.config.contextMenu || event.target.closest(INTERACTIVE + ', .lf-controls, .lf-minimap')) return;
    event.preventDefault();

    const rect = this.getContainerRect();
    const [fx, fy] = this.coords.eventToFlow(event);
    const payload = {
      x: event.clientX - rect.left,
      y: event.clientY - rect.top,
      position: { x: fx, y: fy },
    };

    const nodeEl = event.target.closest('.lf-node[data-node-id]');
    const edgeEl = event.target.closest('g[data-edge-id]');

    if (nodeEl) {
      this.pushEvent('lf:node_context_menu', { ...payload, id: nodeEl.dataset.nodeId, selection: [...this.selectedNodes] });
    } else if (edgeEl) {
      this.pushEvent('lf:edge_context_menu', { ...payload, id: edgeEl.dataset.edgeId });
    } else {
      this.pushEvent('lf:pane_context_menu', payload);
    }
  },

  // ===== Drag & drop from outside =====

  onDragOver(event) {
    if (!event.dataTransfer?.types.includes('application/liveflow')) return;
    event.preventDefault();
    event.dataTransfer.dropEffect = 'move';
  },

  onDrop(event) {
    if (!event.dataTransfer?.types.includes('application/liveflow')) return;
    event.preventDefault();

    const raw = event.dataTransfer.getData('application/liveflow');
    let data = raw;
    try {
      data = JSON.parse(raw);
    } catch (_e) {
      // plain string payload
    }

    const [x, y] = this.coords.eventToFlow(event, { snapToGrid: this.config.snapToGrid });
    this.pushEvent('lf:drop', { data, position: { x, y } });
  },

  // ===== Animated positions =====

  /**
   * Animate nodes to new positions, then push them as position changes.
   * `positions` items: {id, x, y} (stored, possibly relative) and {ax, ay} (absolute target).
   */
  animatePositions(positions, duration) {
    if (this._animationFrame) cancelAnimationFrame(this._animationFrame);
    const index = this.nodeDrag.childrenIndex();
    const targets = new Set(positions.map(p => p.id));

    const items = positions.map(p => {
      const el = this.nodeEl(p.id);
      if (!el) return null;
      return {
        ...p,
        el,
        fromX: parseFloat(el.style.left) || 0,
        fromY: parseFloat(el.style.top) || 0,
        toX: p.ax ?? p.x,
        toY: p.ay ?? p.y,
        width: el.offsetWidth,
        height: el.offsetHeight,
        // children not animated themselves follow their parent
        descendants: this.nodeDrag.descendantsOf(p.id, index).filter(d => !targets.has(d.id)),
      };
    }).filter(Boolean);

    const moving = new Set();
    items.forEach(item => {
      moving.add(item.id);
      item.descendants.forEach(d => moving.add(d.id));
    });
    const edges = this.edges.collect(moving);
    const start = performance.now();

    const frame = (now) => {
      const t = duration > 0 ? Math.min((now - start) / duration, 1) : 1;
      const eased = t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
      const overrides = new Map();

      items.forEach(item => {
        const x = item.fromX + (item.toX - item.fromX) * eased;
        const y = item.fromY + (item.toY - item.fromY) * eased;
        item.el.style.left = `${x}px`;
        item.el.style.top = `${y}px`;
        overrides.set(item.id, { x, y, width: item.width, height: item.height });
        item.descendants.forEach(d => {
          const dx = d.startX + x - item.fromX;
          const dy = d.startY + y - item.fromY;
          d.el.style.left = `${dx}px`;
          d.el.style.top = `${dy}px`;
          overrides.set(d.id, { x: dx, y: dy, width: d.width, height: d.height });
        });
      });
      this.edges.update(edges, overrides);

      if (t < 1) {
        this._animationFrame = requestAnimationFrame(frame);
      } else {
        this._animationFrame = null;
        this.pushNodeChange(items.map(item => ({
          type: 'position', id: item.id, position: { x: item.x, y: item.y }, dragging: false,
        })));
      }
    };

    this._animationFrame = requestAnimationFrame(frame);
  },

  // ===== Wheel / double click =====

  onWheel(event) {
    if (event.target.closest('.nowheel')) return;

    if (event.target.closest('.lf-minimap')) {
      if (this.config.minimapZoomable) {
        event.preventDefault();
        const rect = this.getContainerRect();
        const factor = Math.pow(2, -event.deltaY * 0.002);
        this.panZoom.zoomAt(this.viewport.zoom * factor, rect.width / 2, rect.height / 2);
      }
      return;
    }

    const consumed = this.panZoom.onWheel(event);
    if (consumed || this.config.preventScrolling) {
      event.preventDefault();
    }
  },

  onDoubleClick(event) {
    if (this.onEdgeLabelDblClick(event)) return;
    if (!this.config.zoomOnDoubleClick) return;

    const target = event.target;
    if (target.closest('.lf-node, [data-edge-id], .lf-controls, .lf-minimap, .nopan, .lf-shortcuts-overlay')) return;

    const [cx, cy] = this.coords.eventToScreen(event);
    const { x, y, zoom } = this.viewport;
    const newZoom = this.panZoom.clampZoom(zoom * (event.shiftKey ? 0.5 : 2));
    const scale = newZoom / zoom;
    this.panZoom.animateViewport(this.viewport, {
      x: cx - (cx - x) * scale,
      y: cy - (cy - y) * scale,
      zoom: newZoom,
    }, 250);
  },

  // ===== Touch Support =====

  onTouchStart(event) {
    activeFlow = this;
    const touches = event.touches;

    if (touches.length === 2) {
      // Pinch-to-zoom / two-finger pan start
      event.preventDefault();
      if (this.interactionMode === 'drag' || this.interactionMode === 'resize' || this.interactionMode === 'pan') {
        this.onPointerUp(this.touchToMouse(event));
      } else {
        this.abortInteraction();
      }

      const [midX, midY] = this.touchMidpoint(touches);
      this._touchState = { type: 'pinch', startDist: touchDistance(touches), startZoom: this.viewport.zoom, lastMidX: midX, lastMidY: midY };
      return;
    }

    if (touches.length === 1) {
      // Let form elements inside nodes receive focus and native behaviour
      if (!event.target.closest(INTERACTIVE)) event.preventDefault();
      this._touchState = { type: 'single' };
      this.onMouseDown(this.touchToMouse(event));
    }
  },

  onTouchMove(event) {
    const touches = event.touches;

    if (touches.length === 2 && this._touchState?.type === 'pinch') {
      event.preventDefault();
      const ts = this._touchState;
      const [midX, midY] = this.touchMidpoint(touches);
      const zoom = this.panZoom.clampZoom(ts.startZoom * (touchDistance(touches) / ts.startDist));
      const scale = zoom / this.viewport.zoom;

      this.panZoom.setViewport({
        x: midX - (midX - this.viewport.x) * scale + (midX - ts.lastMidX),
        y: midY - (midY - this.viewport.y) * scale + (midY - ts.lastMidY),
        zoom,
      });
      this.panZoom.throttledPushViewport();

      ts.lastMidX = midX;
      ts.lastMidY = midY;
      return;
    }

    if (touches.length === 1 && this._touchState?.type === 'single' && this.interactionMode) {
      event.preventDefault();
      this.onPointerMove(this.touchToMouse(event));
    }
  },

  onTouchEnd(event) {
    if (this._touchState?.type === 'pinch') {
      if (event.touches.length === 0) {
        this._touchState = null;
        this.panZoom.flushViewport();
      }
      return;
    }

    this._touchState = null;
    if (this.interactionMode) {
      this.onPointerUp(this.touchToMouse(event));
    }
  },

  onTouchCancel() {
    this._touchState = null;
    this.abortInteraction();
  },

  touchToMouse(event) {
    const touch = event.touches[0] || event.changedTouches[0];
    return {
      clientX: touch.clientX,
      clientY: touch.clientY,
      target: event.target,
      button: 0,
      shiftKey: false,
      ctrlKey: false,
      metaKey: false,
      altKey: false,
      isTouch: true,
      preventDefault() {},
      stopPropagation() {},
    };
  },

  touchMidpoint(touches) {
    const rect = this.getContainerRect();
    return [
      (touches[0].clientX + touches[1].clientX) / 2 - rect.left,
      (touches[0].clientY + touches[1].clientY) / 2 - rect.top,
    ];
  },

  // ===== Keyboard =====

  ownsKeyboard() {
    const active = document.activeElement;
    if (this.container.contains(active)) return true;
    return (!active || active === document.body) && activeFlow === this;
  },

  onKeyDown(event) {
    this.keys.down(event);
    if (!this.ownsKeyboard() || isInputTarget(event)) return;

    const config = this.config;
    const key = event.key.toLowerCase();
    const mod = event.ctrlKey || event.metaKey;
    const hasSelection = this.selectedNodes.size > 0 || this.selectedEdges.size > 0;

    if (matchesKeys(event, config.panActivationKey)) {
      // Space would scroll the page
      if (key === ' ') event.preventDefault();
      this.container.dataset.panActive = 'true';
    }

    if (matchesKeys(event, config.deleteKeyCode)) {
      if (hasSelection) {
        event.preventDefault();
        this.pushEvent('lf:delete_selected', {});
      }
      return;
    }

    if (key === 'escape') {
      if (this.connection.isClickConnecting()) {
        this.connection.abortConnection();
      } else if (this.interactionMode) {
        this.abortInteraction();
      } else if (this.shortcutsPanelVisible) {
        this.hideShortcutsPanel();
      } else {
        this.selection.clearSelection();
      }
      return;
    }

    if (mod) {
      switch (key) {
        case 'a':
          event.preventDefault();
          this.selection.selectAll();
          return;
        case 'z':
          event.preventDefault();
          this.pushEvent(event.shiftKey ? 'lf:redo' : 'lf:undo', {});
          return;
        case 'y':
          event.preventDefault();
          this.pushEvent('lf:redo', {});
          return;
        case 'c':
        case 'x':
        case 'd':
          if (hasSelection) {
            event.preventDefault();
            this.pushEvent({ c: 'lf:copy', x: 'lf:cut', d: 'lf:duplicate' }[key], {});
          }
          return;
        case 'v':
          event.preventDefault();
          this.pushEvent('lf:paste', this.pastePayload());
          return;
      }
    }

    if (event.key === '?' && !mod) {
      event.preventDefault();
      this.toggleShortcutsPanel();
      return;
    }

    // Move selected nodes with the arrow keys (Shift = 4x)
    const ARROWS = { arrowup: [0, -1], arrowdown: [0, 1], arrowleft: [-1, 0], arrowright: [1, 0] };
    if (ARROWS[key] && !mod && !config.disableKeyboardA11y && this.selectedNodes.size > 0) {
      event.preventDefault();
      const factor = event.shiftKey ? 4 : 1;
      const [dx, dy] = ARROWS[key];
      const stepX = config.snapToGrid ? config.snapGridX : 5;
      const stepY = config.snapToGrid ? config.snapGridY : 5;
      this.nodeDrag.nudge(dx * stepX * factor, dy * stepY * factor);
    }
  },

  onKeyUp(event) {
    this.keys.up(event);
    if (!this.keys.isHeld(this.config.panActivationKey)) {
      delete this.container.dataset.panActive;
    }
  },

  onWindowBlur() {
    this.keys.clear();
    delete this.container.dataset.panActive;
    this.abortInteraction();
  },

  // ===== Edge Label Editing =====

  /**
   * @returns {boolean} whether the double click started a label edit
   */
  onEdgeLabelDblClick(event) {
    const labelEl = event.target.closest('.lf-edge-label');
    if (!labelEl) return false;

    const edgeGroup = labelEl.closest('[data-edge-id]');
    const wrapper = labelEl.closest('.lf-edge-label-wrapper');
    if (!edgeGroup || !wrapper) return false;

    event.preventDefault();
    event.stopPropagation();

    const edgeId = edgeGroup.dataset.edgeId;
    const currentText = labelEl.textContent.trim();

    wrapper.classList.add('lf-edge-label-editing');
    const input = document.createElement('input');
    input.type = 'text';
    input.className = 'lf-edge-label-input';
    input.value = currentText;

    labelEl.textContent = '';
    labelEl.appendChild(input);
    input.focus();
    input.select();

    let done = false;
    const finish = (commit) => {
      if (done) return;
      done = true;
      const newText = input.value.trim();
      wrapper.classList.remove('lf-edge-label-editing');

      if (commit && newText !== currentText) {
        this.pushEvent('lf:edge_label_change', { id: edgeId, label: newText || null });
      }
      labelEl.textContent = commit ? (newText || currentText) : currentText;
    };

    input.addEventListener('keydown', (e) => {
      e.stopPropagation();
      if (e.key === 'Enter') {
        e.preventDefault();
        finish(true);
      } else if (e.key === 'Escape') {
        e.preventDefault();
        finish(false);
      }
    });
    input.addEventListener('blur', () => finish(true));
    input.addEventListener('mousedown', (e) => e.stopPropagation());
    return true;
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

    const isMac = /mac/i.test(navigator.userAgentData?.platform || navigator.platform || '');
    const mod = isMac ? '⌘' : 'Ctrl';
    const keyLabel = (combos) => combos.map(c => c.map(k => k.length === 1 ? k.toUpperCase() : k[0].toUpperCase() + k.slice(1)).join('+')).join(' / ');

    const shortcuts = [
      { section: 'General' },
      { keys: '?', desc: 'Toggle shortcuts panel' },
      { keys: 'Escape', desc: 'Clear selection / Cancel' },
      { keys: keyLabel(this.config.deleteKeyCode) || '—', desc: 'Delete selected' },
      { keys: `${mod}+A`, desc: 'Select all' },
      { keys: 'Arrows', desc: 'Move selected nodes (Shift = faster)' },
      { section: 'History' },
      { keys: `${mod}+Z`, desc: 'Undo' },
      { keys: `${mod}+Shift+Z`, desc: 'Redo' },
      { section: 'Clipboard' },
      { keys: `${mod}+C`, desc: 'Copy selected' },
      { keys: `${mod}+X`, desc: 'Cut selected' },
      { keys: `${mod}+V`, desc: 'Paste' },
      { keys: `${mod}+D`, desc: 'Duplicate selected' },
      { section: 'Navigation' },
      { keys: this.config.panOnScroll ? 'Scroll' : `${mod}+Scroll`, desc: this.config.panOnScroll ? 'Pan canvas' : 'Pinch zoom' },
      { keys: 'Scroll', desc: this.config.panOnScroll ? '' : 'Zoom in/out' },
      { keys: 'Drag', desc: 'Pan canvas' },
      { keys: `${keyLabel(this.config.panActivationKey)} + Drag`, desc: 'Pan canvas (anywhere)' },
      { keys: `${keyLabel(this.config.selectionKey)} + Drag`, desc: 'Box selection' },
    ].filter(s => s.section || (s.keys && s.desc));

    const overlay = document.createElement('div');
    overlay.className = 'lf-shortcuts-overlay';
    overlay.setAttribute('data-lf-shortcuts', '');

    const panel = document.createElement('div');
    panel.className = 'lf-shortcuts-panel';

    const header = document.createElement('div');
    header.className = 'lf-shortcuts-header';
    header.innerHTML = '<span class="lf-shortcuts-title">Keyboard Shortcuts</span><button class="lf-shortcuts-close" type="button">×</button>';

    const body = document.createElement('div');
    body.className = 'lf-shortcuts-body';

    for (const item of shortcuts) {
      if (item.section) {
        const section = document.createElement('div');
        section.className = 'lf-shortcuts-section';
        section.textContent = item.section;
        body.appendChild(section);
        continue;
      }

      const row = document.createElement('div');
      row.className = 'lf-shortcuts-row';
      const keys = document.createElement('span');
      keys.className = 'lf-shortcuts-keys';
      item.keys.split('+').forEach((k, i) => {
        if (i > 0) keys.append(' + ');
        const kbd = document.createElement('kbd');
        kbd.textContent = k.trim();
        keys.appendChild(kbd);
      });
      const desc = document.createElement('span');
      desc.className = 'lf-shortcuts-desc';
      desc.textContent = item.desc;
      row.append(keys, desc);
      body.appendChild(row);
    }

    panel.append(header, body);
    overlay.appendChild(panel);
    this.interactionLayer.appendChild(overlay);

    overlay.addEventListener('click', (e) => {
      if (e.target === overlay || e.target.closest('.lf-shortcuts-close')) {
        this.hideShortcutsPanel();
      }
    });
  },

  hideShortcutsPanel() {
    this.shortcutsPanelVisible = false;
    this.interactionLayer.querySelector('[data-lf-shortcuts]')?.remove();
  },

  // ===== Viewport Operations =====

  applyViewportTransform() {
    const { x, y, zoom } = this.viewport;
    if (this.viewportEl) {
      this.viewportEl.style.transform = `translate(${x}px, ${y}px) scale(${zoom})`;
    }
    this.updateBackground();
    this.updateMinimapViewport();
    this.cursor?.repositionAll();
    if (this.connection?.isConnecting()) this.connection.updatePreviewLine();
  },

  /**
   * Keep the background pattern aligned with the viewport during client-side
   * pan/zoom. Same math as xyflow's <Background /> (including the 12.11.3
   * offset fix), mirrored by LiveFlow.Components.Flow on the server.
   */
  updateBackground() {
    const bg = this.config.background;
    const pattern = this.backgroundEl?.querySelector('pattern');
    if (!bg || !pattern) return;

    const { x, y, zoom } = this.viewport;
    const gapX = bg.gap[0] * zoom || 1;
    const gapY = bg.gap[1] * zoom || 1;
    const size = bg.size * zoom;
    const isCross = bg.variant === 'cross';
    const dims = isCross ? [size, size] : [gapX, gapY];
    const offsetX = bg.offset[0] * zoom + dims[0] / 2;
    const offsetY = bg.offset[1] * zoom + dims[1] / 2;

    pattern.setAttribute('x', x % gapX);
    pattern.setAttribute('y', y % gapY);
    pattern.setAttribute('width', gapX);
    pattern.setAttribute('height', gapY);
    pattern.setAttribute('patternTransform', `translate(-${offsetX},-${offsetY})`);

    const shape = pattern.firstElementChild;
    if (!shape) return;
    if (bg.variant === 'dots') {
      const r = size / 2;
      shape.setAttribute('cx', r);
      shape.setAttribute('cy', r);
      shape.setAttribute('r', r);
    } else {
      shape.setAttribute('d', `M${dims[0] / 2} 0 V${dims[1]} M0 ${dims[1] / 2} H${dims[0]}`);
    }
  },

  /**
   * Move the minimap viewport rectangle client-side. The node layout of the
   * minimap (scale/offset) is computed by the server.
   */
  updateMinimapViewport() {
    const minimap = this.minimapEl;
    const rectEl = minimap?.querySelector('.lf-minimap-viewport');
    if (!rectEl || !minimap.dataset.scale) return;

    const scale = parseFloat(minimap.dataset.scale);
    const offsetX = parseFloat(minimap.dataset.offsetX);
    const offsetY = parseFloat(minimap.dataset.offsetY);
    const { x, y, zoom } = this.viewport;
    const container = this.containerRect || this.getContainerRect();

    rectEl.style.left = `${(-x / zoom) * scale + offsetX}px`;
    rectEl.style.top = `${(-y / zoom) * scale + offsetY}px`;
    rectEl.style.width = `${(container.width / zoom) * scale}px`;
    rectEl.style.height = `${(container.height / zoom) * scale}px`;
  },

  panToMinimapPoint(event) {
    const minimap = this.minimapEl;
    if (!minimap?.dataset.scale) return;

    const rect = minimap.getBoundingClientRect();
    const scale = parseFloat(minimap.dataset.scale);
    const flowX = (event.clientX - rect.left - parseFloat(minimap.dataset.offsetX)) / scale;
    const flowY = (event.clientY - rect.top - parseFloat(minimap.dataset.offsetY)) / scale;
    const container = this.getContainerRect();
    const { zoom } = this.viewport;

    this.panZoom.setViewport({ x: container.width / 2 - flowX * zoom, y: container.height / 2 - flowY * zoom, zoom });
    this.panZoom.throttledPushViewport();
  },

  // ===== Remote Drag Interpolation =====

  onRemoteDrag(data) {
    if (!data.changes) return;
    for (const change of data.changes) {
      if (!change.position) continue;
      const el = this.nodeEl(change.id);
      if (!el) continue;

      const entry = this._remoteDragTargets.get(change.id);
      if (entry) {
        entry.el = el;
        entry.targetX = change.position.x;
        entry.targetY = change.position.y;
      } else {
        this._remoteDragTargets.set(change.id, {
          el,
          currentX: parseFloat(el.style.left) || 0,
          currentY: parseFloat(el.style.top) || 0,
          targetX: change.position.x,
          targetY: change.position.y,
        });
      }
    }

    if (!this._remoteDragFrame) {
      this._remoteDragFrame = requestAnimationFrame(() => this.animateRemoteDrag());
    }
  },

  animateRemoteDrag() {
    this._remoteDragFrame = null;
    let needsMore = false;
    const movedIds = new Set();

    this._remoteDragTargets.forEach((entry, nodeId) => {
      const dx = entry.targetX - entry.currentX;
      const dy = entry.targetY - entry.currentY;

      if (Math.abs(dx) > 0.5 || Math.abs(dy) > 0.5) {
        entry.currentX += dx * 0.4;
        entry.currentY += dy * 0.4;
        needsMore = true;
      } else {
        entry.currentX = entry.targetX;
        entry.currentY = entry.targetY;
      }

      entry.el.style.left = `${entry.currentX}px`;
      entry.el.style.top = `${entry.currentY}px`;
      movedIds.add(nodeId);
    });

    if (movedIds.size > 0) {
      this.edges.updateForNodes(movedIds);
      this.connection.refreshStart();
    }

    if (needsMore) {
      this._remoteDragFrame = requestAnimationFrame(() => this.animateRemoteDrag());
    } else {
      this._remoteDragTargets.clear();
    }
  },

  // ===== Export =====

  /**
   * @param {{filename?: string, padding?: number}} [options]
   */
  exportSVG(options = {}) {
    const svgString = exportSVG(this.container, { padding: options.padding });
    if (svgString) downloadString(svgString, options.filename || 'flow.svg', 'image/svg+xml');
  },

  /**
   * @param {{filename?: string, padding?: number, scale?: number}} [options]
   */
  exportPNG(options = {}) {
    exportPNG(this.container, options.scale || 2, { padding: options.padding })
      .then(blob => downloadBlob(blob, options.filename || 'flow.png'))
      .catch(err => console.error('[LiveFlow] PNG export failed:', err));
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

function touchDistance(touches) {
  return Math.hypot(touches[0].clientX - touches[1].clientX, touches[0].clientY - touches[1].clientY);
}

function normalizeFitViewPayload(payload = {}) {
  const options = {};
  if (payload.padding !== undefined) options.padding = payload.padding;
  if (payload.duration !== undefined) options.duration = payload.duration;
  if (payload.bounds) options.bounds = payload.bounds;
  if (payload.nodes) options.nodes = payload.nodes;
  if (payload.min_zoom !== undefined) options.minZoom = payload.min_zoom;
  if (payload.max_zoom !== undefined) options.maxZoom = payload.max_zoom;
  return options;
}
