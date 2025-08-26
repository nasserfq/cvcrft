import React from "react";
import { createRoot } from "react-dom/client";
import MultiStepResumeForm from "../components/MultiStepResumeForm";

console.log("=== RESUME FORM ENTRY POINT LOADING ===");
console.log("React version:", React.version);
console.log("createRoot available:", typeof createRoot);
console.log("MultiStepResumeForm component:", MultiStepResumeForm);
console.log("Current timestamp:", Date.now());

// Try to render immediately
console.log("Attempting immediate render...");
const immediateContainer = document.getElementById("resume-form-root");
console.log("Immediate container found:", immediateContainer);

if (immediateContainer) {
 console.log("Container found immediately, rendering...");
 try {
  const root = createRoot(immediateContainer);
  root.render(<MultiStepResumeForm resume={{}} onSubmit={() => {}} />);
  console.log("Immediate render successful!");
 } catch (error) {
  console.error("Immediate render failed:", error);
 }
} else {
 console.log("Container not found immediately, waiting for DOM...");
}

document.addEventListener("DOMContentLoaded", () => {
 console.log("=== DOM CONTENT LOADED EVENT FIRED ===");
 const container = document.getElementById("resume-form-root");
 console.log("Container found on DOMContentLoaded:", container);
 console.log("Container HTML:", container?.innerHTML);

 if (container) {
  console.log("Rendering React form...");

  // Get resume data from window object
  const resumeData = window.resumeData || {};
  console.log("Resume data:", resumeData);

  try {
   // Create React root and render the component
   const root = createRoot(container);
   console.log("React root created successfully");

   const handleSubmit = (formData) => {
    console.log("Form submitted with data:", formData);
    console.log("Form data keys:", Object.keys(formData));
    console.log("Form data values:", Object.values(formData));

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
     console.log(`Adding form field: ${key} = ${value}`);
     if (value) {
      const input = document.createElement("input");
      input.type = "hidden";
      input.name = key;
      input.value = value;
      form.appendChild(input);
     }
    });

    console.log("Form HTML before submission:", form.outerHTML);
    document.body.appendChild(form);
    form.submit();
   };

   console.log("About to render MultiStepResumeForm component");
   root.render(
    <MultiStepResumeForm resume={resumeData} onSubmit={handleSubmit} />
   );

   console.log("React form rendered successfully!");
  } catch (error) {
   console.error("Error rendering React component:", error);
   // Fallback to simple form if React fails
   container.innerHTML = `
        <div class="text-center py-8">
          <p class="text-red-500">Error loading form. Please refresh the page.</p>
          <p class="text-sm text-gray-500">${error.message}</p>
        </div>
      `;
  }
 } else {
  console.error("Container not found on DOMContentLoaded!");
 }
});

// Also try window load event as backup
window.addEventListener("load", () => {
 console.log("=== WINDOW LOAD EVENT FIRED ===");
 const container = document.getElementById("resume-form-root");
 console.log("Container found on window load:", container);

 if (container && !container.hasChildNodes()) {
  console.log("Container exists but is empty, attempting render...");
  try {
   const root = createRoot(container);
   root.render(<MultiStepResumeForm resume={{}} onSubmit={() => {}} />);
   console.log("Window load render successful!");
  } catch (error) {
   console.error("Window load render failed:", error);
  }
 }
});
