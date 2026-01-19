import React, { memo } from "react";
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
  <div className="mb-4 p-3 border border-red-200 rounded-lg bg-red-50" data-error>
    <p className="text-sm text-red-600 flex items-center gap-2">
      <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
      </svg>
      {error}
    </p>
  </div>
) : null;

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
  remainingTranslations = 5,
}) => {
  // Ensure remainingTranslations is always a valid number
  const safeRemainingTranslations = typeof remainingTranslations === 'number' ? remainingTranslations : 5;
  
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
        <div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-emerald-100 text-emerald-600 mb-4">
          <BriefcaseIcon />
        </div>
        <h2 className="text-xl font-semibold text-slate-900">التعليم والخبرات العملية</h2>
        <p className="text-slate-600 mt-2">أضف معلوماتك التعليمية وخبراتك العملية</p>
      </div>

      {/* Education Section */}
      <div className={`p-4 sm:p-6 border ${validationErrors.education ? 'border-red-300' : 'border-slate-200/60'} rounded-lg bg-slate-50/30`}>
        <h3 className="text-lg font-semibold text-slate-900 mb-4 flex items-center gap-2">
          <span className="w-6 h-6 bg-emerald-600 text-white rounded-full flex items-center justify-center text-sm">1</span>
          التعليم
          <span className="text-xs text-red-500 font-normal">*</span>
        </h3>
        <SectionError error={validationErrors.education} />
        <div className="space-y-4">
          {formData.education.map((edu, index) => (
            <div key={index} className="p-4 border border-slate-200/40 rounded-lg bg-white/50 overflow-hidden">
              <div className="flex items-center justify-between mb-3">
                <span className="text-sm font-medium text-slate-700">التعليم {index + 1}</span>
                {formData.education.length > 1 && (
                  <button type="button" onClick={() => removeEducation(index)} className="text-red-500 hover:text-red-700 active:text-red-800 text-xs px-2 py-1 rounded active:bg-red-50 transition-all touch-manipulation">حذف</button>
                )}
              </div>
              <div className="grid gap-3">
                <input
                  type="text"
                  value={edu.degree}
                  onChange={(e) => handleEducationChange(index, "degree", e.target.value)}
                  className="w-full rounded-lg border border-slate-300/70 bg-white/70 px-3 py-2.5 text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/40 text-sm"
                  placeholder="الدرجة العلمية (Bachelor of...)"
                />
                <input
                  type="text"
                  value={edu.institution}
                  onChange={(e) => handleEducationChange(index, "institution", e.target.value)}
                  className="w-full rounded-lg border border-slate-300/70 bg-white/70 px-3 py-2.5 text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/40 text-sm"
                  placeholder="المؤسسة التعليمية"
                />
                <div className="grid grid-cols-2 gap-3">
                  <MobileDatePicker value={edu.start_date} onChange={(value) => handleEducationChange(index, "start_date", value)} placeholder="البداية" />
                  <MobileDatePicker value={edu.end_date} onChange={(value) => handleEducationChange(index, "end_date", value)} disabled={edu.is_current} placeholder="النهاية" />
                </div>
                <label className="flex items-center gap-2 cursor-pointer">
                  <input type="checkbox" checked={edu.is_current} onChange={(e) => handleEducationChange(index, "is_current", e.target.checked)} className="w-4 h-4 text-emerald-600 rounded" />
                  <span className="text-xs text-slate-700">دراسة حالية</span>
                </label>
              </div>
            </div>
          ))}
          <button type="button" onClick={addEducation} className="w-full py-3 text-emerald-600 hover:text-emerald-700 active:text-emerald-800 text-sm font-medium border border-dashed border-emerald-300 rounded-lg hover:bg-emerald-50 active:bg-emerald-100 active:scale-[0.99] transition-all touch-manipulation">
            + إضافة تعليم آخر
          </button>
        </div>
      </div>

      {/* Work Experience Section */}
      <div className={`p-4 sm:p-6 border ${validationErrors.work_experience ? 'border-red-300' : 'border-slate-200/60'} rounded-lg bg-slate-50/30`}>
        <h3 className="text-lg font-semibold text-slate-900 mb-4 flex items-center gap-2">
          <span className="w-6 h-6 bg-emerald-600 text-white rounded-full flex items-center justify-center text-sm">2</span>
          الخبرات العملية
          <span className="text-xs text-red-500 font-normal">*</span>
        </h3>
        <SectionError error={validationErrors.work_experience} />
        <div className="space-y-4">
          {formData.work_experience.map((work, index) => (
            <div key={index} className="p-3 sm:p-4 border border-slate-200/40 rounded-lg bg-white/50">
              <div className="flex items-center justify-between mb-4">
                <span className="text-sm font-medium text-slate-700">الخبرة {index + 1}</span>
                {formData.work_experience.length > 1 && (
                  <button type="button" onClick={() => removeWorkExperience(index)} className="text-red-500 hover:text-red-700 active:text-red-800 text-xs px-2 py-1 rounded active:bg-red-50 transition-all touch-manipulation">حذف</button>
                )}
              </div>
              <div className="space-y-3">
                <input
                  type="text"
                  value={work.job_title}
                  onChange={(e) => handleWorkExperienceChange(index, "job_title", e.target.value)}
                  className="w-full rounded-lg border border-slate-300/70 bg-white px-3 py-3 text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/40 text-base"
                  placeholder="المسمى الوظيفي"
                  style={{ fontSize: "16px" }}
                />
                <input
                  type="text"
                  value={work.company}
                  onChange={(e) => handleWorkExperienceChange(index, "company", e.target.value)}
                  className="w-full rounded-lg border border-slate-300/70 bg-white px-3 py-3 text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/40 text-base"
                  placeholder="اسم الشركة"
                  style={{ fontSize: "16px" }}
                />
                <div className="flex gap-2">
                  <div className="flex-1">
                    <MobileDatePicker value={work.start_date} onChange={(value) => handleWorkExperienceChange(index, "start_date", value)} placeholder="البداية" />
                  </div>
                  <div className="flex-1">
                    <MobileDatePicker value={work.end_date} onChange={(value) => handleWorkExperienceChange(index, "end_date", value)} disabled={work.is_current} placeholder="النهاية" />
                  </div>
                </div>
                <label className="flex items-center gap-2 cursor-pointer py-1">
                  <input type="checkbox" checked={work.is_current} onChange={(e) => handleWorkExperienceChange(index, "is_current", e.target.checked)} className="w-5 h-5 text-emerald-600 rounded" />
                  <span className="text-sm text-slate-700">عمل حالي</span>
                </label>
                <div className="pt-2">
                  <label className="block text-sm font-medium text-slate-700 mb-2">المسؤوليات والإنجازات</label>
                  <div className="space-y-2">
                    {work.responsibilities.map((resp, respIndex) => (
                      <div key={respIndex} className="flex items-start gap-2">
                        <span className="text-emerald-600 mt-3 text-lg">•</span>
                        <textarea
                          value={resp}
                          onChange={(e) => handleResponsibilityChange(index, respIndex, e.target.value)}
                          rows={2}
                          className="flex-1 min-w-0 rounded-lg border border-slate-300/70 bg-white px-3 py-2.5 text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/40 resize-none"
                          placeholder="اكتب مسؤولية أو إنجاز..."
                          style={{ fontSize: "16px" }}
                        />
                        {work.responsibilities.length > 1 && (
                          <button type="button" onClick={() => removeResponsibility(index, respIndex)} className="text-red-500 hover:text-red-700 active:text-red-800 text-lg mt-2 px-2 py-1 rounded active:bg-red-50 transition-all touch-manipulation">×</button>
                        )}
                      </div>
                    ))}
                    <button type="button" onClick={() => addResponsibility(index)} className="text-emerald-600 hover:text-emerald-700 active:text-emerald-800 text-sm font-medium py-2 px-3 rounded active:bg-emerald-50 transition-all touch-manipulation">+ إضافة مسؤولية</button>
                  </div>
                  {/* Show original Arabic if translation was done */}
                  {work.responsibilities_arabic?.length > 0 && (
                    <div className="mt-3 p-3 bg-amber-50 border border-amber-200 rounded-lg">
                      <label className="block text-xs font-medium text-amber-700 mb-1">📝 النص الأصلي (العربي)</label>
                      <ul className="space-y-0.5">
                        {work.responsibilities_arabic.filter(r => r?.trim()).map((respAr, respIdx) => (
                          <li key={respIdx} className="text-xs text-amber-800 flex items-start gap-1">
                            <span className="text-amber-500 mt-0.5">•</span>
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
          <button type="button" onClick={addWorkExperience} className="w-full py-3 text-emerald-600 hover:text-emerald-700 active:text-emerald-800 text-sm font-medium border border-dashed border-emerald-300 rounded-lg hover:bg-emerald-50 active:bg-emerald-100 active:scale-[0.99] transition-all touch-manipulation">
            + إضافة خبرة عمل أخرى
          </button>

          {/* AI Translation Button for all job descriptions */}
          <div className={`mt-4 p-4 border rounded-lg ${jobTranslationSuccess || hasTranslatedResponsibilities ? 'border-green-200 bg-green-50/50' : 'border-blue-200 bg-blue-50/50'}`}>
            {/* Always show loading state when translating */}
            {isTranslatingJobs ? (
              <>
                <p className="text-sm text-blue-700 mb-3 text-center">
                  ⏳ جاري ترجمة المسؤوليات...
                </p>
                <button
                  type="button"
                  disabled={true}
                  className="w-full py-3 px-4 rounded-lg font-medium text-sm transition-all flex items-center justify-center gap-2 bg-blue-400 text-white cursor-not-allowed"
                >
                  <svg className="w-5 h-5 animate-spin" fill="none" viewBox="0 0 24 24">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                  </svg>
                  جاري الترجمة...
                </button>
              </>
            ) : jobTranslationSuccess || hasTranslatedResponsibilities ? (
              <>
                <p className="text-sm text-green-700 mb-3 text-center">
                  ✅ تم ترجمة المسؤوليات بنجاح! يمكنك رؤية الترجمة أعلاه في كل خبرة عمل.
                </p>
                <button
                  type="button"
                  onClick={onTranslateJobDescriptions}
                  disabled={!hasResponsibilities || safeRemainingTranslations <= 0}
                  className={`w-full py-3 px-4 rounded-lg font-medium text-sm transition-all flex items-center justify-center gap-2 ${
                    !hasResponsibilities || safeRemainingTranslations <= 0
                      ? "bg-green-300 text-white cursor-not-allowed"
                      : "bg-green-600 text-white hover:bg-green-700 active:bg-green-800"
                  }`}
                >
                  🔄 إعادة الترجمة ({safeRemainingTranslations} متبقي)
                </button>
                {safeRemainingTranslations <= 0 && (
                  <p className="text-xs text-amber-600 mt-2 text-center">⚠️ لقد استخدمت جميع الترجمات المتاحة</p>
                )}
              </>
            ) : (
              <>
                <p className="text-sm text-blue-700 mb-3 text-center">
                  💡 سيقوم النظام بترجمة جميع المسؤوليات والإنجازات إلى الإنجليزية
                </p>
                <button
                  type="button"
                  onClick={onTranslateJobDescriptions}
                  disabled={!hasResponsibilities || safeRemainingTranslations <= 0}
                  className={`w-full py-3 px-4 rounded-lg font-medium text-sm transition-all flex items-center justify-center gap-2 ${
                    !hasResponsibilities || safeRemainingTranslations <= 0
                      ? "bg-blue-300 text-white cursor-not-allowed"
                      : "bg-blue-600 text-white hover:bg-blue-700 active:bg-blue-800"
                  }`}
                >
                  🌐 ترجم جميع المسؤوليات إلى الإنجليزية ({safeRemainingTranslations} متبقي)
                </button>
                {!hasResponsibilities && (
                  <p className="text-xs text-slate-500 mt-2 text-center">أضف مسؤوليات أولاً للترجمة</p>
                )}
                {safeRemainingTranslations <= 0 && (
                  <p className="text-xs text-amber-600 mt-2 text-center">⚠️ لقد استخدمت جميع الترجمات المتاحة</p>
                )}
              </>
            )}
            {jobTranslationError && (
              <p className="text-sm text-red-600 mt-2 text-center">{jobTranslationError}</p>
            )}
          </div>
        </div>
      </div>

      {renderSaveDraftButton(2)}
    </div>
  );
};

export default memo(CombinedStep2);
