import React, { memo } from "react";
import { useTranslation } from "react-i18next";
import MobileDatePicker from "./MobileDatePicker";

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
const LightbulbIcon = () => (
  <svg className="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z" />
  </svg>
);

const CombinedStep3 = ({
  formData,
  handleSkillsChange,
  addSkills,
  removeSkills,
  handleSkillNameChange,
  handleSkillNameBlur,
  addSkillName,
  removeSkillName,
  addingSkillTo,
  handleNewSkillChange,
  handleNewSkillBlur,
  handleCertificationChange,
  addCertification,
  removeCertification,
  handleLanguageChange,
  addLanguage,
  removeLanguage,
  renderSaveDraftButton,
  validationErrors = {},
}) => {
  const { t } = useTranslation();

  return (
    <div className="space-y-8">
      {/* Section Header */}
      <div className="text-center mb-6">
        <div className="glass-soft inline-flex items-center justify-center w-16 h-16 rounded-[22px] text-gold mb-4">
          <LightbulbIcon />
        </div>
        <h2 className="text-[22px] sm:text-2xl font-semibold text-mist">{t('step3.title')}</h2>
        <p className="text-mist/70 mt-2 text-[15px] sm:text-base font-light">{t('step3.subtitle')}</p>
      </div>

      {/* Skills Section */}
      <div className={`glass-soft rounded-[24px] p-4 sm:p-6 ${validationErrors.skills ? 'ring-2 ring-red-400/50' : ''}`}>
        <h3 className="text-lg font-semibold text-mist mb-4 flex items-center gap-2.5">
          <span className="sr-mono w-7 h-7 shrink-0 rounded-full border border-primary/40 bg-primary/15 text-primary-soft flex items-center justify-center text-[13px] font-semibold">1</span>
          {t('skills.title')}
          <span className="text-xs text-red-300 font-normal">*</span>
        </h3>
        <SectionError error={validationErrors.skills} />
        <div className="space-y-4">
          {formData.skills.map((skill, index) => (
            <div key={index} className="rounded-[20px] border border-white/10 bg-white/[0.04] p-4">
              <div className="mb-3">
                <div className="flex items-center justify-between">
                  <input
                    type="text"
                    value={skill.category}
                    onChange={(e) => handleSkillsChange(index, "category", e.target.value)}
                    className={getInputClass("flex-1 min-w-0 min-h-[48px] rounded-xl border border-white/10 bg-white/[0.06] px-4 py-2.5 text-base text-mist placeholder:text-mist/40 font-medium transition-colors duration-300", validationErrors[`skill_category_${index}`])}
                    placeholder={t('skills.category_placeholder')}
                  />
                  {formData.skills.length > 1 && (
                    <button type="button" onClick={() => removeSkills(index)} className="shrink-0 text-red-300 hover:text-red-200 text-sm min-h-[44px] px-3 ms-2 rounded-xl hover:bg-red-500/10 active:bg-red-500/20 transition-all touch-manipulation">{t('actions.delete')}</button>
                  )}
                </div>
                <FieldError error={validationErrors[`skill_category_${index}`]} />
              </div>
              <div className="space-y-2">
                {(() => {
                  const validSkillNames = skill.skill_names.filter((name) => name && typeof name === "string" && name.trim() !== "");
                  return validSkillNames.map((skillName, nameIndex) => (
                    <div key={nameIndex}>
                      <div className="flex items-center gap-2">
                        <span className="text-primary">•</span>
                        <input
                          type="text"
                          value={skillName}
                          onChange={(e) => handleSkillNameChange(index, nameIndex, e.target.value)}
                          onBlur={() => handleSkillNameBlur(index, nameIndex)}
                          className={getInputClass("flex-1 min-w-0 min-h-[44px] rounded-xl border border-white/10 bg-white/[0.06] px-3 py-2 text-base text-mist placeholder:text-mist/40 transition-colors duration-300", validationErrors[`skill_name_${index}_${nameIndex}`])}
                          placeholder={t('skills.skill_placeholder')}
                        />
                        {validSkillNames.length > 1 && (
                          <button type="button" onClick={() => removeSkillName(index, nameIndex)} className="shrink-0 w-11 h-11 flex items-center justify-center text-red-300 hover:text-red-200 text-lg rounded-xl hover:bg-red-500/10 active:bg-red-500/20 transition-all touch-manipulation">×</button>
                        )}
                      </div>
                      <FieldError error={validationErrors[`skill_name_${index}_${nameIndex}`]} />
                    </div>
                  ));
                })()}
                {addingSkillTo === index ? (
                  <div>
                    <div className="flex items-center gap-2">
                      <span className="text-primary">•</span>
                      <input
                        type="text"
                        autoFocus
                        onChange={(e) => handleNewSkillChange(index, e.target.value)}
                        onBlur={(e) => handleNewSkillBlur(index, e.target.value)}
                        onKeyPress={(e) => { if (e.key === "Enter") handleNewSkillChange(index, e.target.value); }}
                        className={getInputClass("flex-1 min-w-0 min-h-[44px] rounded-xl border border-white/10 bg-white/[0.06] px-3 py-2 text-base text-mist placeholder:text-mist/40 transition-colors duration-300", validationErrors[`skill_name_${index}_new`])}
                        placeholder={t('skills.skill_placeholder')}
                      />
                    </div>
                    <FieldError error={validationErrors[`skill_name_${index}_new`]} />
                  </div>
                ) : (
                  <button type="button" onClick={() => addSkillName(index)} className="text-primary hover:text-mist text-sm font-medium min-h-[44px] px-3 rounded-xl hover:bg-primary/10 active:bg-primary/15 transition-all touch-manipulation">+ {t('skills.add_skill')}</button>
                )}
              </div>
            </div>
          ))}
          <button type="button" onClick={addSkills} className="sr-btn w-full min-h-[48px] py-3 text-primary hover:text-mist text-[15px] font-medium border border-dashed border-primary/40 rounded-2xl hover:bg-primary/10 active:bg-primary/20 touch-manipulation">
            + {t('skills.add_another_category')}
          </button>
        </div>
      </div>

      {/* Certifications Section */}
      <div className="glass-soft rounded-[24px] p-4 sm:p-6">
        <h3 className="text-lg font-semibold text-mist mb-4 flex items-center gap-2.5">
          <span className="sr-mono w-7 h-7 shrink-0 rounded-full border border-primary/40 bg-primary/15 text-primary-soft flex items-center justify-center text-[13px] font-semibold">2</span>
          {t('certifications.title')}
          <span className="text-xs text-mist/55 font-normal">{t('certifications.optional')}</span>
        </h3>
        <SectionError error={validationErrors.certifications} />
        <div className="space-y-4">
          {formData.certifications.map((cert, index) => (
            <div key={index} className="rounded-[20px] border border-white/10 bg-white/[0.04] p-4">
              <div className="flex items-center justify-between mb-3">
                <span className="text-sm font-medium text-mist/80">{t('certifications.certification_n', { n: index + 1 })}</span>
                {formData.certifications.length > 1 && (
                  <button type="button" onClick={() => removeCertification(index)} className="text-red-300 hover:text-red-200 text-sm min-h-[44px] px-3 rounded-xl hover:bg-red-500/10 active:bg-red-500/20 transition-all touch-manipulation">{t('actions.delete')}</button>
                )}
              </div>
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                <div>
                  <input
                    type="text"
                    value={cert.name}
                    onChange={(e) => handleCertificationChange(index, "name", e.target.value)}
                    className={getInputClass("w-full min-h-[48px] rounded-xl border border-white/10 bg-white/[0.06] px-4 py-3 text-base text-mist placeholder:text-mist/40 transition-colors duration-300", validationErrors[`cert_name_${index}`])}
                    placeholder={t('certifications.name_placeholder')}
                  />
                  <FieldError error={validationErrors[`cert_name_${index}`]} />
                </div>
                <div>
                  <input
                    type="text"
                    value={cert.organization}
                    onChange={(e) => handleCertificationChange(index, "organization", e.target.value)}
                    className={getInputClass("w-full min-h-[48px] rounded-xl border border-white/10 bg-white/[0.06] px-4 py-3 text-base text-mist placeholder:text-mist/40 transition-colors duration-300", validationErrors[`cert_organization_${index}`])}
                    placeholder={t('certifications.issuer_placeholder')}
                  />
                  <FieldError error={validationErrors[`cert_organization_${index}`]} />
                </div>
                <MobileDatePicker value={cert.date} onChange={(value) => handleCertificationChange(index, "date", value)} placeholder={t('certifications.date')} />
              </div>
            </div>
          ))}
          <button type="button" onClick={addCertification} className="sr-btn w-full min-h-[48px] py-3 text-primary hover:text-mist text-[15px] font-medium border border-dashed border-primary/40 rounded-2xl hover:bg-primary/10 active:bg-primary/20 touch-manipulation">
            + {t('certifications.add_another')}
          </button>
        </div>
      </div>

      {/* Languages Section */}
      <div className={`glass-soft rounded-[24px] p-4 sm:p-6 ${validationErrors.languages ? 'ring-2 ring-red-400/50' : ''}`}>
        <h3 className="text-lg font-semibold text-mist mb-4 flex items-center gap-2.5">
          <span className="sr-mono w-7 h-7 shrink-0 rounded-full border border-primary/40 bg-primary/15 text-primary-soft flex items-center justify-center text-[13px] font-semibold">3</span>
          {t('languages.title')}
          <span className="text-xs text-red-300 font-normal">*</span>
        </h3>
        <SectionError error={validationErrors.languages} />
        <div className="space-y-4">
          {formData.languages.map((lang, index) => (
            <div key={index} className="rounded-[20px] border border-white/10 bg-white/[0.04] p-4">
              <div className="flex items-center justify-between mb-3">
                <span className="text-sm font-medium text-mist/80">{t('languages.language_n', { n: index + 1 })}</span>
                {formData.languages.length > 1 && (
                  <button type="button" onClick={() => removeLanguage(index)} className="text-red-300 hover:text-red-200 text-sm min-h-[44px] px-3 rounded-xl hover:bg-red-500/10 active:bg-red-500/20 transition-all touch-manipulation">{t('actions.delete')}</button>
                )}
              </div>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <input
                    type="text"
                    value={lang.language}
                    onChange={(e) => handleLanguageChange(index, "language", e.target.value)}
                    className={getInputClass("w-full min-h-[48px] rounded-xl border border-white/10 bg-white/[0.06] px-4 py-3 text-base text-mist placeholder:text-mist/40 transition-colors duration-300", validationErrors[`language_name_${index}`])}
                    placeholder={t('languages.name_placeholder')}
                  />
                  <FieldError error={validationErrors[`language_name_${index}`]} />
                </div>
                <select
                  value={lang.proficiency}
                  onChange={(e) => handleLanguageChange(index, "proficiency", e.target.value)}
                  className="w-full min-h-[48px] rounded-xl border border-white/10 bg-white/[0.06] px-4 py-3 text-base text-mist transition-colors duration-300"
                >
                  <option value="">{t('languages.select_proficiency')}</option>
                  <option value="Native">{t('languages.native')}</option>
                  <option value="Fluent">{t('languages.fluent')}</option>
                  <option value="Advanced">{t('languages.advanced')}</option>
                  <option value="Intermediate">{t('languages.intermediate')}</option>
                  <option value="Beginner">{t('languages.beginner')}</option>
                </select>
              </div>
            </div>
          ))}
          <button type="button" onClick={addLanguage} className="sr-btn w-full min-h-[48px] py-3 text-primary hover:text-mist text-[15px] font-medium border border-dashed border-primary/40 rounded-2xl hover:bg-primary/10 active:bg-primary/20 touch-manipulation">
            + {t('languages.add_another')}
          </button>
        </div>
      </div>

      {renderSaveDraftButton(3)}
    </div>
  );
};

export default memo(CombinedStep3);
