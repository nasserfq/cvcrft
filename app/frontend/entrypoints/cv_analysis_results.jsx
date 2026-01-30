import React from "react";
import { createRoot } from "react-dom/client";
import CvAnalysisResults from "../components/CvAnalysisResults";

let rootInstance = null;
let containerRendered = null;

function renderApp() {
  const container = document.getElementById("cv-analysis-results");
  
  if (!container) {
    console.log("Container #cv-analysis-results not found on this page");
    return;
  }

  // Skip if already rendered on this container
  if (rootInstance && containerRendered === container) {
    console.log("Root already exists for this container, skipping");
    return;
  }

  // If we have a root but container changed (Turbo navigation), unmount first
  if (rootInstance && containerRendered !== container) {
    rootInstance.unmount();
    rootInstance = null;
    containerRendered = null;
  }

  // Get data from window object (set in the view)
  const analysisData = window.cvAnalysisData || {};
  const language = window.cvAnalysisLanguage || "ar";
  const targetJob = window.cvAnalysisTargetJob || "";
  const targetIndustry = window.cvAnalysisTargetIndustry || "";

  rootInstance = createRoot(container);
  containerRendered = container;
  
  rootInstance.render(
    React.createElement(CvAnalysisResults, {
      analysis: analysisData,
      language: language,
      targetJob: targetJob,
      targetIndustry: targetIndustry
    })
  );

  console.log("CvAnalysisResults rendered successfully");
}

// Handle Turbo navigation
document.addEventListener("turbo:load", renderApp);

// Initial render
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", renderApp);
} else {
  renderApp();
}
