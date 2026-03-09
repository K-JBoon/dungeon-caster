// fog_grid model:
//   allFogged=false, fogGrid={}         → no fog
//   allFogged=false, fogGrid={k:true}   → blacklist (those cells fogged)
//   allFogged=true,  revealedGrid={}    → entire map fogged
//   allFogged=true,  revealedGrid={k:t} → entire map fogged except revealed cells
export const FogEditor = {
  mounted() {
    this.canvas = this.el;
    this.ctx = this.canvas.getContext('2d');
    this.sessionId = this.el.dataset.sessionId;
    this.cellSize = parseInt(this.el.dataset.cellSize) || 20;
    this.brushRadius = 0;
    this.painting = false;
    this.pendingReveal = new Set();
    this.pendingCover = new Set();
    this.flushTimer = null;
    this.fogGrid = {};
    this.allFogged = false;
    this.revealedGrid = {};

    // Size the canvas from its actual rendered bounds, not parent.offsetWidth/Height,
    // because the flex layout may not have settled at mount time. ResizeObserver fires
    // once immediately with the correct settled size, and again on any resize.
    this._resizeObserver = new ResizeObserver(() => this.resizeToCanvas());
    this._resizeObserver.observe(this.el);

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

    const brushInput = document.getElementById('brush-radius');
    if (brushInput) {
      brushInput.addEventListener('input', (e) => {
        this.brushRadius = parseInt(e.target.value);
      });
    }

    // morphdom removes canvas width/height attrs on every patch (they're not in server HTML),
    // resetting the buffer to 300×150. Restore correct dimensions whenever data-fog-mode changes.
    this._modeObserver = new MutationObserver(() => { this.resizeToCanvas(); this.redraw(); });
    this._modeObserver.observe(this.el, { attributes: true, attributeFilter: ['data-fog-mode'] });

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

  resizeToCanvas() {
    const rect = this.el.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) return;
    this.canvas.width = Math.round(rect.width);
    this.canvas.height = Math.round(rect.height);
    this.redraw();
  },

  handlePointer(e) {
    if (!this.painting) return;
    const rect = this.el.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    const col = Math.floor(x / this.cellSize);
    const row = Math.floor(y / this.cellSize);
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
    const { width, height } = this.canvas;
    this.ctx.clearRect(0, 0, width, height);
    this.ctx.fillStyle = 'rgba(0, 0, 0, 0.55)';

    if (this.allFogged) {
      this.ctx.fillRect(0, 0, width, height);
      for (const key of Object.keys(this.revealedGrid)) {
        const [r, c] = key.split(',').map(Number);
        this.ctx.clearRect(c * this.cellSize, r * this.cellSize, this.cellSize, this.cellSize);
      }
    } else {
      const cols = Math.ceil(width / this.cellSize);
      const rows = Math.ceil(height / this.cellSize);
      for (let r = 0; r < rows; r++) {
        for (let c = 0; c < cols; c++) {
          if (this.fogGrid[`${r},${c}`]) {
            this.ctx.fillRect(c * this.cellSize, r * this.cellSize, this.cellSize, this.cellSize);
          }
        }
      }
    }

    // Cursor preview
    if (this._lastPointer) {
      const { x, y } = this._lastPointer;
      const col = Math.floor(x / this.cellSize);
      const row = Math.floor(y / this.cellSize);
      const r = this.brushRadius;
      this.ctx.fillStyle = this.currentMode() === 'brush'
        ? 'rgba(0, 0, 0, 0.4)'
        : 'rgba(255, 255, 255, 0.3)';
      for (let dr = -r; dr <= r; dr++) {
        for (let dc = -r; dc <= r; dc++) {
          if (r === 0 || Math.sqrt(dr * dr + dc * dc) <= r) {
            const cr = row + dr, cc = col + dc;
            if (cr >= 0 && cc >= 0)
              this.ctx.fillRect(cc * this.cellSize, cr * this.cellSize, this.cellSize, this.cellSize);
          }
        }
      }
    }
  },

  destroyed() {
    if (this.flushTimer) clearTimeout(this.flushTimer);
    if (this._modeObserver) this._modeObserver.disconnect();
    if (this._resizeObserver) this._resizeObserver.disconnect();
  }
};
