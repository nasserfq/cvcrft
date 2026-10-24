// Sentry in the browser, on every page: errors, page-load speed (web vitals)
// and console warnings/errors as logs.
//
// The DSN comes from a <meta name="sentry-dsn"> tag the layout renders in
// production only, so development and test never send anything. No cookies,
// IPs or other personal data are sent (sendDefaultPii stays off).

import * as Sentry from "@sentry/react";

const meta = (name) =>
  typeof document !== "undefined" &&
  document.querySelector(`meta[name="${name}"]`)?.content;

const dsn = meta("sentry-dsn");
// Name page loads like the server does (HomeController#index), so
// /coach/chats/2 and /coach/chats/3 land in one row next to the request.
const route = meta("sentry-route");

if (dsn && !window.__sentry_initialized) {
  window.__sentry_initialized = true;

  Sentry.init({
    dsn,
    environment: "production",
    release: meta("sentry-release") || undefined,
    integrations: [
      Sentry.browserTracingIntegration({
        beforeStartSpan: (options) =>
          options.op === "pageload" && route ? { ...options, name: route } : options,
      }),
      Sentry.consoleLoggingIntegration({ levels: ["warn", "error"] }),
    ],
    tracesSampleRate: 1.0,
    // Only attach trace headers to our own API, never to third parties.
    tracePropagationTargets: [/^\//, window.location.origin],
    enableLogs: true,
  });
}
