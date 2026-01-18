import React, { memo } from "react";
import { inputClassName } from "./FormUtils";

// Error display component
const FieldError = ({ error }) => error ? (
  <p className="mt-1 text-sm text-red-600 flex items-center gap-1" data-error>
    <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
    </svg>
    {error}
  </p>
) : null;

// Input with error styling
const getInputClassName = (hasError) => 
  hasError 
    ? inputClassName.replace('border-slate-300/70', 'border-red-400').replace('focus:ring-emerald-500/40', 'focus:ring-red-500/40').replace('focus:border-emerald-400', 'focus:border-red-400') + ' ring-red-200'
    : inputClassName;

// Icons
const UserIcon = () => (
  <svg className="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
  </svg>
);

const Spinner = () => (
  <svg className="animate-spin h-5 w-5 text-white" fill="none" viewBox="0 0 24 24">
    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
  </svg>
);

const TranslateIcon = () => (
  <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 5h12M9 3v2m1.048 9.5A18.022 18.022 0 016.412 9m6.088 9h7M11 21l5-10 5 10M12.751 5C11.783 10.77 8.07 15.61 3 18.129" />
  </svg>
);

const CombinedStep1 = ({
  formData,
  handleInputChange,
  translateProfessionalSummary,
  isTranslating,
  translationError,
  remainingTranslations,
  maxTranslations,
  renderSaveDraftButton,
  validationErrors = {},
}) => {
  return (
    <div className="space-y-8">
      {/* Section Header */}
      <div className="text-center mb-6">
        <div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-emerald-100 text-emerald-600 mb-4">
          <UserIcon />
        </div>
        <h2 className="text-xl font-semibold text-slate-900">المعلومات الشخصية والملخص المهني</h2>
        <p className="text-slate-600 mt-2">ابدأ بإدخال معلوماتك الأساسية وملخصك المهني</p>
      </div>

      {/* Personal Info Section */}
      <div className="p-4 sm:p-6 border border-slate-200/60 rounded-lg bg-slate-50/30">
        <h3 className="text-lg font-semibold text-slate-900 mb-4 flex items-center gap-2">
          <span className="w-6 h-6 bg-emerald-600 text-white rounded-full flex items-center justify-center text-sm">1</span>
          المعلومات الشخصية
        </h3>
        <div className="grid gap-4">
          <div>
            <label className="block text-sm font-semibold text-slate-900 mb-2">الاسم الكامل <span className="text-red-500">*</span></label>
            <input
              type="text"
              value={formData.complete_name}
              onChange={(e) => handleInputChange("complete_name", e.target.value)}
              className={getInputClassName(validationErrors.complete_name)}
              placeholder="مثال: Ahmed Ali"
            />
            <FieldError error={validationErrors.complete_name} />
          </div>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-semibold text-slate-900 mb-2">البريد الإلكتروني <span className="text-red-500">*</span></label>
              <input
                type="email"
                value={formData.email}
                onChange={(e) => handleInputChange("email", e.target.value)}
                className={getInputClassName(validationErrors.email)}
                placeholder="ahmed@example.com"
              />
              <FieldError error={validationErrors.email} />
            </div>
            <div>
              <label className="block text-sm font-semibold text-slate-900 mb-2">رقم الهاتف <span className="text-red-500">*</span></label>
              <input
                type="tel"
                value={formData.phone_number}
                onChange={(e) => handleInputChange("phone_number", e.target.value)}
                className={getInputClassName(validationErrors.phone_number)}
                placeholder="+966501234567"
              />
              <FieldError error={validationErrors.phone_number} />
            </div>
          </div>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-semibold text-slate-900 mb-2">المدينة <span className="text-red-500">*</span></label>
              <input
                type="text"
                value={formData.city}
                onChange={(e) => handleInputChange("city", e.target.value)}
                className={getInputClassName(validationErrors.city)}
                placeholder="Riyadh"
              />
              <FieldError error={validationErrors.city} />
            </div>
            <div>
              <label className="block text-sm font-semibold text-slate-900 mb-2">الدولة <span className="text-red-500">*</span></label>
              <input
                type="text"
                value={formData.country}
                onChange={(e) => handleInputChange("country", e.target.value)}
                className={getInputClassName(validationErrors.country)}
                placeholder="Saudi Arabia"
              />
              <FieldError error={validationErrors.country} />
            </div>
          </div>
        </div>
      </div>

      {/* Professional Summary Section */}
      <div className="p-4 sm:p-6 border border-slate-200/60 rounded-lg bg-slate-50/30">
        <h3 className="text-lg font-semibold text-slate-900 mb-4 flex items-center gap-2">
          <span className="w-6 h-6 bg-emerald-600 text-white rounded-full flex items-center justify-center text-sm">2</span>
          الملخص المهني
        </h3>
        <div className="space-y-4">
          <div>
            <label className="block text-sm font-semibold text-slate-900 mb-2">الملخص المهني (بالعربية) <span className="text-red-500">*</span></label>
            <textarea
              value={formData.professional_summary}
              onChange={(e) => handleInputChange("professional_summary", e.target.value)}
              rows={4}
              className={`w-full rounded-lg ${validationErrors.professional_summary ? 'border-red-400 focus:ring-red-500/40 focus:border-red-400' : 'border-slate-300/70 focus:ring-emerald-500/40 focus:border-emerald-400'} bg-white/70 px-4 py-3 text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 ring-1 ring-black/5 transition-all resize-none`}
              placeholder="اكتب ملخصًا مهنيًا مقنعًا يصف خلفيتك المهنية وخبراتك..."
            />
            <FieldError error={validationErrors.professional_summary} />
            <p className="mt-2 text-xs text-blue-600 bg-blue-50 p-2 rounded border border-blue-200">
              💡 سيقوم النظام بترجمة النص العربي إلى الإنجليزية وإنشاء ملخص مهني محسن
            </p>
          </div>

          {/* Translation Button */}
          <div className="text-center">
            <button
              type="button"
              onClick={translateProfessionalSummary}
              disabled={isTranslating || !formData.professional_summary.trim() || remainingTranslations <= 0}
              className="inline-flex items-center gap-2 rounded-lg bg-blue-600 text-white px-6 py-3 text-sm font-medium hover:bg-blue-700 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {isTranslating ? (
                <>
                  <Spinner />
                  جاري الترجمة...
                </>
              ) : (
                <>
                  <TranslateIcon />
                  ترجم وأنشئ ملخص مهني ({remainingTranslations} متبقي)
                </>
              )}
            </button>
          </div>

          {translationError && (
            <div className="p-3 border border-red-200 rounded-lg bg-red-50">
              <p className="text-sm text-red-600 text-center">{translationError}</p>
            </div>
          )}

          {formData.professional_summary_english && (
            <div className="space-y-3">
              <label className="block text-sm font-semibold text-slate-900 mb-2">الملخص المهني (بالإنجليزية)</label>
              <div className="p-4 border border-slate-200/60 rounded-lg bg-slate-50/50">
                <p className="text-slate-700 leading-relaxed text-left" dir="ltr">{formData.professional_summary_english}</p>
              </div>
            </div>
          )}
        </div>
      </div>

      {renderSaveDraftButton(1)}
    </div>
  );
};

export default memo(CombinedStep1);
