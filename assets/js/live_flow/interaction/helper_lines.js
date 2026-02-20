/**
 * HelperLinesManager - Alignment guide lines during node drag
 *
 * Shows snap lines when dragged node edges align with other nodes.
 * Purely client-side, no server events.
 */

const SVG_NS = 'http://www.w3.org/2000/svg';
const THRESHOLD = 5;

export class HelperLinesManager {
  constructor(hook) {
    this.hook = hook;
    this.referenceEdges = [];
    this.overlaySvg = null;
    this.active = false;
  }

  /**
   * Called when drag starts. Precomputes reference edges for all
   * non-dragging, measured nodes.
   */
  startDrag(draggingNodeIds) {
    this.referenceEdges = [];
    this.active = true;

    const nodeEls = this.hook.nodeLayer.querySelectorAll('.lf-node[data-node-id]');
    nodeEls.forEach(el => {
      const nodeId = el.dataset.nodeId;
      if (draggingNodeIds.has(nodeId)) return;

      const x = parseFloat(el.style.left) || 0;
      const y = parseFloat(el.style.top) || 0;
      const w = el.offsetWidth;
      const h = el.offsetHeight;
      if (w === 0 && h === 0) return;

      this.referenceEdges.push({
        nodeId,
        top: y,
        bottom: y + h,
        left: x,
        right: x + w,
        centerX: x + w / 2,
        centerY: y + h / 2,
      });
    });

    this.createOverlay();
  }

  /**
   * Called on each drag move frame.
   * Returns snap corrections to apply to all dragging nodes.
   */
  computeGuides(draggingNodes) {
    if (!this.active || this.referenceEdges.length === 0) {
      this.clearLines();
      return { snapDx: 0, snapDy: 0 };
    }

    let dragTop = Infinity, dragBottom = -Infinity;
    let dragLeft = Infinity, dragRight = -Infinity;

    draggingNodes.forEach((drag) => {
      const x = parseFloat(drag.element.style.left) || 0;
      const y = parseFloat(drag.element.style.top) || 0;
      const w = drag.element.offsetWidth;
      const h = drag.element.offsetHeight;

      dragTop = Math.min(dragTop, y);
      dragBottom = Math.max(dragBottom, y + h);
      dragLeft = Math.min(dragLeft, x);
      dragRight = Math.max(dragRight, x + w);
    });

    const dragCenterX = (dragLeft + dragRight) / 2;
    const dragCenterY = (dragTop + dragBottom) / 2;

    const dragHEdges = [
      { value: dragTop },
      { value: dragBottom },
      { value: dragCenterY },
    ];
    const dragVEdges = [
      { value: dragLeft },
      { value: dragRight },
      { value: dragCenterX },
    ];

    const hGuides = [];
    const vGuides = [];
    let bestSnapDx = null;
    let bestSnapDy = null;
    let bestSnapDxDist = Infinity;
    let bestSnapDyDist = Infinity;

    for (const ref of this.referenceEdges) {
      const refHVals = [ref.top, ref.bottom, ref.centerY];
      const refVVals = [ref.left, ref.right, ref.centerX];

      for (const dEdge of dragHEdges) {
        for (const refVal of refHVals) {
          const dist = Math.abs(dEdge.value - refVal);
          if (dist <= THRESHOLD) {
            hGuides.push({
              y: refVal,
              fromX: Math.min(dragLeft, ref.left),
              toX: Math.max(dragRight, ref.right),
            });
            const snapDy = refVal - dEdge.value;
            if (Math.abs(snapDy) < bestSnapDyDist) {
              bestSnapDyDist = Math.abs(snapDy);
              bestSnapDy = snapDy;
            }
          }
        }
      }

      for (const dEdge of dragVEdges) {
        for (const refVal of refVVals) {
          const dist = Math.abs(dEdge.value - refVal);
          if (dist <= THRESHOLD) {
            vGuides.push({
              x: refVal,
              fromY: Math.min(dragTop, ref.top),
              toY: Math.max(dragBottom, ref.bottom),
            });
            const snapDx = refVal - dEdge.value;
            if (Math.abs(snapDx) < bestSnapDxDist) {
              bestSnapDxDist = Math.abs(snapDx);
              bestSnapDx = snapDx;
            }
          }
        }
      }
    }

    const uniqueH = this.deduplicateH(hGuides);
    const uniqueV = this.deduplicateV(vGuides);

    this.renderGuides(uniqueH, uniqueV);

    return {
      snapDx: bestSnapDx ?? 0,
      snapDy: bestSnapDy ?? 0,
      hasVGuide: bestSnapDx !== null,
      hasHGuide: bestSnapDy !== null,
    };
  }

  /**
   * Called when drag ends.
   */
  endDrag() {
    this.active = false;
    this.referenceEdges = [];
    this.removeOverlay();
  }

  // ===== SVG Overlay (inside phx-update="ignore" wrapper) =====

  createOverlay() {
    this.removeOverlay();

    // Use server-rendered wrapper with phx-update="ignore" to survive DOM patching
    this.wrapperEl = this.hook.container.querySelector('[data-helper-lines-container]');
    if (!this.wrapperEl) return;

    const svg = document.createElementNS(SVG_NS, 'svg');
    svg.style.cssText = 'width:100%;height:100%;overflow:visible;';

    const g = document.createElementNS(SVG_NS, 'g');
    g.setAttribute('data-helper-lines-group', '');
    const { x, y, zoom } = this.hook.viewport;
    g.setAttribute('transform', `translate(${x}, ${y}) scale(${zoom})`);

    svg.appendChild(g);
    this.wrapperEl.appendChild(svg);
    this.overlaySvg = svg;
  }

  renderGuides(hGuides, vGuides) {
    if (!this.overlaySvg) return;

    const g = this.overlaySvg.querySelector('[data-helper-lines-group]');
    if (!g) return;

    const { x, y, zoom } = this.hook.viewport;
    g.setAttribute('transform', `translate(${x}, ${y}) scale(${zoom})`);

    while (g.firstChild) g.removeChild(g.firstChild);

    const strokeWidth = 1 / zoom;

    for (const guide of hGuides) {
      const line = document.createElementNS(SVG_NS, 'line');
      line.setAttribute('x1', guide.fromX);
      line.setAttribute('y1', guide.y);
      line.setAttribute('x2', guide.toX);
      line.setAttribute('y2', guide.y);
      line.setAttribute('class', 'lf-helper-line');
      line.setAttribute('stroke-width', strokeWidth);
      g.appendChild(line);
    }

    for (const guide of vGuides) {
      const line = document.createElementNS(SVG_NS, 'line');
      line.setAttribute('x1', guide.x);
      line.setAttribute('y1', guide.fromY);
      line.setAttribute('x2', guide.x);
      line.setAttribute('y2', guide.toY);
      line.setAttribute('class', 'lf-helper-line');
      line.setAttribute('stroke-width', strokeWidth);
      g.appendChild(line);
    }
  }

  clearLines() {
    if (!this.overlaySvg) return;
    const g = this.overlaySvg.querySelector('[data-helper-lines-group]');
    if (g) {
      while (g.firstChild) g.removeChild(g.firstChild);
    }
  }

  removeOverlay() {
    if (this.overlaySvg) {
      this.overlaySvg.remove();
      this.overlaySvg = null;
    }
    this.wrapperEl = null;
  }

  // ===== Deduplication =====

  deduplicateH(guides) {
    const map = new Map();
    for (const g of guides) {
      const key = Math.round(g.y * 2);
      const existing = map.get(key);
      if (existing) {
        existing.fromX = Math.min(existing.fromX, g.fromX);
        existing.toX = Math.max(existing.toX, g.toX);
      } else {
        map.set(key, { ...g });
      }
    }
    return Array.from(map.values());
  }

  deduplicateV(guides) {
    const map = new Map();
    for (const g of guides) {
      const key = Math.round(g.x * 2);
      const existing = map.get(key);
      if (existing) {
        existing.fromY = Math.min(existing.fromY, g.fromY);
        existing.toY = Math.max(existing.toY, g.toY);
      } else {
        map.set(key, { ...g });
      }
    }
    return Array.from(map.values());
  }

  destroy() {
    this.removeOverlay();
    this.referenceEdges = [];
    this.active = false;
  }
}
