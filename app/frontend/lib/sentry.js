// Sentry for the React pages: browser errors, page-load traces and console
// warnings/errors as logs.
//
// The DSN comes from a <meta name="sentry-dsn"> tag the layout renders in
// production only, so development and test never send anything. No cookies,
// IPs or other personal data are sent (sendDefaultPii stays off).

import * as Sentry from "@sentry/react";

const dsn =
  typeof document !== "undefined" &&
  document.querySelector('meta[name="sentry-dsn"]')?.content;

if (dsn && !window.__sentry_initialized) {
  window.__sentry_initialized = true;

  Sentry.init({
    dsn,
    environment: "production",
    integrations: [
      Sentry.browserTracingIntegration(),
      Sentry.consoleLoggingIntegration({ levels: ["warn", "error"] }),
    ],
    tracesSampleRate: 0.2,
    // Only attach trace headers to our own API, never to third parties.
    tracePropagationTargets: [/^\//, window.location.origin],
    enableLogs: true,
  });
}
