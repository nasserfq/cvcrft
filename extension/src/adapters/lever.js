// Lever (jobs.lever.co). The form lives on /<company>/<posting>/apply.
(function (root) {
  "use strict";

  const adapters = (root.SeeraAdapters = root.SeeraAdapters || {});

  adapters.lever = {
    matches: (url) => /(^|\.)lever\.co$/.test(url.hostname),
    async run(ctx) {
      const F = root.SeeraFill;
      const path = location.pathname.replace(/\/+$/, "");
      const formSelectors = ["form#application-form", "form.application-form", ".application-page form", "form[action*='apply']"];
      if (!/\/apply$/.test(path) && !F.findForm(formSelectors)) {
        const blocked = F.preflight();
        if (blocked) return blocked;
        return { navigate: location.origin + path + "/apply" };
      }
      return F.runStandard(ctx, { formSelectors });
    },
  };
})(globalThis);
