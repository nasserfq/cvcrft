import React, { memo } from "react";
import MobileDatePicker from "./MobileDatePicker";

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
    ? baseClass.replace('border-slate-300/70', 'border-red-400') + ' ring-1 ring-red-200'
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
        <div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-emerald-100 text-emerald-600 mb-4">
          <LightbulbIcon />
        </div>
        <h2 className="text-xl font-semibold text-slate-900">المهارات والشهادات واللغات</h2>
        <p className="text-slate-600 mt-2">أضف مهاراتك وشهاداتك واللغات التي تتحدثها</p>
      </div>

      {/* Skills Section */}
      <div className={`p-4 sm:p-6 border ${validationErrors.skills ? 'border-red-300' : 'border-slate-200/60'} rounded-lg bg-slate-50/30`}>
        <h3 className="text-lg font-semibold text-slate-900 mb-4 flex items-center gap-2">
          <span className="w-6 h-6 bg-emerald-600 text-white rounded-full flex items-center justify-center text-sm">1</span>
          المهارات
          <span className="text-xs text-red-500 font-normal">*</span>
        </h3>
        <SectionError error={validationErrors.skills} />
        <div className="space-y-4">
          {formData.skills.map((skill, index) => (
            <div key={index} className="p-4 border border-slate-200/40 rounded-lg bg-white/50">
              <div className="mb-3">
                <div className="flex items-center justify-between">
                  <input
                    type="text"
                    value={skill.category}
                    onChange={(e) => handleSkillsChange(index, "category", e.target.value)}
                    className={getInputClass("flex-1 rounded-lg border border-slate-300/70 bg-white/70 px-3 py-2 text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/40 text-sm font-medium", validationErrors[`skill_category_${index}`])}
                    placeholder="فئة المهارات (مثال: Technical Skills)"
                  />
                  {formData.skills.length > 1 && (
                    <button type="button" onClick={() => removeSkills(index)} className="text-red-500 hover:text-red-700 active:text-red-800 text-xs px-2 py-1 rounded active:bg-red-50 mr-2 transition-all touch-manipulation">حذف</button>
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
                        <span className="text-emerald-600">•</span>
                        <input
                          type="text"
                          value={skillName}
                          onChange={(e) => handleSkillNameChange(index, nameIndex, e.target.value)}
                          onBlur={() => handleSkillNameBlur(index, nameIndex)}
                          className={getInputClass("flex-1 rounded-lg border border-slate-300/70 bg-white/70 px-3 py-1.5 text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/40 text-sm", validationErrors[`skill_name_${index}_${nameIndex}`])}
                          placeholder="اسم المهارة"
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
                      <span className="text-emerald-600">•</span>
                      <input
                        type="text"
                        autoFocus
                        onChange={(e) => handleNewSkillChange(index, e.target.value)}
                        onBlur={(e) => handleNewSkillBlur(index, e.target.value)}
                        onKeyPress={(e) => { if (e.key === "Enter") handleNewSkillChange(index, e.target.value); }}
                        className={getInputClass("flex-1 rounded-lg border border-slate-300/70 bg-white/70 px-3 py-1.5 text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/40 text-sm", validationErrors[`skill_name_${index}_new`])}
                        placeholder="اسم المهارة"
                      />
                    </div>
                    <FieldError error={validationErrors[`skill_name_${index}_new`]} />
                  </div>
                ) : (
                  <button type="button" onClick={() => addSkillName(index)} className="text-emerald-600 hover:text-emerald-700 active:text-emerald-800 text-sm font-medium py-2 px-3 rounded active:bg-emerald-50 transition-all touch-manipulation">+ إضافة مهارة</button>
                )}
              </div>
            </div>
          ))}
          <button type="button" onClick={addSkills} className="w-full py-3 text-emerald-600 hover:text-emerald-700 active:text-emerald-800 text-sm font-medium border border-dashed border-emerald-300 rounded-lg hover:bg-emerald-50 active:bg-emerald-100 active:scale-[0.99] transition-all touch-manipulation">
            + إضافة فئة مهارات أخرى
          </button>
        </div>
      </div>

      {/* Certifications Section */}
      <div className="p-4 sm:p-6 border border-slate-200/60 rounded-lg bg-slate-50/30">
        <h3 className="text-lg font-semibold text-slate-900 mb-4 flex items-center gap-2">
          <span className="w-6 h-6 bg-emerald-600 text-white rounded-full flex items-center justify-center text-sm">2</span>
          الشهادات
          <span className="text-xs text-slate-500 font-normal">(اختياري)</span>
        </h3>
        <SectionError error={validationErrors.certifications} />
        <div className="space-y-4">
          {formData.certifications.map((cert, index) => (
            <div key={index} className="p-4 border border-slate-200/40 rounded-lg bg-white/50">
              <div className="flex items-center justify-between mb-3">
                <span className="text-sm font-medium text-slate-700">الشهادة {index + 1}</span>
                {formData.certifications.length > 1 && (
                  <button type="button" onClick={() => removeCertification(index)} className="text-red-500 hover:text-red-700 active:text-red-800 text-xs px-2 py-1 rounded active:bg-red-50 transition-all touch-manipulation">حذف</button>
                )}
              </div>
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                <div>
                  <input
                    type="text"
                    value={cert.name}
                    onChange={(e) => handleCertificationChange(index, "name", e.target.value)}
                    className={getInputClass("w-full rounded-lg border border-slate-300/70 bg-white/70 px-3 py-2.5 text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/40 text-sm", validationErrors[`cert_name_${index}`])}
                    placeholder="اسم الشهادة (PMP®)"
                  />
                  <FieldError error={validationErrors[`cert_name_${index}`]} />
                </div>
                <div>
                  <input
                    type="text"
                    value={cert.organization}
                    onChange={(e) => handleCertificationChange(index, "organization", e.target.value)}
                    className={getInputClass("w-full rounded-lg border border-slate-300/70 bg-white/70 px-3 py-2.5 text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/40 text-sm", validationErrors[`cert_organization_${index}`])}
                    placeholder="المؤسسة المانحة"
                  />
                  <FieldError error={validationErrors[`cert_organization_${index}`]} />
                </div>
                <MobileDatePicker value={cert.date} onChange={(value) => handleCertificationChange(index, "date", value)} placeholder="تاريخ الحصول" />
              </div>
            </div>
          ))}
          <button type="button" onClick={addCertification} className="w-full py-3 text-emerald-600 hover:text-emerald-700 active:text-emerald-800 text-sm font-medium border border-dashed border-emerald-300 rounded-lg hover:bg-emerald-50 active:bg-emerald-100 active:scale-[0.99] transition-all touch-manipulation">
            + إضافة شهادة أخرى
          </button>
        </div>
      </div>

      {/* Languages Section */}
      <div className={`p-4 sm:p-6 border ${validationErrors.languages ? 'border-red-300' : 'border-slate-200/60'} rounded-lg bg-slate-50/30`}>
        <h3 className="text-lg font-semibold text-slate-900 mb-4 flex items-center gap-2">
          <span className="w-6 h-6 bg-emerald-600 text-white rounded-full flex items-center justify-center text-sm">3</span>
          اللغات
          <span className="text-xs text-red-500 font-normal">*</span>
        </h3>
        <SectionError error={validationErrors.languages} />
        <div className="space-y-4">
          {formData.languages.map((lang, index) => (
            <div key={index} className="p-4 border border-slate-200/40 rounded-lg bg-white/50">
              <div className="flex items-center justify-between mb-3">
                <span className="text-sm font-medium text-slate-700">اللغة {index + 1}</span>
                {formData.languages.length > 1 && (
                  <button type="button" onClick={() => removeLanguage(index)} className="text-red-500 hover:text-red-700 active:text-red-800 text-xs px-2 py-1 rounded active:bg-red-50 transition-all touch-manipulation">حذف</button>
                )}
              </div>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <input
                    type="text"
                    value={lang.language}
                    onChange={(e) => handleLanguageChange(index, "language", e.target.value)}
                    className={getInputClass("w-full rounded-lg border border-slate-300/70 bg-white/70 px-3 py-2.5 text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/40 text-sm", validationErrors[`language_name_${index}`])}
                    placeholder="اللغة (Arabic, English)"
                  />
                  <FieldError error={validationErrors[`language_name_${index}`]} />
                </div>
                <select
                  value={lang.proficiency}
                  onChange={(e) => handleLanguageChange(index, "proficiency", e.target.value)}
                  className="w-full rounded-lg border border-slate-300/70 bg-white/70 px-3 py-2.5 text-slate-900 focus:outline-none focus:ring-2 focus:ring-emerald-500/40 text-sm"
                >
                  <option value="">اختر مستوى الإتقان</option>
                  <option value="Native">أمية (Native)</option>
                  <option value="Fluent">إتقان كامل (Fluent)</option>
                  <option value="Advanced">متقدم (Advanced)</option>
                  <option value="Intermediate">متوسط (Intermediate)</option>
                  <option value="Beginner">مبتدئ (Beginner)</option>
                </select>
              </div>
            </div>
          ))}
          <button type="button" onClick={addLanguage} className="w-full py-3 text-emerald-600 hover:text-emerald-700 active:text-emerald-800 text-sm font-medium border border-dashed border-emerald-300 rounded-lg hover:bg-emerald-50 active:bg-emerald-100 active:scale-[0.99] transition-all touch-manipulation">
            + إضافة لغة أخرى
          </button>
        </div>
      </div>

      {renderSaveDraftButton(3)}
    </div>
  );
};

export default memo(CombinedStep3);
