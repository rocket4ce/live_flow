/**
 * Keeps edge SVG in sync with node geometry while nodes move client-side
 * (drag, resize, keyboard nudges, remote drag interpolation).
 *
 * Edges rendered by LiveFlow.Components.Edge carry everything needed to
 * recompute their path without a server round-trip:
 *
 *   data-source / data-target                 node ids
 *   data-source-handle / data-target-handle   handle ids (optional)
 *   data-source-floating / data-target-floating
 *   data-path-type                            bezier | straight | step | smoothstep
 *   data-path-options                         JSON path options (border_radius, offset, ...)
 *
 * Custom edge renderers can opt in by adding the same attributes to their
 * root `<g>` element.
 */
import { getEdgePath } from './paths.js';

const DEFAULT_WIDTH = 100;
const DEFAULT_HEIGHT = 40;

export class EdgeUpdater {
  constructor(hook) {
    this.hook = hook;
  }

  /**
   * Collect the edges connected to any of the given node ids.
   * @param {Set<string>} nodeIds
   */
  collect(nodeIds) {
    const entries = [];
    const groups = this.hook.edgeLayer?.querySelectorAll('g[data-edge-id][data-source][data-target]');
    if (!groups) return entries;

    groups.forEach(g => {
      const { source, target } = g.dataset;
      if (!nodeIds.has(source) && !nodeIds.has(target)) return;

      entries.push({
        g,
        source,
        target,
        type: g.dataset.pathType || 'bezier',
        options: parseOptions(g.dataset.pathOptions),
        sourceFloating: g.dataset.sourceFloating === 'true',
        targetFloating: g.dataset.targetFloating === 'true',
        ...this.handleInfo(source, g.dataset.sourceHandle, 'source', 'source'),
        ...this.handleInfo(target, g.dataset.targetHandle, 'target', 'target'),
        // Only the edge's own paths; icons inside foreignObjects also use <path>
        paths: g.querySelectorAll(':scope > path'),
        // Built-in overlays centered on the label point (custom foreignObjects are left alone)
        overlays: g.querySelectorAll(
          ':scope > foreignObject:is(.lf-edge-label-wrapper, .lf-edge-insert-wrapper, .lf-edge-toolbar-wrapper, .lf-edge-delete-wrapper, [data-lf-label-anchor])'
        ),
        sourceReconnect: g.querySelector(':scope > [data-reconnect-end="source"]'),
        targetReconnect: g.querySelector(':scope > [data-reconnect-end="target"]'),
      });
    });

    return entries;
  }

  /**
   * Recompute the given edges.
   * @param {Array} entries - result of collect()
   * @param {Map<string, {x?, y?, width?, height?}>} [overrides] - client-side geometry
   */
  update(entries, overrides) {
    for (const edge of entries) {
      const sourceRect = this.nodeRect(edge.source, overrides);
      const targetRect = this.nodeRect(edge.target, overrides);
      if (!sourceRect || !targetRect) continue;

      const source = edge.sourceFloating
        ? floatingPoint(sourceRect, targetRect)
        : { ...sidePoint(sourceRect, edge.sourcePosition, edge.sourceOffset), position: edge.sourcePosition };
      const target = edge.targetFloating
        ? floatingPoint(targetRect, sourceRect)
        : { ...sidePoint(targetRect, edge.targetPosition, edge.targetOffset), position: edge.targetPosition };

      const { path, labelX, labelY } = getEdgePath(edge.type, source, target, edge.options);

      edge.paths.forEach(p => p.setAttribute('d', path));

      // Labels, toolbars and buttons are foreignObjects centered on the label point
      edge.overlays.forEach(fo => {
        const width = parseFloat(fo.getAttribute('width')) || 0;
        const height = parseFloat(fo.getAttribute('height')) || 0;
        fo.setAttribute('x', labelX - width / 2);
        fo.setAttribute('y', labelY - height / 2);
      });

      if (edge.sourceReconnect) {
        edge.sourceReconnect.setAttribute('cx', source.x);
        edge.sourceReconnect.setAttribute('cy', source.y);
      }
      if (edge.targetReconnect) {
        edge.targetReconnect.setAttribute('cx', target.x);
        edge.targetReconnect.setAttribute('cy', target.y);
      }
    }
  }

  /**
   * Convenience: collect and update edges for a set of node ids in one go.
   */
  updateForNodes(nodeIds, overrides) {
    this.update(this.collect(nodeIds), overrides);
  }

  /**
   * Side (top/bottom/left/right) and offset along it of an edge endpoint,
   * as `{<prefix>Position, <prefix>Offset}`.
   */
  handleInfo(nodeId, handleId, type, prefix) {
    const nodeEl = this.hook.nodeEl(nodeId);
    let handleEl = null;
    if (nodeEl && handleId) {
      handleEl = nodeEl.querySelector(`[data-handle-id="${CSS.escape(handleId)}"]`);
    }
    if (nodeEl && !handleEl) {
      handleEl = nodeEl.querySelector(`[data-handle-type="${type}"]`);
    }

    const offset = parseFloat(handleEl?.dataset.handleOffset);
    return {
      [`${prefix}Position`]: handleEl?.dataset.handlePosition || (type === 'source' ? 'right' : 'left'),
      [`${prefix}Offset`]: Number.isFinite(offset) ? offset : 0.5,
    };
  }

  /**
   * Handle position (top/bottom/left/right) for an edge endpoint.
   */
  handlePosition(nodeId, handleId, type) {
    return this.handleInfo(nodeId, handleId, type, 'handle').handlePosition;
  }

  /**
   * Node rectangle in flow coordinates, preferring client-side overrides.
   */
  nodeRect(nodeId, overrides) {
    const nodeEl = this.hook.nodeEl(nodeId);
    if (!nodeEl) return null;

    const o = overrides?.get(nodeId);
    return {
      x: o?.x ?? (parseFloat(nodeEl.style.left) || 0),
      y: o?.y ?? (parseFloat(nodeEl.style.top) || 0),
      width: o?.width ?? (nodeEl.offsetWidth || DEFAULT_WIDTH),
      height: o?.height ?? (nodeEl.offsetHeight || DEFAULT_HEIGHT),
    };
  }
}

function parseOptions(json) {
  if (!json) return {};
  try {
    return JSON.parse(json);
  } catch (_e) {
    return {};
  }
}

/**
 * Point on a side of the node box, `t` from 0 (top/left) to 1 (bottom/right).
 * Mirrors LiveFlow.Paths.Geometry.side_point/3.
 */
function sidePoint({ x, y, width, height }, position, t = 0.5) {
  switch (position) {
    case 'top': return { x: x + width * t, y };
    case 'bottom': return { x: x + width * t, y: y + height };
    case 'left': return { x, y: y + height * t };
    default: return { x: x + width, y: y + height * t };
  }
}

/**
 * Nearest point on `rect`'s border facing `other`'s center.
 * Mirrors get_floating_position/2 in LiveFlow.Components.Edge.
 */
function floatingPoint(rect, other) {
  const cx = rect.x + rect.width / 2;
  const cy = rect.y + rect.height / 2;
  const dx = other.x + other.width / 2 - cx;
  const dy = other.y + other.height / 2 - cy;

  if (Math.abs(dx) < 0.001 && Math.abs(dy) < 0.001) {
    return { x: rect.x + rect.width, y: cy, position: 'right' };
  }

  const candidates = [];
  if (dx > 0) candidates.push([rect.width / 2 / dx, 'right']);
  if (dx < 0) candidates.push([-rect.width / 2 / dx, 'left']);
  if (dy > 0) candidates.push([rect.height / 2 / dy, 'bottom']);
  if (dy < 0) candidates.push([-rect.height / 2 / dy, 'top']);

  const [t, position] = candidates.reduce((min, c) => (c[0] < min[0] ? c : min));
  const x = Math.max(rect.x, Math.min(cx + dx * t, rect.x + rect.width));
  const y = Math.max(rect.y, Math.min(cy + dy * t, rect.y + rect.height));

  return { x, y, position };
}
