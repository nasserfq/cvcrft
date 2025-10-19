import React from "react";
import CvBuilderPdfPreview from "./CvBuilderPdfPreview";

const CvActions = ({ resume }) => {
 const handleDownload = () => {
  if (!resume?.metadata?.pdf_data) {
   alert("PDF data is not available");
   return;
  }

  try {
   // Convert base64 PDF data to blob
   const pdfData = atob(resume.metadata.pdf_data);
   const pdfArray = new Uint8Array(pdfData.length);
   for (let i = 0; i < pdfData.length; i++) {
    pdfArray[i] = pdfData.charCodeAt(i);
   }
   const pdfBlob = new Blob([pdfArray], { type: "application/pdf" });

   // Create download link
   const url = window.URL.createObjectURL(pdfBlob);
   const link = document.createElement("a");
   link.href = url;
   link.download = `${resume.complete_name || "cv"}.pdf`;
   document.body.appendChild(link);
   link.click();
   document.body.removeChild(link);
   window.URL.revokeObjectURL(url);
  } catch (error) {
   console.error("Error downloading PDF:", error);
   alert("حدث خطأ أثناء محاولة تحميل السيرة الذاتية.");
  }
 };

 return (
  <div className="flex space-x-2 rtl:space-x-reverse">
   <CvBuilderPdfPreview resume={resume} />
   <button
    onClick={handleDownload}
    className="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-lg inline-flex items-center transition-colors duration-150"
   >
    <span className="mr-2">⬇️</span>
    تحميل PDF
   </button>
  </div>
 );
};

export default CvActions;
