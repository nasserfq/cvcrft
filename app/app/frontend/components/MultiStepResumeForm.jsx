import React, { useState } from "react";

const MultiStepResumeForm = ({ resume, onSubmit }) => {
 console.log("MultiStepResumeForm component rendered with props:", {
  resume,
  onSubmit,
 });

 const [currentStep, setCurrentStep] = useState(1);
 const [formData, setFormData] = useState({
  title: resume?.title || "",
  target_position: resume?.target_position || "",
  summary: resume?.summary || "",
  // Add more fields as needed
 });

 const totalSteps = 3;

 const handleInputChange = (field, value) => {
  setFormData((prev) => ({
   ...prev,
   [field]: value,
  }));
 };

 const nextStep = () => {
  if (currentStep < totalSteps) {
   setCurrentStep(currentStep + 1);
  }
 };

 const prevStep = () => {
  if (currentStep > 1) {
   setCurrentStep(currentStep - 1);
  }
 };

 const handleSubmit = (e) => {
  e.preventDefault();
  if (onSubmit) {
   // Transform form data to Rails parameter format
   const railsFormData = {
    "resume[title]": formData.title,
    "resume[target_position]": formData.target_position,
    "resume[summary]": formData.summary,
   };
   onSubmit(railsFormData);
  }
 };

 const renderStep1 = () => (
  <div className="space-y-6">
   <div className="text-center mb-6">
    <div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-emerald-100 text-emerald-600 mb-4">
     <svg
      className="w-8 h-8"
      fill="none"
      stroke="currentColor"
      viewBox="0 0 24 24"
     >
      <path
       strokeLinecap="round"
       strokeLinejoin="round"
       strokeWidth={2}
       d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
      />
     </svg>
    </div>
    <h2 className="text-xl font-semibold text-slate-900">المعلومات الأساسية</h2>
    <p className="text-slate-600 mt-2">
     ابدأ بالمعلومات الأساسية عن سيرتك الذاتية
    </p>
   </div>

   <div className="grid gap-6">
    <div>
     <label className="block text-sm font-semibold text-slate-900 mb-2">
      عنوان السيرة الذاتية
     </label>
     <input
      type="text"
      value={formData.title}
      onChange={(e) => handleInputChange("title", e.target.value)}
      className="w-full rounded-lg border border-slate-300/70 bg-white/70 px-4 py-3 text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/40 focus:border-emerald-400 ring-1 ring-black/5 transition-all"
      placeholder="مثال: سيرة ذاتية لمهندس برمجيات أول"
     />
     <p className="mt-2 text-xs text-slate-500">
      عنوان السيرة الذاتية - يمكن أن يكون اسمك أو الوظيفة المستهدفة
     </p>
    </div>

    <div>
     <label className="block text-sm font-semibold text-slate-900 mb-2">
      الوظيفة المستهدفة
     </label>
     <input
      type="text"
      value={formData.target_position}
      onChange={(e) => handleInputChange("target_position", e.target.value)}
      className="w-full rounded-lg border border-slate-300/70 bg-white/70 px-4 py-3 text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/40 focus:border-emerald-400 ring-1 ring-black/5 transition-all"
      placeholder="مثال: مهندس برمجيات أول"
     />
     <p className="mt-2 text-xs text-slate-500">الوظيفة التي تتقدم إليها</p>
    </div>

    <div>
     <label className="block text-sm font-semibold text-slate-900 mb-2">
      الملخص المهني
     </label>
     <textarea
      value={formData.summary}
      onChange={(e) => handleInputChange("summary", e.target.value)}
      rows={4}
      className="w-full rounded-lg border border-slate-300/70 bg-white/70 px-4 py-3 text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/40 focus:border-emerald-400 ring-1 ring-black/5 transition-all resize-none"
      placeholder="اكتب ملخصًا مهنيًا مقنعًا يصف خلفيتك المهنية وأهدافك الوظيفية..."
     />
     <p className="mt-2 text-xs text-slate-500">
      يجب أن يكون 2-4 جمل تصف خلفيتك المهنية وأهدافك الوظيفية
     </p>
    </div>
   </div>
  </div>
 );

 const renderStep2 = () => (
  <div className="space-y-6">
   <div className="text-center mb-6">
    <div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-emerald-100 text-emerald-600 mb-4">
     <svg
      className="w-8 h-8"
      fill="none"
      stroke="currentColor"
      viewBox="0 0 24 24"
     >
      <path
       strokeLinecap="round"
       strokeLinejoin="round"
       strokeWidth={2}
       d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2-2v2m8 0V6a2 2 0 012 2v6a2 2 0 01-2 2H8a2 2 0 01-2-2V8a2 2 0 012-2V6"
      />
     </svg>
    </div>
    <h2 className="text-xl font-semibold text-slate-900">الخبرات العملية</h2>
    <p className="text-slate-600 mt-2">أضف خبراتك العملية السابقة</p>
   </div>

   <div className="space-y-4">
    <div className="p-4 border border-slate-200/60 rounded-lg bg-slate-50/50">
     <p className="text-sm text-slate-600 text-center">
      سيتم إضافة هذه الميزة في الخطوة التالية
     </p>
    </div>
   </div>
  </div>
 );

 const renderStep3 = () => (
  <div className="space-y-6">
   <div className="text-center mb-6">
    <div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-emerald-100 text-emerald-600 mb-4">
     <svg
      className="w-8 h-8"
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
    <h2 className="text-xl font-semibold text-slate-900">مراجعة النهائية</h2>
    <p className="text-slate-600 mt-2">راجع معلوماتك قبل الإنشاء</p>
   </div>

   <div className="space-y-4">
    <div className="p-4 border border-slate-200/60 rounded-lg bg-slate-50/50">
     <div className="space-y-3">
      <div>
       <span className="font-medium text-slate-900">العنوان:</span>
       <span className="text-slate-600 ml-2">
        {formData.title || "غير محدد"}
       </span>
      </div>
      <div>
       <span className="font-medium text-slate-900">الوظيفة المستهدفة:</span>
       <span className="text-slate-600 ml-2">
        {formData.target_position || "غير محدد"}
       </span>
      </div>
      <div>
       <span className="font-medium text-slate-900">الملخص:</span>
       <span className="text-slate-600 ml-2">
        {formData.summary || "غير محدد"}
       </span>
      </div>
     </div>
    </div>
   </div>
  </div>
 );

 const renderStepContent = () => {
  switch (currentStep) {
   case 1:
    return renderStep1();
   case 2:
    return renderStep2();
   case 3:
    return renderStep3();
   default:
    return renderStep1();
  }
 };

 return (
  <form
   onSubmit={handleSubmit}
   className="max-w-4xl mx-auto p-6 bg-white rounded-xl shadow-sm ring-1 ring-black/5"
  >
   {/* Progress Bar */}
   <div className="mb-8">
    <div className="flex items-center justify-between mb-4">
     <h1 className="text-2xl font-bold text-slate-900">
      إنشاء سيرة ذاتية جديدة
     </h1>
     <span className="text-sm text-slate-500">
      الخطوة {currentStep} من {totalSteps}
     </span>
    </div>
    <div className="w-full bg-slate-200 rounded-full h-2">
     <div
      className="bg-emerald-600 h-2 rounded-full transition-all duration-300"
      style={{ width: `${(currentStep / totalSteps) * 100}%` }}
     ></div>
    </div>
   </div>

   {/* Step Content */}
   {renderStepContent()}

   {/* Navigation Buttons */}
   <div className="flex items-center justify-between pt-6 border-t border-slate-200/60">
    <div className="flex items-center gap-3">
     {currentStep > 1 && (
      <button
       type="button"
       onClick={prevStep}
       className="inline-flex items-center gap-2 rounded-lg px-4 py-2.5 text-sm font-medium text-slate-700 ring-1 ring-slate-300/70 transition-all hover:bg-slate-50 hover:ring-slate-400/70"
      >
       <svg
        className="w-4 h-4"
        fill="none"
        stroke="currentColor"
        viewBox="0 0 24 24"
       >
        <path
         strokeLinecap="round"
         strokeLinejoin="round"
         strokeWidth={2}
         d="M9 5l7 7-7 7"
        />
       </svg>
       السابق
      </button>
     )}
    </div>

    <div className="flex items-center gap-3">
     <a
      href="/resumes"
      className="inline-flex items-center gap-2 rounded-lg px-4 py-2.5 text-sm font-medium text-slate-700 ring-1 ring-slate-300/70 transition-all hover:bg-slate-50 hover:ring-slate-400/70"
     >
      <svg
       className="w-4 h-4"
       fill="none"
       stroke="currentColor"
       viewBox="0 0 24 24"
      >
       <path
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={2}
        d="M6 18L18 6M6 6l12 12"
       />
      </svg>
      إلغاء
     </a>

     {currentStep < totalSteps ? (
      <button
       type="button"
       onClick={nextStep}
       className="inline-flex items-center gap-2 rounded-lg bg-emerald-600 px-6 py-2.5 text-sm font-medium text-white ring-1 ring-black/5 transition-all hover:bg-emerald-700 hover:shadow"
      >
       التالي
       <svg
        className="w-4 h-4"
        fill="none"
        stroke="currentColor"
        viewBox="0 0 24 24"
       >
        <path
         strokeLinecap="round"
         strokeLinejoin="round"
         strokeWidth={2}
         d="M15 19l-7-7 7-7"
        />
       </svg>
      </button>
     ) : (
      <button
       type="submit"
       className="inline-flex items-center gap-2 rounded-lg bg-emerald-600 px-6 py-2.5 text-sm font-medium text-white ring-1 ring-black/5 transition-all hover:bg-emerald-700 hover:shadow"
      >
       إنشاء السيرة الذاتية
       <svg i
       
        className="w-4 h-4"
        fill="none"
        stroke="currentColor"
        viewBox="0 0 24 24"
       >
        <path
         strokeLinecap="round"
         strokeLinejoin="round"
         strokeWidth={2}
         d="M12 6v6m0 0v6m0-6h6m-6 0H6"
        />
       </svg>
      </button>
     )}
    </div>
   </div>
  </form>
 );
};

export default MultiStepResumeForm;
