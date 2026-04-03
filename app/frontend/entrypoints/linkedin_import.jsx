import React from "react";
import { createRoot } from "react-dom/client";
import StructuredCvEditor from "../components/StructuredCvEditor";
import "../lib/posthog"; // Initialize PostHog analytics

// Track root instances by container using WeakMap
const rootMap = new WeakMap();

function renderApp() {
  const container = document.getElementById("structured-cv-editor");
  
  if (!container) {
    console.log("Container #structured-cv-editor not found on this page");
    return;
  }

  // Check if we already have a root for this exact container
  if (rootMap.has(container)) {
    console.log("Root already exists for this container, skipping");
    return;
  }

  // Get data from window object
  const importId = window.linkedinImportId || "";
  const initialData = window.linkedinImportData || {};
  const updateUrl = window.linkedinImportUpdateUrl || "";
  const saveToResumeUrl = window.linkedinImportSaveToResumeUrl || "";
  const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content || "";

  try {
    // Clear any existing content before creating root
    container.innerHTML = "";
    const root = createRoot(container);
    rootMap.set(container, root);
    root.render(
      React.createElement(StructuredCvEditor, {
        importId: importId,
        initialData: initialData,
        updateUrl: updateUrl,
        saveToResumeUrl: saveToResumeUrl,
        csrfToken: csrfToken
      })
    );
    console.log("StructuredCvEditor rendered successfully");
  } catch (error) {
    console.error("Error rendering StructuredCvEditor:", error);
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
