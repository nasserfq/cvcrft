// Workable (apply.workable.com). The form is on the posting URL + "apply/".
(function (root) {
  "use strict";

  const adapters = (root.SeeraAdapters = root.SeeraAdapters || {});

  adapters.workable = {
    matches: (url) => /(^|\.)workable\.com$/.test(url.hostname),
    async run(ctx) {
      const F = root.SeeraFill;
      const formSelectors = ["form[data-ui='application-form']", "form[class*='application']"];
      const path = location.pathname.replace(/\/+$/, "");
      if (!/\/apply$/.test(path)) {
        const blocked = F.preflight();
        if (blocked) return blocked;
        const link = document.querySelector("a[href$='/apply/'], a[href$='/apply'], [data-ui='apply-button']");
        if (link && link.tagName === "A" && link.href) return { navigate: link.href };
        if (!F.findForm(formSelectors)) return { navigate: location.origin + path + "/apply/" };
      }
      return F.runStandard(ctx, {
        formSelectors,
        formTimeoutMs: 15000,
        async openForm() {
          const button = F.findClickable(/^apply( for this job| now)?$/i);
          if (button) button.click();
        },
      });
    },
  };
})(globalThis);
