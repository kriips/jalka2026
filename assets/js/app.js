// We import the CSS which is extracted to its own file by esbuild.
// Remove this line if you add a your own CSS build pipeline (e.g postcss).
import "../css/app.css"

// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include vendor dependencies by placing them in assets/vendor and
// importing them using relative paths:
//
//     import "../vendor/some-package.js"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

// LiveView Hooks
let Hooks = {}

Hooks.LeaderboardUpdates = {
  mounted() {
    // Mark leaderboard as visited for onboarding checklist
    localStorage.setItem('leaderboard_visited', 'true')

    this.handleEvent("leaderboard-updated", (_data) => {
      // Clear flash updates after animation completes
      setTimeout(() => {
        // The animations handle their own fade-out via CSS
        // After 3 seconds, the rank changes will have faded
      }, 3000)
    })
  }
}

Hooks.MatchChat = {
  mounted() {
    this.scrollToBottom()
    this.handleEvent("new-comment", () => {
      this.scrollToBottom()
    })
  },
  updated() {
    this.scrollToBottom()
  },
  scrollToBottom() {
    const container = this.el.querySelector('[data-chat-messages]')
    if (container) {
      container.scrollTop = container.scrollHeight
    }
  }
}

Hooks.BottomSheet = {
  mounted() {
    this.startY = null
    this.currentY = null
    this.isDragging = false

    const handle = this.el.querySelector('.bottom-sheet-handle-area')
    if (!handle) return

    this.handleTouchStart = (e) => {
      this.startY = e.touches[0].clientY
      this.isDragging = true
      this.el.style.transition = 'none'
    }

    this.handleTouchMove = (e) => {
      if (!this.isDragging) return
      this.currentY = e.touches[0].clientY
      const diff = this.currentY - this.startY
      if (diff > 0) {
        this.el.style.transform = `translateY(${diff}px)`
      }
    }

    this.handleTouchEnd = () => {
      if (!this.isDragging) return
      this.isDragging = false
      this.el.style.transition = ''

      const diff = this.currentY - this.startY
      if (diff > 100) {
        // Dismiss if dragged down more than 100px
        this.el.style.transform = 'translateY(100%)'
        setTimeout(() => {
          this.pushEvent('close_bottom_sheet', {})
        }, 200)
      } else {
        this.el.style.transform = ''
      }

      this.startY = null
      this.currentY = null
    }

    handle.addEventListener('touchstart', this.handleTouchStart, {passive: true})
    document.addEventListener('touchmove', this.handleTouchMove, {passive: true})
    document.addEventListener('touchend', this.handleTouchEnd, {passive: true})

    // Also support mouse drag for desktop
    this.handleMouseDown = (e) => {
      this.startY = e.clientY
      this.isDragging = true
      this.el.style.transition = 'none'
      e.preventDefault()
    }

    this.handleMouseMove = (e) => {
      if (!this.isDragging) return
      this.currentY = e.clientY
      const diff = this.currentY - this.startY
      if (diff > 0) {
        this.el.style.transform = `translateY(${diff}px)`
      }
    }

    this.handleMouseUp = () => {
      if (!this.isDragging) return
      this.isDragging = false
      this.el.style.transition = ''

      if (this.currentY && this.startY) {
        const diff = this.currentY - this.startY
        if (diff > 100) {
          this.el.style.transform = 'translateY(100%)'
          setTimeout(() => {
            this.pushEvent('close_bottom_sheet', {})
          }, 200)
        } else {
          this.el.style.transform = ''
        }
      }

      this.startY = null
      this.currentY = null
    }

    handle.addEventListener('mousedown', this.handleMouseDown)
    document.addEventListener('mousemove', this.handleMouseMove)
    document.addEventListener('mouseup', this.handleMouseUp)

    // Close on Escape key
    this.handleKeyDown = (e) => {
      if (e.key === 'Escape') {
        this.pushEvent('close_bottom_sheet', {})
      }
    }
    document.addEventListener('keydown', this.handleKeyDown)
  },
  destroyed() {
    document.removeEventListener('touchmove', this.handleTouchMove)
    document.removeEventListener('touchend', this.handleTouchEnd)
    document.removeEventListener('mousemove', this.handleMouseMove)
    document.removeEventListener('mouseup', this.handleMouseUp)
    document.removeEventListener('keydown', this.handleKeyDown)
  }
}

Hooks.ScoreInput = {
  mounted() {
    this.longPressTimer = null
    this.LONG_PRESS_MS = 500

    const inputs = this.el.querySelectorAll('input[data-score-input]')
    const values = this.el.querySelectorAll('[data-score-tap]')

    // Long-press on score value spans to open direct input
    values.forEach((span) => {
      const side = span.dataset.scoreTap
      const input = this.el.querySelector(`input[data-score-input="${side}"]`)
      if (!input) return

      const startLongPress = (e) => {
        this.longPressTimer = setTimeout(() => {
          this.longPressTimer = null
          this.activateInput(input, span)
        }, this.LONG_PRESS_MS)
      }

      const cancelLongPress = () => {
        if (this.longPressTimer) {
          clearTimeout(this.longPressTimer)
          this.longPressTimer = null
        }
      }

      span.addEventListener('touchstart', startLongPress, {passive: true})
      span.addEventListener('touchend', cancelLongPress)
      span.addEventListener('touchmove', cancelLongPress)
      span.addEventListener('mousedown', startLongPress)
      span.addEventListener('mouseup', cancelLongPress)
      span.addEventListener('mouseleave', cancelLongPress)
    })

    // Handle input blur and Enter key
    inputs.forEach((input) => {
      input.addEventListener('blur', () => {
        this.commitInput(input)
      })

      input.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') {
          e.preventDefault()
          input.blur()
        }
        if (e.key === 'Escape') {
          e.preventDefault()
          input.value = ''
          input.classList.remove('score-input-active')
          const span = this.el.querySelector(`[data-score-tap="${input.dataset.scoreInput}"]`)
          if (span) span.style.display = ''
        }
      })
    })
  },

  activateInput(input, span) {
    // Get the current score from the span text
    const current = span.textContent.trim()
    input.value = current === '-' ? '' : current
    span.style.display = 'none'
    input.classList.add('score-input-active')
    input.focus()
    input.select()
  },

  commitInput(input) {
    const rawVal = input.value.trim()
    const span = this.el.querySelector(`[data-score-tap="${input.dataset.scoreInput}"]`)

    input.classList.remove('score-input-active')
    if (span) span.style.display = ''

    if (rawVal === '') return // no change on empty

    const val = parseInt(rawVal, 10)
    if (isNaN(val) || val < 0) return // ignore invalid

    const score = Math.min(val, 99) // reasonable cap
    this.pushEvent('set-score', {
      match: input.dataset.matchId,
      side: input.dataset.scoreInput,
      score: score,
      "home-score": input.dataset.homeScore,
      "away-score": input.dataset.awayScore
    })
  },

  destroyed() {
    if (this.longPressTimer) {
      clearTimeout(this.longPressTimer)
    }
  }
}

Hooks.Countdown = {
  mounted() {
    this.deadline = new Date(this.el.dataset.deadline).getTime()
    this.tick()
    this.timer = setInterval(() => this.tick(), 1000)
  },
  updated() {
    // Re-read deadline in case it changes
    this.deadline = new Date(this.el.dataset.deadline).getTime()
  },
  destroyed() {
    if (this.timer) clearInterval(this.timer)
  },
  tick() {
    const now = Date.now()
    const diff = this.deadline - now

    if (diff <= 0) {
      clearInterval(this.timer)
      this.el.querySelector('[data-countdown-timer]').style.display = 'none'
      this.el.querySelector('[data-countdown-locked]').style.display = ''
      this.pushEvent('predictions_locked', {})
      return
    }

    const days = Math.floor(diff / (1000 * 60 * 60 * 24))
    const hours = Math.floor((diff % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60))
    const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60))
    const seconds = Math.floor((diff % (1000 * 60)) / 1000)

    const dEl = this.el.querySelector('[data-cd-days]')
    const hEl = this.el.querySelector('[data-cd-hours]')
    const mEl = this.el.querySelector('[data-cd-minutes]')
    const sEl = this.el.querySelector('[data-cd-seconds]')

    if (dEl) dEl.textContent = String(days).padStart(2, '0')
    if (hEl) hEl.textContent = String(hours).padStart(2, '0')
    if (mEl) mEl.textContent = String(minutes).padStart(2, '0')
    if (sEl) sEl.textContent = String(seconds).padStart(2, '0')
  }
}

Hooks.OnboardingChecklist = {
  mounted() {
    // Check if the user has previously visited the leaderboard
    const visited = localStorage.getItem('leaderboard_visited') === 'true'
    if (visited) {
      this.pushEvent('leaderboard_visited', {})
    }
  }
}

Hooks.ScrollIntoView = {
  mounted() {
    // Small delay to ensure DOM is fully rendered after LiveView patch
    requestAnimationFrame(() => {
      // Account for fixed header (~5.2rem ≈ 83px) with some padding
      const headerOffset = 90
      const elementPosition = this.el.getBoundingClientRect().top + window.scrollY
      window.scrollTo({ top: elementPosition - headerOffset, behavior: 'smooth' })
    })
  }
}

Hooks.SwipeNavigation = {
  mounted() {
    this.startX = null
    this.startY = null

    this.handleTouchStart = (e) => {
      const touch = e.touches[0]
      this.startX = touch.clientX
      this.startY = touch.clientY
    }

    this.handleTouchEnd = (e) => {
      if (this.startX === null || this.startY === null) return

      const touch = e.changedTouches[0]
      const diffX = touch.clientX - this.startX
      const diffY = touch.clientY - this.startY

      this.startX = null
      this.startY = null

      // Require minimum horizontal distance of 50px and mostly horizontal swipe
      if (Math.abs(diffX) < 50 || Math.abs(diffY) > Math.abs(diffX)) return

      if (diffX < 0) {
        // Swipe left -> next group
        const link = this.el.querySelector("[data-nav-next]")
        if (link) { link.click() }
      } else {
        // Swipe right -> previous group
        const link = this.el.querySelector("[data-nav-prev]")
        if (link) { link.click() }
      }
    }

    this.el.addEventListener("touchstart", this.handleTouchStart, {passive: true})
    this.el.addEventListener("touchend", this.handleTouchEnd, {passive: true})
  },
  destroyed() {
    this.el.removeEventListener("touchstart", this.handleTouchStart)
    this.el.removeEventListener("touchend", this.handleTouchEnd)
  }
}

let liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show())
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// Theme toggle
function getTheme() {
  return localStorage.getItem('theme') || document.documentElement.getAttribute('data-theme') || 'light'
}

function setTheme(theme) {
  document.documentElement.setAttribute('data-theme', theme)
  localStorage.setItem('theme', theme)

  // Sync to server if user is logged in
  let toggleBtn = document.getElementById('theme-toggle')
  if (toggleBtn && toggleBtn.dataset.userId) {
    fetch('/users/settings/theme', {
      method: 'PUT',
      headers: {
        'content-type': 'application/json',
        'x-csrf-token': csrfToken
      },
      body: JSON.stringify({theme: theme})
    }).catch(function() {})
  }
}

function initThemeToggle() {
  let toggleBtn = document.getElementById('theme-toggle')
  if (toggleBtn) {
    toggleBtn.addEventListener('click', function() {
      let current = getTheme()
      let next = current === 'dark' ? 'light' : 'dark'
      setTheme(next)
    })
  }
}

// Bind immediately since deferred scripts run after DOM is ready
initThemeToggle()
// Also bind on DOMContentLoaded as fallback
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initThemeToggle)
}

