// To see this message, add the following to the `<head>` section in your
// views/layouts/application.html.erb
//
//    <%= vite_client_tag %>
//    <%= vite_javascript_tag 'application' %>
console.log("Vite ⚡️ Rails");

// If using a TypeScript entrypoint file:
//     <%= vite_typescript_tag 'application' %>
//
// If you want to use .jsx or .tsx, add the extension:
//     <%= vite_javascript_tag 'application.jsx' %>

console.log(
 "Visit the guide for more information: ",
 "https://vite-ruby.netlify.app/guide/rails"
);

// Load Rails libraries in Vite.
import * as Turbo from "@hotwired/turbo";
Turbo.start();

import * as ActiveStorage from "@rails/activestorage";
ActiveStorage.start();

// PostHog Analytics - Initialize globally for all pages
import posthog from 'posthog-js';

const posthogKey = import.meta.env.VITE_PUBLIC_POSTHOG_KEY;
const posthogHost = import.meta.env.VITE_PUBLIC_POSTHOG_HOST || 'https://us.i.posthog.com';

if (posthogKey) {
  posthog.init(posthogKey, {
    api_host: posthogHost,
    person_profiles: 'identified_only',
    capture_pageview: true,
    capture_pageleave: true,
    autocapture: true,
    persistence: 'localStorage',
    // Enable Web Vitals capture (LCP, INP, CLS)
    capture_performance: true,
    // Enable scroll depth tracking
    enable_recording_console_log: false,
  });

  // Re-capture pageview on Turbo navigation for SPA-like behavior
  document.addEventListener('turbo:load', () => {
    posthog.capture('$pageview');
  });
}

// Import all channels.
const channels = import.meta.globEager("./**/*_channel.js");

// Example: Import a stylesheet in app/frontend/index.css
// import '~/index.css'
