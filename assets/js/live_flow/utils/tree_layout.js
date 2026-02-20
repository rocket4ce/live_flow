/**
 * Tree layout algorithm for LiveFlow.
 *
 * Positions nodes in a top-down (or left-right) tree hierarchy.
 * Pure JS, no external dependencies.
 */

/**
 * Compute tree layout positions for the given nodes and edges.
 *
 * @param {Array<{id: string, width?: number, height?: number}>} nodes
 * @param {Array<{id: string, source: string, target: string}>} edges
 * @param {Object} options
 * @param {string} options.direction - 'TB' (top-bottom) or 'LR' (left-right)
 * @param {number} options.nodeSpacing - horizontal gap between siblings
 * @param {number} options.levelSpacing - vertical gap between levels
 * @returns {Array<{id: string, x: number, y: number}>}
 */
export function treeLayout(nodes, edges, options = {}) {
  const {
    direction = 'TB',
    nodeSpacing = 40,
    levelSpacing = 100,
  } = options;

  const DEFAULT_W = 150;
  const DEFAULT_H = 50;

  // Build maps
  const nodeMap = new Map();
  nodes.forEach(n => nodeMap.set(n.id, {
    id: n.id,
    w: n.width || DEFAULT_W,
    h: n.height || DEFAULT_H,
  }));

  const childrenOf = new Map();   // parent -> [child ids]
  const parentOf = new Map();     // child -> parent id

  edges.forEach(e => {
    if (!nodeMap.has(e.source) || !nodeMap.has(e.target)) return;
    if (!childrenOf.has(e.source)) childrenOf.set(e.source, []);
    childrenOf.get(e.source).push(e.target);
    parentOf.set(e.target, e.source);
  });

  // Find roots (nodes with no incoming edge)
  const roots = [];
  nodeMap.forEach((_, id) => {
    if (!parentOf.has(id)) roots.push(id);
  });

  if (roots.length === 0) {
    return nodes.map(n => ({ id: n.id, x: 0, y: 0 }));
  }

  // Post-order: compute subtree widths
  function computeSubtreeSize(id) {
    const node = nodeMap.get(id);
    const kids = childrenOf.get(id) || [];

    if (kids.length === 0) {
      node._subtreeW = node.w;
      node._subtreeH = node.h;
      return;
    }

    kids.forEach(kid => computeSubtreeSize(kid));

    let totalChildW = 0;
    let maxChildH = 0;
    kids.forEach((kid, i) => {
      const kidNode = nodeMap.get(kid);
      totalChildW += kidNode._subtreeW;
      if (i > 0) totalChildW += nodeSpacing;
      maxChildH = Math.max(maxChildH, kidNode._subtreeH);
    });

    node._subtreeW = Math.max(node.w, totalChildW);
    node._subtreeH = node.h + levelSpacing + maxChildH;
  }

  // Compute subtree sizes for all roots
  roots.forEach(rootId => computeSubtreeSize(rootId));

  // Compute max height per depth level (so all nodes at same level align)
  const maxHeightAtDepth = new Map();
  function collectDepths(id, depth) {
    const node = nodeMap.get(id);
    node._depth = depth;
    const prev = maxHeightAtDepth.get(depth) || 0;
    maxHeightAtDepth.set(depth, Math.max(prev, node.h));
    (childrenOf.get(id) || []).forEach(kid => collectDepths(kid, depth + 1));
  }
  roots.forEach(rootId => collectDepths(rootId, 0));

  // Compute cumulative Y offset per level
  const levelY = new Map();
  let accY = 0;
  const maxDepth = Math.max(...maxHeightAtDepth.keys());
  for (let d = 0; d <= maxDepth; d++) {
    levelY.set(d, accY);
    accY += (maxHeightAtDepth.get(d) || 0) + levelSpacing;
  }

  // Pre-order: assign positions
  function assignPositions(id, offsetX) {
    const node = nodeMap.get(id);
    const kids = childrenOf.get(id) || [];

    // Center this node within its subtree width
    node._x = offsetX + (node._subtreeW - node.w) / 2;
    node._y = levelY.get(node._depth);

    // Place children starting from offsetX
    let childX = offsetX;
    kids.forEach(kid => {
      const kidNode = nodeMap.get(kid);
      assignPositions(kid, childX);
      childX += kidNode._subtreeW + nodeSpacing;
    });
  }

  // Layout each root side by side
  let rootX = 0;
  roots.forEach(rootId => {
    assignPositions(rootId, rootX);
    rootX += nodeMap.get(rootId)._subtreeW + nodeSpacing * 2;
  });

  // Build result, swap axes for LR direction
  const result = [];
  nodeMap.forEach((node) => {
    if (direction === 'LR') {
      result.push({ id: node.id, x: node._y, y: node._x });
    } else {
      result.push({ id: node.id, x: node._x, y: node._y });
    }
  });

  return result;
}
