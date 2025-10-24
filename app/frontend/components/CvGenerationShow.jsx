import React, { useState, useEffect } from "react";
import PdfViewer from "./PdfViewer";
import PdfPreviewButton from "./PdfPreviewButton";

const CvGenerationShow = ({ cvGenerationId }) => {
 const [cvGeneration, setCvGeneration] = useState(null);
 const [loading, setLoading] = useState(true);
 const [error, setError] = useState(null);
 const [refreshing, setRefreshing] = useState(false);
 const [userCvCount, setUserCvCount] = useState(0);
 const [maxCvGenerations, setMaxCvGenerations] = useState(0);

 useEffect(() => {
  fetchCvGeneration();
  fetchUserCvCount();

  // Auto-refresh every 3 seconds if status is processing
  const interval = setInterval(() => {
   if (cvGeneration && cvGeneration.status === "processing") {
    setRefreshing(true);
    fetchCvGeneration();
   }
  }, 3000);

  return () => clearInterval(interval);
 }, [cvGenerationId]);

 const fetchCvGeneration = async () => {
  try {
   const response = await fetch(`/cv_generations/${cvGenerationId}.json`);
   if (!response.ok) {
    throw new Error("Failed to fetch CV generation");
   }
   const data = await response.json();
   console.log("CvGenerationShow - CV Data loaded:", data);
   console.log(
    "CvGenerationShow - PDF Generated:",
    data.metadata?.pdf_generated
   );
   console.log(
    "CvGenerationShow - PDF Generated Type:",
    typeof data.metadata?.pdf_generated
   );
   console.log("CvGenerationShow - Has PDF Data:", !!data.metadata?.pdf_data);
   setCvGeneration(data);
   setRefreshing(false);
  } catch (err) {
   console.error("Error fetching CV generation:", err);
   setError(err.message);
   setRefreshing(false);
  } finally {
   setLoading(false);
  }
 };

 const fetchUserCvCount = async () => {
  try {
   const response = await fetch("/cv_generations/count.json");
   if (response.ok) {
    const data = await response.json();
    setUserCvCount(data.count || 0);
    setMaxCvGenerations(data.limit || 150); // Set the max limit from backend, fallback to 150
   }
  } catch (err) {
   console.error("Error fetching user CV count:", err);
  }
 };

 const formatDate = (dateString) => {
  return new Date(dateString).toLocaleDateString("en-US", {
   year: "numeric",
   month: "long",
   day: "numeric",
   hour: "2-digit",
   minute: "2-digit",
  });
 };

 const getStatusColor = (status) => {
  switch (status) {
   case "completed":
    return "bg-green-100 text-green-800";
   case "processing":
    return "bg-yellow-100 text-yellow-800";
   case "failed":
    return "bg-red-100 text-red-800";
   case "cancelled":
    return "bg-gray-100 text-gray-800";
   default:
    return "bg-gray-100 text-gray-800";
  }
 };

 if (loading) {
  return (
   <div className="container mx-auto px-4 py-8">
    <div className="flex items-center justify-center h-64">
     <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
     <span className="ml-3 text-gray-600">Loading CV generation...</span>
    </div>
   </div>
  );
 }

 if (error || !cvGeneration) {
  return (
   <div className="container mx-auto px-4 py-8">
    <div className="text-center py-12">
     <div className="text-red-500 text-lg mb-4">
      ❌ {error || "CV generation not found"}
     </div>
     <button
      onClick={() => (window.location.href = "/cv_generations")}
      className="bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded"
     >
      Back to CV Generations
     </button>
    </div>
   </div>
  );
 }

 return (
  <div className="container mx-auto px-4 py-8">
   <div className="max-w-6xl mx-auto">
    {/* Header */}
    <div className="flex justify-between items-center mb-8">
     <h1 className="text-3xl font-bold text-gray-900">
      CV Generation #{cvGeneration.id}
     </h1>
     <div className="flex space-x-2">
      <button
       onClick={() => (window.location.href = "/cv_generations")}
       className="bg-gray-500 hover:bg-gray-600 text-white font-bold py-2 px-4 rounded-lg transition duration-200"
      >
       Back to List
      </button>
      {cvGeneration.status === "failed" && (
       <button
        onClick={() =>
         (window.location.href = `/cv_generations/${cvGeneration.id}/retry`)
        }
        className="bg-yellow-500 hover:bg-yellow-600 text-white font-bold py-2 px-4 rounded-lg transition duration-200"
       >
        Retry
       </button>
      )}
      {cvGeneration.metadata?.pdf_generated === true && (
       <div className="flex space-x-2">
        <button
         onClick={() => {
          const previewWindow = window.open("", "_blank");
          previewWindow.document.write(`
             <!DOCTYPE html>
             <html>
               <head>
                 <title>CV Preview</title>
                 <meta charset="utf-8" />
                 <meta name="viewport" content="width=device-width, initial-scale=1" />
                 <style>
                   body, html { margin: 0; padding: 0; height: 100vh; overflow: hidden; }
                   .pdf-container { width: 100%; height: 100vh; }
                   .pdf-viewer { width: 100%; height: 100%; border: none; }
                   .loading { 
                     position: fixed; 
                     top: 50%; 
                     left: 50%; 
                     transform: translate(-50%, -50%);
                     text-align: center; 
                     font-family: Arial, sans-serif;
                     background: white;
                     padding: 20px;
                     border-radius: 8px;
                     box-shadow: 0 2px 4px rgba(0,0,0,0.1);
                   }
                   .error-message {
                     display: none;
                     position: fixed;
                     top: 50%;
                     left: 50%;
                     transform: translate(-50%, -50%);
                     background: white;
                     padding: 20px;
                     border-radius: 8px;
                     box-shadow: 0 2px 4px rgba(0,0,0,0.1);
                     text-align: center;
                   }
                 </style>
               </head>
               <body>
                 <div id="pdfContainer" class="pdf-container">
                   <div id="loading" class="loading">Loading PDF preview...</div>
                   <div id="error" class="error-message">
                     Unable to display PDF. <a href="/cv_generations/${cvGeneration.id}/preview" target="_blank">Open in new tab</a>
                   </div>
                   <iframe
                     class="pdf-viewer"
                     src="/cv_generations/${cvGeneration.id}/preview#toolbar=1&view=FitH"
                     type="application/pdf"
                     onload="document.getElementById('loading').style.display='none';"
                     onerror="document.getElementById('error').style.display='block'; document.getElementById('loading').style.display='none';"
                   ></iframe>
                 </div>
                 <script>
                   window.addEventListener('load', function() {
                     const iframe = document.querySelector('iframe');
                     if (iframe.contentDocument && iframe.contentDocument.body.innerHTML === '') {
                       document.getElementById('error').style.display = 'block';
                       document.getElementById('loading').style.display = 'none';
                     }
                   });
                 </script>
               </body>
             </html>
           `);
          previewWindow.document.close();
         }}
         className="bg-blue-500 hover:bg-blue-600 text-white font-bold py-2 px-4 rounded-lg transition duration-200 flex items-center"
        >
         <span className="mr-2">👁️</span>
         Preview CV
        </button>
        <a
         href={`/cv_generations/${cvGeneration.id}/download`}
         className="bg-green-500 hover:bg-green-600 text-white font-bold py-2 px-4 rounded-lg transition duration-200 flex items-center"
        >
         <span className="mr-2">⬇️</span>
         Download CV
        </a>
       </div>
      )}
     </div>
    </div>{" "}
    <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
     {/* Status and Info Panel */}
     <div className="lg:col-span-1">
      <div className="bg-white rounded-lg shadow-md p-6 mb-6">
       <h2 className="text-xl font-semibold text-gray-900 mb-4">
        Status & Information
       </h2>
       <div className="space-y-4">
        <div>
         <label className="block text-sm font-medium text-gray-700">
          Status
         </label>
         <span
          className={`px-3 py-1 rounded-full text-sm font-medium mt-1 inline-block ${getStatusColor(
           cvGeneration.status
          )}`}
         >
          {cvGeneration.status?.charAt(0).toUpperCase() +
           cvGeneration.status?.slice(1)}
         </span>
        </div>
        <div>
         <label className="block text-sm font-medium text-gray-700">
          Created
         </label>
         <p className="text-sm text-gray-600">
          {formatDate(cvGeneration.created_at)}
         </p>
        </div>
        <div>
         <label className="block text-sm font-medium text-gray-700">
          Last Updated
         </label>
         <p className="text-sm text-gray-600">
          {formatDate(cvGeneration.updated_at)}
         </p>
        </div>
        {cvGeneration.tokens_used && (
         <div>
          <label className="block text-sm font-medium text-gray-700">
           Tokens Used
          </label>
          <p className="text-sm text-gray-600">
           {cvGeneration.tokens_used.toLocaleString()}
          </p>
         </div>
        )}
        {cvGeneration.resume_id && (
         <div>
          <label className="block text-sm font-medium text-gray-700">
           Resume ID
          </label>
          <p className="text-sm text-gray-600">
           {cvGeneration.resume_id}
           <a
            href={`/resumes/${cvGeneration.resume_id}`}
            className="text-blue-600 hover:text-blue-800 ml-2"
           >
            View Resume
           </a>
          </p>
         </div>
        )}
        <div>
         <label className="block text-sm font-medium text-gray-700">
          AI Model
         </label>
         <p className="text-sm text-gray-600">{cvGeneration.ai_model}</p>
        </div>

        {/* CV Generation Limit */}
        <div className="border-t pt-4">
         <label className="block text-sm font-medium text-gray-700">
          CV Generations
         </label>
         <div className="mt-2">
          <div className="flex justify-between text-sm text-gray-600 mb-1">
           <span>Used: {userCvCount}</span>
           <span>Limit: {maxCvGenerations}</span>
          </div>
          <div className="w-full bg-gray-200 rounded-full h-2">
           <div
            className={`h-2 rounded-full transition-all duration-300 ${
             userCvCount >= maxCvGenerations
              ? "bg-red-500"
              : userCvCount >= maxCvGenerations * 0.8
              ? "bg-yellow-500"
              : "bg-green-500"
            }`}
            style={{
             width: `${Math.min((userCvCount / maxCvGenerations) * 100, 100)}%`,
            }}
           ></div>
          </div>
          {userCvCount >= maxCvGenerations && (
           <p className="text-xs text-red-600 mt-1">
            ⚠️ You've reached the maximum CV generations limit
           </p>
          )}
          {userCvCount >= maxCvGenerations * 0.8 &&
           userCvCount < maxCvGenerations && (
            <p className="text-xs text-yellow-600 mt-1">
             ⚠️ You're approaching the CV generations limit
            </p>
           )}
         </div>
        </div>
       </div>
      </div>
     </div>

     {/* Main Content */}
     <div className="lg:col-span-2">
      {/* Job Description */}
      <div className="bg-white rounded-lg shadow-md p-6 mb-6">
       <h2 className="text-xl font-semibold text-gray-900 mb-4">
        Job Description
       </h2>
       <div className="bg-gray-50 p-4 rounded border">
        <p className="text-sm text-gray-700 whitespace-pre-wrap">
         {cvGeneration.job_description}
        </p>
       </div>
      </div>

      {/* Generated Professional Summary (AI preferred) */}
      {(cvGeneration.professional_summary_english ||
       cvGeneration.generated_content ||
       cvGeneration.professional_summary) && (
       <div className="bg-white rounded-lg shadow-md p-6 mb-6">
        <h2 className="text-xl font-semibold text-gray-900 mb-4">
         Generated Professional Summary
        </h2>
        <div className="bg-gray-50 p-4 rounded border">
         <p className="text-sm text-gray-700 whitespace-pre-wrap">
          {cvGeneration.professional_summary_english ||
           cvGeneration.generated_content ||
           cvGeneration.professional_summary}
         </p>
        </div>
        {(cvGeneration.metadata?.pdf_generated === true ||
         cvGeneration.metadata?.pdf_generated === "true") && (
         <div className="mt-4 p-3 bg-green-50 border border-green-200 rounded">
          <p className="text-sm text-green-700">
           <strong>✓ PDF Generated Successfully</strong> - Size:{" "}
           {cvGeneration.metadata?.pdf_size
            ? `${(cvGeneration.metadata?.pdf_size / 1024).toFixed(1)} KB`
            : "Unknown"}{" "}
           | Filename:{" "}
           {cvGeneration.metadata?.pdf_filename || "generated_cv.pdf"}
          </p>
         </div>
        )}
        {cvGeneration.metadata?.pdf_error && (
         <div className="mt-4 p-3 bg-red-50 border border-red-200 rounded">
          <p className="text-sm text-red-700">
           <strong>✗ PDF Generation Failed:</strong>{" "}
           {cvGeneration.metadata.pdf_error}
          </p>
         </div>
        )}
       </div>
      )}

      {/* Success Status for PDF */}
      {(cvGeneration.metadata?.pdf_generated === true ||
       cvGeneration.metadata?.pdf_generated === "true") && (
       <div className="bg-gradient-to-r from-green-50 to-blue-50 border border-green-200 rounded-lg p-4 mb-6">
        <div className="flex items-center space-x-3">
         <div className="flex-shrink-0">
          <svg
           className="w-6 h-6 text-green-600"
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
          <h3 className="text-lg font-semibold text-green-800">
           PDF Generated Successfully
          </h3>
          <p className="text-sm text-green-700">
           Your CV PDF is ready for download and preview. File size:{" "}
           {cvGeneration.metadata?.pdf_size
            ? `${(cvGeneration.metadata.pdf_size / 1024).toFixed(1)} KB`
            : "Unknown"}
          </p>
         </div>
        </div>
       </div>
      )}

      {/* PDF Viewer */}
      {(cvGeneration.metadata?.pdf_generated === true ||
       cvGeneration.metadata?.pdf_generated === "true") &&
       cvGeneration.metadata?.pdf_data && (
        <PdfViewer
         cvGenerationId={cvGeneration.id}
         pdfData={cvGeneration.metadata.pdf_data}
         filename={cvGeneration.metadata.pdf_filename}
         fileSize={cvGeneration.metadata.pdf_size}
        />
       )}

      {/* Processing Status */}
      {cvGeneration.status === "processing" && (
       <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-6">
        <div className="flex items-center">
         <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-yellow-600 mr-3"></div>
         <div>
          <h3 className="text-lg font-medium text-yellow-800">
           Processing CV Generation
          </h3>
          <p className="text-sm text-yellow-700">
           Your CV is being generated. This may take a few minutes.
           {refreshing && (
            <span className="ml-2 text-blue-600">
             🔄 Checking for updates...
            </span>
           )}
          </p>
         </div>
        </div>
       </div>
      )}

      {/* Error Status */}
      {cvGeneration.status === "failed" && (
       <div className="bg-red-50 border border-red-200 rounded-lg p-6">
        <h3 className="text-lg font-medium text-red-800">Generation Failed</h3>
        <p className="text-sm text-red-700">
         There was an error generating your CV. You can try again using the
         retry button above.
        </p>
       </div>
      )}
     </div>
    </div>
   </div>
  </div>
 );
};

export default CvGenerationShow;
