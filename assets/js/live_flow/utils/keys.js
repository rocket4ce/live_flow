/**
 * Keyboard helpers for LiveFlow.
 *
 * Key options (`delete_key_code`, `pan_activation_key`, `selection_key`, ...)
 * accept a single key, a combination joined with "+" (any number of keys, e.g.
 * "Meta+Shift+s") or a list of them. `nil`/`false` disables the binding.
 */

const MODIFIERS = ['meta', 'control', 'shift', 'alt'];

const ALIASES = {
  ' ': 'space',
  spacebar: 'space',
  ctrl: 'control',
  cmd: 'meta',
  command: 'meta',
  os: 'meta',
  option: 'alt',
  esc: 'escape',
  del: 'delete',
};

export function normalizeKey(key) {
  if (key == null) return '';
  const lower = String(key).toLowerCase();
  return ALIASES[lower] ?? lower;
}

/**
 * Parse a key option into a list of combinations (arrays of normalized keys).
 *   "Backspace"           -> [["backspace"]]
 *   ["Meta+Shift+s", "x"] -> [["meta", "shift", "s"], ["x"]]
 */
export function parseKeys(value) {
  if (value === null || value === undefined || value === false || value === '') return [];
  const list = Array.isArray(value) ? value : [value];
  return list
    .filter(v => typeof v === 'string' && v.length > 0)
    .map(combo => (combo === '+' ? ['+'] : combo.split('+').map(normalizeKey).filter(Boolean)));
}

function eventKeys(event) {
  const keys = new Set();
  keys.add(normalizeKey(event.key));
  if (event.code) {
    const code = event.code.toLowerCase();
    keys.add(code);
    // "KeyS" -> "s", "Digit1" -> "1"
    if (code.startsWith('key')) keys.add(code.slice(3));
    if (code.startsWith('digit')) keys.add(code.slice(5));
  }
  return keys;
}

function modifierState(event, modifier) {
  switch (modifier) {
    case 'meta': return event.metaKey;
    case 'control': return event.ctrlKey;
    case 'shift': return event.shiftKey;
    case 'alt': return event.altKey;
    default: return false;
  }
}

/**
 * Does a keydown event trigger one of the combinations?
 * Modifiers must match exactly, so "Backspace" does not fire on Meta+Backspace.
 */
export function matchesKeys(event, combos) {
  if (!combos || combos.length === 0) return false;
  const pressed = eventKeys(event);

  return combos.some(combo => {
    const mainKeys = combo.filter(k => !MODIFIERS.includes(k));
    const modifiers = combo.filter(k => MODIFIERS.includes(k));

    const modifiersMatch = MODIFIERS.every(m => {
      // A combo made only of modifiers (e.g. "Shift") is matched by its own keydown
      if (mainKeys.length === 0 && pressed.has(m)) return true;
      return modifierState(event, m) === modifiers.includes(m);
    });

    if (!modifiersMatch) return false;
    if (mainKeys.length === 0) return modifiers.some(m => pressed.has(m));
    return mainKeys.every(k => pressed.has(k));
  });
}

/**
 * Tracks which keys are being held, so "activation" keys (Space to pan,
 * Shift to select) can be combined with pointer gestures.
 */
export class HeldKeys {
  constructor() {
    this.held = new Set();
  }

  down(event) {
    eventKeys(event).forEach(k => this.held.add(k));
  }

  up(event) {
    eventKeys(event).forEach(k => this.held.delete(k));
    // Releasing a modifier can swallow keyup events of other keys on macOS
    if (event.key === 'Meta') this.held.clear();
  }

  clear() {
    this.held.clear();
  }

  /**
   * Is any of the combinations currently held? Pointer events carry reliable
   * modifier state, so it is used for modifiers when available.
   */
  isHeld(combos, pointerEvent) {
    if (!combos || combos.length === 0) return false;
    return combos.some(combo =>
      combo.every(k => {
        if (pointerEvent && MODIFIERS.includes(k)) return modifierState(pointerEvent, k);
        return this.held.has(k);
      })
    );
  }
}

/**
 * Keyboard events coming from form fields inside nodes must not trigger flow
 * shortcuts (typing Backspace in an input would otherwise delete the node).
 */
export function isInputTarget(event) {
  const target = event.composedPath?.()[0] || event.target;
  if (!target || target.nodeType !== 1) return false;
  return (
    ['INPUT', 'SELECT', 'TEXTAREA'].includes(target.nodeName) ||
    target.isContentEditable ||
    !!target.closest?.('.nokey')
  );
}
