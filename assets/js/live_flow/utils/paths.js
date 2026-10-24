/**
 * Path calculation utilities for LiveFlow.
 *
 * These mirror the server-side modules in lib/live_flow/paths/ so edges keep
 * their exact shape while nodes are dragged or resized client-side:
 *
 *   - bezier     -> LiveFlow.Paths.Bezier
 *   - straight   -> LiveFlow.Paths.Straight
 *   - smoothstep -> LiveFlow.Paths.Smoothstep (port of xyflow's getSmoothStepPath)
 *   - step       -> LiveFlow.Paths.Step (smoothstep with border_radius 0)
 *
 * Every function returns `{ path, labelX, labelY }`.
 */

const DEFAULT_CURVATURE = 0.25;
const MIN_OFFSET = 50;

const HANDLE_DIRECTIONS = {
  left: { x: -1, y: 0 },
  right: { x: 1, y: 0 },
  top: { x: 0, y: -1 },
  bottom: { x: 0, y: 1 },
};

// Round to 2 decimals and drop trailing zeros (matches the Elixir formatter)
const fmt = (n) => `${+n.toFixed(2)}`;

export function oppositePosition(position) {
  switch (position) {
    case 'left': return 'right';
    case 'right': return 'left';
    case 'top': return 'bottom';
    case 'bottom': return 'top';
    default: return 'left';
  }
}

// ===== Bezier =====

function controlPoint(x, y, position, curvature, tx, ty) {
  const offset = Math.max(Math.max(Math.abs(tx - x), Math.abs(ty - y)) * curvature, MIN_OFFSET);

  switch (position) {
    case 'left': return [x - offset, y];
    case 'top': return [x, y - offset];
    case 'bottom': return [x, y + offset];
    default: return [x + offset, y];
  }
}

export function getBezierPath(sx, sy, sourcePosition, tx, ty, targetPosition, options = {}) {
  const curvature = options.curvature ?? DEFAULT_CURVATURE;
  targetPosition = targetPosition || oppositePosition(sourcePosition);

  const [c1x, c1y] = controlPoint(sx, sy, sourcePosition, curvature, tx, ty);
  const [c2x, c2y] = controlPoint(tx, ty, targetPosition, curvature, sx, sy);

  // Point on the cubic curve at t = 0.5
  const labelX = 0.125 * sx + 0.375 * c1x + 0.375 * c2x + 0.125 * tx;
  const labelY = 0.125 * sy + 0.375 * c1y + 0.375 * c2y + 0.125 * ty;

  return {
    path: `M ${fmt(sx)},${fmt(sy)} C ${fmt(c1x)},${fmt(c1y)} ${fmt(c2x)},${fmt(c2y)} ${fmt(tx)},${fmt(ty)}`,
    labelX,
    labelY,
  };
}

/**
 * Backwards compatible helper that only returns the path string.
 */
export function calculateBezierPath(sx, sy, sourcePosition, tx, ty, targetPosition, curvature = DEFAULT_CURVATURE) {
  return getBezierPath(sx, sy, sourcePosition, tx, ty, targetPosition, { curvature }).path;
}

// ===== Straight =====

export function getStraightPath(sx, sy, tx, ty) {
  return {
    path: `M ${fmt(sx)},${fmt(sy)} L ${fmt(tx)},${fmt(ty)}`,
    labelX: (sx + tx) / 2,
    labelY: (sy + ty) / 2,
  };
}

// ===== Smoothstep / Step =====

const distance = (a, b) => Math.sqrt((b.x - a.x) ** 2 + (b.y - a.y) ** 2);

// Checks if b lies on the straight segment from a to c, including b === c
const isBetween = (a, b, c) =>
  (a.x === b.x && b.x === c.x && (b.y - a.y) * (c.y - b.y) >= 0) ||
  (a.y === b.y && b.y === c.y && (b.x - a.x) * (c.x - b.x) >= 0);

function getDirection(source, sourcePosition, target) {
  if (sourcePosition === 'left' || sourcePosition === 'right') {
    return source.x < target.x ? { x: 1, y: 0 } : { x: -1, y: 0 };
  }
  return source.y < target.y ? { x: 0, y: 1 } : { x: 0, y: -1 };
}

/*
 * Mimics an orthogonal edge routing behaviour. Not as good as a real
 * orthogonal router, but fast and good enough for step/smoothstep edges.
 */
function getStepPoints(source, sourcePosition, target, targetPosition, center, offset, stepPosition) {
  const sourceDir = HANDLE_DIRECTIONS[sourcePosition];
  const targetDir = HANDLE_DIRECTIONS[targetPosition];
  const sourceGapped = { x: source.x + sourceDir.x * offset, y: source.y + sourceDir.y * offset };
  const targetGapped = { x: target.x + targetDir.x * offset, y: target.y + targetDir.y * offset };
  const dir = getDirection(sourceGapped, sourcePosition, targetGapped);
  const axis = dir.x !== 0 ? 'x' : 'y';
  const currDir = dir[axis];

  let points = [];
  let centerX, centerY;
  const sourceGapOffset = { x: 0, y: 0 };
  const targetGapOffset = { x: 0, y: 0 };

  if (sourceDir[axis] * targetDir[axis] === -1) {
    // Opposite handle positions (default case)
    if (axis === 'x') {
      centerX = center.x ?? sourceGapped.x + (targetGapped.x - sourceGapped.x) * stepPosition;
      centerY = center.y ?? (sourceGapped.y + targetGapped.y) / 2;
    } else {
      centerX = center.x ?? (sourceGapped.x + targetGapped.x) / 2;
      centerY = center.y ?? sourceGapped.y + (targetGapped.y - sourceGapped.y) * stepPosition;
    }

    const verticalSplit = [{ x: centerX, y: sourceGapped.y }, { x: centerX, y: targetGapped.y }];
    const horizontalSplit = [{ x: sourceGapped.x, y: centerY }, { x: targetGapped.x, y: centerY }];

    if (sourceDir[axis] === currDir) {
      points = axis === 'x' ? verticalSplit : horizontalSplit;
    } else {
      points = axis === 'x' ? horizontalSplit : verticalSplit;
    }
  } else {
    // sourceTarget takes x from source and y from target, targetSource the opposite
    const sourceTarget = [{ x: sourceGapped.x, y: targetGapped.y }];
    const targetSource = [{ x: targetGapped.x, y: sourceGapped.y }];

    if (axis === 'x') {
      points = sourceDir.x === currDir ? targetSource : sourceTarget;
    } else {
      points = sourceDir.y === currDir ? sourceTarget : targetSource;
    }

    if (sourcePosition === targetPosition) {
      // Same handle positions closer than the offset would overlap the gapped points
      const diff = Math.abs(source[axis] - target[axis]);

      if (diff <= offset) {
        const gapOffset = Math.min(offset - 1, offset - diff);
        if (sourceDir[axis] === currDir) {
          sourceGapOffset[axis] = (sourceGapped[axis] > source[axis] ? -1 : 1) * gapOffset;
        } else {
          targetGapOffset[axis] = (targetGapped[axis] > target[axis] ? -1 : 1) * gapOffset;
        }
      }
    }

    // Mixed handle positions like right -> bottom
    if (sourcePosition !== targetPosition) {
      const opp = axis === 'x' ? 'y' : 'x';
      const isSameDir = sourceDir[axis] === targetDir[opp];
      const sourceGtTarget = sourceGapped[opp] > targetGapped[opp];
      const sourceLtTarget = sourceGapped[opp] < targetGapped[opp];
      const flip =
        (sourceDir[axis] === 1 && ((!isSameDir && sourceGtTarget) || (isSameDir && sourceLtTarget))) ||
        (sourceDir[axis] !== 1 && ((!isSameDir && sourceLtTarget) || (isSameDir && sourceGtTarget)));

      if (flip) {
        points = axis === 'x' ? sourceTarget : targetSource;
      }
    }

    const sourceGapPoint = { x: sourceGapped.x + sourceGapOffset.x, y: sourceGapped.y + sourceGapOffset.y };
    const targetGapPoint = { x: targetGapped.x + targetGapOffset.x, y: targetGapped.y + targetGapOffset.y };
    const maxXDistance = Math.max(Math.abs(sourceGapPoint.x - points[0].x), Math.abs(targetGapPoint.x - points[0].x));
    const maxYDistance = Math.max(Math.abs(sourceGapPoint.y - points[0].y), Math.abs(targetGapPoint.y - points[0].y));

    // Place the label on the longest segment of the edge
    if (maxXDistance >= maxYDistance) {
      centerX = (sourceGapPoint.x + targetGapPoint.x) / 2;
      centerY = points[0].y;
    } else {
      centerX = points[0].x;
      centerY = (sourceGapPoint.y + targetGapPoint.y) / 2;
    }
  }

  const gappedSource = { x: sourceGapped.x + sourceGapOffset.x, y: sourceGapped.y + sourceGapOffset.y };
  const gappedTarget = { x: targetGapped.x + targetGapOffset.x, y: targetGapped.y + targetGapOffset.y };

  const pathPoints = [];
  for (const point of [source, gappedSource, ...points, gappedTarget, target]) {
    const [a, b] = pathPoints.slice(-2);
    // Drop b if the path runs straight through it, otherwise it would shrink the next bend
    if (b && isBetween(a, b, point)) {
      pathPoints.pop();
    }
    pathPoints.push(point);
  }

  return [pathPoints, centerX, centerY];
}

function getBend(a, b, c, size) {
  const bendSize = Math.min(distance(a, b) / 2, distance(b, c) / 2, size);
  const { x, y } = b;

  if (bendSize <= 0 || (a.x === x && x === c.x) || (a.y === y && y === c.y)) {
    return `L${fmt(x)} ${fmt(y)}`;
  }

  // First segment is horizontal
  if (a.y === y) {
    const xDir = a.x < c.x ? -1 : 1;
    const yDir = a.y < c.y ? 1 : -1;
    return `L ${fmt(x + bendSize * xDir)},${fmt(y)}Q ${fmt(x)},${fmt(y)} ${fmt(x)},${fmt(y + bendSize * yDir)}`;
  }

  const xDir = a.x < c.x ? 1 : -1;
  const yDir = a.y < c.y ? -1 : 1;
  return `L ${fmt(x)},${fmt(y + bendSize * yDir)}Q ${fmt(x)},${fmt(y)} ${fmt(x + bendSize * xDir)},${fmt(y)}`;
}

export function getSmoothStepPath(sx, sy, sourcePosition = 'bottom', tx, ty, targetPosition = 'top', options = {}) {
  const [points, labelX, labelY] = getStepPoints(
    { x: sx, y: sy },
    sourcePosition || 'bottom',
    { x: tx, y: ty },
    targetPosition || 'top',
    { x: options.center_x ?? undefined, y: options.center_y ?? undefined },
    options.offset ?? 20,
    options.step_position ?? 0.5
  );
  const borderRadius = options.border_radius ?? 5;

  let path = `M${fmt(points[0].x)} ${fmt(points[0].y)}`;
  for (let i = 1; i < points.length - 1; i++) {
    path += getBend(points[i - 1], points[i], points[i + 1], borderRadius);
  }
  const last = points[points.length - 1];
  path += `L${fmt(last.x)} ${fmt(last.y)}`;

  return { path, labelX, labelY };
}

export function getStepPath(sx, sy, sourcePosition, tx, ty, targetPosition, options = {}) {
  return getSmoothStepPath(sx, sy, sourcePosition, tx, ty, targetPosition, { ...options, border_radius: 0 });
}

// Path functions registered by apps for their own edge types
const customPaths = new Map();

/**
 * Register a path function so the client can redraw a custom edge type while
 * nodes are dragged (render the edge with `data-path-type="<type>"`).
 *
 *     registerEdgePath('arc', (source, target, options) => ({
 *       path: `M ${source.x},${source.y} A 60 60 0 0 1 ${target.x},${target.y}`,
 *       labelX: (source.x + target.x) / 2,
 *       labelY: (source.y + target.y) / 2,
 *     }))
 *
 * @param {string} type
 * @param {(source, target, options) => {path: string, labelX: number, labelY: number}} fn
 */
export function registerEdgePath(type, fn) {
  customPaths.set(type, fn);
}

/**
 * Compute the path for any built-in edge type.
 *
 * @param {string} type - 'bezier' | 'straight' | 'step' | 'smoothstep' (unknown types fall back to bezier)
 * @param {{x: number, y: number, position: string}} source
 * @param {{x: number, y: number, position: string}} target
 * @param {Object} [options] - Path options as serialized from the server (snake_case keys)
 * @returns {{path: string, labelX: number, labelY: number}}
 */
export function getEdgePath(type, source, target, options = {}) {
  const custom = customPaths.get(type);
  if (custom) return custom(source, target, options);

  switch (type) {
    case 'straight':
      return getStraightPath(source.x, source.y, target.x, target.y);
    case 'step':
      return getStepPath(source.x, source.y, source.position, target.x, target.y, target.position, options);
    case 'smoothstep':
      return getSmoothStepPath(source.x, source.y, source.position, target.x, target.y, target.position, options);
    default:
      return getBezierPath(source.x, source.y, source.position, target.x, target.y, target.position, options);
  }
}
