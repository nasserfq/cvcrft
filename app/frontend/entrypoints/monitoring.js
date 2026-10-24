// Loaded on every page by the layout: browser errors and page speed.
// Sentry waits until the page has loaded and gone idle, so it never competes
// with the page itself. Page-load timings and web vitals are read back from
// the browser's performance buffer, so nothing is lost by starting late.
const start = () => import("../lib/sentry");
const whenIdle = () =>
  "requestIdleCallback" in window ? requestIdleCallback(start, { timeout: 3000 }) : setTimeout(start, 1);

if (document.readyState === "complete") whenIdle();
else window.addEventListener("load", whenIdle, { once: true });
