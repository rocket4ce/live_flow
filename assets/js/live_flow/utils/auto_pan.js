/**
 * Auto-pan: moves the viewport while the pointer is close to the edge of the
 * flow during node drags, connections and selections.
 * Port of xyflow's calcAutoPan.
 */

const clamp = (value, min, max) => Math.min(Math.max(value, min), max);

function velocity(value, min, max) {
  if (value < min) return clamp(Math.abs(value - min), 1, min) / min;
  if (value > max) return -clamp(Math.abs(value - max), 1, min) / min;
  return 0;
}

/**
 * @param {{x: number, y: number}} pos - pointer position relative to the container
 * @param {{width: number, height: number}} bounds - container size
 * @returns {[number, number]} screen-space movement for this frame
 */
export function calcAutoPan(pos, bounds, speed = 15, distance = 40) {
  return [
    velocity(pos.x, distance, bounds.width - distance) * speed,
    velocity(pos.y, distance, bounds.height - distance) * speed,
  ];
}

export class AutoPan {
  constructor(hook) {
    this.hook = hook;
    this.frame = null;
    this.pointer = null;
    this.onPan = null;
  }

  /**
   * Start the loop. `onPan` is called after every viewport move so the active
   * interaction can recompute positions for the (unchanged) pointer location.
   */
  start(onPan) {
    this.onPan = onPan;
    if (this.frame) return;

    const tick = () => {
      this.frame = requestAnimationFrame(tick);
      if (!this.pointer) return;

      const rect = this.hook.getContainerRect();
      const [dx, dy] = calcAutoPan(this.pointer, rect, this.hook.config.autoPanSpeed);
      if ((dx !== 0 || dy !== 0) && this.hook.panZoom.panBy(dx, dy)) {
        this.onPan?.();
      }
    };

    this.frame = requestAnimationFrame(tick);
  }

  /**
   * @param {MouseEvent} event
   */
  update(event) {
    const [x, y] = this.hook.coords.eventToScreen(event);
    this.pointer = { x, y };
  }

  stop() {
    if (this.frame) cancelAnimationFrame(this.frame);
    this.frame = null;
    this.pointer = null;
    this.onPan = null;
  }
}
