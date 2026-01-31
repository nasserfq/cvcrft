import React from "react";
import { createRoot } from "react-dom/client";
import MultiStepResumeForm from "../components/MultiStepResumeForm";
import "../lib/posthog"; // Initialize PostHog analytics

// Track root instances by container
const rootMap = new WeakMap();

function renderApp() {
 const container = document.getElementById("resume-form-root");
 
 if (!container) {
  console.log("Container #resume-form-root not found on this page");
  return;
 }

 // Check if we already have a root for this exact container
 if (rootMap.has(container)) {
  console.log("Root already exists for this container, skipping");
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
  // Clear any existing content before creating root
  container.innerHTML = "";
  const root = createRoot(container);
  rootMap.set(container, root);
  root.render(
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

// Render when DOM is ready
if (document.readyState === "loading") {
 document.addEventListener("DOMContentLoaded", renderApp);
} else {
 renderApp();
}

// Handle Turbo navigation - use turbo:render which fires after DOM is stable
document.addEventListener("turbo:render", renderApp);
