// SortableScenes: HTML5 drag-and-drop scene reordering.
// Pushes "reorder_scenes" with new ID order to LiveView.
export const SortableScenes = {
  mounted() {
    this.el.addEventListener("dragstart", e => {
      const item = e.target.closest("[data-scene-id]")
      if (!item) return
      e.dataTransfer.setData("text/plain", item.dataset.sceneId)
      e.dataTransfer.effectAllowed = "move"
      item.classList.add("opacity-50")
    })

    this.el.addEventListener("dragend", e => {
      const item = e.target.closest("[data-scene-id]")
      if (item) item.classList.remove("opacity-50")
    })

    this.el.addEventListener("dragover", e => {
      e.preventDefault()
      e.dataTransfer.dropEffect = "move"
      const target = e.target.closest("[data-scene-id]")
      if (target) target.classList.add("ring-1", "ring-primary")
    })

    this.el.addEventListener("dragleave", e => {
      const target = e.target.closest("[data-scene-id]")
      if (target) target.classList.remove("ring-1", "ring-primary")
    })

    this.el.addEventListener("drop", e => {
      e.preventDefault()
      const draggedId = e.dataTransfer.getData("text/plain")
      const target = e.target.closest("[data-scene-id]")
      if (!target || target.dataset.sceneId === draggedId) return
      target.classList.remove("ring-1", "ring-primary")

      const items = [...this.el.querySelectorAll("[data-scene-id]")]
      const ids = items.map(i => i.dataset.sceneId)
      const fromIdx = ids.indexOf(draggedId)
      const toIdx = ids.indexOf(target.dataset.sceneId)
      if (fromIdx === -1 || toIdx === -1) return

      ids.splice(fromIdx, 1)
      ids.splice(toIdx, 0, draggedId)
      this.pushEvent("reorder_scenes", {ids})
    })
  }
}
