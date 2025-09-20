import React, { useState, useEffect } from "react";

const PdfViewer = ({ cvGenerationId, pdfData, filename, fileSize }) => {
 const [pdfUrl, setPdfUrl] = useState(null);
 const [loading, setLoading] = useState(true);
 const [error, setError] = useState(null);

 useEffect(() => {
  if (pdfData) {
   try {
    // Create a blob from the base64 PDF data
    const byteCharacters = atob(pdfData);
    const byteNumbers = new Array(byteCharacters.length);
    for (let i = 0; i < byteCharacters.length; i++) {
     byteNumbers[i] = byteCharacters.charCodeAt(i);
    }
    const byteArray = new Uint8Array(byteNumbers);
    const blob = new Blob([byteArray], { type: "application/pdf" });

    // Create object URL for the PDF
    const url = URL.createObjectURL(blob);
    setPdfUrl(url);
    setLoading(false);
   } catch (err) {
    console.error("Error creating PDF URL:", err);
    setError("Failed to load PDF");
    setLoading(false);
   }
  } else {
   setError("No PDF data available");
   setLoading(false);
  }

  // Cleanup function to revoke object URL
  return () => {
   if (pdfUrl) {
    URL.revokeObjectURL(pdfUrl);
   }
  };
 }, [pdfData]);

 const handleDownload = () => {
  if (pdfUrl) {
   const link = document.createElement("a");
   link.href = pdfUrl;
   link.download = filename || "generated_cv.pdf";
   document.body.appendChild(link);
   link.click();
   document.body.removeChild(link);
  }
 };

 const handleOpenInNewTab = () => {
  if (pdfUrl) {
   window.open(pdfUrl, "_blank");
  }
 };

 if (loading) {
  return (
   <div className="bg-gradient-to-br from-blue-50 to-indigo-50 rounded-xl shadow-lg border border-blue-200 p-6 mb-6">
    <div className="flex items-center justify-center h-64">
     <div className="text-center">
      <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
      <h3 className="text-lg font-semibold text-gray-900 mb-2">
       Loading PDF Preview
      </h3>
      <p className="text-gray-600">Please wait while we prepare your CV...</p>
     </div>
    </div>
   </div>
  );
 }

 if (error) {
  return (
   <div className="bg-gradient-to-br from-red-50 to-pink-50 rounded-xl shadow-lg border border-red-200 p-6 mb-6">
    <div className="text-center py-8">
     <div className="w-16 h-16 bg-red-100 rounded-full flex items-center justify-center mx-auto mb-4">
      <svg
       className="w-8 h-8 text-red-600"
       fill="none"
       stroke="currentColor"
       viewBox="0 0 24 24"
      >
       <path
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={2}
        d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z"
       />
      </svg>
     </div>
     <h3 className="text-lg font-semibold text-red-800 mb-2">
      PDF Preview Error
     </h3>
     <p className="text-red-600 mb-4">{error}</p>
     <p className="text-gray-600">Unable to display PDF preview</p>
    </div>
   </div>
  );
 }

 return (
  <div className="bg-gradient-to-br from-blue-50 to-indigo-50 rounded-xl shadow-lg border border-blue-200 p-6 mb-6">
   {/* Header with Success Animation */}
   <div className="flex items-center justify-between mb-6">
    <div className="flex items-center space-x-3">
     <div className="flex items-center justify-center w-12 h-12 bg-green-100 rounded-full">
      <div className="animate-pulse">
       <svg
        className="w-6 h-6 text-green-600"
        fill="none"
        stroke="currentColor"
        viewBox="0 0 24 24"
       >
        <path
         strokeLinecap="round"
         strokeLinejoin="round"
         strokeWidth={2}
         d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
        />
       </svg>
      </div>
     </div>
     <div>
      <h2 className="text-2xl font-bold text-gray-900">
       CV Generated Successfully!
      </h2>
      <p className="text-sm text-gray-600">
       Your professional CV is ready for download and preview
      </p>
     </div>
    </div>

    {/* Action Buttons */}
    <div className="flex space-x-3">
     <button
      onClick={handleDownload}
      className="bg-green-500 hover:bg-green-600 text-white font-semibold py-3 px-6 rounded-lg transition-all duration-200 transform hover:scale-105 shadow-md hover:shadow-lg flex items-center space-x-2"
     >
      <svg
       className="w-5 h-5"
       fill="none"
       stroke="currentColor"
       viewBox="0 0 24 24"
      >
       <path
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={2}
        d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
       />
      </svg>
      <span>Download PDF</span>
     </button>
     <button
      onClick={handleOpenInNewTab}
      className="bg-blue-500 hover:bg-blue-600 text-white font-semibold py-3 px-6 rounded-lg transition-all duration-200 transform hover:scale-105 shadow-md hover:shadow-lg flex items-center space-x-2"
     >
      <svg
       className="w-5 h-5"
       fill="none"
       stroke="currentColor"
       viewBox="0 0 24 24"
      >
       <path
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={2}
        d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"
       />
      </svg>
      <span>Open in New Tab</span>
     </button>
    </div>
   </div>

   {/* PDF Preview Container */}
   <div className="bg-white rounded-lg shadow-inner border border-gray-200 overflow-hidden">
    {/* PDF Header */}
    <div className="bg-gray-50 px-6 py-4 border-b border-gray-200">
     <div className="flex items-center justify-between">
      <div className="flex items-center space-x-3">
       <div className="w-8 h-8 bg-red-100 rounded flex items-center justify-center">
        <svg
         className="w-5 h-5 text-red-600"
         fill="currentColor"
         viewBox="0 0 20 20"
        >
         <path
          fillRule="evenodd"
          d="M4 4a2 2 0 012-2h4.586A2 2 0 0112 2.586L15.414 6A2 2 0 0116 7.414V16a2 2 0 01-2 2H6a2 2 0 01-2-2V4zm2 6a1 1 0 011-1h6a1 1 0 110 2H7a1 1 0 01-1-1zm1 3a1 1 0 100 2h6a1 1 0 100-2H7z"
          clipRule="evenodd"
         />
        </svg>
       </div>
       <div>
        <h3 className="font-semibold text-gray-900">
         {filename || "generated_cv.pdf"}
        </h3>
        <p className="text-sm text-gray-500">
         {fileSize ? `${(fileSize / 1024).toFixed(1)} KB` : "Unknown size"} •
         PDF Document
        </p>
       </div>
      </div>
      <div className="flex items-center space-x-2">
       <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
        ✓ Ready
       </span>
      </div>
     </div>
    </div>

    {/* PDF Preview */}
    <div className="relative" style={{ height: "700px" }}>
     <iframe
      src={pdfUrl}
      width="100%"
      height="100%"
      style={{ border: "none" }}
      title="Generated CV PDF Preview"
      onLoad={() => setLoading(false)}
      className="transition-opacity duration-300"
     >
      <div className="flex items-center justify-center h-full bg-gray-50">
       <div className="text-center p-8">
        <div className="w-16 h-16 bg-gray-200 rounded-full flex items-center justify-center mx-auto mb-4">
         <svg
          className="w-8 h-8 text-gray-400"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
         >
          <path
           strokeLinecap="round"
           strokeLinejoin="round"
           strokeWidth={2}
           d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
          />
         </svg>
        </div>
        <h3 className="text-lg font-semibold text-gray-900 mb-2">
         PDF Preview Not Available
        </h3>
        <p className="text-gray-600 mb-4">
         Your browser doesn't support PDF preview
        </p>
        <button
         onClick={handleDownload}
         className="inline-flex items-center px-4 py-2 bg-blue-600 text-white font-medium rounded-lg hover:bg-blue-700 transition-colors"
        >
         <svg
          className="w-4 h-4 mr-2"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
         >
          <path
           strokeLinecap="round"
           strokeLinejoin="round"
           strokeWidth={2}
           d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
          />
         </svg>
         Download PDF Instead
        </button>
       </div>
      </div>
     </iframe>
    </div>
   </div>

   {/* Success Message */}
   <div className="mt-6 p-4 bg-green-50 border border-green-200 rounded-lg">
    <div className="flex items-start space-x-3">
     <div className="flex-shrink-0">
      <svg
       className="w-5 h-5 text-green-600"
       fill="currentColor"
       viewBox="0 0 20 20"
      >
       <path
        fillRule="evenodd"
        d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
        clipRule="evenodd"
       />
      </svg>
     </div>
     <div>
      <h4 className="text-sm font-semibold text-green-800">
       PDF Auto-Preview Active
      </h4>
      <p className="text-sm text-green-700 mt-1">
       Your CV is automatically displayed above. You can scroll, zoom, download,
       or open in a new tab using the controls above.
      </p>
     </div>
    </div>
   </div>
  </div>
 );
};

export default PdfViewer;
