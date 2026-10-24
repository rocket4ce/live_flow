// ELK (elkjs, ~1.6 MB) is optional: apps that use the client-side ELK layout
// register it once, which `mix live_flow.gen.elk` sets up in app.js:
//
//     import ELK from "../vendor/elk.bundled.cjs"
//     import {registerElk} from "live_flow"
//     registerElk(ELK)
let elk = null;

export const ELK_MISSING =
  '[LiveFlow] The ELK layout engine is not installed. Run `mix live_flow.gen.elk`, or ' +
  'import elkjs and call registerElk(ELK). LiveFlow.Layout.tree/2 and force/2 lay out ' +
  'flows on the server without ELK.';

/**
 * Registers the ELK engine used by `lf:layout_data`.
 *
 * @param {Function|Object} engine - the elkjs constructor (its default export) or an
 *   instance, e.g. `new ELK({workerUrl})` to run the layout in a web worker
 * @returns {Object} the ELK instance
 */
export function registerElk(engine) {
  elk = typeof engine?.layout === 'function' ? engine : new engine();
  return elk;
}

/** Returns true when an ELK engine has been registered. */
export function hasElk() {
  return elk !== null;
}

const DEFAULT_OPTIONS = {
  'elk.algorithm': 'layered',
  'elk.direction': 'DOWN',
  'elk.spacing.nodeNode': '80',
  'elk.layered.spacing.nodeNodeBetweenLayers': '100',
  'elk.spacing.edgeNode': '40',
  'elk.layered.nodePlacement.strategy': 'NETWORK_SIMPLEX',
};

/**
 * Runs ELK layout on the given nodes and edges.
 *
 * @param {Array<{id: string, width: number, height: number}>} nodes
 * @param {Array<{id: string, source: string, target: string}>} edges
 * @param {Object} options - ELK layout options override
 * @returns {Promise<Array<{id: string, x: number, y: number}>>} positioned nodes
 */
export async function getLayoutedElements(nodes, edges, options = {}) {
  if (!elk) throw new Error(ELK_MISSING);

  const layoutOptions = { ...DEFAULT_OPTIONS, ...options };

  // Handles become ELK ports on a fixed side, so ELK can order them to
  // reduce edge crossings (nodes with several handles)
  const portIds = new Set();
  const graph = {
    id: 'root',
    layoutOptions,
    children: nodes.map(node => {
      const ports = (node.ports || []).map(port => {
        const id = `${node.id}::${port.id}`;
        portIds.add(id);
        return { id, width: 1, height: 1, layoutOptions: { 'elk.port.side': port.side } };
      });

      return {
        id: node.id,
        width: node.width || 150,
        height: node.height || 50,
        ...(ports.length > 0 && {
          ports,
          layoutOptions: { 'elk.portConstraints': 'FIXED_ORDER' },
        }),
      };
    }),
    edges: edges.map(edge => {
      const source = `${edge.source}::${edge.source_handle}`;
      const target = `${edge.target}::${edge.target_handle}`;
      return {
        id: edge.id,
        sources: [portIds.has(source) ? source : edge.source],
        targets: [portIds.has(target) ? target : edge.target],
      };
    }),
  };

  const layoutedGraph = await elk.layout(graph);

  return layoutedGraph.children.map(node => ({
    id: node.id,
    x: node.x,
    y: node.y,
  }));
}
