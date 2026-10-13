import "../lib/sentry"; // Initialize Sentry first so it catches errors from everything below
import React from "react";
import { createRoot } from "react-dom/client";
import CvAnalysisResults from "../components/CvAnalysisResults";
import "../lib/posthog"; // Initialize PostHog analytics

// Track root instances by container using WeakMap
const rootMap = new WeakMap();

function renderApp() {
  const container = document.getElementById("cv-analysis-results");
  
  if (!container) {
    console.log("Container #cv-analysis-results not found on this page");
    return;
  }

  // Check if we already have a root for this exact container
  if (rootMap.has(container)) {
    console.log("Root already exists for this container, skipping");
    return;
  }

  // Get data from window object (set in the view)
  const analysisData = window.cvAnalysisData || {};
  const language = window.cvAnalysisLanguage || "ar";
  const targetJob = window.cvAnalysisTargetJob || "";
  const targetIndustry = window.cvAnalysisTargetIndustry || "";

  try {
    // Clear any existing content before creating root
    container.innerHTML = "";
    const root = createRoot(container);
    rootMap.set(container, root);
    
    root.render(
      React.createElement(CvAnalysisResults, {
        analysis: analysisData,
        language: language,
        targetJob: targetJob,
        targetIndustry: targetIndustry
      })
    );
    console.log("CvAnalysisResults rendered successfully");
  } catch (error) {
    console.error("Error rendering CvAnalysisResults:", error);
  }
}

// Initial render
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", renderApp);
} else {
  renderApp();
}

// Handle Turbo navigation - use turbo:render which fires after DOM is stable
document.addEventListener("turbo:render", renderApp);
