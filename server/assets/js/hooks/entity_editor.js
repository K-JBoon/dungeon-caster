const BADGE_RE = /~\[([^\]]+)\]\{([^}]+)\}/g

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

    editor.addEventListener('input', () => this._onInput())
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
    if (editor.childNodes.length === 0) {
      editor.appendChild(document.createTextNode(''))
    }
  },

  _makeBadge(name, ref) {
    const span = document.createElement('span')
    span.className = 'entity-badge'
    span.dataset.ref = ref
    span.dataset.display = name
    span.contentEditable = 'false'
    span.textContent = name
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
    this.textarea.value = md
    this.textarea.dispatchEvent(new Event('input', { bubbles: true }))
    this._checkTrigger()
  },

  _onKeydown(e) {
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

    const node = this._pendingNode
    const triggerStart = this._pendingOffset
    const triggerEnd = triggerStart + 1 + this._pendingQuery.length // ~query

    const before = document.createTextNode(node.textContent.slice(0, triggerStart))
    const after = document.createTextNode('\u00A0') // non-breaking space as cursor anchor
    const badge = this._makeBadge(name, `${type}:${id}`)

    const parent = node.parentNode
    parent.insertBefore(before, node)
    parent.insertBefore(badge, node)
    parent.insertBefore(after, node)
    parent.removeChild(node)

    // Move cursor after the badge
    const sel = window.getSelection()
    const range = document.createRange()
    range.setStart(after, 1)
    range.collapse(true)
    sel.removeAllRanges()
    sel.addRange(range)

    this._pendingQuery = null
    this._pendingNode = null

    this.textarea.value = this._serialize()
    this.textarea.dispatchEvent(new Event('input', { bubbles: true }))
  },

  // ── Utils ─────────────────────────────────────────────────────────────

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
