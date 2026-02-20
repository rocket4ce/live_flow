/**
 * LiveFlow - Phoenix LiveView Flow Library
 *
 * Export the main hook for use in Phoenix applications.
 */

import { LiveFlowHook } from './hooks/flow_hook.js';

export { LiveFlowHook };

// Export individual managers for advanced usage
export { CoordinateUtils } from './utils/coordinates.js';
export { PanZoomManager } from './interaction/pan_zoom.js';
export { NodeDragManager } from './interaction/node_drag.js';
export { ConnectionManager } from './interaction/connection.js';
export { SelectionManager } from './interaction/selection.js';

// Default export for convenience
export default {
  LiveFlow: LiveFlowHook
};
