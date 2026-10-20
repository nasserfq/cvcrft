import { Controller } from "@hotwired/stimulus"

// Intercepts destructive form submits and asks for confirmation in a native
// <dialog> before letting the form through. Works with or without Turbo:
// we cancel the original submit (Turbo ignores defaultPrevented submits) and
// re-submit the form ourselves once the person confirms.
//
// Markup (see app/views/shared/_confirm_dialog.html.erb):
//   <div data-controller="confirm-delete">
//     <form data-action="submit->confirm-delete#intercept"
//           data-confirm-delete-title-param="..."
//           data-confirm-delete-body-param="..."
//           data-confirm-delete-confirm-label-param="..."
//           data-confirm-delete-phrase-param="DELETE">  <!-- optional -->
//     ...
//     <%= render "shared/confirm_dialog" %>
//   </div>
export default class extends Controller {
  static targets = ["dialog", "title", "body", "confirmButton", "phraseField", "phraseLabel", "phraseInput"]

  connect() {
    this.pendingForm = null
    this.approvedForm = null
  }

  intercept(event) {
    const form = event.target.closest("form") || event.target

    // Second pass after the person confirmed: let it through untouched.
    if (this.approvedForm === form) {
      this.approvedForm = null
      return
    }

    event.preventDefault()
    event.stopImmediatePropagation()

    const params = event.params || {}
    const title = params.title || ""
    const body = params.body || ""

    if (!this.hasDialogTarget || typeof this.dialogTarget.showModal !== "function") {
      // Very old browsers: fall back to the native confirm.
      if (window.confirm([title, body].filter(Boolean).join("\n\n"))) this.submit(form)
      return
    }

    this.pendingForm = form
    this.phrase = (params.phrase || "").toString().trim()

    this.titleTarget.textContent = title
    this.bodyTarget.textContent = body
    if (params.confirmLabel) this.confirmButtonTarget.textContent = params.confirmLabel
    else this.confirmButtonTarget.textContent = this.confirmButtonTarget.dataset.defaultLabel || ""

    if (this.phrase) {
      this.phraseFieldTarget.hidden = false
      this.phraseLabelTarget.textContent =
        (this.phraseLabelTarget.dataset.template || "%{phrase}").replace("%{phrase}", this.phrase)
      this.phraseInputTarget.value = ""
      this.phraseInputTarget.placeholder = this.phrase
      this.confirmButtonTarget.disabled = true
    } else {
      this.phraseFieldTarget.hidden = true
      this.confirmButtonTarget.disabled = false
    }

    this.dialogTarget.showModal()
    if (this.phrase) this.phraseInputTarget.focus()
    else this.dialogTarget.querySelector("[data-confirm-delete-cancel]")?.focus()
  }

  checkPhrase() {
    if (!this.phrase) return
    const typed = this.phraseInputTarget.value.trim()
    // Accept the localized phrase, or the English "DELETE" in any case.
    const ok = typed === this.phrase || typed.toUpperCase() === "DELETE" ||
      typed.toUpperCase() === this.phrase.toUpperCase()
    this.confirmButtonTarget.disabled = !ok
  }

  confirm(event) {
    event.preventDefault()
    if (this.confirmButtonTarget.disabled) return
    const form = this.pendingForm
    this.close()
    if (form) this.submit(form)
  }

  cancel(event) {
    event?.preventDefault()
    this.close()
  }

  // Clicking the backdrop (the dialog element itself, outside its panel) cancels.
  backdropClick(event) {
    if (event.target === this.dialogTarget) this.close()
  }

  close() {
    this.pendingForm = null
    if (this.hasDialogTarget && this.dialogTarget.open) this.dialogTarget.close()
  }

  submit(form) {
    this.approvedForm = form
    if (typeof form.requestSubmit === "function") {
      // The re-dispatched submit event fires synchronously inside requestSubmit,
      // so clear the flag right after in case validation blocked the submit.
      form.requestSubmit()
      this.approvedForm = null
    } else {
      this.approvedForm = null
      form.submit()
    }
  }
}
