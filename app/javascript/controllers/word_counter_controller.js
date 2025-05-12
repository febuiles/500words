import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["textarea", "counter"]
  static values = { goal: Number }

  // Define a constant for the word goal
  static WORD_GOAL = 500

  connect() {
    this.goalValue = this.constructor.WORD_GOAL
    this.updateWordCount()
  }

  updateWordCount() {
    const text = this.textareaTarget.value
    // TODO: optimize this
    const wordCount = text.split(/\s+/).filter(word => word.length > 0).length

    this.counterTarget.textContent = wordCount + '/' + this.goalValue

    if (wordCount >= this.goalValue) {
      this.counterTarget.classList.add('goal-reached')
    } else {
      this.counterTarget.classList.remove('goal-reached')
    }
  }
}
