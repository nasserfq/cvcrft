// PURE: human-paced wait between applications, 1-3 minutes, uniform.
// No other timing tricks: this only keeps the pace of a person clicking through.
(function (root) {
  "use strict";

  const lib = (root.SeeraLib = root.SeeraLib || {});

  const MIN_DELAY_MS = 60000;
  const MAX_DELAY_MS = 180000;

  function nextDelayMs(rand) {
    const r = typeof rand === "function" ? rand() : rand === undefined ? Math.random() : rand;
    const clamped = Math.min(Math.max(Number(r) || 0, 0), 1);
    return Math.min(MIN_DELAY_MS + Math.floor(clamped * (MAX_DELAY_MS - MIN_DELAY_MS)), MAX_DELAY_MS);
  }

  lib.delay = { nextDelayMs, MIN_DELAY_MS, MAX_DELAY_MS };
})(globalThis);
