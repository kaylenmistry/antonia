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
import { LiveSocket } from "phoenix_live_view"
import topbar from "../vendor/topbar"
import SaladUI from "salad_ui";
import "salad_ui/components/dropdown_menu";
import "salad_ui/components/dialog";
import "./salad_ui_patches";

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

let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: { SaladUI: SafeSaladUIHook }
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

