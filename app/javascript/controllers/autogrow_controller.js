import { Controller } from "@hotwired/stimulus"

// Grows the textarea to fit its content so the page scrolls, never the
// textarea. Browsers with CSS `field-sizing: content` do this natively;
// this controller covers the rest.
export default class extends Controller {
  static targets = ["textarea"]

  connect() {
    this.native = CSS.supports("field-sizing", "content")
    this.resize()
  }

  resize() {
    if (this.native) return
    const el = this.textareaTarget
    el.style.height = "auto"
    el.style.height = el.scrollHeight + "px"
  }
}
