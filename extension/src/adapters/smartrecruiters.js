// SmartRecruiters (jobs.smartrecruiters.com). "I'm interested" leads to the
// one-click application page.
(function (root) {
  "use strict";

  const adapters = (root.SeeraAdapters = root.SeeraAdapters || {});

  adapters.smartrecruiters = {
    matches: (url) => /(^|\.)smartrecruiters\.com$/.test(url.hostname),
    async run(ctx) {
      const F = root.SeeraFill;
      const formSelectors = ["form[name='applicationForm']", "oc-apply-form form", "form[class*='application']"];
      if (!/oneclick-ui|\/apply/.test(location.pathname)) {
        const blocked = F.preflight();
        if (blocked) return blocked;
        const link = document.querySelector("a[href*='oneclick-ui'], a#st-apply, a.js-oneclick");
        if (link && link.href) return { navigate: link.href };
      }
      return F.runStandard(ctx, {
        formSelectors,
        formTimeoutMs: 15000,
        async openForm() {
          const button = F.findClickable(/i'?m interested|apply now|^apply$/i);
          if (button) button.click();
        },
      });
    },
  };
})(globalThis);
