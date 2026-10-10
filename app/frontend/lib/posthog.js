// PostHog Analytics for React
// https://posthog.com/docs/libraries/js
//
// Consent-gated. Nothing initialises and no event is sent until the visitor
// has accepted via the banner in app/views/shared/_posthog.html.erb, which
// records the decision in the `analytics_consent` cookie. Every helper below
// is a no-op without consent, so callers do not need to check first.

import posthog from 'posthog-js';

const posthogKey = import.meta.env.VITE_PUBLIC_POSTHOG_KEY;
const baseUrl = typeof window !== 'undefined' ? window.location.origin : '';

const hasConsent = () => {
  if (typeof document === 'undefined') return false;
  return /(?:^|;\s*)analytics_consent=granted(?:;|$)/.test(document.cookie);
};

let started = false;

const start = () => {
  if (started || !posthogKey || !hasConsent()) return false;
  if (typeof window !== 'undefined' && window.__posthog_react_initialized) {
    started = true;
    return true;
  }

  posthog.init(posthogKey, {
    api_host: `${baseUrl}/ingest`,      // Use reverse proxy
    ui_host: 'https://us.posthog.com',
    person_profiles: 'identified_only', // Only create profiles for identified users
    capture_pageview: true,
    capture_pageleave: true,
    autocapture: true,
    persistence: 'localStorage',
    capture_performance: true,
    enable_heatmaps: true,
  });

  started = true;
  if (typeof window !== 'undefined') window.__posthog_react_initialized = true;
  return true;
};

// Try at load time; if consent is not yet given this does nothing. Accepting
// the banner calls back in here so tracking starts without a page reload.
start();

if (typeof window !== 'undefined') {
  window.__posthogReactStart = start;
}

// `ready` guards every public helper: no consent means no client and no send.
const ready = () => started || start();

export default posthog;

export const identifyUser = (userId, properties = {}) => {
  if (!ready()) return;
  posthog.identify(userId, properties);
};

export const trackEvent = (eventName, properties = {}) => {
  if (!ready()) return;
  posthog.capture(eventName, properties);
};

export const resetUser = () => {
  if (!started) return;
  posthog.reset();
};
