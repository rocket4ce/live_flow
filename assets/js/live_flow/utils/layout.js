import ELK from '../vendor/elk.bundled.js';

const elk = new ELK();

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
  const layoutOptions = { ...DEFAULT_OPTIONS, ...options };

  const graph = {
    id: 'root',
    layoutOptions,
    children: nodes.map(node => ({
      id: node.id,
      width: node.width || 150,
      height: node.height || 50,
    })),
    edges: edges.map(edge => ({
      id: edge.id,
      sources: [edge.source],
      targets: [edge.target],
    })),
  };

  const layoutedGraph = await elk.layout(graph);

  return layoutedGraph.children.map(node => ({
    id: node.id,
    x: node.x,
    y: node.y,
  }));
}
