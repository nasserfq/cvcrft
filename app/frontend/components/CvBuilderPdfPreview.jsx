import React from "react";

const CvBuilderPdfPreview = ({ resume }) => {
 const handlePreview = () => {
  if (!resume?.pdf_url) {
   alert("PDF preview is not available");
   return;
  }
  // Open preview window with embedded PDF viewer, always fetches latest PDF
  const previewWindow = window.open("", "_blank");
  previewWindow.document.write(`
    <!DOCTYPE html>
    <html dir="rtl" lang="ar">
      <head>
        <title>معاينة السيرة الذاتية</title>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <style>
          body, html { margin: 0; padding: 0; height: 100dvh; display: flex; flex-direction: column; background-color: #525659; }
          .header { background: white; padding: 1rem; display: flex; justify-content: space-between; align-items: center; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
          .close-btn { padding: 0.5rem 1rem; background: #e5e7eb; border: none; border-radius: 0.375rem; cursor: pointer; }
          @media (hover: hover) and (pointer: fine) { .close-btn:hover { background: #d1d5db; } }
          .pdf-container { flex: 1; display: flex; align-items: center; justify-content: center; }
          .pdf-viewer { width: 100%; height: 100%; border: none; background: white; }
          .loading, .error-message { position: fixed; top: 50%; left: 50%; transform: translate(-50%, -50%); background: white; padding: 1.5rem; border-radius: 0.5rem; box-shadow: 0 4px 6px rgba(0,0,0,0.1); text-align: center; font-family: system-ui, -apple-system, sans-serif; }
          .error-message { display: none; }
        </style>
      </head>
      <body>
        <div class="header">
          <h1 style="margin: 0; font-size: 1.25rem;">معاينة السيرة الذاتية</h1>
          <button class="close-btn" onclick="window.close()">إغلاق</button>
        </div>
        <div class="pdf-container">
          <div id="loading" class="loading">جاري تحميل معاينة السيرة الذاتية...</div>
          <iframe
            class="pdf-viewer"
            src="${resume.pdf_url}?preview=true#toolbar=1&view=FitH"
            type="application/pdf"
            onload="document.getElementById('loading').style.display='none';"
          ></iframe>
        </div>
      </body>
    </html>
  `);
  previewWindow.document.close();
 };

 return (
  <button
   onClick={handlePreview}
   className="bg-emerald-600 hover:bg-emerald-700 text-white px-4 py-2 rounded-lg inline-flex items-center transition-colors duration-150"
  >
   <span className="mr-2">👁️</span>
   فتح في نافذة جديدة
  </button>
 );
};

export default CvBuilderPdfPreview;
