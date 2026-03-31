// We import the CSS which is extracted to its own file by esbuild.
// Remove this line if you add a your own CSS build pipeline (e.g postcss).
import "../css/app.css"

// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
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

