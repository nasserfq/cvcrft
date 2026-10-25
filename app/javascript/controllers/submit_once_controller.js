import { Controller } from "@hotwired/stimulus"

// Disables a form's buttons once it submits, so a double tap sends one request.
//   <form data-controller="submit-once" data-action="submit->submit-once#disable">
export default class extends Controller {
  connect() {
    // Coming back through the browser's back/forward cache restores the
    // disabled buttons, so turn them back on.
    this.restore = (event) => { if (event.persisted) this.toggle(false) }
    window.addEventListener("pageshow", this.restore)
  }

  disconnect() {
    window.removeEventListener("pageshow", this.restore)
  }

  disable(event) {
    if (event.defaultPrevented) return
    this.toggle(true)
  }

  toggle(disabled) {
    this.element.querySelectorAll("button, input[type=submit]").forEach((button) => {
      button.disabled = disabled
      button.toggleAttribute("aria-busy", disabled)
    })
  }
}
