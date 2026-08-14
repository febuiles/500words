import { Controller } from "@hotwired/stimulus"

// Guest-only drafting: mirrors the guest editor into localStorage so the
// text survives the signup/login round-trip. The logged-in editor sets
// `consume` — it restores the draft once, deletes it immediately, and
// never writes one: drafts don't exist for logged-in writers.
export default class extends Controller {
  static targets = ["textarea"]
  static values = { consume: Boolean }

  static STORAGE_KEY = "500words:draft"

  connect() {
    const draft = localStorage.getItem(this.constructor.STORAGE_KEY)
    if (draft && this.textareaTarget.value.trim() === "") {
      this.textareaTarget.value = draft
      // Let other controllers on the textarea (e.g. word-counter,
      // autogrow) react to the restored content.
      this.textareaTarget.dispatchEvent(new Event("input", { bubbles: true }))
    }
    if (this.consumeValue) localStorage.removeItem(this.constructor.STORAGE_KEY)
  }

  save() {
    localStorage.setItem(this.constructor.STORAGE_KEY, this.textareaTarget.value)
  }
}
