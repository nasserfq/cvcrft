import React from "react";
import { createRoot } from "react-dom/client";
import MultiStepResumeForm from "../components/MultiStepResumeForm";

// Track root instances by container identity
let rootInstance = null;
let lastContainerId = null;

function renderApp() {
 const container = document.getElementById("resume-form-root");
 
 if (!container) {
  console.log("Container #resume-form-root not found on this page");
  return;
 }

 // Generate a unique ID for this container instance
 const containerId = container.dataset.instanceId || Date.now().toString();
 container.dataset.instanceId = containerId;

 // If it's a different container (e.g., after Turbo navigation), reset the root
 if (lastContainerId !== null && lastContainerId !== containerId) {
  console.log("New container detected, resetting root instance");
  if (rootInstance) {
   try {
    rootInstance.unmount();
   } catch (e) {
    console.log("Could not unmount old root:", e);
   }
  }
  rootInstance = null;
 }
 
 lastContainerId = containerId;

 // Skip if already rendered to this container
 if (rootInstance && container.hasChildNodes()) {
  console.log("Root already exists and container has children, skipping");
  return;
 }

 // Get resume data from window object
 const resumeData = window.resumeData || {};

 const handleSubmit = (formData) => {
  // Create a form element and submit it
  const form = document.createElement("form");
  form.method = "POST";
  form.action = "/resumes";

  // Add CSRF token
  const csrfToken = document
   .querySelector('meta[name="csrf-token"]')
   ?.getAttribute("content");
  if (csrfToken) {
   const csrfInput = document.createElement("input");
   csrfInput.type = "hidden";
   csrfInput.name = "authenticity_token";
   csrfInput.value = csrfToken;
   form.appendChild(csrfInput);
  }

  // Add form data
  Object.entries(formData).forEach(([key, value]) => {
   if (value) {
    const input = document.createElement("input");
    input.type = "hidden";
    input.name = key;
    input.value = value;
    form.appendChild(input);
   }
  });

  document.body.appendChild(form);
  form.submit();
 };

 try {
  console.log("Creating React root for resume form...");
  rootInstance = createRoot(container);
  rootInstance.render(
   <MultiStepResumeForm resume={resumeData} onSubmit={handleSubmit} />
  );
  console.log("React form rendered successfully");
 } catch (error) {
  console.error("Error rendering React component:", error);
  container.innerHTML = `
   <div class="text-center py-8">
    <p class="text-red-500">Error loading form. Please refresh the page.</p>
    <p class="text-sm text-gray-500">${error.message}</p>
   </div>
  `;
 }
}

// Clean up on Turbo navigation
function cleanup() {
 if (rootInstance) {
  try {
   rootInstance.unmount();
  } catch (e) {
   console.log("Could not unmount root on cleanup:", e);
  }
  rootInstance = null;
  lastContainerId = null;
 }
}

// Render when DOM is ready
if (document.readyState === "loading") {
 document.addEventListener("DOMContentLoaded", renderApp);
} else {
 renderApp();
}

// Handle Turbo navigation - re-render on each page load
document.addEventListener("turbo:load", renderApp);
document.addEventListener("turbo:before-render", cleanup);
