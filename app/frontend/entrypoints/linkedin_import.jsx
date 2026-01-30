import React from "react";
import { createRoot } from "react-dom/client";
import StructuredCvEditor from "../components/StructuredCvEditor";

// Track root instances
let rootInstance = null;

function renderApp() {
  const container = document.getElementById("structured-cv-editor");
  
  if (!container) {
    console.log("Container #structured-cv-editor not found on this page");
    return;
  }

  // Skip if already rendered
  if (rootInstance && container.hasChildNodes()) {
    console.log("Root already exists, skipping");
    return;
  }

  // Get data from window object
  const importId = window.linkedinImportId || "";
  const initialData = window.linkedinImportData || {};
  const updateUrl = window.linkedinImportUpdateUrl || "";
  const saveToResumeUrl = window.linkedinImportSaveToResumeUrl || "";
  const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content || "";

  // Create root and render
  rootInstance = createRoot(container);
  rootInstance.render(
    React.createElement(StructuredCvEditor, {
      importId: importId,
      initialData: initialData,
      updateUrl: updateUrl,
      saveToResumeUrl: saveToResumeUrl,
      csrfToken: csrfToken
    })
  );

  console.log("StructuredCvEditor rendered successfully");
}

// Initial render
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", renderApp);
} else {
  renderApp();
}

// Re-render on Turbo navigation
document.addEventListener("turbo:load", renderApp);
document.addEventListener("turbo:render", renderApp);
