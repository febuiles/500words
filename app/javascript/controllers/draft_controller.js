import { Controller } from "@hotwired/stimulus"

// Mirrors unsaved editor content into localStorage so a guest's text survives
// the signup/login round-trip. The logged-in editor restores it on load and
// clears it once the post is actually saved.
export default class extends Controller {
  static targets = ["textarea"]

  static STORAGE_KEY = "500words:draft"

  connect() {
    if (this.textareaTarget.value.trim() !== "") return

    const draft = localStorage.getItem(this.constructor.STORAGE_KEY)
    if (!draft) return

    this.textareaTarget.value = draft
    // Let other controllers on the textarea (e.g. word-counter) react to the
    // restored content.
    this.textareaTarget.dispatchEvent(new Event("input", { bubbles: true }))
  }

  save() {
    localStorage.setItem(this.constructor.STORAGE_KEY, this.textareaTarget.value)
  }

  // Bound to turbo:submit-end so a failed submission keeps the draft around.
  clear(event) {
    if (event.detail?.success === false) return
    localStorage.removeItem(this.constructor.STORAGE_KEY)
  }
}
