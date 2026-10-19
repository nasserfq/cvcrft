// Greenhouse (boards.greenhouse.io, job-boards.greenhouse.io). The form is on
// the posting page; older boards hide it behind an "Apply" button.
(function (root) {
  "use strict";

  const adapters = (root.SeeraAdapters = root.SeeraAdapters || {});

  adapters.greenhouse = {
    matches: (url) => /(^|\.)greenhouse\.io$/.test(url.hostname),
    async run(ctx) {
      const F = root.SeeraFill;
      return F.runStandard(ctx, {
        formSelectors: ["#application-form", "form#application_form", "#application_form", "form[action*='greenhouse']"],
        async openForm() {
          const button = document.querySelector("#apply_button") || F.findClickable(/^apply( for this job| now)?$/i);
          if (button) button.click();
        },
      });
    },
  };
})(globalThis);
