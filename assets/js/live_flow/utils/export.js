/**
 * LiveFlow Export Utilities
 *
 * Exports the flow diagram as SVG or PNG by capturing the rendered DOM.
 */

/**
 * Collects all relevant CSS rules for LiveFlow elements.
 */
function collectStyles() {
  const rules = [];
  for (const sheet of document.styleSheets) {
    try {
      for (const rule of sheet.cssRules || []) {
        const text = rule.cssText || '';
        if (text.includes('lf-') || text.includes('--lf-')) {
          rules.push(text);
        }
      }
    } catch (e) {
      // Cross-origin stylesheet, skip
    }
  }
  return rules.join('\n');
}

/**
 * Reads node position and size data from the DOM.
 * Captures only .lf-node-content innerHTML (excludes handles & delete button).
 */
function getNodeData(container) {
  const viewport = container.querySelector('.lf-viewport');
  if (!viewport) return [];

  const nodeLayer = viewport.querySelector('[data-node-layer]');
  if (!nodeLayer) return [];

  const nodes = nodeLayer.querySelectorAll('.lf-node');
  const result = [];

  nodes.forEach(node => {
    const x = parseFloat(node.style.left) || 0;
    const y = parseFloat(node.style.top) || 0;
    const w = node.offsetWidth;
    const h = node.offsetHeight;
    const nodeStyle = getComputedStyle(node);

    const contentEl = node.querySelector('.lf-node-content');
    const labelEl = node.querySelector('.lf-default-node-label') || contentEl;
    const label = labelEl ? labelEl.textContent.trim() : '';

    const contentHTML = contentEl ? cleanHTML(contentEl.innerHTML) : '';
    const contentStyle = contentEl ? getComputedStyle(contentEl) : {};

    result.push({
      x, y, w, h, label,
      innerHTML: contentHTML,
      bg: nodeStyle.backgroundColor,
      border: nodeStyle.border,
      borderRadius: nodeStyle.borderRadius,
      boxShadow: nodeStyle.boxShadow,
      contentPadding: contentStyle.padding || '0px',
      color: nodeStyle.color,
      fontFamily: nodeStyle.fontFamily,
      fontSize: nodeStyle.fontSize,
    });
  });

  return result;
}

/**
 * Strips Phoenix debug comments and data-phx attributes from HTML.
 */
function cleanHTML(html) {
  return html
    .replace(/<!--.*?-->/g, '')
    .replace(/\s*data-phx-[a-z-]+="[^"]*"/g, '');
}

/**
 * Calculates the bounding box of all flow content (nodes + edges).
 */
function calculateBounds(container) {
  const nodes = getNodeData(container);
  if (nodes.length === 0) return { x: 0, y: 0, width: 800, height: 600 };

  let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;

  nodes.forEach(({ x, y, w, h }) => {
    minX = Math.min(minX, x);
    minY = Math.min(minY, y);
    maxX = Math.max(maxX, x + w);
    maxY = Math.max(maxY, y + h);
  });

  if (!isFinite(minX)) return { x: 0, y: 0, width: 800, height: 600 };

  const padding = 40;
  return {
    x: minX - padding,
    y: minY - padding,
    width: (maxX - minX) + padding * 2,
    height: (maxY - minY) + padding * 2
  };
}

/**
 * Collects edge label data from foreignObject elements before stripping them.
 * Captures full styling for native SVG rendering (background, border, font).
 */
function getEdgeLabelData(edgeSvg) {
  const labels = [];
  if (!edgeSvg) return labels;

  const foreignObjects = edgeSvg.querySelectorAll('foreignObject.lf-edge-label-wrapper');
  foreignObjects.forEach(fo => {
    const labelEl = fo.querySelector('.lf-edge-label');
    if (!labelEl) return;

    const x = parseFloat(fo.getAttribute('x')) || 0;
    const y = parseFloat(fo.getAttribute('y')) || 0;
    const w = parseFloat(fo.getAttribute('width')) || 100;
    const h = parseFloat(fo.getAttribute('height')) || 20;
    const text = labelEl.textContent.trim();
    const ls = getComputedStyle(labelEl);

    labels.push({
      x: x + w / 2,
      y: y + h / 2,
      foW: w,
      foH: h,
      text,
      color: ls.color || '#666666',
      fontSize: ls.fontSize || '12px',
      fontFamily: ls.fontFamily || 'sans-serif',
      fontWeight: ls.fontWeight || '400',
      bg: ls.backgroundColor,
      border: ls.border,
      borderRadius: parseFloat(ls.borderRadius) || 4,
      padding: ls.padding,
    });
  });

  return labels;
}

/**
 * Creates common SVG setup: root element, styles, background, edges.
 * When nativeModeForPng is true, foreignObject elements are stripped from edges
 * and replaced with native SVG text to avoid canvas taint.
 */
function createBaseSvg(container, bounds, { nativeModeForPng = false } = {}) {
  const viewport = container.querySelector('.lf-viewport');
  if (!viewport) return null;

  const edgeSvg = viewport.querySelector('.lf-edges');
  const computed = getComputedStyle(container);

  const svgNs = 'http://www.w3.org/2000/svg';
  const svg = document.createElementNS(svgNs, 'svg');
  svg.setAttribute('xmlns', svgNs);
  svg.setAttribute('xmlns:xlink', 'http://www.w3.org/1999/xlink');
  svg.setAttribute('width', bounds.width);
  svg.setAttribute('height', bounds.height);
  svg.setAttribute('viewBox', `${bounds.x} ${bounds.y} ${bounds.width} ${bounds.height}`);

  // Embed styles
  const styleEl = document.createElementNS(svgNs, 'style');
  const cssText = collectStyles();
  const themeVars = [
    '--lf-background', '--lf-node-bg', '--lf-node-border', '--lf-node-border-radius',
    '--lf-node-shadow', '--lf-node-selected-border', '--lf-edge-stroke',
    '--lf-edge-stroke-width', '--lf-text-primary', '--lf-text-muted'
  ].map(v => `${v}: ${computed.getPropertyValue(v)}`).filter(v => !v.endsWith(': ')).join('; ');

  styleEl.textContent = `:root { ${themeVars} }\n${cssText}\n` +
    `.lf-node { position: absolute; }\n` +
    `.lf-edge-interaction { display: none; }\n` +
    `.lf-edge-delete-wrapper { display: none; }`;
  svg.appendChild(styleEl);

  // Background
  const bgRect = document.createElementNS(svgNs, 'rect');
  bgRect.setAttribute('x', bounds.x);
  bgRect.setAttribute('y', bounds.y);
  bgRect.setAttribute('width', bounds.width);
  bgRect.setAttribute('height', bounds.height);
  bgRect.setAttribute('fill', computed.getPropertyValue('--lf-background') || '#f8f8f8');
  svg.appendChild(bgRect);

  // Collect edge label data before cloning (for native mode replacement)
  const edgeLabels = nativeModeForPng ? getEdgeLabelData(edgeSvg) : [];

  // Clone and add edge SVG content
  if (edgeSvg) {
    const edgeClone = edgeSvg.cloneNode(true);

    // Strip foreignObject elements for PNG (they taint the canvas)
    if (nativeModeForPng) {
      const fos = edgeClone.querySelectorAll('foreignObject');
      fos.forEach(fo => fo.remove());
    } else {
      // For SVG export: ensure foreignObject HTML content has XHTML namespace
      // (required for standalone SVG files to render HTML correctly)
      const fos = edgeClone.querySelectorAll('foreignObject');
      fos.forEach(fo => {
        const firstChild = fo.firstElementChild;
        if (firstChild && !firstChild.getAttribute('xmlns')) {
          firstChild.setAttribute('xmlns', 'http://www.w3.org/1999/xhtml');
        }
        // Inline computed styles so labels render correctly standalone
        const origFo = edgeSvg.querySelector(`foreignObject[x="${fo.getAttribute('x')}"][y="${fo.getAttribute('y')}"]`);
        if (origFo) {
          const origLabel = origFo.querySelector('.lf-edge-label');
          const clonedLabel = fo.querySelector('.lf-edge-label');
          if (origLabel && clonedLabel) {
            const ls = getComputedStyle(origLabel);
            clonedLabel.style.cssText = `
              display: flex; justify-content: center; align-items: center;
              font-family: ${ls.fontFamily}; font-size: ${ls.fontSize}; font-weight: ${ls.fontWeight};
              color: ${ls.color}; background: ${ls.backgroundColor};
              padding: ${ls.padding}; border-radius: ${ls.borderRadius};
              border: ${ls.border}; box-shadow: ${ls.boxShadow};
            `;
          }
        }
      });
    }

    for (const child of Array.from(edgeClone.children)) {
      svg.appendChild(child.cloneNode(true));
    }
  }

  // Add native SVG elements for edge labels in PNG mode (with background)
  if (nativeModeForPng) {
    edgeLabels.forEach(label => {
      const g = document.createElementNS(svgNs, 'g');

      // Estimate text width from character count and font size
      const charWidth = parseFloat(label.fontSize) * 0.6;
      const textW = label.text.length * charWidth;
      const padH = 8, padV = 2;
      const rectW = textW + padH * 2;
      const rectH = parseFloat(label.fontSize) + padV * 2 + 4;

      // Background rect
      const bg = label.bg && label.bg !== 'rgba(0, 0, 0, 0)' ? label.bg : '#ffffff';
      const rect = document.createElementNS(svgNs, 'rect');
      rect.setAttribute('x', label.x - rectW / 2);
      rect.setAttribute('y', label.y - rectH / 2);
      rect.setAttribute('width', rectW);
      rect.setAttribute('height', rectH);
      rect.setAttribute('fill', bg);
      rect.setAttribute('rx', label.borderRadius);
      rect.setAttribute('ry', label.borderRadius);
      const borderColor = parseBorderColor(label.border);
      if (borderColor) {
        rect.setAttribute('stroke', borderColor);
        rect.setAttribute('stroke-width', parseBorderWidth(label.border) || '1');
      }
      g.appendChild(rect);

      // Text
      const text = document.createElementNS(svgNs, 'text');
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

      svg.appendChild(g);
    });
  }

  return svg;
}

/**
 * Exports the flow as an SVG string (uses foreignObject for rich node rendering).
 */
export function exportSVG(container) {
  const bounds = calculateBounds(container);
  const svg = createBaseSvg(container, bounds);
  if (!svg) return null;

  const svgNs = 'http://www.w3.org/2000/svg';
  const nodes = getNodeData(container);

  // Add nodes as foreignObject (rich HTML rendering)
  nodes.forEach(node => {
    const fo = document.createElementNS(svgNs, 'foreignObject');
    fo.setAttribute('x', node.x);
    fo.setAttribute('y', node.y);
    fo.setAttribute('width', node.w);
    fo.setAttribute('height', node.h);

    const div = document.createElement('div');
    div.setAttribute('xmlns', 'http://www.w3.org/1999/xhtml');
    div.innerHTML = node.innerHTML;
    div.style.cssText = `
      width: ${node.w}px;
      height: ${node.h}px;
      box-sizing: border-box;
      font-family: ${node.fontFamily};
      font-size: ${node.fontSize};
      background: ${node.bg};
      border: ${node.border};
      border-radius: ${node.borderRadius};
      box-shadow: ${node.boxShadow};
      padding: ${node.contentPadding};
      color: ${node.color};
      overflow: hidden;
    `;
    fo.appendChild(div);
    svg.appendChild(fo);
  });

  const serializer = new XMLSerializer();
  return serializer.serializeToString(svg);
}

/**
 * Captures text blocks and background rects from a node's DOM for native SVG rendering.
 * All positions are in CSS-pixel space (unscaled), accounting for viewport zoom.
 */
function getNodeVisualData(nodeEl) {
  const content = nodeEl.querySelector('.lf-node-content');
  if (!content) return { textBlocks: [], bgRects: [] };

  const nodeRect = nodeEl.getBoundingClientRect();
  const zoom = nodeRect.width / (nodeEl.offsetWidth || 1);
  const textBlocks = [];
  const bgRects = [];

  // Capture colored background elements (headers, status dots, border-tops)
  const allEls = content.querySelectorAll('*');
  allEls.forEach(el => {
    const style = getComputedStyle(el);
    const bg = style.backgroundColor;
    if (bg && bg !== 'rgba(0, 0, 0, 0)' && bg !== 'transparent') {
      const elRect = el.getBoundingClientRect();
      if (elRect.width > 0 && elRect.height > 0) {
        bgRects.push({
          x: (elRect.left - nodeRect.left) / zoom,
          y: (elRect.top - nodeRect.top) / zoom,
          w: elRect.width / zoom,
          h: elRect.height / zoom,
          bg,
          borderRadius: parseFloat(style.borderRadius) || 0,
        });
      }
    }
    // Capture visible border-top (like card node colored borders)
    const btWidth = parseFloat(style.borderTopWidth);
    if (btWidth >= 2 && style.borderTopColor && style.borderTopColor !== 'rgba(0, 0, 0, 0)') {
      const elRect = el.getBoundingClientRect();
      bgRects.push({
        x: (elRect.left - nodeRect.left) / zoom,
        y: (elRect.top - nodeRect.top) / zoom,
        w: elRect.width / zoom,
        h: btWidth,
        bg: style.borderTopColor,
        borderRadius: 0,
      });
    }
  });

  // Walk text nodes and capture their rendered positions + styles
  const walker = document.createTreeWalker(content, NodeFilter.SHOW_TEXT, null);
  let textNode;
  while ((textNode = walker.nextNode())) {
    const text = textNode.textContent.trim();
    if (!text) continue;

    const parent = textNode.parentElement;
    if (!parent) continue;

    const range = document.createRange();
    range.selectNodeContents(textNode);
    const clientRects = range.getClientRects();
    if (clientRects.length === 0) continue;

    const style = getComputedStyle(parent);
    const isHidden = style.display === 'none' || style.visibility === 'hidden' || style.opacity === '0';
    if (isHidden) continue;

    for (const cr of clientRects) {
      if (cr.width === 0 || cr.height === 0) continue;
      const lineText = text.length <= 60 ? text : text.substring(0, 57) + '...';
      textBlocks.push({
        text: lineText,
        x: (cr.left - nodeRect.left) / zoom,
        y: (cr.top - nodeRect.top) / zoom + cr.height / zoom * 0.75,
        w: cr.width / zoom,
        fontSize: style.fontSize,
        fontWeight: style.fontWeight,
        fontFamily: style.fontFamily,
        color: style.color,
        textAlign: style.textAlign,
      });
      break;
    }
  }

  return { textBlocks, bgRects };
}

/**
 * Creates a pure-SVG representation of nodes (no foreignObject).
 * Walks the DOM to capture text positions, colors, and backgrounds.
 */
function buildNativeSvgNodes(svg, nodes, container) {
  const svgNs = 'http://www.w3.org/2000/svg';
  const viewport = container.querySelector('.lf-viewport');
  if (!viewport) return;
  const nodeLayer = viewport.querySelector('[data-node-layer]');
  if (!nodeLayer) return;

  const nodeEls = nodeLayer.querySelectorAll('.lf-node');

  nodeEls.forEach(nodeEl => {
    const x = parseFloat(nodeEl.style.left) || 0;
    const y = parseFloat(nodeEl.style.top) || 0;
    const w = nodeEl.offsetWidth;
    const h = nodeEl.offsetHeight;
    const nodeStyle = getComputedStyle(nodeEl);

    const clipId = 'clip-' + (nodeEl.dataset.nodeId || Math.random().toString(36).slice(2));
    const g = document.createElementNS(svgNs, 'g');

    // Clipping rect to prevent overflow
    const defs = document.createElementNS(svgNs, 'defs');
    const clipPath = document.createElementNS(svgNs, 'clipPath');
    clipPath.setAttribute('id', clipId);
    const clipRect = document.createElementNS(svgNs, 'rect');
    clipRect.setAttribute('x', x);
    clipRect.setAttribute('y', y);
    clipRect.setAttribute('width', w);
    clipRect.setAttribute('height', h);
    clipRect.setAttribute('rx', parseFloat(nodeStyle.borderRadius) || 8);
    clipPath.appendChild(clipRect);
    defs.appendChild(clipPath);
    g.appendChild(defs);

    // Node background rect
    const rect = document.createElementNS(svgNs, 'rect');
    rect.setAttribute('x', x);
    rect.setAttribute('y', y);
    rect.setAttribute('width', w);
    rect.setAttribute('height', h);
    rect.setAttribute('fill', nodeStyle.backgroundColor || '#ffffff');
    rect.setAttribute('stroke', parseBorderColor(nodeStyle.border) || '#d1d5db');
    rect.setAttribute('stroke-width', parseBorderWidth(nodeStyle.border) || '1');
    rect.setAttribute('rx', parseFloat(nodeStyle.borderRadius) || 8);
    rect.setAttribute('ry', parseFloat(nodeStyle.borderRadius) || 8);
    g.appendChild(rect);

    // Clipped content group
    const contentG = document.createElementNS(svgNs, 'g');
    contentG.setAttribute('clip-path', `url(#${clipId})`);

    const { textBlocks, bgRects } = getNodeVisualData(nodeEl);

    // Render background rects (colored headers, status dots, border-tops)
    bgRects.forEach(bg => {
      const bgEl = document.createElementNS(svgNs, 'rect');
      bgEl.setAttribute('x', x + bg.x);
      bgEl.setAttribute('y', y + bg.y);
      bgEl.setAttribute('width', bg.w);
      bgEl.setAttribute('height', bg.h);
      bgEl.setAttribute('fill', bg.bg);
      if (bg.borderRadius > 0) {
        bgEl.setAttribute('rx', bg.borderRadius);
        bgEl.setAttribute('ry', bg.borderRadius);
      }
      contentG.appendChild(bgEl);
    });

    // Render text blocks at their actual positions
    textBlocks.forEach(tb => {
      const text = document.createElementNS(svgNs, 'text');
      text.setAttribute('x', x + tb.x);
      text.setAttribute('y', y + tb.y);
      text.setAttribute('fill', tb.color || '#333333');
      text.setAttribute('font-family', tb.fontFamily || 'sans-serif');
      text.setAttribute('font-size', tb.fontSize || '14px');
      text.setAttribute('font-weight', tb.fontWeight || '400');
      text.textContent = tb.text;
      contentG.appendChild(text);
    });

    g.appendChild(contentG);
    svg.appendChild(g);
  });
}

function parseBorderColor(border) {
  if (!border) return null;
  const match = border.match(/(?:rgb\([^)]+\)|rgba\([^)]+\)|#[0-9a-fA-F]+|\w+)$/);
  return match ? match[0] : null;
}

function parseBorderWidth(border) {
  if (!border) return null;
  const match = border.match(/^(\d+(?:\.\d+)?)/);
  return match ? match[1] : null;
}

/**
 * Exports the flow as a PNG blob via canvas rendering.
 * Uses native SVG elements (no foreignObject) to avoid tainted canvas.
 */
export function exportPNG(container, scale = 2) {
  return new Promise((resolve, reject) => {
    const bounds = calculateBounds(container);
    const svg = createBaseSvg(container, bounds, { nativeModeForPng: true });
    if (!svg) {
      reject(new Error('Could not generate SVG'));
      return;
    }

    // Use native SVG elements for nodes (avoids canvas taint from foreignObject)
    buildNativeSvgNodes(svg, null, container);

    const serializer = new XMLSerializer();
    const svgString = serializer.serializeToString(svg);

    const canvas = document.createElement('canvas');
    canvas.width = bounds.width * scale;
    canvas.height = bounds.height * scale;
    const ctx = canvas.getContext('2d');
    ctx.scale(scale, scale);

    const img = new Image();
    const blob = new Blob([svgString], { type: 'image/svg+xml;charset=utf-8' });
    const url = URL.createObjectURL(blob);

    img.onload = () => {
      ctx.drawImage(img, 0, 0);
      URL.revokeObjectURL(url);
      try {
        canvas.toBlob((pngBlob) => {
          if (pngBlob) {
            resolve(pngBlob);
          } else {
            reject(new Error('Canvas toBlob returned null'));
          }
        }, 'image/png');
      } catch (e) {
        reject(new Error('Canvas export failed: ' + e.message));
      }
    };

    img.onerror = () => {
      URL.revokeObjectURL(url);
      reject(new Error('Failed to render SVG to canvas'));
    };

    img.src = url;
  });
}

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
