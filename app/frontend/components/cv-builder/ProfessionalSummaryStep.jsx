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
    className="animate-spin -ms-1 me-3 h-5 w-5 text-white"
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
        <div className="glass-soft inline-flex items-center justify-center w-16 h-16 rounded-[22px] text-gold mb-4">
          <DocumentIcon />
        </div>
        <h2 className="text-[22px] sm:text-2xl font-semibold text-mist">الملخص المهني</h2>
        <p className="text-mist/70 mt-2 text-[15px] sm:text-base font-light">
          اكتب ملخصًا مهنيًا مقنعًا يصف خبراتك وأهدافك
        </p>
      </div>

      <div className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-mist/90 mb-2">
            الملخص المهني (بالعربية)
          </label>
          <textarea
            value={formData.professional_summary}
            onChange={(e) => handleInputChange("professional_summary", e.target.value)}
            rows={6}
            className="w-full rounded-xl border border-white/10 bg-white/[0.06] px-4 py-3 text-base text-mist placeholder:text-mist/40 transition-colors duration-300 resize-none"
            placeholder="اكتب ملخصًا مهنيًا مقنعًا يصف خلفيتك المهنية وخبراتك ومهاراتك وأهدافك الوظيفية. يجب أن يكون 3-5 جمل تعطي صورة واضحة عنك كمحترف..."
          />
          <p className="mt-2 text-xs text-mist/55">
            اكتب 3-5 جمل تصف خلفيتك المهنية وخبراتك ومهاراتك وأهدافك الوظيفية
          </p>
          <p className="mt-2 text-xs text-primary bg-primary/10 p-2 rounded-xl border border-primary/20">
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
            className="sr-btn inline-flex items-center gap-2 min-h-[48px] rounded-2xl bg-action text-darkBase px-6 py-3 text-[15px] font-semibold hover:bg-actionHover shadow-glow-gold disabled:opacity-50 disabled:cursor-not-allowed"
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
          <div className="mt-2 text-xs text-mist/55">
            الترجمات المستخدمة: {translationCount} من {maxTranslations}
          </div>
        </div>

        {/* Translation Error */}
        {translationError && (
          <div role="alert" className="p-3 border border-red-400/30 rounded-xl bg-red-500/10">
            <p className="text-sm text-red-300 text-center">{translationError}</p>
          </div>
        )}

        {/* English Translation Result */}
        {formData.professional_summary_english && (
          <div className="space-y-3">
            <label className="block text-sm font-medium text-mist/90 mb-2">
              الملخص المهني (بالإنجليزية)
            </label>
            <div className="glass-soft rounded-[20px] p-4">
              <p className="text-mist/80 leading-relaxed text-left" dir="ltr">
                {formData.professional_summary_english}
              </p>
            </div>

            {/* Skills Extracted */}
            {formData.skills_extracted && formData.skills_extracted.length > 0 && (
              <div className="space-y-2">
                <h4 className="text-sm font-medium text-mist">
                  المهارات المستخرجة:
                </h4>
                <div className="flex flex-wrap gap-2">
                  {formData.skills_extracted.map((skill, index) => (
                    <span
                      key={index}
                      className="px-3 py-1 text-xs bg-primary/15 text-primary-soft rounded-full border border-primary/30"
                    >
                      {skill.name} ({skill.level})
                    </span>
                  ))}
                </div>
              </div>
            )}

            {/* Translation Notes */}
            {formData.translation_notes && (
              <div className="p-3 bg-gold/10 border border-gold/30 rounded-xl">
                <h4 className="text-sm font-medium text-gold mb-1">
                  ملاحظات الترجمة:
                </h4>
                <p className="text-xs text-gold">{formData.translation_notes}</p>
              </div>
            )}

            <p className="text-xs text-mist/55 text-center">
              تم ترجمة النص العربي وإنشاء هذا الملخص المهني المحسن باستخدام الذكاء
              الاصطناعي
            </p>
          </div>
        )}

        <div className="glass-soft rounded-[20px] p-4">
          <h3 className="text-sm font-medium text-mist mb-2">
            نصائح لكتابة ملخص مهني قوي:
          </h3>
          <ul className="text-xs text-mist/80 space-y-1">
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
