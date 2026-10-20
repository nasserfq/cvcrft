import React, { memo } from "react";
import { useTranslation } from "react-i18next";
import MobileDatePicker from "./MobileDatePicker";

// Helper to safely get responsibilities as an array
const getResponsibilitiesArray = (responsibilities) => {
  if (!responsibilities) return [];
  if (Array.isArray(responsibilities)) return responsibilities;
  if (typeof responsibilities === 'string') {
    try {
      const parsed = JSON.parse(responsibilities);
      return Array.isArray(parsed) ? parsed : [];
    } catch {
      return [];
    }
  }
  return [];
};

// Error display component
const SectionError = ({ error }) => error ? (
  <div className="mb-4 p-3 border border-red-400/30 rounded-xl bg-red-500/10" role="alert" data-error>
    <p className="text-sm text-red-300 flex items-center gap-2">
      <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
      </svg>
      {error}
    </p>
  </div>
) : null;

// Field-level error display
const FieldError = ({ error }) => error ? (
  <p className="mt-1 text-xs text-red-300">{error}</p>
) : null;

// Input with error styling helper
const getInputClass = (baseClass, hasError) => 
  hasError 
    ? baseClass.replace('border-white/10', 'border-red-400') + ' ring-2 ring-red-400/60'
    : baseClass;

// Icon
const BriefcaseIcon = () => (
  <svg className="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2 2v2m4 6h.01M5 20h14a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
  </svg>
);

const CombinedStep2 = ({
  formData,
  handleEducationChange,
  addEducation,
  removeEducation,
  handleWorkExperienceChange,
  addWorkExperience,
  removeWorkExperience,
  handleResponsibilityChange,
  addResponsibility,
  removeResponsibility,
  renderSaveDraftButton,
  validationErrors = {},
  // Translation props
  onTranslateJobDescriptions,
  isTranslatingJobs = false,
  jobTranslationError = "",
  jobTranslationSuccess = false,
  remainingJobsTranslations = 5,
  unlimitedUsage = false,
}) => {
  const { t } = useTranslation();

  const jobsLimitReached = !unlimitedUsage && remainingJobsTranslations <= 0;
  const safeRemainingJobsTranslations = typeof remainingJobsTranslations === 'number' ? remainingJobsTranslations : 0;
  
  // Check if there are any responsibilities to translate
  const hasResponsibilities = formData.work_experience.some(
    work => getResponsibilitiesArray(work.responsibilities).some(r => r?.trim())
  );

  // Check if any job has been translated (has original Arabic stored)
  const hasTranslatedResponsibilities = formData.work_experience.some(
    work => work.responsibilities_arabic?.length > 0
  );

  return (
    <div className="space-y-8">
      {/* Section Header */}
      <div className="text-center mb-6">
        <div className="glass-soft inline-flex items-center justify-center w-16 h-16 rounded-[22px] text-gold mb-4">
          <BriefcaseIcon />
        </div>
        <h2 className="text-[22px] sm:text-2xl font-semibold text-mist">{t('step2.title')}</h2>
        <p className="text-mist/70 mt-2 text-[15px] sm:text-base font-light">{t('step2.subtitle')}</p>
      </div>

      {/* Education Section */}
      <div className={`glass-soft rounded-[24px] p-4 sm:p-6 ${validationErrors.education ? 'ring-2 ring-red-400/50' : ''}`}>
        <h3 className="text-lg font-semibold text-mist mb-4 flex items-center gap-2.5">
          <span className="sr-mono w-7 h-7 shrink-0 rounded-full border border-primary/40 bg-primary/15 text-primary-soft flex items-center justify-center text-[13px] font-semibold">1</span>
          {t('education.title')}
          <span className="text-xs text-red-300 font-normal">*</span>
        </h3>
        <SectionError error={validationErrors.education} />
        <div className="space-y-4">
          {formData.education.map((edu, index) => (
            <div key={index} className="rounded-[20px] border border-white/10 bg-white/[0.04] p-4 overflow-hidden">
              <div className="flex items-center justify-between mb-3">
                <span className="text-sm font-medium text-mist/80">{t('education.education_n', { n: index + 1 })}</span>
                {formData.education.length > 1 && (
                  <button type="button" onClick={() => removeEducation(index)} className="text-red-300 hover:text-red-200 text-sm min-h-[44px] px-3 rounded-xl hover:bg-red-500/10 active:bg-red-500/20 transition-all touch-manipulation">{t('actions.delete')}</button>
                )}
              </div>
              <div className="grid gap-3">
                <div>
                  <input
                    type="text"
                    value={edu.degree}
                    onChange={(e) => handleEducationChange(index, "degree", e.target.value)}
                    className={getInputClass("w-full min-h-[48px] rounded-xl border border-white/10 bg-white/[0.06] px-4 py-3 text-base text-mist placeholder:text-mist/40 transition-colors duration-300", validationErrors[`education_degree_${index}`])}
                    placeholder={t('education.degree_placeholder')}
                  />
                  <FieldError error={validationErrors[`education_degree_${index}`]} />
                </div>
                <div>
                  <input
                    type="text"
                    value={edu.institution}
                    onChange={(e) => handleEducationChange(index, "institution", e.target.value)}
                    className={getInputClass("w-full min-h-[48px] rounded-xl border border-white/10 bg-white/[0.06] px-4 py-3 text-base text-mist placeholder:text-mist/40 transition-colors duration-300", validationErrors[`education_institution_${index}`])}
                    placeholder={t('education.institution_placeholder')}
                  />
                  <FieldError error={validationErrors[`education_institution_${index}`]} />
                </div>
                <div className="grid grid-cols-2 gap-3">
                  <MobileDatePicker value={edu.start_date} onChange={(value) => handleEducationChange(index, "start_date", value)} placeholder={t('experience.start_date')} />
                  <MobileDatePicker value={edu.end_date} onChange={(value) => handleEducationChange(index, "end_date", value)} disabled={edu.is_current} placeholder={t('experience.end_date')} />
                </div>
                <label className="flex items-center gap-2.5 min-h-[44px] cursor-pointer">
                  <input type="checkbox" checked={edu.is_current} onChange={(e) => handleEducationChange(index, "is_current", e.target.checked)} className="w-5 h-5 shrink-0 rounded accent-[#0b7f48]" />
                  <span className="text-sm text-mist/80">{t('education.current_study')}</span>
                </label>
              </div>
            </div>
          ))}
          <button type="button" onClick={addEducation} className="sr-btn w-full min-h-[48px] py-3 text-primary hover:text-mist text-[15px] font-medium border border-dashed border-primary/40 rounded-2xl hover:bg-primary/10 active:bg-primary/20 touch-manipulation">
            + {t('education.add_another')}
          </button>
        </div>
      </div>

      {/* Work Experience Section */}
      <div className={`glass-soft rounded-[24px] p-4 sm:p-6 ${validationErrors.work_experience ? 'ring-2 ring-red-400/50' : ''}`}>
        <h3 className="text-lg font-semibold text-mist mb-4 flex items-center gap-2.5">
          <span className="sr-mono w-7 h-7 shrink-0 rounded-full border border-primary/40 bg-primary/15 text-primary-soft flex items-center justify-center text-[13px] font-semibold">2</span>
          {t('experience.title')}
          <span className="text-xs text-red-300 font-normal">*</span>
        </h3>
        <SectionError error={validationErrors.work_experience} />
        <div className="space-y-4">
          {formData.work_experience.map((work, index) => (
            <div key={index} className="rounded-[20px] border border-white/10 bg-white/[0.04] p-3 sm:p-4">
              <div className="flex items-center justify-between mb-4">
                <span className="text-sm font-medium text-mist/80">{t('experience.experience_n', { n: index + 1 })}</span>
                {formData.work_experience.length > 1 && (
                  <button type="button" onClick={() => removeWorkExperience(index)} className="text-red-300 hover:text-red-200 text-sm min-h-[44px] px-3 rounded-xl hover:bg-red-500/10 active:bg-red-500/20 transition-all touch-manipulation">{t('actions.delete')}</button>
                )}
              </div>
              <div className="space-y-3">
                <div>
                  <input
                    type="text"
                    value={work.job_title}
                    onChange={(e) => handleWorkExperienceChange(index, "job_title", e.target.value)}
                    className={getInputClass("w-full min-h-[48px] rounded-xl border border-white/10 bg-white/[0.06] px-4 py-3 text-base text-mist placeholder:text-mist/40 transition-colors duration-300", validationErrors[`work_job_title_${index}`])}
                    placeholder={t('experience.position_placeholder')}
                    style={{ fontSize: "16px" }}
                  />
                  <FieldError error={validationErrors[`work_job_title_${index}`]} />
                </div>
                <div>
                  <input
                    type="text"
                    value={work.company}
                    onChange={(e) => handleWorkExperienceChange(index, "company", e.target.value)}
                    className={getInputClass("w-full min-h-[48px] rounded-xl border border-white/10 bg-white/[0.06] px-4 py-3 text-base text-mist placeholder:text-mist/40 transition-colors duration-300", validationErrors[`work_company_${index}`])}
                    placeholder={t('experience.company_placeholder')}
                    style={{ fontSize: "16px" }}
                  />
                  <FieldError error={validationErrors[`work_company_${index}`]} />
                </div>
                <div className="flex gap-2">
                  <div className="flex-1">
                    <MobileDatePicker value={work.start_date} onChange={(value) => handleWorkExperienceChange(index, "start_date", value)} placeholder={t('experience.start_date')} />
                  </div>
                  <div className="flex-1">
                    <MobileDatePicker value={work.end_date} onChange={(value) => handleWorkExperienceChange(index, "end_date", value)} disabled={work.is_current} placeholder={t('experience.end_date')} />
                  </div>
                </div>
                <label className="flex items-center gap-2.5 min-h-[44px] cursor-pointer">
                  <input type="checkbox" checked={work.is_current} onChange={(e) => handleWorkExperienceChange(index, "is_current", e.target.checked)} className="w-5 h-5 shrink-0 rounded accent-[#0b7f48]" />
                  <span className="text-sm text-mist/80">{t('experience.current_job')}</span>
                </label>
                <div className="pt-2">
                  <label className="block text-sm font-medium text-mist/80 mb-2">{t('experience.responsibilities')}</label>
                  <div className="space-y-2">
                    {work.responsibilities.map((resp, respIndex) => (
                      <div key={respIndex} className="flex items-start gap-2">
                        <span className="text-primary mt-3 text-lg">•</span>
                        <textarea
                          value={resp}
                          onChange={(e) => handleResponsibilityChange(index, respIndex, e.target.value)}
                          rows={2}
                          className="flex-1 min-w-0 min-h-[48px] rounded-xl border border-white/10 bg-white/[0.06] px-4 py-3 text-base text-mist placeholder:text-mist/40 resize-none transition-colors duration-300"
                          placeholder={t('experience.responsibility_placeholder')}
                          style={{ fontSize: "16px" }}
                        />
                        {work.responsibilities.length > 1 && (
                          <button type="button" onClick={() => removeResponsibility(index, respIndex)} className="shrink-0 w-11 h-11 mt-0.5 flex items-center justify-center text-red-300 hover:text-red-200 text-lg rounded-xl hover:bg-red-500/10 active:bg-red-500/20 transition-all touch-manipulation">×</button>
                        )}
                      </div>
                    ))}
                    <button type="button" onClick={() => addResponsibility(index)} className="text-primary hover:text-mist text-sm font-medium min-h-[44px] px-3 rounded-xl hover:bg-primary/10 active:bg-primary/15 transition-all touch-manipulation">+ {t('experience.add_responsibility')}</button>
                  </div>
                  {/* Show original Arabic if translation was done */}
                  {work.responsibilities_arabic?.length > 0 && (
                    <div className="mt-3 p-3 bg-gold/10 border border-gold/30 rounded-xl">
                      <label className="block text-xs font-medium text-gold mb-1">{t('step2.original_arabic')}</label>
                      <ul className="space-y-0.5">
                        {work.responsibilities_arabic.filter(r => r?.trim()).map((respAr, respIdx) => (
                          <li key={respIdx} className="text-xs text-gold flex items-start gap-1">
                            <span className="text-gold mt-0.5">•</span>
                            <span>{respAr}</span>
                          </li>
                        ))}
                      </ul>
                    </div>
                  )}
                </div>
              </div>
            </div>
          ))}
          <button type="button" onClick={addWorkExperience} className="sr-btn w-full min-h-[48px] py-3 text-primary hover:text-mist text-[15px] font-medium border border-dashed border-primary/40 rounded-2xl hover:bg-primary/10 active:bg-primary/20 touch-manipulation">
            + {t('experience.add_another')}
          </button>

          {/* AI Translation Button for all job descriptions */}
          <div className={`mt-4 p-4 border rounded-[20px] bg-primary/10 ${jobTranslationSuccess || hasTranslatedResponsibilities ? 'border-primary/40' : 'border-primary/25'}`}>
            {/* Always show loading state when translating */}
            {isTranslatingJobs ? (
              <>
                <p className="text-sm text-primary-soft mb-3 text-center">
                  ⏳ {t('step2.translating_responsibilities')}
                </p>
                <button
                  type="button"
                  disabled={true}
                  className="w-full min-h-[48px] py-3 px-4 rounded-2xl font-semibold text-[15px] transition-all flex items-center justify-center gap-2 bg-action/70 text-darkBase cursor-not-allowed"
                >
                  <svg className="w-5 h-5 animate-spin" fill="none" viewBox="0 0 24 24">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                  </svg>
                  {t('step1.translating')}
                </button>
              </>
            ) : jobTranslationSuccess || hasTranslatedResponsibilities ? (
              <>
                <p className="text-sm text-primary-soft mb-3 text-center">
                  {t('step2.translation_success')}
                </p>
                <button
                  type="button"
                  onClick={onTranslateJobDescriptions}
                  disabled={!hasResponsibilities || jobsLimitReached}
                  className={`sr-btn w-full min-h-[48px] py-3 px-4 rounded-2xl font-semibold text-[15px] flex items-center justify-center gap-2 ${
                    !hasResponsibilities || jobsLimitReached
                      ? "bg-primary/40 text-white/70 cursor-not-allowed"
                      : "sr-primary shadow-glow"
                  }`}
                >
                  🔄 {unlimitedUsage
                    ? t('step2.retranslate_unlimited')
                    : t('step2.retranslate', { remaining: safeRemainingJobsTranslations })}
                </button>
                {jobsLimitReached && (
                  <p className="text-xs text-gold mt-2 text-center">{t('step2.translations_exhausted')}</p>
                )}
              </>
            ) : (
              <>
                <p className="text-sm text-primary-soft mb-3 text-center">
                  💡 {t('step2.translate_hint')}
                </p>
                <button
                  type="button"
                  onClick={onTranslateJobDescriptions}
                  disabled={!hasResponsibilities || jobsLimitReached}
                  className={`sr-btn w-full min-h-[48px] py-3 px-4 rounded-2xl font-semibold text-[15px] flex items-center justify-center gap-2 ${
                    !hasResponsibilities || jobsLimitReached
                      ? "bg-action/50 text-darkBase cursor-not-allowed"
                      : "bg-action text-darkBase hover:bg-actionHover shadow-glow-gold"
                  }`}
                >
                  🌐 {unlimitedUsage
                    ? t('step2.translate_all_unlimited')
                    : t('step2.translate_all', { remaining: safeRemainingJobsTranslations })}
                </button>
                {!hasResponsibilities && (
                  <p className="text-xs text-mist/55 mt-2 text-center">{t('step2.add_responsibilities_first')}</p>
                )}
                {safeRemainingJobsTranslations <= 0 && (
                  <p className="text-xs text-gold mt-2 text-center">{t('step2.translations_exhausted')}</p>
                )}
              </>
            )}
            {jobTranslationError && (
              <p className="text-sm text-red-300 mt-2 text-center">{jobTranslationError}</p>
            )}
          </div>
        </div>
      </div>

      {renderSaveDraftButton(2)}
    </div>
  );
};

export default memo(CombinedStep2);
