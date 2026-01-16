import React, { memo } from "react";

// Document icon component
const DocumentIcon = () => (
  <svg className="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
    <path
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth={2}
      d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
    />
  </svg>
);

// Spinner component
const Spinner = () => (
  <svg
    className="animate-spin -ml-1 mr-3 h-5 w-5 text-white"
    xmlns="http://www.w3.org/2000/svg"
    fill="none"
    viewBox="0 0 24 24"
  >
    <circle
      className="opacity-25"
      cx="12"
      cy="12"
      r="10"
      stroke="currentColor"
      strokeWidth="4"
    />
    <path
      className="opacity-75"
      fill="currentColor"
      d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
    />
  </svg>
);

// Translate icon component
const TranslateIcon = () => (
  <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
    <path
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth={2}
      d="M3 5h12M9 3v2m1.048 9.5A18.022 18.022 0 016.412 9m6.088 9h7M11 21l5-10 5 10M12.751 5C11.783 10.77 8.07 15.61 3 18.129"
    />
  </svg>
);

const ProfessionalSummaryStep = ({
  formData,
  handleInputChange,
  translateProfessionalSummary,
  isTranslating,
  translationError,
  translationCount,
  maxTranslations,
  renderSaveDraftButton,
}) => {
  return (
    <div className="space-y-6">
      <div className="text-center mb-6">
        <div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-emerald-100 text-emerald-600 mb-4">
          <DocumentIcon />
        </div>
        <h2 className="text-xl font-semibold text-slate-900">الملخص المهني</h2>
        <p className="text-slate-600 mt-2">
          اكتب ملخصًا مهنيًا مقنعًا يصف خبراتك وأهدافك
        </p>
      </div>

      <div className="space-y-4">
        <div>
          <label className="block text-sm font-semibold text-slate-900 mb-2">
            الملخص المهني (بالعربية)
          </label>
          <textarea
            value={formData.professional_summary}
            onChange={(e) => handleInputChange("professional_summary", e.target.value)}
            rows={6}
            className="w-full rounded-lg border border-slate-300/70 bg-white/70 px-4 py-3 text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/40 focus:border-emerald-400 ring-1 ring-black/5 transition-all resize-none"
            placeholder="اكتب ملخصًا مهنيًا مقنعًا يصف خلفيتك المهنية وخبراتك ومهاراتك وأهدافك الوظيفية. يجب أن يكون 3-5 جمل تعطي صورة واضحة عنك كمحترف..."
          />
          <p className="mt-2 text-xs text-slate-500">
            اكتب 3-5 جمل تصف خلفيتك المهنية وخبراتك ومهاراتك وأهدافك الوظيفية
          </p>
          <p className="mt-2 text-xs text-blue-600 bg-blue-50 p-2 rounded border border-blue-200">
            💡 <strong>ملاحظة:</strong> سيقوم النظام بترجمة النص العربي إلى الإنجليزية{" "}
            <strong>وإنشاء</strong> ملخص مهني شامل ومحسن لسيرتك الذاتية
          </p>
        </div>

        {/* Translation Button */}
        <div className="text-center">
          <button
            type="button"
            onClick={translateProfessionalSummary}
            disabled={
              isTranslating ||
              !formData.professional_summary.trim() ||
              translationCount >= maxTranslations
            }
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
                ترجم وأنشئ ملخص مهني ({maxTranslations - translationCount} متبقي)
              </>
            )}
          </button>

          {/* Translation limit info */}
          <div className="mt-2 text-xs text-slate-500">
            الترجمات المستخدمة: {translationCount} من {maxTranslations}
          </div>
        </div>

        {/* Translation Error */}
        {translationError && (
          <div className="p-3 border border-red-200 rounded-lg bg-red-50">
            <p className="text-sm text-red-600 text-center">{translationError}</p>
          </div>
        )}

        {/* English Translation Result */}
        {formData.professional_summary_english && (
          <div className="space-y-3">
            <label className="block text-sm font-semibold text-slate-900 mb-2">
              الملخص المهني (بالإنجليزية)
            </label>
            <div className="p-4 border border-slate-200/60 rounded-lg bg-slate-50/50">
              <p className="text-slate-700 leading-relaxed text-left" dir="ltr">
                {formData.professional_summary_english}
              </p>
            </div>

            {/* Skills Extracted */}
            {formData.skills_extracted && formData.skills_extracted.length > 0 && (
              <div className="space-y-2">
                <h4 className="text-sm font-medium text-slate-900">
                  المهارات المستخرجة:
                </h4>
                <div className="flex flex-wrap gap-2">
                  {formData.skills_extracted.map((skill, index) => (
                    <span
                      key={index}
                      className="px-3 py-1 text-xs bg-blue-100 text-blue-800 rounded-full border border-blue-200"
                    >
                      {skill.name} ({skill.level})
                    </span>
                  ))}
                </div>
              </div>
            )}

            {/* Translation Notes */}
            {formData.translation_notes && (
              <div className="p-3 bg-amber-50 border border-amber-200 rounded-lg">
                <h4 className="text-sm font-medium text-amber-800 mb-1">
                  ملاحظات الترجمة:
                </h4>
                <p className="text-xs text-amber-700">{formData.translation_notes}</p>
              </div>
            )}

            <p className="text-xs text-slate-500 text-center">
              تم ترجمة النص العربي وإنشاء هذا الملخص المهني المحسن باستخدام الذكاء
              الاصطناعي
            </p>
          </div>
        )}

        <div className="p-4 border border-slate-200/60 rounded-lg bg-slate-50/50">
          <h3 className="text-sm font-medium text-slate-900 mb-2">
            نصائح لكتابة ملخص مهني قوي:
          </h3>
          <ul className="text-xs text-slate-600 space-y-1">
            <li>• ابدأ بوصف هويتك المهنية وعدد سنوات الخبرة</li>
            <li>• اذكر مجالات التخصص والمهارات الرئيسية</li>
            <li>• وضح الإنجازات المهمة والمسؤوليات</li>
            <li>• اختتم بأهدافك الوظيفية القصيرة والطويلة المدى</li>
          </ul>
        </div>
      </div>

      {renderSaveDraftButton(2)}
    </div>
  );
};

export default memo(ProfessionalSummaryStep);
