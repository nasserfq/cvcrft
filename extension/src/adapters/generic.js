// Any other host: same steps as the others, without an apply-button click.
(function (root) {
  "use strict";

  const adapters = (root.SeeraAdapters = root.SeeraAdapters || {});

  adapters.generic = {
    matches: () => true,
    async run(ctx) {
      return root.SeeraFill.runStandard(ctx, {});
    },
  };
})(globalThis);
