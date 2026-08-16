import { Controller } from "@hotwired/stimulus"

// Optimistic feedback for the root-switch dropdown while the switch request is in flight.
export default class extends Controller {
  select(event) {
    const item = event.currentTarget
    if (!item || item.matches("[disabled], [aria-disabled='true']")) return

    if (this.element.dataset.switching === "true") {
      event.preventDefault()
      return
    }

    this.element.dataset.switching = "true"
    this.applyOptimisticState(this.labelFor(item))
  }

  labelFor(item) {
    const textSpan = item.querySelector("span.flex-1")
    return (textSpan?.textContent || item.textContent || "").replace(/\s+/g, " ").trim()
  }

  applyOptimisticState(label) {
    const trigger = this.triggerElement()
    if (!trigger) return

    const labelSpan = Array.from(trigger.querySelectorAll("span")).find((span) => !span.closest("svg"))
    if (labelSpan && label) {
      labelSpan.textContent = label
    }

    trigger.disabled = true
    trigger.setAttribute("aria-busy", "true")
    trigger.setAttribute("aria-expanded", "false")
    trigger.classList.add("opacity-70", "pointer-events-none")
  }

  triggerElement() {
    return this.element.querySelector('[data-flat-pack--button-dropdown-target="trigger"]')
  }
}
