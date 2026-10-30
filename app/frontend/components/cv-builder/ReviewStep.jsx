import React, { memo, useCallback, useEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import { useTranslation } from "react-i18next";

// Static page-1 WebP previews live in public/ats_previews (bin/rails ats_previews:generate).
// Cards load the small thumbnail (1x/2x); the full image loads only in the lightbox.
const atsThumbSrc = (template) => template.thumb_url || `/ats_previews/${template.key}-thumb.webp`;
const atsThumb2xSrc = (template) => template.thumb_2x_url || `/ats_previews/${template.key}-thumb@2x.webp`;
const atsFullSrc = (template) => template.full_url || `/ats_previews/${template.key}.webp`;

const MagnifierIcon = ({ className }) => (
  <svg
    className={className}
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth="2"
    strokeLinecap="round"
    strokeLinejoin="round"
    aria-hidden="true"
    focusable="false"
  >
    <circle cx="11" cy="11" r="7" />
    <path d="M20 20l-3.5-3.5" />
    <path d="M11 8v6M8 11h6" />
  </svg>
);

const AtsTemplateLightbox = ({ template, onClose, onUse, t }) => {
  const closeRef = useRef(null);
  const panelRef = useRef(null);
  const onCloseRef = useRef(onClose);
  const [imageFailed, setImageFailed] = useState(false);
  onCloseRef.current = onClose;

  useEffect(() => {
    const trigger = document.activeElement;
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    closeRef.current?.focus();

    const handleKeyDown = (event) => {
      if (event.key === "Escape") {
        event.preventDefault();
        onCloseRef.current();
        return;
      }
      if (event.key !== "Tab" || !panelRef.current) return;
      const focusable = panelRef.current.querySelectorAll("button:not([disabled])");
      if (focusable.length === 0) return;
      const first = focusable[0];
      const last = focusable[focusable.length - 1];
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    };
    document.addEventListener("keydown", handleKeyDown);

    return () => {
      document.removeEventListener("keydown", handleKeyDown);
      document.body.style.overflow = previousOverflow;
      if (trigger && typeof trigger.focus === "function") trigger.focus();
    };
  }, []);

  const titleId = `ats-preview-title-${template.key}`;

  // Portal to <body> so a transformed or backdrop-filtered ancestor cannot trap the fixed overlay.
  return createPortal(
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm p-3 sm:p-6"
      onClick={(event) => {
        if (event.target === event.currentTarget) onClose();
      }}
    >
      <div
        ref={panelRef}
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        className="glass rounded-[28px] p-3 sm:p-5 w-full max-w-xl max-h-full flex flex-col text-mist"
      >
        <div className="mb-3 min-w-0">
          <h2 id={titleId} className="text-base sm:text-lg font-semibold leading-snug text-mist">
            {template.name}
          </h2>
          {template.description && (
            <p className="text-xs sm:text-sm text-white/60 mt-0.5 line-clamp-2">{template.description}</p>
          )}
        </div>
        <div className="flex-1 min-h-0 overflow-auto overscroll-contain rounded-xl border border-white/10 bg-white/5 flex items-center justify-center">
          {imageFailed ? (
            <p className="p-6 text-sm text-white/70 text-center">{template.description || template.name}</p>
          ) : (
            <img
              src={atsFullSrc(template)}
              alt={template.name}
              decoding="async"
              className="block max-h-[calc(100dvh-11rem)] sm:max-h-[85dvh] w-auto max-w-full bg-white keep-light"
              onError={() => setImageFailed(true)}
            />
          )}
        </div>
        <div className="flex flex-wrap items-center justify-end gap-2 mt-3">
          <button
            ref={closeRef}
            type="button"
            onClick={onClose}
            className="glass-soft sr-btn min-h-[44px] px-4 rounded-xl text-sm font-medium text-white hover:bg-white/10 touch-manipulation"
          >
            {t("templates.close")}
          </button>
          <button
            type="button"
            onClick={onUse}
            className="sr-btn sr-primary min-h-[44px] px-4 rounded-xl text-sm font-semibold touch-manipulation"
          >
            {t("templates.use_template")}
          </button>
        </div>
      </div>
    </div>,
    document.body
  );
};

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
  const [previewTemplate, setPreviewTemplate] = useState(null);
  const [failedPreviews, setFailedPreviews] = useState({});
  const markPreviewFailed = useCallback(
    (key) => setFailedPreviews((prev) => (prev[key] ? prev : { ...prev, [key]: true })),
    []
  );
  const closePreview = useCallback(() => setPreviewTemplate(null), []);

  return (
    <div className="space-y-4 sm:space-y-6 -mx-1 sm:mx-0">
      <div className="text-center mb-4 sm:mb-6 px-1">
        <h2 className="text-[22px] sm:text-2xl font-semibold text-mist">
          {t("review.title")}
        </h2>
        <p className="text-[15px] sm:text-base font-light text-mist/70 mt-2">
          {t("review.subtitle")}
        </p>
      </div>

      <div className="glass-soft w-full max-w-4xl mx-auto p-3 sm:p-5 rounded-[24px]">
        <label className="block text-sm font-medium text-mist/80 mb-3">
          {t("templates.ats_picker_label")}
        </label>
        <div
          className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-2 sm:gap-3 max-h-[70dvh] sm:max-h-none overflow-y-auto sm:overflow-visible overscroll-contain p-0.5"
          role="group"
          aria-label={t("templates.ats_picker_label")}
        >
          {templateOptions.map((template) => {
            const isSelected = selectedTemplate === template.key;
            const hasImage = !failedPreviews[template.key];
            return (
              <div key={template.key} className="relative">
                <button
                  type="button"
                  aria-pressed={isSelected}
                  onClick={() => onTemplateChange(template.key)}
                  className={`flex flex-col w-full h-full text-start p-2 sm:p-2.5 rounded-xl border transition-all touch-manipulation min-h-[44px] ${
                    isSelected
                      ? "border-primary bg-primary/20 ring-2 ring-primary/25"
                      : "border-white/10 bg-white/[0.04] hover:bg-white/[0.07] hover:border-primary/40 active:scale-[0.99]"
                  }`}
                >
                  {hasImage && (
                    <span className="block w-full aspect-[1/1.294] rounded-lg overflow-hidden border border-white/10 bg-white keep-light mb-2">
                      <img
                        src={atsThumbSrc(template)}
                        srcSet={`${atsThumbSrc(template)} 1x, ${atsThumb2xSrc(template)} 2x`}
                        width="320"
                        height="414"
                        alt={template.name}
                        loading="lazy"
                        decoding="async"
                        className="block w-full h-full object-cover object-top"
                        onError={() => markPreviewFailed(template.key)}
                      />
                    </span>
                  )}
                  <span className="block text-sm font-medium text-white leading-snug px-0.5">
                    {template.name}
                  </span>
                  <span className="block text-xs text-mist/55 mt-1 line-clamp-2 leading-relaxed px-0.5">
                    {template.description}
                  </span>
                </button>
                {hasImage && (
                  <button
                    type="button"
                    onClick={() => setPreviewTemplate(template)}
                    aria-label={`${t("templates.preview_template")}: ${template.name}`}
                    title={t("templates.preview_template")}
                    className="absolute top-2 end-2 h-11 w-11 inline-flex items-center justify-center rounded-full touch-manipulation group focus-visible:outline-none"
                  >
                    <span className="inline-flex h-8 w-8 items-center justify-center rounded-full border border-white/25 bg-[#07120D]/70 backdrop-blur-md text-white transition-transform group-hover:scale-110 group-focus-visible:ring-2 group-focus-visible:ring-primary">
                      <MagnifierIcon className="h-4 w-4" />
                    </span>
                  </button>
                )}
              </div>
            );
          })}
        </div>
      </div>

      <div className="glass-soft w-full max-w-4xl mx-auto rounded-[24px] overflow-hidden">
        {resumeId && pdfPreviewUrl && (
          <div className="flex items-center justify-between gap-2 px-3 py-2 border-b border-white/10 bg-white/5">
            <span className="text-xs sm:text-sm font-medium text-mist/80 truncate">
              {t("preview.title")}
            </span>
            <a
              href={pdfPreviewUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="shrink-0 inline-flex items-center justify-center min-h-[44px] px-3 py-2 text-xs sm:text-sm font-medium text-primary hover:text-mist touch-manipulation"
            >
              {t("preview.open_full")}
            </a>
          </div>
        )}

        {isPdfPreviewLoading && (
          <div className="p-4 text-sm text-mist/55 text-center">{t("preview.loading")}</div>
        )}
        {pdfPreviewError && (
          <div className="p-4 text-sm text-red-300 text-center break-words px-3">{pdfPreviewError}</div>
        )}
        {!resumeId && !pdfPreviewError && (
          <div className="p-4 text-sm text-mist/55 text-center px-3">
            {t("preview.resume_required_for_live")}
          </div>
        )}

        {resumeId && pdfPreviewUrl && (
          <div className="relative w-full overflow-hidden bg-black/20">
            {isPdfPreviewLoading && (
              <div className="absolute inset-0 z-10 flex items-center justify-center bg-darkBase/70 backdrop-blur-sm">
                <span className="text-sm text-mist/55">{t("preview.loading")}</span>
              </div>
            )}
            <iframe
              key={pdfPreviewUrl}
              src={pdfPreviewUrl}
              title={t("preview.title")}
              className="w-full max-w-full block"
              style={{
                border: 0,
                height: "clamp(320px, 60dvh, 900px)",
                minHeight: "320px",
              }}
              onLoad={onPdfPreviewLoaded}
              onError={onPdfPreviewError}
            />
          </div>
        )}
      </div>

      <div className="pt-2">{renderSaveDraftButton(4)}</div>

      {previewTemplate && (
        <AtsTemplateLightbox
          template={previewTemplate}
          t={t}
          onClose={closePreview}
          onUse={() => {
            onTemplateChange(previewTemplate.key);
            setPreviewTemplate(null);
          }}
        />
      )}
    </div>
  );
};

export default memo(ReviewStep);
