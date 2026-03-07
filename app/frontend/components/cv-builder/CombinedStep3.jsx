import React, { memo } from "react";
import MobileDatePicker from "./MobileDatePicker";
import i18n from "../../lib/i18n";

// Simple translation function
const t = (key, options) => i18n.t(key, options);

// Error display component
const SectionError = ({ error }) => error ? (
  <div className="mb-4 p-3 border border-red-200 rounded-lg bg-red-50" data-error>
    <p className="text-sm text-red-600 flex items-center gap-2">
      <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
      </svg>
      {error}
    </p>
  </div>
) : null;

// Field-level error display
const FieldError = ({ error }) => error ? (
  <p className="mt-1 text-xs text-red-600">{error}</p>
) : null;

// Input with error styling helper
const getInputClass = (baseClass, hasError) => 
  hasError 
    ? baseClass.replace('border-[#E6E8F0]/70', 'border-red-400') + ' ring-1 ring-red-200'
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
  return (
    <div className="space-y-8">
      {/* Section Header */}
      <div className="text-center mb-6">
        <div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-[#7C6CF2]/10 text-[#7C6CF2] mb-4">
          <LightbulbIcon />
        </div>
        <h2 className="text-xl font-semibold text-gray-900 dark:text-white">{t('step3.title')}</h2>
        <p className="text-gray-600 dark:text-gray-300 mt-2">{t('step3.subtitle')}</p>
      </div>

      {/* Skills Section */}
      <div className={`p-4 sm:p-6 border ${validationErrors.skills ? 'border-red-300' : 'border-[#E6E8F0]/60 dark:border-gray-700'} rounded-xl bg-[#F8F7FF]/30 dark:bg-gray-800/50`}>
        <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-4 flex items-center gap-2">
          <span className="w-6 h-6 bg-[#7C6CF2] text-white rounded-full flex items-center justify-center text-sm">1</span>
          {t('skills.title')}
          <span className="text-xs text-red-500 font-normal">*</span>
        </h3>
        <SectionError error={validationErrors.skills} />
        <div className="space-y-4">
          {formData.skills.map((skill, index) => (
            <div key={index} className="p-4 border border-[#E6E8F0]/40 dark:border-gray-600 rounded-xl bg-white/50 dark:bg-gray-700/50">
              <div className="mb-3">
                <div className="flex items-center justify-between">
                  <input
                    type="text"
                    value={skill.category}
                    onChange={(e) => handleSkillsChange(index, "category", e.target.value)}
                    className={getInputClass("flex-1 rounded-xl border border-[#E6E8F0]/70 dark:border-gray-600 bg-white/70 dark:bg-gray-800 px-3 py-2 text-gray-900 dark:text-white placeholder:text-gray-400 dark:placeholder:text-gray-500 focus:outline-none focus:ring-2 focus:ring-[#7C6CF2]/40 text-sm font-medium", validationErrors[`skill_category_${index}`])}
                    placeholder={t('skills.category_placeholder')}
                  />
                  {formData.skills.length > 1 && (
                    <button type="button" onClick={() => removeSkills(index)} className="text-red-500 hover:text-red-700 active:text-red-800 text-xs px-2 py-1 rounded active:bg-red-50 mr-2 transition-all touch-manipulation">{t('actions.delete')}</button>
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
                        <span className="text-[#7C6CF2]">•</span>
                        <input
                          type="text"
                          value={skillName}
                          onChange={(e) => handleSkillNameChange(index, nameIndex, e.target.value)}
                          onBlur={() => handleSkillNameBlur(index, nameIndex)}
                          className={getInputClass("flex-1 rounded-xl border border-[#E6E8F0]/70 dark:border-gray-600 bg-white/70 dark:bg-gray-800 px-3 py-1.5 text-gray-900 dark:text-white placeholder:text-gray-400 dark:placeholder:text-gray-500 focus:outline-none focus:ring-2 focus:ring-[#7C6CF2]/40 text-sm", validationErrors[`skill_name_${index}_${nameIndex}`])}
                          placeholder={t('skills.skill_placeholder')}
                        />
                        {validSkillNames.length > 1 && (
                          <button type="button" onClick={() => removeSkillName(index, nameIndex)} className="text-red-500 hover:text-red-700 active:text-red-800 text-sm px-2 py-1 rounded active:bg-red-50 transition-all touch-manipulation">×</button>
                        )}
                      </div>
                      <FieldError error={validationErrors[`skill_name_${index}_${nameIndex}`]} />
                    </div>
                  ));
                })()}
                {addingSkillTo === index ? (
                  <div>
                    <div className="flex items-center gap-2">
                      <span className="text-[#7C6CF2]">•</span>
                      <input
                        type="text"
                        autoFocus
                        onChange={(e) => handleNewSkillChange(index, e.target.value)}
                        onBlur={(e) => handleNewSkillBlur(index, e.target.value)}
                        onKeyPress={(e) => { if (e.key === "Enter") handleNewSkillChange(index, e.target.value); }}
                        className={getInputClass("flex-1 rounded-xl border border-[#E6E8F0]/70 dark:border-gray-600 bg-white/70 dark:bg-gray-800 px-3 py-1.5 text-gray-900 dark:text-white placeholder:text-gray-400 dark:placeholder:text-gray-500 focus:outline-none focus:ring-2 focus:ring-[#7C6CF2]/40 text-sm", validationErrors[`skill_name_${index}_new`])}
                        placeholder={t('skills.skill_placeholder')}
                      />
                    </div>
                    <FieldError error={validationErrors[`skill_name_${index}_new`]} />
                  </div>
                ) : (
                  <button type="button" onClick={() => addSkillName(index)} className="text-[#7C6CF2] hover:text-[#6A5AE0] active:text-[#6A5AE0] text-sm font-medium py-2 px-3 rounded active:bg-[#7C6CF2]/10 transition-all touch-manipulation">+ {t('skills.add_skill')}</button>
                )}
              </div>
            </div>
          ))}
          <button type="button" onClick={addSkills} className="w-full py-3 text-[#7C6CF2] hover:text-[#6A5AE0] active:text-[#6A5AE0] text-sm font-medium border border-dashed border-[#7C6CF2]/30 rounded-xl hover:bg-[#7C6CF2]/10 active:bg-[#7C6CF2]/20 active:scale-[0.99] transition-all touch-manipulation">
            + {t('skills.add_another_category')}
          </button>
        </div>
      </div>

      {/* Certifications Section */}
      <div className="p-4 sm:p-6 border border-[#E6E8F0]/60 dark:border-gray-700 rounded-xl bg-[#F8F7FF]/30 dark:bg-gray-800/50">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-4 flex items-center gap-2">
          <span className="w-6 h-6 bg-[#7C6CF2] text-white rounded-full flex items-center justify-center text-sm">2</span>
          {t('certifications.title')}
          <span className="text-xs text-gray-500 dark:text-gray-400 font-normal">{t('certifications.optional')}</span>
        </h3>
        <SectionError error={validationErrors.certifications} />
        <div className="space-y-4">
          {formData.certifications.map((cert, index) => (
            <div key={index} className="p-4 border border-[#E6E8F0]/40 dark:border-gray-600 rounded-xl bg-white/50 dark:bg-gray-700/50">
              <div className="flex items-center justify-between mb-3">
                <span className="text-sm font-medium text-gray-700 dark:text-gray-200">{t('certifications.certification_n', { n: index + 1 })}</span>
                {formData.certifications.length > 1 && (
                  <button type="button" onClick={() => removeCertification(index)} className="text-red-500 hover:text-red-700 active:text-red-800 text-xs px-2 py-1 rounded active:bg-red-50 transition-all touch-manipulation">{t('actions.delete')}</button>
                )}
              </div>
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                <div>
                  <input
                    type="text"
                    value={cert.name}
                    onChange={(e) => handleCertificationChange(index, "name", e.target.value)}
                    className={getInputClass("w-full rounded-xl border border-[#E6E8F0]/70 dark:border-gray-600 bg-white/70 dark:bg-gray-800 px-3 py-2.5 text-gray-900 dark:text-white placeholder:text-gray-400 dark:placeholder:text-gray-500 focus:outline-none focus:ring-2 focus:ring-[#7C6CF2]/40 text-sm", validationErrors[`cert_name_${index}`])}
                    placeholder={t('certifications.name_placeholder')}
                  />
                  <FieldError error={validationErrors[`cert_name_${index}`]} />
                </div>
                <div>
                  <input
                    type="text"
                    value={cert.organization}
                    onChange={(e) => handleCertificationChange(index, "organization", e.target.value)}
                    className={getInputClass("w-full rounded-xl border border-[#E6E8F0]/70 dark:border-gray-600 bg-white/70 dark:bg-gray-800 px-3 py-2.5 text-gray-900 dark:text-white placeholder:text-gray-400 dark:placeholder:text-gray-500 focus:outline-none focus:ring-2 focus:ring-[#7C6CF2]/40 text-sm", validationErrors[`cert_organization_${index}`])}
                    placeholder={t('certifications.issuer_placeholder')}
                  />
                  <FieldError error={validationErrors[`cert_organization_${index}`]} />
                </div>
                <MobileDatePicker value={cert.date} onChange={(value) => handleCertificationChange(index, "date", value)} placeholder={t('certifications.date')} />
              </div>
            </div>
          ))}
          <button type="button" onClick={addCertification} className="w-full py-3 text-[#7C6CF2] hover:text-[#6A5AE0] active:text-[#6A5AE0] text-sm font-medium border border-dashed border-[#7C6CF2]/30 rounded-xl hover:bg-[#7C6CF2]/10 active:bg-[#7C6CF2]/20 active:scale-[0.99] transition-all touch-manipulation">
            + {t('certifications.add_another')}
          </button>
        </div>
      </div>

      {/* Languages Section */}
      <div className={`p-4 sm:p-6 border ${validationErrors.languages ? 'border-red-300' : 'border-[#E6E8F0]/60 dark:border-gray-700'} rounded-xl bg-[#F8F7FF]/30 dark:bg-gray-800/50`}>
        <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-4 flex items-center gap-2">
          <span className="w-6 h-6 bg-[#7C6CF2] text-white rounded-full flex items-center justify-center text-sm">3</span>
          {t('languages.title')}
          <span className="text-xs text-red-500 font-normal">*</span>
        </h3>
        <SectionError error={validationErrors.languages} />
        <div className="space-y-4">
          {formData.languages.map((lang, index) => (
            <div key={index} className="p-4 border border-[#E6E8F0]/40 dark:border-gray-600 rounded-xl bg-white/50 dark:bg-gray-700/50">
              <div className="flex items-center justify-between mb-3">
                <span className="text-sm font-medium text-gray-700 dark:text-gray-200">{t('languages.language_n', { n: index + 1 })}</span>
                {formData.languages.length > 1 && (
                  <button type="button" onClick={() => removeLanguage(index)} className="text-red-500 hover:text-red-700 active:text-red-800 text-xs px-2 py-1 rounded active:bg-red-50 transition-all touch-manipulation">{t('actions.delete')}</button>
                )}
              </div>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <input
                    type="text"
                    value={lang.language}
                    onChange={(e) => handleLanguageChange(index, "language", e.target.value)}
                    className={getInputClass("w-full rounded-xl border border-[#E6E8F0]/70 dark:border-gray-600 bg-white/70 dark:bg-gray-800 px-3 py-2.5 text-gray-900 dark:text-white placeholder:text-gray-400 dark:placeholder:text-gray-500 focus:outline-none focus:ring-2 focus:ring-[#7C6CF2]/40 text-sm", validationErrors[`language_name_${index}`])}
                    placeholder={t('languages.name_placeholder')}
                  />
                  <FieldError error={validationErrors[`language_name_${index}`]} />
                </div>
                <select
                  value={lang.proficiency}
                  onChange={(e) => handleLanguageChange(index, "proficiency", e.target.value)}
                  className="w-full rounded-xl border border-[#E6E8F0]/70 dark:border-gray-600 bg-white/70 dark:bg-gray-800 px-3 py-2.5 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-[#7C6CF2]/40 text-sm"
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
          <button type="button" onClick={addLanguage} className="w-full py-3 text-[#7C6CF2] hover:text-[#6A5AE0] active:text-[#6A5AE0] text-sm font-medium border border-dashed border-[#7C6CF2]/30 rounded-xl hover:bg-[#7C6CF2]/10 active:bg-[#7C6CF2]/20 active:scale-[0.99] transition-all touch-manipulation">
            + {t('languages.add_another')}
          </button>
        </div>
      </div>

      {renderSaveDraftButton(3)}
    </div>
  );
};

export default memo(CombinedStep3);
