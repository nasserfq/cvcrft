import React, { memo } from "react";
import { useTranslation } from "react-i18next";
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
    ? inputClassName.replace('border-borderLight', 'border-red-400').replace('focus:ring-primary/40', 'focus:ring-red-500/40').replace('focus:border-primary', 'focus:border-red-400') + ' ring-red-200'
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
  remainingSummaryTranslations = 5,
  maxSummaryTranslations = 5,
  unlimitedUsage = false,
  renderSaveDraftButton,
  validationErrors = {},
}) => {
  const { t } = useTranslation();

  return (
    <div className="space-y-8">
      {/* Section Header */}
      <div className="text-center mb-6">
        <div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-primary/10 text-primary mb-4">
          <UserIcon />
        </div>
        <h2 className="text-xl font-semibold text-gray-900 dark:text-white">{t('step1.title')}</h2>
        <p className="text-gray-600 dark:text-gray-400 mt-2">{t('step1.subtitle')}</p>
      </div>

      {/* Personal Info Section */}
      <div className="p-4 sm:p-6 border border-borderLight dark:border-white/10 rounded-xl bg-canvas/30 dark:bg-white/5">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-4 flex items-center gap-2">
          <span className="w-6 h-6 bg-primary text-white rounded-full flex items-center justify-center text-sm">1</span>
          {t('step1.personal_section')}
        </h3>
        <div className="grid gap-4">
          <div>
            <label className="block text-sm font-semibold text-gray-900 dark:text-white mb-2">{t('personal.full_name')} <span className="text-red-500">*</span></label>
            <input
              type="text"
              value={formData.complete_name}
              onChange={(e) => handleInputChange("complete_name", e.target.value)}
              className={getInputClassName(validationErrors.complete_name)}
              placeholder={t('personal.full_name_placeholder')}
            />
            <FieldError error={validationErrors.complete_name} />
          </div>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-semibold text-gray-900 dark:text-white mb-2">{t('personal.email')} <span className="text-red-500">*</span></label>
              <input
                type="email"
                value={formData.email}
                onChange={(e) => handleInputChange("email", e.target.value)}
                className={getInputClassName(validationErrors.email)}
                placeholder={t('personal.email_placeholder')}
              />
              <FieldError error={validationErrors.email} />
            </div>
            <div>
              <label className="block text-sm font-semibold text-gray-900 dark:text-white mb-2">{t('personal.phone')} <span className="text-red-500">*</span></label>
              <input
                type="tel"
                value={formData.phone_number}
                onChange={(e) => handleInputChange("phone_number", e.target.value)}
                className={getInputClassName(validationErrors.phone_number)}
                placeholder={t('personal.phone_placeholder')}
              />
              <FieldError error={validationErrors.phone_number} />
            </div>
          </div>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-semibold text-gray-900 dark:text-white mb-2">{t('personal.city')} <span className="text-red-500">*</span></label>
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
              <label className="block text-sm font-semibold text-gray-900 dark:text-white mb-2">{t('personal.country')} <span className="text-red-500">*</span></label>
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
      <div className="p-4 sm:p-6 border border-borderLight dark:border-white/10 rounded-xl bg-canvas/30 dark:bg-white/5">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-4 flex items-center gap-2">
          <span className="w-6 h-6 bg-primary text-white rounded-full flex items-center justify-center text-sm">2</span>
          {t('step1.summary_section')}
        </h3>
        <div className="space-y-4">
          <div>
            <label className="block text-sm font-semibold text-gray-900 dark:text-white mb-2">{t('step1.summary_arabic')} <span className="text-red-500">*</span></label>
            <textarea
              value={formData.professional_summary}
              onChange={(e) => handleInputChange("professional_summary", e.target.value)}
              rows={4}
              className={`w-full rounded-xl ${validationErrors.professional_summary ? 'border-red-400 focus:ring-red-500/40 focus:border-red-400' : 'border-borderLight dark:border-white/10 focus:ring-primary/40 focus:border-primary'} bg-white/70 dark:bg-darkCard/70 px-4 py-3 text-gray-900 dark:text-white placeholder:text-gray-400 dark:placeholder:text-gray-500 focus:outline-none focus:ring-2 ring-1 ring-black/5 dark:ring-white/5 transition-all resize-none`}
              placeholder={t('personal.summary_placeholder')}
            />
            <FieldError error={validationErrors.professional_summary} />
            <p className="mt-2 text-xs text-primary bg-primary/10 p-2 rounded-lg border border-primary/20">
              {t('step1.summary_hint')}
            </p>
          </div>

          {/* Translation Button */}
          <div className="text-center">
            <button
              type="button"
              onClick={translateProfessionalSummary}
              disabled={isTranslating || !formData.professional_summary.trim() || (!unlimitedUsage && remainingSummaryTranslations <= 0)}
              className="inline-flex items-center gap-2 rounded-xl bg-action text-darkBase px-6 py-3 text-sm font-medium hover:bg-actionHover transition-all disabled:opacity-50 disabled:cursor-not-allowed shadow-[0_0_20px_-5px_rgba(214,184,119,0.4)]"
            >
              {isTranslating ? (
                <>
                  <Spinner />
                  {t('step1.translating')}
                </>
              ) : (
                <>
                  <TranslateIcon />
                  {unlimitedUsage
                    ? t('step1.translate_summary_unlimited')
                    : t('step1.translate_summary', { remaining: remainingSummaryTranslations })}
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
              <label className="block text-sm font-semibold text-gray-900 dark:text-white mb-2">{t('step1.summary_english')}</label>
              <div className="p-4 border border-borderLight dark:border-white/10 rounded-xl bg-canvas/50 dark:bg-white/5">
                <p className="text-gray-700 dark:text-gray-300 leading-relaxed text-left" dir="ltr">{formData.professional_summary_english}</p>
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
