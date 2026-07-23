import { Controller } from "@hotwired/stimulus"

// Inline rename for a post: swaps the name for a text input, saves on the
// Save button, Enter, or blur, cancels on Escape. PATCHes { post: { title } }
// and shows whatever name the server settles on (a cleared title falls back
// to the default "Post N").
//
// The Save button acts on mousedown with :prevent so the input never loses
// focus — otherwise its blur handler would race this save.
export default class extends Controller {
  static targets = ["display", "input"]
  static values = { url: String, pageTitle: Boolean }

  edit() {
    this.inputTarget.value = this.displayTarget.textContent.trim()
    this.element.classList.add("editing")
    this.inputTarget.focus()
    this.inputTarget.select()
  }

  keydown(event) {
    if (event.key === "Enter") {
      event.preventDefault()
      this.save()
    } else if (event.key === "Escape") {
      this.cancel()
    }
  }

  async save() {
    if (this.saving || !this.element.classList.contains("editing")) return

    const title = this.inputTarget.value.trim()
    if (title === this.displayTarget.textContent.trim()) return this.cancel()

    this.saving = true
    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
        },
        body: JSON.stringify({ post: { title } })
      })

      if (response.ok) {
        const data = await response.json()
        this.displayTarget.textContent = data.title
        if (this.pageTitleValue) document.title = `500words — ${data.title}`
      }
    } finally {
      this.saving = false
      this.cancel()
    }
  }

  cancel() {
    this.element.classList.remove("editing")
  }
}
