// PostHog Analytics for React
// https://posthog.com/docs/libraries/js

import posthog from 'posthog-js';

// Initialize PostHog with Vite environment variables
const posthogKey = import.meta.env.VITE_PUBLIC_POSTHOG_KEY;
const posthogHost = import.meta.env.VITE_PUBLIC_POSTHOG_HOST || 'https://us.i.posthog.com';

if (posthogKey) {
  posthog.init(posthogKey, {
    api_host: posthogHost,
    person_profiles: 'identified_only', // Only create profiles for identified users
    capture_pageview: true,             // Auto-capture page views
    capture_pageleave: true,            // Capture when user leaves page
    autocapture: true,                  // Auto-capture clicks, form submissions, etc.
    persistence: 'localStorage',
  });
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
