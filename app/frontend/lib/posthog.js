// PostHog Analytics for React
// https://posthog.com/docs/libraries/js

import posthog from 'posthog-js';

// Initialize PostHog with Vite environment variables
// Uses reverse proxy to avoid ad blockers
const posthogKey = import.meta.env.VITE_PUBLIC_POSTHOG_KEY;
const baseUrl = typeof window !== 'undefined' ? window.location.origin : '';

// Only initialize if not already done by the ERB snippet
if (posthogKey && !window.__posthog_initialized) {
  posthog.init(posthogKey, {
    api_host: `${baseUrl}/ingest`,      // Use reverse proxy
    ui_host: 'https://us.posthog.com',
    person_profiles: 'identified_only', // Only create profiles for identified users
    capture_pageview: true,             // Auto-capture page views
    capture_pageleave: true,            // Capture when user leaves page
    autocapture: true,                  // Auto-capture clicks, form submissions, etc.
    persistence: 'localStorage',
    capture_performance: true,          // Capture Web Vitals (LCP, INP, CLS)
    enable_heatmaps: true,
  });
  window.__posthog_initialized = true;
}

// Export for use in components
export default posthog;

// Helper to identify user after login
export const identifyUser = (userId, properties = {}) => {
  posthog.identify(userId, properties);
};

// Helper to track custom events
export const trackEvent = (eventName, properties = {}) => {
  posthog.capture(eventName, properties);
};

// Helper to reset on logout
export const resetUser = () => {
  posthog.reset();
};
