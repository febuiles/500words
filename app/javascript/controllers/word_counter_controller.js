import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["textarea", "counter"]
  static values = { goal: Number }

  // Define a constant for the word goal
  static WORD_GOAL = 500

  connect() {
    this.goalValue = this.constructor.WORD_GOAL
    this.celebrated = false
    this.updateWordCount()
  }

  updateWordCount() {
    const text = this.textareaTarget.value
    // TODO: optimize this
    const wordCount = text.split(/\s+/).filter(word => word.length > 0).length

    this.counterTarget.textContent = wordCount + ' words'

    const progress = Math.min(wordCount / this.goalValue, 1)
    this.updateProgressIndication(progress)

    if (wordCount >= this.goalValue) {
      this.counterTarget.classList.add('goal-reached')

      if (!this.celebrated) {
        this.celebrated = true
        this.counterTarget.textContent = wordCount + ' words! Goal reached!'
        this.playCelebration()
      } else {
        this.counterTarget.textContent = wordCount + ' words - Goal reached!'
      }
    } else {
      this.counterTarget.classList.remove('goal-reached')
      this.celebrated = false
    }
  }
  // TODO: Update colors, remove active border
  updateProgressIndication(progress) {
    if (progress < 0.25) {
      this.counterTarget.style.backgroundColor = '#f3f3f3'
    } else if (progress < 0.5) {
      this.counterTarget.style.backgroundColor = '#e6f7ff' // light blue
    } else if (progress < 0.75) {
      this.counterTarget.style.backgroundColor = '#fffde7' // light yellow
    } else if (progress < 1) {
      this.counterTarget.style.backgroundColor = '#fff9c4' // brighter yellow
    }

    this.createOrUpdateProgressBar(progress)
  }

  createOrUpdateProgressBar(progress) {
    let progressBar = document.getElementById('word-progress-bar')

    if (!progressBar) {
      const container = document.createElement('div')
      container.id = 'word-progress-container'
      container.style.width = '100%'
      container.style.height = '6px'
      container.style.backgroundColor = '#e0e0e0'
      container.style.borderRadius = '3px'
      container.style.overflow = 'hidden'
      container.style.marginTop = '5px'

      progressBar = document.createElement('div')
      progressBar.id = 'word-progress-bar'
      progressBar.style.height = '100%'
      progressBar.style.transition = 'width 0.3s ease, background-color 0.3s ease'

      container.appendChild(progressBar)
      this.element.insertBefore(container, this.textareaTarget)
    }

    progressBar.style.width = `${progress * 100}%`

    if (progress < 0.25) {
      progressBar.style.backgroundColor = '#c5c5c5'
    } else if (progress < 0.5) {
      progressBar.style.backgroundColor = '#64b5f6'
    } else if (progress < 0.75) {
      progressBar.style.backgroundColor = '#ffee58'
    } else if (progress < 1) {
      progressBar.style.backgroundColor = '#ffa726'
    } else {
      progressBar.style.backgroundColor = '#ff5722'
    }
  }

  playCelebration() {
    this.addFlashMessage()

    this.shakeElement(this.textareaTarget)

    this.addBackgroundPulse()

    this.showMotivationalMessage()
  }

  addFlashMessage() {
    const container = document.querySelector('.container')
    if (!container) return

    const flashDiv = document.createElement('div')
    flashDiv.className = 'flash notice celebration-flash'
    flashDiv.innerHTML = `<strong>Congratulations!</strong> You've reached ${this.constructor.WORD_GOAL} words!`
    flashDiv.style.animation = 'fadeInOut 5s ease-in-out'

    // Add some specific styles for the celebration flash
    flashDiv.style.backgroundColor = '#ffd700'
    flashDiv.style.color = '#333'
    flashDiv.style.border = '1px solid #ffc107'

    // Insert at the top of the container
    container.insertBefore(flashDiv, container.firstChild)

    // Remove after animation completes
    setTimeout(() => {
      if (flashDiv.parentNode) {
        flashDiv.parentNode.removeChild(flashDiv)
      }
    }, 5000)
  }

  showMotivationalMessage() {
    const goal = this.constructor.WORD_GOAL
    // TODO: Use nicer phrases
    const messages = [
      `Amazing work! You've hit your ${goal}-word goal!`,
      `Writing milestone achieved! ${goal} words down!`,
      `You're on fire! ${goal} words and counting!`,
      `What an achievement! ${goal} words completed!`,
      `Creative juices flowing! ${goal} words reached!`
    ]

    const message = messages[Math.floor(Math.random() * messages.length)]

    const msgElement = document.createElement('div')
    msgElement.className = 'motivational-message'
    msgElement.textContent = message
    msgElement.style.marginTop = '15px'
    msgElement.style.padding = '10px'
    msgElement.style.backgroundColor = '#e3f2fd'
    msgElement.style.borderLeft = '4px solid #2196f3'
    msgElement.style.borderRadius = '4px'
    msgElement.style.animation = 'fadeInOut 4s ease-in-out'

    this.element.appendChild(msgElement)

    setTimeout(() => {
      if (msgElement.parentNode) {
        msgElement.parentNode.removeChild(msgElement)
      }
    }, 4000)
  }

  addBackgroundPulse() {
    // Create a style element if it doesn't exist
    if (!document.getElementById('background-pulse-style')) {
      const style = document.createElement('style')
      style.id = 'background-pulse-style'
      style.textContent = `
        @keyframes backgroundPulse {
          0% { background-color: rgba(255, 193, 7, 0.1); }
          50% { background-color: rgba(255, 193, 7, 0.2); }
          100% { background-color: rgba(255, 193, 7, 0); }
        }
        .background-pulse {
          animation: backgroundPulse 2s ease-out;
        }
      `
      document.head.appendChild(style)
    }

    this.element.classList.add('background-pulse')

    setTimeout(() => {
      this.element.classList.remove('background-pulse')
    }, 2000)
  }

  shakeElement(element) {
    element.classList.add('shake-effect')

    // Add the CSS for the shake effect if it doesn't exist
    if (!document.getElementById('shake-effect-style')) {
      const style = document.createElement('style')
      style.id = 'shake-effect-style'
      style.textContent = `
        @keyframes shake {
          0% { transform: translateX(0); }
          10%, 30%, 50%, 70%, 90% { transform: translateX(-5px); }
          20%, 40%, 60%, 80% { transform: translateX(5px); }
          100% { transform: translateX(0); }
        }
        .shake-effect {
          animation: shake 0.8s cubic-bezier(.36,.07,.19,.97) both;
        }
      `
      document.head.appendChild(style)
    }

    // Remove the class after the animation completes
    setTimeout(() => {
      element.classList.remove('shake-effect')
    }, 800)
  }
}
