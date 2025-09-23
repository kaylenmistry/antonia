// Patches for SaladUI to handle focus and transition issues
// This file provides defensive programming for common SaladUI issues

// Patch for focus-trap null reference errors
const originalFocusTrap = window.FocusTrap;
if (originalFocusTrap) {
  // Override the setInitialFocus method to be more defensive
  const originalSetInitialFocus = originalFocusTrap.prototype.setInitialFocus;
  originalFocusTrap.prototype.setInitialFocus = function () {
    if (!this.element || !document.body.contains(this.element)) {
      console.warn('SaladUI: Focus trap element not found or not in DOM');
      return;
    }

    try {
      originalSetInitialFocus.call(this);
    } catch (error) {
      console.warn('SaladUI: Focus trap initialization failed:', error);
      // Fallback: just focus the element itself
      if (this.element && this.element.focus) {
        this.element.focus();
      }
    }
  };

  // Override the activate method to be more defensive
  const originalActivate = originalFocusTrap.prototype.activate;
  originalFocusTrap.prototype.activate = function () {
    if (!this.element || !document.body.contains(this.element)) {
      console.warn('SaladUI: Cannot activate focus trap - element not found');
      return;
    }

    try {
      originalActivate.call(this);
    } catch (error) {
      console.warn('SaladUI: Focus trap activation failed:', error);
    }
  };

  // Override the deactivate method to be more defensive
  const originalDeactivate = originalFocusTrap.prototype.deactivate;
  originalFocusTrap.prototype.deactivate = function () {
    try {
      originalDeactivate.call(this);
    } catch (error) {
      console.warn('SaladUI: Focus trap deactivation failed:', error);
    }
  };
}

// Add a global error handler for SaladUI component errors
window.addEventListener('error', function (event) {
  if (event.filename && event.filename.includes('salad_ui')) {
    console.warn('SaladUI Error caught and handled:', event.error);
    event.preventDefault(); // Prevent the error from breaking the app
  }
});

// Add defensive programming for dialog transitions
document.addEventListener('DOMContentLoaded', function () {
  // Wait for SaladUI to be available
  const checkSaladUI = () => {
    if (window.SaladUI && window.SaladUI.Component) {
      const originalTransition = window.SaladUI.Component.prototype.transition;
      if (originalTransition) {
        window.SaladUI.Component.prototype.transition = function (event, params = {}) {
          try {
            if (!this.stateMachine) {
              console.warn('SaladUI: State machine not initialized for transition:', event);
              return Promise.resolve();
            }
            return originalTransition.call(this, event, params);
          } catch (error) {
            console.warn('SaladUI: Transition failed:', error);
            return Promise.resolve();
          }
        };
      }
    } else {
      // Retry after a short delay
      setTimeout(checkSaladUI, 100);
    }
  };

  checkSaladUI();
});

export default {};