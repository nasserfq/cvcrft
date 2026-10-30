import React, { useState, useEffect } from "react";
import PdfViewer from "./PdfViewer";
import PdfPreviewButton from "./PdfPreviewButton";
import { trackEvent } from "../lib/posthog";

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
  
  // Track CV generation view
  trackEvent("cv_generation_viewed", { cv_generation_id: cvGenerationId });

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
   
   // Track status changes
   if (data.status === "completed") {
    trackEvent("cv_generation_completed", { cv_generation_id: cvGenerationId });
   } else if (data.status === "failed") {
    trackEvent("cv_generation_failed", { cv_generation_id: cvGenerationId });
   }
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
    return "bg-primary/10 text-primary-soft";
   case "processing":
    return "bg-gold/10 text-gold";
   case "failed":
    return "bg-red-500/10 text-red-300";
   case "cancelled":
    return "bg-white/5 text-mist";
   default:
    return "bg-white/5 text-mist";
  }
 };

 if (loading) {
  return (
   <div className="container mx-auto px-4 py-8">
    <div className="flex items-center justify-center h-64">
     <div className="animate-spin rounded-full h-8 w-8 border-2 border-white/10 border-t-gold"></div>
     <span className="ms-3 text-mist/70">Loading CV generation...</span>
    </div>
   </div>
  );
 }

 if (error || !cvGeneration) {
  return (
   <div className="container mx-auto px-4 py-8">
    <div className="text-center py-12">
     <div className="text-red-300 text-lg mb-4">
      ❌ {error || "CV generation not found"}
     </div>
     <button
      onClick={() => (window.location.href = "/cv_generations")}
      className="sr-btn sr-primary inline-flex items-center justify-center gap-2 min-h-[44px] px-4 rounded-2xl font-semibold text-[15px] shadow-glow"
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
    <div className="sr-up flex flex-wrap justify-between items-center gap-4 mb-8">
     <h1 className="text-3xl font-semibold text-mist">
      CV Generation #{cvGeneration.id}
     </h1>
     <div className="flex flex-wrap gap-2">
      <button
       onClick={() => (window.location.href = "/cv_generations")}
       className="sr-btn glass-soft inline-flex items-center justify-center gap-2 min-h-[44px] px-4 rounded-2xl font-medium text-[15px] text-mist"
      >
       Back to List
      </button>
      {cvGeneration.status === "failed" && (
       <button
        onClick={() =>
         (window.location.href = `/cv_generations/${cvGeneration.id}/retry`)
        }
        className="sr-btn inline-flex items-center justify-center gap-2 min-h-[44px] px-4 rounded-2xl bg-action text-darkBase hover:bg-actionHover font-semibold text-[15px] shadow-glow-gold"
       >
        Retry
       </button>
      )}
      {cvGeneration.metadata?.pdf_generated === true && (
       <div className="flex flex-wrap gap-2">
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
                   body, html { margin: 0; padding: 0; height: 100dvh; overflow: hidden; }
                   .pdf-container { width: 100%; height: 100dvh; }
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
         className="sr-btn glass-soft inline-flex items-center justify-center gap-2 min-h-[44px] px-4 rounded-2xl font-medium text-[15px] text-mist"
        >
         <span>👁️</span>
         Preview CV
        </button>
        <a
         href={`/cv_generations/${cvGeneration.id}/download`}
         className="sr-btn sr-primary inline-flex items-center justify-center gap-2 min-h-[44px] px-4 rounded-2xl font-semibold text-[15px] shadow-glow"
        >
         <span>⬇️</span>
         Download CV
        </a>
       </div>
      )}
     </div>
    </div>{" "}
    <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
     {/* Status and Info Panel */}
     <div className="lg:col-span-1">
      <div className="glass sr-up rounded-[28px] p-5 sm:p-6 mb-6">
       <h2 className="text-xl font-semibold text-mist mb-4">
        Status & Information
       </h2>
       <div className="space-y-4">
        <div>
         <label className="block text-sm font-medium text-mist/70">
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
         <label className="block text-sm font-medium text-mist/70">
          Created
         </label>
         <p className="text-sm text-mist/70">
          {formatDate(cvGeneration.created_at)}
         </p>
        </div>
        <div>
         <label className="block text-sm font-medium text-mist/70">
          Last Updated
         </label>
         <p className="text-sm text-mist/70">
          {formatDate(cvGeneration.updated_at)}
         </p>
        </div>
        {cvGeneration.tokens_used && (
         <div>
          <label className="block text-sm font-medium text-mist/70">
           Tokens Used
          </label>
          <p className="text-sm text-mist/70">
           {cvGeneration.tokens_used.toLocaleString()}
          </p>
         </div>
        )}
        {cvGeneration.resume_id && (
         <div>
          <label className="block text-sm font-medium text-mist/70">
           Resume ID
          </label>
          <p className="text-sm text-mist/70">
           {cvGeneration.resume_id}
           <a
            href={`/resumes/${cvGeneration.resume_id}`}
            className="text-primary-soft hover:text-mist ms-2 underline underline-offset-4"
           >
            View Resume
           </a>
          </p>
         </div>
        )}
        <div>
         <label className="block text-sm font-medium text-mist/70">
          AI Model
         </label>
         <p className="text-sm text-mist/70">{cvGeneration.ai_model}</p>
        </div>

        {/* CV Generation Limit */}
        <div className="border-t border-white/10 pt-4">
         <label className="block text-sm font-medium text-mist/70">
          CV Generations
         </label>
         <div className="mt-2">
          <div className="flex justify-between text-sm text-mist/70 mb-1">
           <span>Used: {userCvCount}</span>
           <span>Limit: {maxCvGenerations}</span>
          </div>
          <div className="w-full bg-white/10 rounded-full h-2 overflow-hidden">
           <div
            className={`h-2 rounded-full transition-all duration-300 ${
             userCvCount >= maxCvGenerations
              ? "bg-red-400"
              : userCvCount >= maxCvGenerations * 0.8
              ? "bg-gold"
              : "bg-primary-soft"
            }`}
            style={{
             width: `${Math.min((userCvCount / maxCvGenerations) * 100, 100)}%`,
            }}
           ></div>
          </div>
          {userCvCount >= maxCvGenerations && (
           <p className="text-xs text-red-300 mt-1">
            ⚠️ You've reached the maximum CV generations limit
           </p>
          )}
          {userCvCount >= maxCvGenerations * 0.8 &&
           userCvCount < maxCvGenerations && (
            <p className="text-xs text-gold mt-1">
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
      <div className="glass sr-up rounded-[28px] p-5 sm:p-6 mb-6">
       <h2 className="text-xl font-semibold text-mist mb-4">
        Job Description
       </h2>
       <div className="rounded-[18px] border border-white/10 bg-white/[0.04] p-4">
        <p className="text-sm text-mist/70 whitespace-pre-wrap">
         {cvGeneration.job_description}
        </p>
       </div>
      </div>

      {/* Generated Professional Summary (AI preferred) */}
      {(cvGeneration.professional_summary_english ||
       cvGeneration.generated_content ||
       cvGeneration.professional_summary) && (
       <div className="glass sr-up rounded-[28px] p-5 sm:p-6 mb-6">
        <h2 className="text-xl font-semibold text-mist mb-4">
         Generated Professional Summary
        </h2>
        <div className="rounded-[18px] border border-white/10 bg-white/[0.04] p-4">
         <p className="text-sm text-mist/70 whitespace-pre-wrap">
          {cvGeneration.professional_summary_english ||
           cvGeneration.generated_content ||
           cvGeneration.professional_summary}
         </p>
        </div>
        {(cvGeneration.metadata?.pdf_generated === true ||
         cvGeneration.metadata?.pdf_generated === "true") && (
         <div className="mt-4 p-3 bg-primary/10 border border-primary/30 rounded-xl">
          <p className="text-sm text-primary-soft">
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
         <div className="mt-4 p-3 bg-red-500/10 border border-red-400/30 rounded-xl" role="alert">
          <p className="text-sm text-red-300">
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
       <div className="glass-soft rounded-[22px] border border-primary/30 p-4 mb-6">
        <div className="flex items-center gap-3">
         <div className="flex-shrink-0">
          <svg
           className="w-6 h-6 text-primary-soft"
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
          <h3 className="text-lg font-semibold text-primary-soft">
           PDF Generated Successfully
          </h3>
          <p className="text-sm text-primary-soft">
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
       <div className="bg-gold/10 border border-gold/30 rounded-[22px] p-6">
        <div className="flex items-center">
         <div className="animate-spin rounded-full h-6 w-6 border-2 border-white/10 border-t-gold me-3"></div>
         <div>
          <h3 className="text-lg font-medium text-gold">
           Processing CV Generation
          </h3>
          <p className="text-sm text-gold">
           Your CV is being generated. This may take a few minutes.
           {refreshing && (
            <span className="ms-2 text-primary-soft">
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
       <div className="bg-red-500/10 border border-red-400/30 rounded-[22px] p-6" role="alert">
        <h3 className="text-lg font-medium text-red-300">Generation Failed</h3>
        <p className="text-sm text-red-300">
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
