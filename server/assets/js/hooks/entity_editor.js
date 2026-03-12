const BADGE_RE = /~\[([^\]]+)\]\{([^}]+)\}/g

const ENTITY_TYPE_ICONS = {
  npc: 'hero-user-group',
  location: 'hero-map-pin',
  faction: 'hero-shield-check',
  session: 'hero-calendar-days',
  'stat-block': 'hero-book-open',
  map: 'hero-map',
  audio: 'hero-speaker-wave'
}

export const EntityEditor = {
  mounted() {
    const textarea = this.el.querySelector('textarea')
    if (!textarea) return
    this.textarea = textarea

    const editor = document.createElement('div')
    editor.contentEditable = 'true'
    // Copy monospace/sizing classes; add entity-editor-content for white-space: pre-wrap
    editor.className = textarea.className + ' entity-editor-content'
    editor.dataset.placeholder = textarea.getAttribute('placeholder') || ''
    if (textarea.rows) {
      editor.style.minHeight = (textarea.rows * 24) + 'px'
    }

    this._setContent(editor, textarea.value)
    textarea.parentNode.insertBefore(editor, textarea)
    textarea.style.display = 'none'
    this.editor = editor

    this._pendingQuery = null
    this._pendingNode = null
    this._pendingOffset = 0
    this._dropdown = null
    this._searchTimer = null
    this._isApplyingHistory = false
    this._history = []
    this._historyIndex = -1

    this._pushHistory(this.textarea.value, this._getCaretOffset())

    this.handleEvent('entity_editor:set_content', ({id, content}) => {
      if (id !== this.el.id) return
      this._setExternalContent(content || '')
    })

    editor.addEventListener('input', () => this._onInput())
    editor.addEventListener('beforeinput', (e) => this._onBeforeInput(e))
    editor.addEventListener('keydown', (e) => this._onKeydown(e))
    editor.addEventListener('click', (e) => this._onClick(e))
  },

  destroyed() {
    this._hideDropdown()
  },

  // ── Content helpers ──────────────────────────────────────────────────

  _setContent(editor, markdown) {
    editor.innerHTML = ''
    BADGE_RE.lastIndex = 0
    let last = 0
    let match
    while ((match = BADGE_RE.exec(markdown)) !== null) {
      if (match.index > last) {
        editor.appendChild(document.createTextNode(markdown.slice(last, match.index)))
      }
      editor.appendChild(this._makeBadge(match[1], match[2]))
      last = BADGE_RE.lastIndex
    }
    if (last < markdown.length) {
      editor.appendChild(document.createTextNode(markdown.slice(last)))
    }
    // Leave truly empty so :empty::before placeholder CSS fires
  },

  _makeBadge(name, ref) {
    const [type] = ref.split(':', 1)
    const span = document.createElement('span')
    span.className = 'entity-badge'
    span.dataset.ref = ref
    span.dataset.display = name
    span.dataset.type = type || ''
    span.contentEditable = 'false'

    const icon = document.createElement('span')
    icon.className = `entity-badge__icon ${ENTITY_TYPE_ICONS[type] || 'hero-link'} size-3`
    icon.setAttribute('aria-hidden', 'true')

    const label = document.createElement('span')
    label.className = 'entity-badge__label'
    label.textContent = name

    span.appendChild(icon)
    span.appendChild(label)
    return span
  },

  _serialize() {
    let text = ''
    const walk = (node) => {
      if (node.nodeType === Node.TEXT_NODE) {
        text += node.textContent
      } else if (node.nodeType === Node.ELEMENT_NODE) {
        if (node.classList && node.classList.contains('entity-badge')) {
          text += `~[${node.dataset.display}]{${node.dataset.ref}}`
        } else {
          for (const child of node.childNodes) walk(child)
        }
      }
    }
    for (const child of this.editor.childNodes) walk(child)
    return text
  },

  // ── Event handlers ───────────────────────────────────────────────────

  _onInput() {
    const md = this._serialize()
    this._syncTextarea(md)
    if (!this._isApplyingHistory) {
      this._pushHistory(md, this._getCaretOffset())
    }
    this._checkTrigger()
  },

  _onBeforeInput(e) {
    if (e.inputType === 'historyUndo') {
      e.preventDefault()
      this._undo()
    } else if (e.inputType === 'historyRedo') {
      e.preventDefault()
      this._redo()
    }
  },

  _onKeydown(e) {
    if ((e.metaKey || e.ctrlKey) && !e.altKey) {
      const key = e.key.toLowerCase()
      if (key === 'z') {
        e.preventDefault()
        if (e.shiftKey) {
          this._redo()
        } else {
          this._undo()
        }
        return
      }
      if (key === 'y') {
        e.preventDefault()
        this._redo()
        return
      }
    }

    // Normalize Enter to insert literal newline (avoid browser-specific div/p insertion)
    if (e.key === 'Enter' && !this._dropdown) {
      e.preventDefault()
      document.execCommand('insertText', false, '\n')
      return
    }

    if (!this._dropdown) return

    if (e.key === 'ArrowDown') {
      e.preventDefault(); this._moveSelection(1)
    } else if (e.key === 'ArrowUp') {
      e.preventDefault(); this._moveSelection(-1)
    } else if (e.key === 'Enter') {
      e.preventDefault()
      const sel = this._dropdown.querySelector('li.selected')
      if (sel) this._selectItem({ id: sel.dataset.id, type: sel.dataset.type, name: sel.dataset.name })
    } else if (e.key === 'Tab' || e.key === 'ArrowRight' || e.key === 'Escape') {
      this._hideDropdown()
    }
  },

  _onClick(e) {
    const badge = e.target.closest('.entity-badge')
    if (badge) {
      e.preventDefault()
      this.pushEvent('open_entity_popover', { ref: badge.dataset.ref })
    }
  },

  // ── Trigger detection ────────────────────────────────────────────────

  _checkTrigger() {
    const sel = window.getSelection()
    if (!sel || !sel.rangeCount) return

    const range = sel.getRangeAt(0)
    const node = range.startContainer
    if (node.nodeType !== Node.TEXT_NODE) { this._hideDropdown(); return }

    const textBefore = node.textContent.slice(0, range.startOffset)
    const match = textBefore.match(/~(\S+)$/)

    if (match && match[1].length > 0) {
      this._pendingQuery = match[1]
      this._pendingNode = node
      this._pendingOffset = range.startOffset - match[0].length

      clearTimeout(this._searchTimer)
      this._searchTimer = setTimeout(() => {
        this.pushEvent('search_entities', { q: this._pendingQuery }, (reply) => {
          if (reply && reply.results) this._showDropdown(reply.results)
        })
      }, 200)
    } else {
      this._pendingQuery = null
      this._pendingNode = null
      this._hideDropdown()
    }
  },

  // ── Autocomplete dropdown ────────────────────────────────────────────

  _showDropdown(results) {
    this._hideDropdown()
    if (!results || results.length === 0 || !this._pendingQuery) return

    const dropdown = document.createElement('ul')
    dropdown.className = 'entity-autocomplete'
    dropdown.setAttribute('role', 'listbox')

    results.forEach((r, i) => {
      const li = document.createElement('li')
      li.className = i === 0 ? 'selected' : ''
      li.dataset.id = r.id
      li.dataset.type = r.type
      li.dataset.name = r.name
      li.setAttribute('role', 'option')
      li.innerHTML = `<span class="entity-type-pill">${this._esc(r.type)}</span><span>${this._esc(r.name)}</span>`
      li.addEventListener('mousedown', (e) => {
        e.preventDefault()
        this._selectItem({ id: r.id, type: r.type, name: r.name })
      })
      dropdown.appendChild(li)
    })

    const rect = this._caretRect()
    dropdown.style.left = rect.left + 'px'
    dropdown.style.top = (rect.bottom + 4) + 'px'
    document.body.appendChild(dropdown)
    this._dropdown = dropdown

    this._outsideHandler = (e) => {
      if (!dropdown.contains(e.target)) this._hideDropdown()
    }
    document.addEventListener('mousedown', this._outsideHandler)
  },

  _hideDropdown() {
    if (this._dropdown) {
      this._dropdown.remove()
      this._dropdown = null
      document.removeEventListener('mousedown', this._outsideHandler)
    }
    clearTimeout(this._searchTimer)
  },

  _moveSelection(delta) {
    const items = [...this._dropdown.querySelectorAll('li')]
    const idx = items.findIndex(li => li.classList.contains('selected'))
    const next = Math.max(0, Math.min(items.length - 1, idx + delta))
    items.forEach((li, i) => li.classList.toggle('selected', i === next))
    items[next].scrollIntoView({ block: 'nearest' })
  },

  _selectItem({ id, type, name }) {
    this._hideDropdown()
    if (!this._pendingNode) return
    // Guard against stale node (removed from DOM between trigger and selection)
    if (!this._pendingNode.parentNode) {
      this._pendingQuery = null
      this._pendingNode = null
      return
    }

    const node = this._pendingNode
    const triggerStart = this._pendingOffset
    const triggerEnd = triggerStart + 1 + this._pendingQuery.length // ~query

    const before = document.createTextNode(node.textContent.slice(0, triggerStart))
    const trailingText = node.textContent.slice(triggerEnd)
    const after = document.createTextNode(trailingText.length > 0 ? trailingText : '\u00A0')
    const badge = this._makeBadge(name, `${type}:${id}`)

    const parent = node.parentNode
    parent.insertBefore(before, node)
    parent.insertBefore(badge, node)
    parent.insertBefore(after, node)
    parent.removeChild(node)

    // Move cursor after the badge
    const sel = window.getSelection()
    const range = document.createRange()
    range.setStart(after, trailingText.length > 0 ? 0 : 1)
    range.collapse(true)
    sel.removeAllRanges()
    sel.addRange(range)

    this._pendingQuery = null
    this._pendingNode = null

    const md = this._serialize()
    this._syncTextarea(md)
    this._pushHistory(md, this._getCaretOffset())
  },

  // ── Utils ─────────────────────────────────────────────────────────────

  _syncTextarea(markdown) {
    this.textarea.value = markdown
    this.textarea.dispatchEvent(new Event('input', { bubbles: true }))
  },

  _setExternalContent(markdown) {
    this._hideDropdown()
    this._pendingQuery = null
    this._pendingNode = null
    this._setContent(this.editor, markdown)
    this._restoreCaretOffset(markdown.length)
    this._syncTextarea(markdown)
    this._pushHistory(markdown, this._getCaretOffset())
    this.editor.focus()
  },

  _pushHistory(markdown, caret) {
    const snapshot = { markdown, caret }
    const current = this._history[this._historyIndex]
    if (current && current.markdown === markdown && current.caret === caret) return

    if (this._historyIndex < this._history.length - 1) {
      this._history = this._history.slice(0, this._historyIndex + 1)
    }

    this._history.push(snapshot)
    if (this._history.length > 200) {
      this._history.shift()
    }
    this._historyIndex = this._history.length - 1
  },

  _undo() {
    if (this._historyIndex <= 0) return
    this._applyHistory(this._historyIndex - 1)
  },

  _redo() {
    if (this._historyIndex >= this._history.length - 1) return
    this._applyHistory(this._historyIndex + 1)
  },

  _applyHistory(index) {
    const snapshot = this._history[index]
    if (!snapshot) return

    this._isApplyingHistory = true
    this._historyIndex = index
    this._setContent(this.editor, snapshot.markdown)
    this._restoreCaretOffset(snapshot.caret)
    this._syncTextarea(snapshot.markdown)
    this._hideDropdown()
    this._pendingQuery = null
    this._pendingNode = null
    this._isApplyingHistory = false
  },

  _getCaretOffset() {
    const sel = window.getSelection()
    if (!sel || !sel.rangeCount) return this._serialize().length

    const range = sel.getRangeAt(0)
    if (!this.editor.contains(range.startContainer)) return this._serialize().length

    let offset = 0
    let found = false

    const walk = (node) => {
      if (found) return

      if (node.nodeType === Node.TEXT_NODE) {
        if (node === range.startContainer) {
          offset += range.startOffset
          found = true
          return
        }
        offset += node.textContent.length
        return
      }

      if (node.nodeType !== Node.ELEMENT_NODE) return

      if (node.classList && node.classList.contains('entity-badge')) {
        const token = `~[${node.dataset.display}]{${node.dataset.ref}}`
        if (node === range.startContainer) {
          offset += range.startOffset > 0 ? token.length : 0
          found = true
          return
        }
        offset += token.length
        return
      }

      if (node === range.startContainer) {
        const children = [...node.childNodes]
        for (let i = 0; i < range.startOffset; i += 1) {
          offset += this._nodeMarkdownLength(children[i])
        }
        found = true
        return
      }

      for (const child of node.childNodes) {
        walk(child)
        if (found) return
      }
    }

    walk(this.editor)
    return found ? offset : this._serialize().length
  },

  _restoreCaretOffset(target) {
    const offset = Math.max(0, target || 0)
    let consumed = 0
    let placed = false
    const sel = window.getSelection()
    const range = document.createRange()

    const place = (node, nodeOffset) => {
      range.setStart(node, nodeOffset)
      range.collapse(true)
      sel.removeAllRanges()
      sel.addRange(range)
      placed = true
    }

    const walk = (node) => {
      if (placed) return

      if (node.nodeType === Node.TEXT_NODE) {
        const length = node.textContent.length
        if (offset <= consumed + length) {
          place(node, offset - consumed)
          return
        }
        consumed += length
        return
      }

      if (node.nodeType !== Node.ELEMENT_NODE) return

      if (node.classList && node.classList.contains('entity-badge')) {
        const length = this._nodeMarkdownLength(node)
        if (offset <= consumed + length) {
          const parent = node.parentNode
          const index = [...parent.childNodes].indexOf(node)
          place(parent, offset === consumed ? index : index + 1)
          return
        }
        consumed += length
        return
      }

      for (const child of node.childNodes) {
        walk(child)
        if (placed) return
      }
    }

    walk(this.editor)

    if (!placed) {
      place(this.editor, this.editor.childNodes.length)
    }
  },

  _nodeMarkdownLength(node) {
    if (!node) return 0
    if (node.nodeType === Node.TEXT_NODE) return node.textContent.length
    if (node.nodeType !== Node.ELEMENT_NODE) return 0
    if (node.classList && node.classList.contains('entity-badge')) {
      return `~[${node.dataset.display}]{${node.dataset.ref}}`.length
    }

    let length = 0
    for (const child of node.childNodes) {
      length += this._nodeMarkdownLength(child)
    }
    return length
  },

  _caretRect() {
    const sel = window.getSelection()
    if (!sel || !sel.rangeCount) return { left: 20, bottom: 100 }
    const range = sel.getRangeAt(0).cloneRange()
    range.collapse(true)
    const rect = range.getBoundingClientRect()
    return { left: rect.left || 20, bottom: rect.bottom || (rect.top + 20) }
  },

  _esc(text) {
    return String(text)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
  }
}
