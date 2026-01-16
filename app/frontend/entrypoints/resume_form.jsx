import React from "react";
import { createRoot } from "react-dom/client";
import MultiStepResumeForm from "../components/MultiStepResumeForm";

// Track if we've already rendered
let rootInstance = null;

function renderApp() {
 const container = document.getElementById("resume-form-root");
 
 if (!container) {
  console.error("Container #resume-form-root not found");
  return;
 }

 // Only create root once
 if (rootInstance) {
  console.log("Root already exists, skipping duplicate render");
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
  rootInstance = createRoot(container);
  rootInstance.render(
   <MultiStepResumeForm resume={resumeData} onSubmit={handleSubmit} />
  );
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
