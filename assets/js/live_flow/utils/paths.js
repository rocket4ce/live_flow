/**
 * Path calculation utilities for LiveFlow
 * Ported from lib/live_flow/paths/bezier.ex
 */

const DEFAULT_CURVATURE = 0.25;
const MIN_OFFSET = 50;

/**
 * Calculate control point based on handle position
 */
function controlPoint(x, y, position, curvature, tx, ty) {
  const dx = Math.abs(tx - x);
  const dy = Math.abs(ty - y);
  const offset = Math.max(Math.max(dx, dy) * curvature, MIN_OFFSET);

  switch (position) {
    case 'left':  return [x - offset, y];
    case 'right': return [x + offset, y];
    case 'top':   return [x, y - offset];
    case 'bottom': return [x, y + offset];
    default:      return [x + offset, y];
  }
}

function oppositePosition(position) {
  switch (position) {
    case 'left':   return 'right';
    case 'right':  return 'left';
    case 'top':    return 'bottom';
    case 'bottom': return 'top';
    default:       return 'left';
  }
}

/**
 * Calculate a cubic Bezier SVG path string between two points.
 *
 * @param {number} sx - Source X
 * @param {number} sy - Source Y
 * @param {string} sourcePosition - Handle position ('left'|'right'|'top'|'bottom')
 * @param {number} tx - Target X
 * @param {number} ty - Target Y
 * @param {string} [targetPosition] - Target handle position (defaults to opposite of source)
 * @param {number} [curvature] - Bezier curvature factor (default 0.25)
 * @returns {string} SVG path d attribute
 */
export function calculateBezierPath(sx, sy, sourcePosition, tx, ty, targetPosition, curvature = DEFAULT_CURVATURE) {
  if (!targetPosition) {
    targetPosition = oppositePosition(sourcePosition);
  }

  const [c1x, c1y] = controlPoint(sx, sy, sourcePosition, curvature, tx, ty);
  const [c2x, c2y] = controlPoint(tx, ty, targetPosition, curvature, sx, sy);

  return `M ${sx.toFixed(2)},${sy.toFixed(2)} C ${c1x.toFixed(2)},${c1y.toFixed(2)} ${c2x.toFixed(2)},${c2y.toFixed(2)} ${tx.toFixed(2)},${ty.toFixed(2)}`;
}
