// Ashby (jobs.ashbyhq.com). The form is the posting's "Application" tab,
// /<company>/<posting>/application.
(function (root) {
  "use strict";

  const adapters = (root.SeeraAdapters = root.SeeraAdapters || {});

  adapters.ashby = {
    matches: (url) => /(^|\.)ashbyhq\.com$/.test(url.hostname),
    async run(ctx) {
      const F = root.SeeraFill;
      const formSelectors = ["form[class*='application']", "[class*='ApplicationForm'] form"];
      return F.runStandard(ctx, {
        formSelectors,
        formTimeoutMs: 15000,
        async openForm() {
          const tab =
            document.querySelector("a[href$='/application'], [role='tab'][id*='application' i]") ||
            F.findClickable(/^(application|apply for this job|apply)$/i);
          if (tab) tab.click();
        },
      });
    },
  };
})(globalThis);
