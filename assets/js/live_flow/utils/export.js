/**
 * LiveFlow Export Utilities
 *
 * Exports the flow diagram as SVG or PNG from the rendered DOM.
 *
 * Nodes and edge labels are cloned with their *computed* styles inlined
 * (only the properties that differ from the browser defaults), so the export
 * is self-contained: Tailwind classes, theme variables, icons (CSS masks)
 * and markers render exactly as on screen, without depending on the page
 * stylesheets. The PNG is a rasterization of that same SVG.
 *
 * Editor chrome (delete buttons, resizers, edge toolbars, reconnect handles)
 * is left out. Add `data-lf-export-ignore` to any element to exclude it.
 */

const SVG_NS = 'http://www.w3.org/2000/svg';
const XHTML_NS = 'http://www.w3.org/1999/xhtml';

const EXCLUDE = [
  '.lf-node-delete-btn',
  '.lf-node-resizer-container',
  '.lf-edge-interaction',
  '.lf-edge-delete-wrapper',
  '.lf-edge-insert-wrapper',
  '.lf-edge-toolbar-wrapper',
  '.lf-edge-reconnect-handle',
  '[data-lf-export-ignore]',
].join(', ');

// Properties that don't affect the picture
const SKIP_PROPERTY = /^(animation|transition|cursor|pointer-events|user-select|-webkit-user-select|will-change|caret-color|touch-action|outline|scrollbar-|text-size-adjust|-webkit-locale|-webkit-tap-highlight-color|color-scheme|text-emphasis-color)|-rule-color$/;
// Logical properties duplicate the physical ones (border-block-start = border-top)
const LOGICAL_PROPERTY = /-(block|inline)(-|$)/;
// SVG elements only need paint and text properties; geometry lives in attributes
const SVG_PROPERTY = /^(fill|stroke|opacity|display|visibility|overflow|color$|font|text-anchor|dominant-baseline|letter-spacing|marker|paint-order|shape-rendering|mix-blend-mode|filter|clip-path|mask|transform|vector-effect)/;

// Room around nodes so handles and shadows aren't clipped
const NODE_OVERFLOW = 12;

/**
 * Inlines computed styles, diffing against the browser defaults of each
 * element type (read from a blank sandbox iframe).
 */
class StyleInliner {
  constructor() {
    this.defaults = new Map();
    this.pseudoRules = [];
    this.pseudoCount = 0;
    this.iframe = null;
  }

  sandbox() {
    if (!this.iframe) {
      this.iframe = document.createElement('iframe');
      this.iframe.setAttribute('aria-hidden', 'true');
      this.iframe.style.cssText = 'position:fixed;left:-10000px;top:0;width:100px;height:100px;visibility:hidden;border:0;';
      document.body.appendChild(this.iframe);
      const doc = this.iframe.contentDocument;
      doc.open();
      doc.write(`<!DOCTYPE html><html><head></head><body><svg xmlns="${SVG_NS}"></svg></body></html>`);
      doc.close();
    }
    return this.iframe;
  }

  defaultsFor(el, pseudo = null) {
    const key = `${el.namespaceURI}|${el.localName}|${pseudo || ''}`;
    if (this.defaults.has(key)) return this.defaults.get(key);

    const iframe = this.sandbox();
    const doc = iframe.contentDocument;
    const parent = el.namespaceURI === SVG_NS ? doc.querySelector('svg') : doc.body;
    const sandboxEl = doc.createElementNS(el.namespaceURI, el.localName);
    parent.appendChild(sandboxEl);

    const style = iframe.contentWindow.getComputedStyle(sandboxEl, pseudo);
    const values = new Map();
    for (let i = 0; i < style.length; i++) {
      values.set(style[i], style.getPropertyValue(style[i]));
    }

    sandboxEl.remove();
    this.defaults.set(key, values);
    return values;
  }

  declarations(source, pseudo = null) {
    const computed = getComputedStyle(source, pseudo);
    const defaults = this.defaultsFor(source, pseudo);
    const isSvg = source.namespaceURI === SVG_NS;
    const declarations = [];

    for (let i = 0; i < computed.length; i++) {
      const name = computed[i];
      if (name.startsWith('--') || SKIP_PROPERTY.test(name) || LOGICAL_PROPERTY.test(name)) continue;
      if (isSvg && !SVG_PROPERTY.test(name)) continue;

      const value = computed.getPropertyValue(name);
      if (value !== defaults.get(name)) {
        declarations.push(`${name}:${value}`);
      }
    }

    return declarations;
  }

  inline(source, target) {
    target.setAttribute('style', this.declarations(source).join(';'));

    // ::before / ::after can't be inlined: emit a scoped rule instead
    for (const pseudo of ['::before', '::after']) {
      const content = getComputedStyle(source, pseudo).getPropertyValue('content');
      if (!content || content === 'none' || content === 'normal') continue;

      const className = `lf-export-p${this.pseudoCount++}`;
      target.setAttribute('class', `${target.getAttribute('class') || ''} ${className}`.trim());
      this.pseudoRules.push(`.${className}${pseudo}{${this.declarations(source, pseudo).join(';')}}`);
    }
  }

  destroy() {
    this.iframe?.remove();
    this.iframe = null;
  }
}

/**
 * Deep-clones `source`, inlining computed styles and dropping comments,
 * editor chrome and framework attributes.
 */
function cloneWithStyles(source, inliner) {
  if (source.nodeType === Node.TEXT_NODE) return source.cloneNode(false);
  if (source.nodeType !== Node.ELEMENT_NODE) return null;
  if (source.matches(EXCLUDE)) return null;

  const clone = source.cloneNode(false);
  const isSvg = source.namespaceURI === SVG_NS;

  for (const { name } of Array.from(clone.attributes)) {
    // SVG ids are referenced by markers (marker-end="url(#...)")
    const keepId = name === 'id' && isSvg;
    if (!keepId && (name === 'id' || name === 'class' || name === 'style' ||
        name.startsWith('phx-') || name.startsWith('data-'))) {
      clone.removeAttribute(name);
    }
  }

  // Form fields keep their current value
  if (source instanceof HTMLInputElement) {
    if (source.type === 'checkbox' || source.type === 'radio') {
      if (source.checked) clone.setAttribute('checked', '');
    } else {
      clone.setAttribute('value', source.value);
    }
  }

  inliner.inline(source, clone);

  if (source instanceof HTMLTextAreaElement) {
    clone.textContent = source.value;
    return clone;
  }

  for (const child of source.childNodes) {
    const childClone = cloneWithStyles(child, inliner);
    if (childClone) clone.appendChild(childClone);
  }

  if (source instanceof HTMLSelectElement) {
    clone.querySelectorAll('option').forEach(option => {
      if (option.getAttribute('value') === source.value) option.setAttribute('selected', '');
    });
  }

  return clone;
}

// ===== Bounds =====

function renderedNodes(container) {
  return Array.from(container.querySelectorAll('[data-node-layer] .lf-node[data-node-id]'))
    .filter(el => el.offsetWidth > 0 || el.offsetHeight > 0);
}

function nodeRect(el) {
  return {
    x: parseFloat(el.style.left) || 0,
    y: parseFloat(el.style.top) || 0,
    width: el.offsetWidth,
    height: el.offsetHeight,
  };
}

/**
 * Bounds of everything drawn (nodes, edge paths, edge labels) in flow coordinates.
 */
function calculateBounds(container, padding) {
  let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
  const include = (x, y, width, height) => {
    minX = Math.min(minX, x);
    minY = Math.min(minY, y);
    maxX = Math.max(maxX, x + width);
    maxY = Math.max(maxY, y + height);
  };

  renderedNodes(container).forEach(el => {
    const r = nodeRect(el);
    include(r.x, r.y, r.width, r.height);
  });

  container.querySelectorAll('[data-edge-layer] path.lf-edge').forEach(path => {
    try {
      const box = path.getBBox();
      if (box.width || box.height) include(box.x, box.y, box.width, box.height);
    } catch (_e) {
      // Not rendered
    }
  });

  container.querySelectorAll('[data-edge-layer] foreignObject.lf-edge-label-wrapper').forEach(fo => {
    include(
      parseFloat(fo.getAttribute('x')) || 0,
      parseFloat(fo.getAttribute('y')) || 0,
      parseFloat(fo.getAttribute('width')) || 0,
      parseFloat(fo.getAttribute('height')) || 0
    );
  });

  if (!isFinite(minX)) return { x: 0, y: 0, width: 800, height: 600 };

  return {
    x: minX - padding,
    y: minY - padding,
    width: maxX - minX + padding * 2,
    height: maxY - minY + padding * 2,
  };
}

// ===== SVG building =====

function readConfig(container) {
  try {
    return JSON.parse(container.dataset.config || '{}');
  } catch (_e) {
    return {};
  }
}

function createRoot(bounds, scale) {
  const svg = document.createElementNS(SVG_NS, 'svg');
  svg.setAttribute('xmlns', SVG_NS);
  svg.setAttribute('width', bounds.width * scale);
  svg.setAttribute('height', bounds.height * scale);
  svg.setAttribute('viewBox', `${bounds.x} ${bounds.y} ${bounds.width} ${bounds.height}`);
  return svg;
}

/**
 * Canvas color plus the background pattern, in flow coordinates (zoom 1).
 */
function appendBackground(svg, container, bounds) {
  const computed = getComputedStyle(container);
  const rect = document.createElementNS(SVG_NS, 'rect');
  rect.setAttribute('x', bounds.x);
  rect.setAttribute('y', bounds.y);
  rect.setAttribute('width', bounds.width);
  rect.setAttribute('height', bounds.height);
  rect.setAttribute('fill', computed.backgroundColor || '#f8f8f8');
  svg.appendChild(rect);

  const bg = readConfig(container).background;
  const source = container.querySelector('[data-background] .lf-background-pattern');
  if (!bg || !source) return;

  const [gapX, gapY] = bg.gap;
  const isDots = bg.variant === 'dots';
  const dims = bg.variant === 'cross' ? [bg.size, bg.size] : [gapX, gapY];
  const sourceStyle = getComputedStyle(source);

  const pattern = document.createElementNS(SVG_NS, 'pattern');
  pattern.setAttribute('id', 'lf-export-background');
  pattern.setAttribute('patternUnits', 'userSpaceOnUse');
  pattern.setAttribute('x', 0);
  pattern.setAttribute('y', 0);
  pattern.setAttribute('width', gapX);
  pattern.setAttribute('height', gapY);
  pattern.setAttribute('patternTransform', `translate(-${bg.offset[0] + dims[0] / 2},-${bg.offset[1] + dims[1] / 2})`);

  let shape;
  if (isDots) {
    const r = bg.size / 2;
    shape = document.createElementNS(SVG_NS, 'circle');
    shape.setAttribute('cx', r);
    shape.setAttribute('cy', r);
    shape.setAttribute('r', r);
    shape.setAttribute('fill', sourceStyle.fill);
  } else {
    shape = document.createElementNS(SVG_NS, 'path');
    shape.setAttribute('d', `M${dims[0] / 2} 0 V${dims[1]} M0 ${dims[1] / 2} H${dims[0]}`);
    shape.setAttribute('stroke', sourceStyle.stroke);
    shape.setAttribute('stroke-width', bg.lineWidth || 1);
    shape.setAttribute('fill', 'none');
  }

  const defs = document.createElementNS(SVG_NS, 'defs');
  pattern.appendChild(shape);
  defs.appendChild(pattern);
  svg.appendChild(defs);

  const fill = document.createElementNS(SVG_NS, 'rect');
  fill.setAttribute('x', bounds.x);
  fill.setAttribute('y', bounds.y);
  fill.setAttribute('width', bounds.width);
  fill.setAttribute('height', bounds.height);
  fill.setAttribute('fill', 'url(#lf-export-background)');
  svg.appendChild(fill);
}

/**
 * Edges (markers, paths and labels) with inlined styles.
 * In native mode foreignObject labels are replaced with SVG text.
 */
function appendEdges(svg, container, inliner, native) {
  const edgeSvg = container.querySelector('[data-edge-layer]');
  if (!edgeSvg) return;

  for (const child of edgeSvg.children) {
    const clone = cloneWithStyles(child, inliner);
    if (!clone) continue;

    if (native) {
      clone.querySelectorAll('foreignObject').forEach(fo => fo.remove());
    }
    svg.appendChild(clone);
  }

  if (native) {
    getEdgeLabelData(edgeSvg).forEach(label => svg.appendChild(nativeLabel(label)));
  }
}

/**
 * Nodes as foreignObjects containing a styled clone of the node element.
 */
function appendNodes(svg, container, inliner) {
  renderedNodes(container).forEach(el => {
    const r = nodeRect(el);
    const clone = cloneWithStyles(el, inliner);
    if (!clone) return;

    // Lay the node out inside its foreignObject instead of the viewport
    clone.style.position = 'relative';
    clone.style.left = '0';
    clone.style.top = '0';
    clone.style.margin = '0';
    clone.style.transform = 'none';

    const wrapper = document.createElementNS(XHTML_NS, 'div');
    wrapper.setAttribute('style', `padding:${NODE_OVERFLOW}px;width:${r.width}px;height:${r.height}px;box-sizing:content-box;`);
    wrapper.appendChild(clone);

    const fo = document.createElementNS(SVG_NS, 'foreignObject');
    fo.setAttribute('x', r.x - NODE_OVERFLOW);
    fo.setAttribute('y', r.y - NODE_OVERFLOW);
    fo.setAttribute('width', r.width + NODE_OVERFLOW * 2);
    fo.setAttribute('height', r.height + NODE_OVERFLOW * 2);
    fo.appendChild(wrapper);
    svg.appendChild(fo);
  });
}

function appendPseudoRules(svg, inliner) {
  if (inliner.pseudoRules.length === 0) return;
  const style = document.createElementNS(SVG_NS, 'style');
  style.textContent = inliner.pseudoRules.join('\n');
  svg.insertBefore(style, svg.firstChild);
}

/**
 * Builds the export SVG element.
 *
 * @param {HTMLElement} container - the .lf-container element
 * @param {Object} [options]
 * @param {number} [options.scale=1] - output size multiplier
 * @param {number} [options.padding=40] - space around the content, in flow units
 * @param {boolean} [options.background=true] - include the canvas background
 * @param {boolean} [options.native=false] - pure SVG (no foreignObject)
 */
export function buildExportSvg(container, options = {}) {
  const { scale = 1, padding = 40, background = true, native = false } = options;
  const bounds = calculateBounds(container, padding);
  const svg = createRoot(bounds, scale);
  const inliner = new StyleInliner();

  try {
    if (background) appendBackground(svg, container, bounds);
    appendEdges(svg, container, inliner, native);

    if (native) {
      buildNativeSvgNodes(svg, container);
    } else {
      appendNodes(svg, container, inliner);
    }

    appendPseudoRules(svg, inliner);
  } finally {
    inliner.destroy();
  }

  return { svg, bounds };
}

/**
 * Exports the flow as an SVG string.
 */
export function exportSVG(container, options = {}) {
  if (!container.querySelector('.lf-viewport')) return null;
  const { svg } = buildExportSvg(container, withoutUndefined(options));
  return new XMLSerializer().serializeToString(svg);
}

/**
 * Exports the flow as a PNG blob, rasterizing the same SVG as exportSVG.
 * Falls back to a pure-SVG rendering if the browser taints the canvas.
 */
export async function exportPNG(container, scale = 2, options = {}) {
  if (!container.querySelector('.lf-viewport')) throw new Error('Could not generate SVG');
  options = withoutUndefined(options);

  try {
    return await rasterize(buildExportSvg(container, { ...options, scale }), scale);
  } catch (error) {
    if (error?.name !== 'SecurityError') throw error;
    return rasterize(buildExportSvg(container, { ...options, scale, native: true }), scale);
  }
}

function withoutUndefined(options) {
  return Object.fromEntries(Object.entries(options || {}).filter(([, v]) => v !== undefined && v !== null));
}

async function rasterize({ svg, bounds }, scale) {
  const svgString = new XMLSerializer().serializeToString(svg);
  const img = new Image();
  img.decoding = 'sync';
  img.src = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svgString);

  try {
    await img.decode();
  } catch (_e) {
    throw new Error('Failed to render SVG to canvas');
  }

  const canvas = document.createElement('canvas');
  canvas.width = Math.ceil(bounds.width * scale);
  canvas.height = Math.ceil(bounds.height * scale);
  const ctx = canvas.getContext('2d');

  // WebKit may paint foreignObject content a tick late. Not requestAnimationFrame:
  // it never fires in background tabs and the export would hang.
  await new Promise(resolve => setTimeout(resolve, 0));
  ctx.drawImage(img, 0, 0, canvas.width, canvas.height);

  return new Promise((resolve, reject) => {
    // toBlob throws a SecurityError on a tainted canvas
    canvas.toBlob(blob => {
      if (blob) resolve(blob);
      else reject(new Error('Canvas toBlob returned null'));
    }, 'image/png');
  });
}

// ===== Native fallback (no foreignObject) =====

function getEdgeLabelData(edgeSvg) {
  const labels = [];
  edgeSvg.querySelectorAll('foreignObject.lf-edge-label-wrapper').forEach(fo => {
    const labelEl = fo.querySelector('.lf-edge-label');
    if (!labelEl) return;

    const w = parseFloat(fo.getAttribute('width')) || 100;
    const h = parseFloat(fo.getAttribute('height')) || 20;
    const ls = getComputedStyle(labelEl);

    labels.push({
      x: (parseFloat(fo.getAttribute('x')) || 0) + w / 2,
      y: (parseFloat(fo.getAttribute('y')) || 0) + h / 2,
      text: labelEl.textContent.trim(),
      color: ls.color || '#666666',
      fontSize: ls.fontSize || '12px',
      fontFamily: ls.fontFamily || 'sans-serif',
      fontWeight: ls.fontWeight || '400',
      bg: ls.backgroundColor,
      border: ls.border,
      borderRadius: parseFloat(ls.borderRadius) || 4,
    });
  });
  return labels;
}

function nativeLabel(label) {
  const g = document.createElementNS(SVG_NS, 'g');
  const textW = label.text.length * parseFloat(label.fontSize) * 0.6;
  const rectW = textW + 16;
  const rectH = parseFloat(label.fontSize) + 8;

  const rect = document.createElementNS(SVG_NS, 'rect');
  rect.setAttribute('x', label.x - rectW / 2);
  rect.setAttribute('y', label.y - rectH / 2);
  rect.setAttribute('width', rectW);
  rect.setAttribute('height', rectH);
  rect.setAttribute('fill', label.bg && label.bg !== 'rgba(0, 0, 0, 0)' ? label.bg : '#ffffff');
  rect.setAttribute('rx', label.borderRadius);
  const borderColor = parseBorderColor(label.border);
  if (borderColor) {
    rect.setAttribute('stroke', borderColor);
    rect.setAttribute('stroke-width', parseBorderWidth(label.border) || '1');
  }
  g.appendChild(rect);

  const text = document.createElementNS(SVG_NS, 'text');
  text.setAttribute('x', label.x);
  text.setAttribute('y', label.y);
  text.setAttribute('text-anchor', 'middle');
  text.setAttribute('dominant-baseline', 'central');
  text.setAttribute('fill', label.color);
  text.setAttribute('font-size', label.fontSize);
  text.setAttribute('font-family', label.fontFamily);
  text.setAttribute('font-weight', label.fontWeight);
  text.textContent = label.text;
  g.appendChild(text);

  return g;
}

/**
 * Pure-SVG nodes: box, colored backgrounds and text runs at their rendered
 * positions. Icons and other CSS-only visuals are lost.
 */
function buildNativeSvgNodes(svg, container) {
  renderedNodes(container).forEach(nodeEl => {
    const { x, y, width: w, height: h } = nodeRect(nodeEl);
    const nodeStyle = getComputedStyle(nodeEl);
    const radius = parseFloat(nodeStyle.borderRadius) || 8;
    const clipId = 'lf-clip-' + (nodeEl.dataset.nodeId || Math.random().toString(36).slice(2));
    const g = document.createElementNS(SVG_NS, 'g');

    const defs = document.createElementNS(SVG_NS, 'defs');
    const clipPath = document.createElementNS(SVG_NS, 'clipPath');
    clipPath.setAttribute('id', clipId);
    const clipRect = document.createElementNS(SVG_NS, 'rect');
    clipRect.setAttribute('x', x);
    clipRect.setAttribute('y', y);
    clipRect.setAttribute('width', w);
    clipRect.setAttribute('height', h);
    clipRect.setAttribute('rx', radius);
    clipPath.appendChild(clipRect);
    defs.appendChild(clipPath);
    g.appendChild(defs);

    const rect = document.createElementNS(SVG_NS, 'rect');
    rect.setAttribute('x', x);
    rect.setAttribute('y', y);
    rect.setAttribute('width', w);
    rect.setAttribute('height', h);
    rect.setAttribute('fill', nodeStyle.backgroundColor || '#ffffff');
    rect.setAttribute('stroke', parseBorderColor(nodeStyle.border) || '#d1d5db');
    rect.setAttribute('stroke-width', parseBorderWidth(nodeStyle.border) || '1');
    rect.setAttribute('rx', radius);
    g.appendChild(rect);

    const content = document.createElementNS(SVG_NS, 'g');
    content.setAttribute('clip-path', `url(#${clipId})`);
    const { textBlocks, bgRects } = getNodeVisualData(nodeEl);

    bgRects.forEach(bg => {
      const el = document.createElementNS(SVG_NS, 'rect');
      el.setAttribute('x', x + bg.x);
      el.setAttribute('y', y + bg.y);
      el.setAttribute('width', bg.w);
      el.setAttribute('height', bg.h);
      el.setAttribute('fill', bg.bg);
      if (bg.borderRadius > 0) el.setAttribute('rx', bg.borderRadius);
      content.appendChild(el);
    });

    textBlocks.forEach(tb => {
      const text = document.createElementNS(SVG_NS, 'text');
      text.setAttribute('x', x + tb.x);
      text.setAttribute('y', y + tb.y);
      text.setAttribute('fill', tb.color || '#333333');
      text.setAttribute('font-family', tb.fontFamily || 'sans-serif');
      text.setAttribute('font-size', tb.fontSize || '14px');
      text.setAttribute('font-weight', tb.fontWeight || '400');
      text.textContent = tb.text;
      content.appendChild(text);
    });

    g.appendChild(content);
    svg.appendChild(g);
  });
}

function getNodeVisualData(nodeEl) {
  const content = nodeEl.querySelector('.lf-node-content');
  if (!content) return { textBlocks: [], bgRects: [] };

  const nodeRectBox = nodeEl.getBoundingClientRect();
  const zoom = nodeRectBox.width / (nodeEl.offsetWidth || 1);
  const textBlocks = [];
  const bgRects = [];

  content.querySelectorAll('*').forEach(el => {
    const style = getComputedStyle(el);
    const bg = style.backgroundColor;
    if (bg && bg !== 'rgba(0, 0, 0, 0)' && bg !== 'transparent') {
      const r = el.getBoundingClientRect();
      if (r.width > 0 && r.height > 0) {
        bgRects.push({
          x: (r.left - nodeRectBox.left) / zoom,
          y: (r.top - nodeRectBox.top) / zoom,
          w: r.width / zoom,
          h: r.height / zoom,
          bg,
          borderRadius: parseFloat(style.borderRadius) || 0,
        });
      }
    }
  });

  const walker = document.createTreeWalker(content, NodeFilter.SHOW_TEXT, null);
  let textNode;
  while ((textNode = walker.nextNode())) {
    const text = textNode.textContent.trim();
    const parent = textNode.parentElement;
    if (!text || !parent) continue;

    const style = getComputedStyle(parent);
    if (style.display === 'none' || style.visibility === 'hidden' || style.opacity === '0') continue;

    const range = document.createRange();
    range.selectNodeContents(textNode);
    const cr = Array.from(range.getClientRects()).find(rect => rect.width > 0 && rect.height > 0);
    if (!cr) continue;

    textBlocks.push({
      text: text.length <= 60 ? text : text.substring(0, 57) + '...',
      x: (cr.left - nodeRectBox.left) / zoom,
      y: (cr.top - nodeRectBox.top) / zoom + (cr.height / zoom) * 0.75,
      fontSize: style.fontSize,
      fontWeight: style.fontWeight,
      fontFamily: style.fontFamily,
      color: style.color,
    });
  }

  return { textBlocks, bgRects };
}

function parseBorderColor(border) {
  if (!border) return null;
  const match = border.match(/(?:rgb\([^)]+\)|rgba\([^)]+\)|oklch\([^)]+\)|#[0-9a-fA-F]+|\w+)$/);
  return match ? match[0] : null;
}

function parseBorderWidth(border) {
  if (!border) return null;
  const match = border.match(/^(\d+(?:\.\d+)?)/);
  return match ? match[1] : null;
}

// ===== Downloads =====

/**
 * Downloads a blob as a file.
 * Uses a visible anchor with delayed cleanup to ensure Safari/WebKit processes the download.
 */
export function downloadBlob(blob, filename) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.style.position = 'fixed';
  a.style.left = '-9999px';
  a.style.top = '-9999px';
  a.style.opacity = '0';
  document.body.appendChild(a);
  a.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, view: window }));
  setTimeout(() => {
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }, 10000);
}

/**
 * Downloads a string as a file.
 * For text content, uses a data URI which is more reliable across browsers.
 */
export function downloadString(content, filename, type) {
  const a = document.createElement('a');
  a.href = 'data:' + (type || 'application/octet-stream') + ';charset=utf-8,' + encodeURIComponent(content);
  a.download = filename;
  a.style.position = 'fixed';
  a.style.left = '-9999px';
  a.style.top = '-9999px';
  a.style.opacity = '0';
  document.body.appendChild(a);
  a.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, view: window }));
  setTimeout(() => {
    document.body.removeChild(a);
  }, 10000);
}
