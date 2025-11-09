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
import { Socket } from "phoenix"
import { Hooks as BackpexHooks } from 'backpex';
import { LiveSocket } from "phoenix_live_view"
import topbar from "../vendor/topbar"
import Alpine from "alpinejs"
import SaladUI from "salad_ui";
import "salad_ui/components/dropdown_menu";
import "salad_ui/components/dialog";
import "./salad_ui_patches";

// Initialize Alpine.js for Backpex dropdowns and interactive components
window.Alpine = Alpine
Alpine.start()

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
// Custom hook to handle SaladUI dialog issues
const SafeSaladUIHook = {
  ...SaladUI.SaladUIHook,
  mounted() {
    try {
      // Add a small delay to ensure DOM is ready
      setTimeout(() => {
        if (SaladUI.SaladUIHook.mounted) {
          SaladUI.SaladUIHook.mounted.call(this);
        }
      }, 50);
    } catch (error) {
      console.warn('SaladUI hook mounting failed:', error);
    }
  },
  
  updated() {
    try {
      if (SaladUI.SaladUIHook.updated) {
        SaladUI.SaladUIHook.updated.call(this);
      }
    } catch (error) {
      console.warn('SaladUI hook update failed:', error);
    }
  }
};

// AutoDismiss hook for flash messages
const AutoDismiss = {
  mounted() {
    let timeout = this.el.dataset.timeout;
    if (timeout) {
      setTimeout(() => {
        this.el.classList.add("fade-out");
        setTimeout(() => {
          this.pushEventTo(this.el, "lv:clear-flash", { key: this.el.dataset.kind });
        }, 300);
      }, parseInt(timeout));
    }
  }
};

let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: { 
    SaladUI: SafeSaladUIHook,
    AutoDismiss: AutoDismiss,
    ...BackpexHooks
  },
  dom: {
    onBeforeElUpdated(from, to) {
      // Preserve Alpine.js state when LiveView updates DOM
      if (from._x_dataStack) {
        window.Alpine.clone(from, to);
        window.Alpine.initTree(to);
      }
    },
  }
})

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// Handle dialog closing events
window.addEventListener("phx:close-dialog", (event) => {
  const dialogId = event.detail.id;
  const dialogElement = document.getElementById(dialogId);
  if (dialogElement) {
    // Find the close button and trigger click
    const closeButton = dialogElement.querySelector('[data-action="close"]');
    if (closeButton) {
      closeButton.click();
    }
  }
})

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// Theme selector handler - integrates with Backpex's theme system
function applyTheme(theme) {
  // Store in both keys for compatibility
  localStorage.setItem("backpexTheme", theme);
  localStorage.setItem("theme", theme);
  // Update document root
  document.documentElement.setAttribute("data-theme", theme);
  // Update body
  document.body.setAttribute("data-theme", theme);
  // Update all elements with data-theme attribute
  document.querySelectorAll("[data-theme]").forEach((el) => {
    el.setAttribute("data-theme", theme);
  });
}

// Listen for Backpex theme change events
window.addEventListener("backpex:theme-change", () => {
  // Find the checked radio button
  const checkedRadio = document.querySelector('input[name="theme-selector"]:checked');
  if (checkedRadio) {
    applyTheme(checkedRadio.value);
  }
});

// Ensure theme selector shows correct selection when dropdown opens
document.addEventListener("click", (e) => {
  // Check if a dropdown is being opened
  if (e.target.closest('[role="button"][tabindex="0"]')) {
    // Small delay to ensure dropdown is open
    setTimeout(() => {
      const theme = localStorage.getItem("backpexTheme") || localStorage.getItem("theme") || "business";
      const radio = document.querySelector(`input[name="theme-selector"][value="${theme}"]`);
      if (radio) {
        radio.checked = true;
      }
    }, 50);
  }
});

// Apply theme on page load - check Backpex's key first, then fallback
function initTheme() {
  const theme = localStorage.getItem("backpexTheme") || localStorage.getItem("theme") || "business";
  applyTheme(theme);
  
  // Mark the corresponding radio button as checked if it exists
  const radio = document.querySelector(`input[name="theme-selector"][value="${theme}"]`);
  if (radio) {
    radio.checked = true;
  }
}

// Initialize theme on load
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", initTheme);
} else {
  initTheme();
}

// Re-apply theme after LiveView updates
document.addEventListener("phx:update", () => {
  const theme = localStorage.getItem("backpexTheme") || localStorage.getItem("theme") || "business";
  applyTheme(theme);
  
  // Mark the corresponding radio button as checked if it exists
  const radio = document.querySelector(`input[name="theme-selector"][value="${theme}"]`);
  if (radio) {
    radio.checked = true;
  }
});

