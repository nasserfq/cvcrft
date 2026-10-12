import React, { memo } from "react";
import { useTranslation } from "react-i18next";

const ReviewStep = ({
  renderSaveDraftButton,
  selectedTemplate,
  onTemplateChange,
  templateOptions,
  resumeId,
  pdfPreviewUrl,
  isPdfPreviewLoading,
  pdfPreviewError,
  onPdfPreviewLoaded,
  onPdfPreviewError,
}) => {
  const { t } = useTranslation();

  return (
    <div className="space-y-4 sm:space-y-6 -mx-1 sm:mx-0">
      <div className="text-center mb-4 sm:mb-6 px-1">
        <h2 className="text-lg sm:text-xl font-semibold text-gray-900 dark:text-white">
          {t("review.title")}
        </h2>
        <p className="text-sm sm:text-base text-gray-600 dark:text-gray-400 mt-2">
          {t("review.subtitle")}
        </p>
      </div>

      <div className="w-full max-w-4xl mx-auto p-3 sm:p-4 bg-white/70 dark:bg-white/5 border border-gray-200 dark:border-white/10 rounded-xl">
        <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-3">
          {t("templates.ats_picker_label")}
        </label>
        <div
          className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-2 sm:gap-3 max-h-[min(50vh,28rem)] sm:max-h-none overflow-y-auto overscroll-contain pr-0.5 sm:pr-0 sm:overflow-visible"
          role="listbox"
          aria-label={t("templates.ats_picker_label")}
        >
          {templateOptions.map((template) => {
            const isSelected = selectedTemplate === template.key;
            return (
              <button
                key={template.key}
                type="button"
                role="option"
                aria-selected={isSelected}
                onClick={() => onTemplateChange(template.key)}
                className={`text-start p-3 sm:p-3.5 rounded-xl border transition-all touch-manipulation min-h-[44px] ${
                  isSelected
                    ? "border-primary bg-primary/10 dark:bg-primary/20 ring-2 ring-primary/25"
                    : "border-gray-200 dark:border-white/10 bg-white dark:bg-darkBase hover:border-primary/40 active:scale-[0.99]"
                }`}
              >
                <span className="block text-sm font-medium text-gray-900 dark:text-white leading-snug">
                  {template.name}
                </span>
                <span className="block text-xs text-gray-500 dark:text-gray-400 mt-1 line-clamp-2 leading-relaxed">
                  {template.description}
                </span>
              </button>
            );
          })}
        </div>
      </div>

      <div className="w-full max-w-4xl mx-auto bg-white dark:bg-darkBase border border-gray-200 dark:border-white/10 rounded-xl shadow-sm overflow-hidden">
        {resumeId && pdfPreviewUrl && (
          <div className="flex items-center justify-between gap-2 px-3 py-2 border-b border-gray-100 dark:border-white/10 bg-gray-50/80 dark:bg-white/5">
            <span className="text-xs sm:text-sm font-medium text-gray-700 dark:text-gray-300 truncate">
              {t("preview.title")}
            </span>
            <a
              href={pdfPreviewUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="shrink-0 inline-flex items-center justify-center min-h-[44px] px-3 py-2 text-xs sm:text-sm font-medium text-primary hover:text-primaryHover touch-manipulation"
            >
              {t("preview.open_full")}
            </a>
          </div>
        )}

        {isPdfPreviewLoading && (
          <div className="p-4 text-sm text-gray-600 dark:text-gray-400 text-center">{t("preview.loading")}</div>
        )}
        {pdfPreviewError && (
          <div className="p-4 text-sm text-red-600 text-center break-words px-3">{pdfPreviewError}</div>
        )}
        {!resumeId && !pdfPreviewError && (
          <div className="p-4 text-sm text-gray-600 dark:text-gray-400 text-center px-3">
            {t("preview.resume_required_for_live")}
          </div>
        )}

        {resumeId && pdfPreviewUrl && (
          <div className="relative w-full overflow-hidden bg-gray-100 dark:bg-darkBase">
            {isPdfPreviewLoading && (
              <div className="absolute inset-0 z-10 flex items-center justify-center bg-white/80 dark:bg-darkBase/80">
                <span className="text-sm text-gray-600 dark:text-gray-400">{t("preview.loading")}</span>
              </div>
            )}
            <iframe
              key={pdfPreviewUrl}
              src={pdfPreviewUrl}
              title={t("preview.title")}
              className="w-full max-w-full block"
              style={{
                border: 0,
                height: "clamp(320px, 60vh, 900px)",
                minHeight: "320px",
              }}
              onLoad={onPdfPreviewLoaded}
              onError={onPdfPreviewError}
            />
          </div>
        )}
      </div>

      <div className="pt-2">{renderSaveDraftButton(4)}</div>
    </div>
  );
};

export default memo(ReviewStep);
