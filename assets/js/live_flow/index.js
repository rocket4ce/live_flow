/**
 * LiveFlow - Phoenix LiveView Flow Library
 *
 * Export the main hook for use in Phoenix applications.
 */

import { LiveFlowHook } from './hooks/flow_hook.js';

export { LiveFlowHook };

// Export utility hooks for file import/export
export { FileImportHook, setupDownloadHandler } from './hooks/utility_hooks.js';

// Path helpers, mirroring LiveFlow.Paths.* on the server (useful for custom edges)
export {
  getEdgePath,
  getBezierPath,
  getStraightPath,
  getStepPath,
  getSmoothStepPath,
  calculateBezierPath,
  registerEdgePath,
} from './utils/paths.js';

// Optional ELK auto-layout engine (`mix live_flow.gen.elk` adds and registers it)
export { registerElk, hasElk, getLayoutedElements } from './utils/layout.js';

// SVG/PNG export of a .lf-container element (used by lf:export-svg / lf:export-png)
export { exportSVG, exportPNG, buildExportSvg } from './utils/export.js';

// Export individual managers for advanced usage
export { CoordinateUtils } from './utils/coordinates.js';
export { EdgeUpdater } from './utils/edge_updater.js';
export { calcAutoPan } from './utils/auto_pan.js';
export { parseKeys, matchesKeys } from './utils/keys.js';
export { PanZoomManager } from './interaction/pan_zoom.js';
export { NodeDragManager } from './interaction/node_drag.js';
export { ConnectionManager } from './interaction/connection.js';
export { SelectionManager } from './interaction/selection.js';

// Default export for convenience
export default {
  LiveFlow: LiveFlowHook
};
