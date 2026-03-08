export const FogEditor = {
  mounted() {
    this.canvas = this.el;
    this.ctx = this.canvas.getContext('2d');
    this.sessionId = this.el.dataset.sessionId;
    this.cellSize = parseInt(this.el.dataset.cellSize) || 20;
    this.brushRadius = 3; // default, updated by brush-radius input
    this.painting = false;
    this.pendingCells = new Set();
    this.flushTimer = null;
    this.fogGrid = {}; // "row,col" => true (revealed)

    this.resizeToParent();
    window.addEventListener('resize', () => this.resizeToParent());

    this.el.addEventListener('pointerdown', (e) => {
      this.painting = true;
      this.el.setPointerCapture(e.pointerId);
      this.handlePointer(e);
    });
    this.el.addEventListener('pointermove', (e) => this.handlePointer(e));
    this.el.addEventListener('pointerup', () => { this.painting = false; });

    // Listen for brush radius changes from the DOM input
    const brushInput = document.getElementById('brush-radius');
    if (brushInput) {
      brushInput.addEventListener('input', (e) => {
        this.brushRadius = parseInt(e.target.value);
      });
    }

    // Receive fog state updates from server (for DM's own view)
    this.handleEvent('fog_state', ({fog_grid}) => {
      this.fogGrid = fog_grid || {};
      this.redraw();
    });
  },

  resizeToParent() {
    const parent = this.el.parentElement;
    this.canvas.width = parent.offsetWidth;
    this.canvas.height = parent.offsetHeight;
    this.redraw();
  },

  handlePointer(e) {
    if (!this.painting) return;
    const rect = this.el.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    const col = Math.floor(x / this.cellSize);
    const row = Math.floor(y / this.cellSize);

    for (let dr = -this.brushRadius; dr <= this.brushRadius; dr++) {
      for (let dc = -this.brushRadius; dc <= this.brushRadius; dc++) {
        if (Math.sqrt(dr * dr + dc * dc) <= this.brushRadius) {
          const r = row + dr;
          const c = col + dc;
          if (r >= 0 && c >= 0) {
            const key = `${r},${c}`;
            if (!this.fogGrid[key]) {
              this.fogGrid[key] = true;
              this.pendingCells.add(key);
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
      if (this.pendingCells.size > 0) {
        this.pushEvent('reveal_cells', { cells: Array.from(this.pendingCells) });
        this.pendingCells.clear();
      }
      this.flushTimer = null;
    }, 50);
  },

  redraw() {
    const { width, height } = this.canvas;
    this.ctx.clearRect(0, 0, width, height);

    // DM view: draw semi-transparent fog over unrevealed cells
    const cols = Math.ceil(width / this.cellSize);
    const rows = Math.ceil(height / this.cellSize);
    this.ctx.fillStyle = 'rgba(0, 0, 0, 0.55)';
    for (let r = 0; r < rows; r++) {
      for (let c = 0; c < cols; c++) {
        if (!this.fogGrid[`${r},${c}`]) {
          this.ctx.fillRect(c * this.cellSize, r * this.cellSize, this.cellSize, this.cellSize);
        }
      }
    }
  },

  destroyed() {
    if (this.flushTimer) clearTimeout(this.flushTimer);
  }
};
