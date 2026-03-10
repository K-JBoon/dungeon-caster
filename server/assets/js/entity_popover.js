const EntityPopover = {
  _windows: [],
  _z: 1000,
  _offsetIndex: 0,

  init() {
    if (this._initialized) return
    this._initialized = true
    window.addEventListener('phx:entity:popover-open', (e) => {
      this.open(e.detail)
    })
  },

  open({ ref, name, type, html }) {
    const offset = (this._offsetIndex % 6) * 24
    this._offsetIndex++

    const win = document.createElement('div')
    win.className = 'entity-popover'
    win.style.cssText = [
      'position:fixed',
      `left:${40 + offset}px`,
      `top:${60 + offset}px`,
      'width:380px',
      'height:420px',
      `z-index:${++this._z}`,
    ].join(';')

    win.innerHTML = `
      <div class="entity-popover-header">
        <span class="entity-popover-type">${this._esc(type)}</span>
        <span class="entity-popover-name">${this._esc(name)}</span>
        <button class="entity-popover-fullscreen" title="Fullscreen">⛶</button>
        <button class="entity-popover-close" title="Close">✕</button>
      </div>
      <div class="entity-popover-content prose prose-sm max-w-none">
        ${html || '<p style="opacity:0.4;font-size:0.875rem">No content.</p>'}
      </div>
      <div class="entity-popover-resize" aria-hidden="true"></div>
    `

    document.body.appendChild(win)
    this._windows.push(win)

    win.addEventListener('pointerdown', () => this._raise(win))
    this._makeDraggable(win, win.querySelector('.entity-popover-header'))
    this._makeResizable(win, win.querySelector('.entity-popover-resize'))
    win.querySelector('.entity-popover-fullscreen').addEventListener('click', () => this._toggleFullscreen(win))
    win.querySelector('.entity-popover-close').addEventListener('click', () => this._close(win))
  },

  _raise(win) {
    win.style.zIndex = ++this._z
  },

  _close(win) {
    win.remove()
    this._windows = this._windows.filter(w => w !== win)
  },

  _makeDraggable(win, handle) {
    let lastTap = 0
    handle.addEventListener('pointerdown', (e) => {
      if (win._fullscreen) return
      if (e.target.closest('button')) return

      const now = Date.now()
      if (now - lastTap < 300) {
        lastTap = 0
        this._toggleCollapse(win)
        return
      }
      lastTap = now

      e.preventDefault()

      const startX = e.clientX, startY = e.clientY
      const startL = parseInt(win.style.left) || 0
      const startT = parseInt(win.style.top) || 0

      const onMove = (e) => {
        win.style.left = Math.max(0, startL + e.clientX - startX) + 'px'
        win.style.top = Math.max(0, startT + e.clientY - startY) + 'px'
      }
      const onUp = () => {
        document.removeEventListener('pointermove', onMove)
        document.removeEventListener('pointerup', onUp)
      }

      document.addEventListener('pointermove', onMove)
      document.addEventListener('pointerup', onUp)
      handle.setPointerCapture(e.pointerId)
    })
  },

  _makeResizable(win, handle) {
    handle.addEventListener('pointerdown', (e) => {
      if (win._fullscreen) return
      e.preventDefault()
      e.stopPropagation()

      const startX = e.clientX, startY = e.clientY
      const startW = win.offsetWidth, startH = win.offsetHeight

      const onMove = (e) => {
        win.style.width = Math.max(280, startW + e.clientX - startX) + 'px'
        win.style.height = Math.max(200, startH + e.clientY - startY) + 'px'
      }
      const onUp = () => {
        document.removeEventListener('pointermove', onMove)
        document.removeEventListener('pointerup', onUp)
      }

      document.addEventListener('pointermove', onMove)
      document.addEventListener('pointerup', onUp)
      handle.setPointerCapture(e.pointerId)
    })
  },

  _toggleCollapse(win) {
    if (win._fullscreen) return
    if (win.classList.contains('collapsed')) {
      win.classList.remove('collapsed')
      if (win._savedHeightBeforeCollapse) win.style.height = win._savedHeightBeforeCollapse
    } else {
      win._savedHeightBeforeCollapse = win.style.height
      win.classList.add('collapsed')
    }
  },

  _toggleFullscreen(win) {
    if (win._fullscreen) {
      win.style.left = win._savedLeft
      win.style.top = win._savedTop
      win.style.width = win._savedWidth
      win.style.height = win._savedHeight
      win.style.borderRadius = ''
      win._fullscreen = false
    } else {
      win._savedLeft = win.style.left
      win._savedTop = win.style.top
      win._savedWidth = win.style.width
      win._savedHeight = win.style.height
      win.style.left = '0'
      win.style.top = '0'
      win.style.width = '100vw'
      win.style.height = '100dvh'
      win.style.borderRadius = '0'
      win._fullscreen = true
      this._raise(win)
    }
  },

  _esc(text) {
    return String(text)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
  }
}

export default EntityPopover
