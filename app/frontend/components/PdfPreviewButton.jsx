import React from "react";
import i18n from "../lib/i18n";
import { trackEvent } from "../lib/posthog";

// Simple translation function using i18n directly (avoids hook issues)
const t = (key, options) => i18n.t(key, options);

const PdfPreviewButton = ({ cvId }) => {
 const handlePreview = async () => {
  // Track PDF preview click
  trackEvent("pdf_preview_clicked", { cv_id: cvId });
  
  // Get translations for popup window
  const translations = {
    title: t('preview.title'),
    close: t('common.close'),
    loading: t('preview.loading'),
    error: t('preview.error'),
    downloadFile: t('preview.download_file'),
    errorAlert: t('preview.error_alert')
  };
  
  try {
   const response = await fetch(`/cv_generations/${cvId}/preview`);
   if (!response.ok) {
    throw new Error("Failed to fetch PDF");
   }

   // Create a blob from the PDF data
   const pdfBlob = await response.blob();
   const pdfUrl = URL.createObjectURL(pdfBlob);

   // Open preview window with embedded PDF viewer
   const previewWindow = window.open("", "_blank");
   previewWindow.document.write(`
        <!DOCTYPE html>
        <html>
          <head>
            <title>${translations.title}</title>
            <meta charset="utf-8" />
            <meta name="viewport" content="width=device-width, initial-scale=1" />
            <style>
              body, html { 
                margin: 0; 
                padding: 0; 
                height: 100dvh; 
                display: flex;
                flex-direction: column;
                background-color: #525659;
              }
              .header {
                background: white;
                padding: 1rem;
                display: flex;
                justify-content: space-between;
                align-items: center;
                box-shadow: 0 2px 4px rgba(0,0,0,0.1);
              }
              .close-btn {
                padding: 0.5rem 1rem;
                background: #e5e7eb;
                border: none;
                border-radius: 0.375rem;
                cursor: pointer;
              }
              @media (hover: hover) and (pointer: fine) {
                .close-btn:hover {
                  background: #d1d5db;
                }
              }
              .pdf-container { 
                flex: 1;
                display: flex;
                align-items: center;
                justify-content: center;
              }
              .pdf-viewer { 
                width: 100%;
                height: 100%;
                border: none;
                background: white;
              }
              .loading, .error-message { 
                position: fixed;
                top: 50%;
                left: 50%;
                transform: translate(-50%, -50%);
                background: white;
                padding: 1.5rem;
                border-radius: 0.5rem;
                box-shadow: 0 4px 6px rgba(0,0,0,0.1);
                text-align: center;
                font-family: system-ui, -apple-system, sans-serif;
              }
              .error-message {
                display: none;
              }
              .error-message a {
                color: #2563eb;
                text-decoration: none;
                margin-right: 0.5rem;
              }
              @media (hover: hover) and (pointer: fine) {
                .error-message a:hover {
                  text-decoration: underline;
                }
              }
            </style>
          </head>
          <body>
            <div class="header">
              <h1 style="margin: 0; font-size: 1.25rem;">${translations.title}</h1>
              <button class="close-btn" onclick="window.close()">${translations.close}</button>
            </div>
            <div class="pdf-container">
              <div id="loading" class="loading">${translations.loading}</div>
              <div id="error" class="error-message">
                ${translations.error} 
                <a href="${pdfUrl}" download="cv_preview.pdf">${translations.downloadFile}</a>
              </div>
              <iframe
                class="pdf-viewer"
                src="${pdfUrl}#toolbar=1&view=FitH"
                type="application/pdf"
                onload="document.getElementById('loading').style.display='none';"
                onerror="document.getElementById('error').style.display='block'; document.getElementById('loading').style.display='none';"
              ></iframe>
            </div>
            <script>
              window.addEventListener('load', function() {
                const iframe = document.querySelector('iframe');
                setTimeout(() => {
                  if (!iframe.contentDocument || iframe.contentDocument.body.innerHTML === '') {
                    document.getElementById('error').style.display = 'block';
                    document.getElementById('loading').style.display = 'none';
                  }
                }, 2000);
              });
            </script>
          </body>
        </html>
      `);
   previewWindow.document.close();
   
   // Track successful PDF preview
   trackEvent("pdf_preview_loaded", { cv_id: cvId });
  } catch (error) {
   console.error("Error previewing PDF:", error);
   trackEvent("pdf_preview_failed", { cv_id: cvId, error: error.message });
   alert(translations.errorAlert);
  }
 };

 return (
  <button
   onClick={handlePreview}
   className="bg-emerald-500 hover:bg-emerald-600 text-white font-bold py-2 px-4 rounded-lg transition duration-200 flex items-center"
  >
   <span className="mr-2">👁️</span>
   {t('preview.button')}
  </button>
 );
};

export default PdfPreviewButton;
