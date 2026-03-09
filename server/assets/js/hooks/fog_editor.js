// fog_grid model:
//   allFogged=false, fogGrid={}         → no fog
//   allFogged=false, fogGrid={k:true}   → blacklist (those cells fogged)
//   allFogged=true,  revealedGrid={}    → entire map fogged
//   allFogged=true,  revealedGrid={k:t} → entire map fogged except revealed cells
//
// Cell (row, col) is defined in terms of the server-supplied grid (gridCols × gridRows).
// The grid divides the rendered image into equal tiles — no naturalWidth dependency.
// getMetrics() converts between grid cells and screen/canvas coordinates.
export const FogEditor = {
  mounted() {
    this.canvas = this.el;
    this.ctx = this.canvas.getContext('2d');
    this.sessionId = this.el.dataset.sessionId;
    this.brushRadius = 0;
    this.painting = false;
    this.pendingReveal = new Set();
    this.pendingCover = new Set();
    this.flushTimer = null;
    this.fogGrid = {};
    this.allFogged = false;
    this.revealedGrid = {};

    // Size canvas buffer to CSS pixel dimensions so coordinates stay 1:1.
    this._resizeObserver = new ResizeObserver(() => this.resizeToCanvas());
    this._resizeObserver.observe(this.el);

    // morphdom clears canvas width/height attributes on every LiveView patch because
    // they're set via JS and not in the server HTML. Watch ALL attribute mutations so
    // we restore the correct buffer size whenever that happens.
    this._attrObserver = new MutationObserver(() => this.resizeToCanvas());
    this._attrObserver.observe(this.el, { attributes: true });

    this.el.addEventListener('pointerdown', (e) => {
      this.painting = true;
      this.el.setPointerCapture(e.pointerId);
      this.handlePointer(e);
    });
    this.el.addEventListener('pointermove', (e) => {
      const rect = this.el.getBoundingClientRect();
      this._lastPointer = { x: e.clientX - rect.left, y: e.clientY - rect.top };
      this.handlePointer(e);
      if (!this.painting) this.redraw();
    });
    this.el.addEventListener('pointerleave', () => { this._lastPointer = null; this.redraw(); });
    this.el.addEventListener('pointerup', () => { this.painting = false; });
    this.el.addEventListener('pointercancel', () => { this.painting = false; });

    const brushInput = document.getElementById('brush-radius');
    if (brushInput) {
      brushInput.addEventListener('input', (e) => {
        this.brushRadius = parseInt(e.target.value);
      });
    }

    this.handleEvent('fog_state', ({fog_grid}) => {
      if (fog_grid === 'all_fogged') {
        this.allFogged = true;
        this.fogGrid = {};
        this.revealedGrid = {};
      } else if (fog_grid && fog_grid.mode === 'partial_reveal') {
        this.allFogged = true;
        this.fogGrid = {};
        this.revealedGrid = fog_grid.revealed || {};
      } else {
        this.allFogged = false;
        this.fogGrid = fog_grid || {};
        this.revealedGrid = {};
      }
      this.redraw();
    });
  },

  currentMode() {
    return this.el.dataset.fogMode || 'eraser';
  },

  // Returns metrics in both CSS pixel space (for pointer->cell) and canvas buffer
  // pixel space (for ctx drawing). Uses server-supplied grid dims from data attributes.
  getMetrics() {
    const cols = parseInt(this.el.dataset.gridCols) || 0;
    const rows = parseInt(this.el.dataset.gridRows) || 0;
    if (!cols || !rows) return null;

    // CSS pixel dimensions — always live regardless of canvas buffer state
    const rect = this.el.getBoundingClientRect();
    const cssW = rect.width, cssH = rect.height;

    const scale = Math.min(cssW / cols, cssH / rows);
    const rendW = cols * scale, rendH = rows * scale;
    const ox = (cssW - rendW) / 2, oy = (cssH - rendH) / 2;
    const cellCSS = scale; // CSS px per cell

    // Scale from CSS px to canvas buffer px (may differ after morphdom reset)
    const bufW = this.canvas.width  || cssW;
    const bufH = this.canvas.height || cssH;
    const sx = bufW / cssW, sy = bufH / cssH;

    return {
      ox, oy, cellCSS,          // CSS space (pointer events)
      box: ox * sx,             // buffer space (ctx drawing)
      boy: oy * sy,
      cellBuf: cellCSS * sx,
      bufW, bufH,
    };
  },

  resizeToCanvas() {
    const rect = this.el.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) return;
    const w = Math.round(rect.width), h = Math.round(rect.height);
    if (this.canvas.width === w && this.canvas.height === h) return; // avoid re-trigger
    this.canvas.width = w;
    this.canvas.height = h;
    this.redraw();
  },

  handlePointer(e) {
    if (!this.painting) return;
    const m = this.getMetrics();
    if (!m) return;

    const rect = this.el.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    const col = Math.floor((x - m.ox) / m.cellCSS);
    const row = Math.floor((y - m.oy) / m.cellCSS);
    if (col < 0 || row < 0) return;

    const isBrush = this.currentMode() === 'brush';
    const r = this.brushRadius;

    if (this.allFogged) {
      for (let dr = -r; dr <= r; dr++) {
        for (let dc = -r; dc <= r; dc++) {
          if (r === 0 || Math.sqrt(dr * dr + dc * dc) <= r) {
            const cr = row + dr, cc = col + dc;
            if (cr >= 0 && cc >= 0) {
              const key = `${cr},${cc}`;
              if (isBrush) {
                if (this.revealedGrid[key]) {
                  delete this.revealedGrid[key];
                  this.pendingCover.add(key);
                }
              } else {
                if (!this.revealedGrid[key]) {
                  this.revealedGrid[key] = true;
                  this.pendingReveal.add(key);
                }
              }
            }
          }
        }
      }
      this.redraw();
      this.scheduleFlush();
      return;
    }

    for (let dr = -r; dr <= r; dr++) {
      for (let dc = -r; dc <= r; dc++) {
        if (r === 0 || Math.sqrt(dr * dr + dc * dc) <= r) {
          const cr = row + dr, cc = col + dc;
          if (cr >= 0 && cc >= 0) {
            const key = `${cr},${cc}`;
            if (isBrush) {
              if (!this.fogGrid[key]) {
                this.fogGrid[key] = true;
                this.pendingCover.add(key);
              }
            } else {
              if (this.fogGrid[key]) {
                delete this.fogGrid[key];
                this.pendingReveal.add(key);
              }
            }
          }
        }
      }
    }

    this.redraw();
    this.scheduleFlush();
  },

  scheduleFlush() {
    if (this.flushTimer) return;
    this.flushTimer = setTimeout(() => {
      if (this.pendingReveal.size > 0) {
        this.pushEvent('reveal_cells', { cells: Array.from(this.pendingReveal) });
        this.pendingReveal.clear();
      }
      if (this.pendingCover.size > 0) {
        this.pushEvent('cover_cells', { cells: Array.from(this.pendingCover) });
        this.pendingCover.clear();
      }
      this.flushTimer = null;
    }, 50);
  },

  redraw() {
    const m = this.getMetrics();
    if (!m) {
      this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
      return;
    }

    const { box, boy, cellBuf, bufW, bufH } = m;

    this.ctx.clearRect(0, 0, bufW, bufH);
    this.ctx.fillStyle = 'rgba(0, 0, 0, 0.55)';

    if (this.allFogged) {
      this.ctx.fillRect(0, 0, bufW, bufH);
      for (const key of Object.keys(this.revealedGrid)) {
        const [r, c] = key.split(',').map(Number);
        this.ctx.clearRect(box + c * cellBuf, boy + r * cellBuf, cellBuf, cellBuf);
      }
    } else {
      for (const key of Object.keys(this.fogGrid)) {
        const [r, c] = key.split(',').map(Number);
        this.ctx.fillRect(box + c * cellBuf, boy + r * cellBuf, cellBuf, cellBuf);
      }
    }

    // Cursor preview
    if (this._lastPointer) {
      const { x, y } = this._lastPointer;
      const col = Math.floor((x - m.ox) / m.cellCSS);
      const row = Math.floor((y - m.oy) / m.cellCSS);
      const r = this.brushRadius;
      this.ctx.fillStyle = this.currentMode() === 'brush'
        ? 'rgba(0, 0, 0, 0.4)'
        : 'rgba(255, 255, 255, 0.3)';
      for (let dr = -r; dr <= r; dr++) {
        for (let dc = -r; dc <= r; dc++) {
          if (r === 0 || Math.sqrt(dr * dr + dc * dc) <= r) {
            const cr = row + dr, cc = col + dc;
            if (cr >= 0 && cc >= 0)
              this.ctx.fillRect(box + cc * cellBuf, boy + cr * cellBuf, cellBuf, cellBuf);
          }
        }
      }
    }
  },

  destroyed() {
    if (this.flushTimer) clearTimeout(this.flushTimer);
    if (this._attrObserver) this._attrObserver.disconnect();
    if (this._resizeObserver) this._resizeObserver.disconnect();
  }
};
