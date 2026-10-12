import React, { useState, useRef, useCallback } from "react";
import { createPortal } from "react-dom";
import { useTranslation } from "react-i18next";

const CvImportModal = ({ isOpen, onClose, onImportComplete }) => {
  const { t } = useTranslation();
  const [isDragOver, setIsDragOver] = useState(false);
  const [file, setFile] = useState(null);
  const [isUploading, setIsUploading] = useState(false);
  const [isProcessing, setIsProcessing] = useState(false);
  const [error, setError] = useState("");
  const [uploadProgress, setUploadProgress] = useState(0);
  const fileInputRef = useRef(null);
  const pollingRef = useRef(null);

  const handleDragOver = useCallback((e) => {
    e.preventDefault();
    setIsDragOver(true);
  }, []);

  const handleDragLeave = useCallback((e) => {
    e.preventDefault();
    setIsDragOver(false);
  }, []);

  const validateAndSetFile = useCallback(
    (selectedFile) => {
      setError("");

      if (!selectedFile) return;

      if (selectedFile.type !== "application/pdf") {
        setError(t("import.pdf_only_error"));
        return;
      }

      if (selectedFile.size > 10 * 1024 * 1024) {
        setError(t("import.file_too_large"));
        return;
      }

      setFile(selectedFile);
    },
    [t]
  );

  const handleDrop = useCallback(
    (e) => {
      e.preventDefault();
      setIsDragOver(false);
      validateAndSetFile(e.dataTransfer.files[0]);
    },
    [validateAndSetFile]
  );

  const handleFileSelect = useCallback(
    (e) => {
      validateAndSetFile(e.target.files[0]);
    },
    [validateAndSetFile]
  );

  const pollStatus = async (importId, statusUrl) => {
    try {
      const response = await fetch(statusUrl);
      const data = await response.json();

      if (data.completed) {
        clearInterval(pollingRef.current);
        setIsProcessing(false);
        onImportComplete(data.parsed_data);
        onClose();
      } else if (data.failed) {
        clearInterval(pollingRef.current);
        setIsProcessing(false);
        setError(data.error_message || t("import.processing_failed"));
      }
    } catch (err) {
      console.error("Polling error:", err);
    }
  };

  const handleUpload = async () => {
    if (!file) return;

    setIsUploading(true);
    setError("");
    setUploadProgress(0);

    const formData = new FormData();
    formData.append("pdf_file", file);

    try {
      const csrfToken = document
        .querySelector('meta[name="csrf-token"]')
        ?.getAttribute("content");

      const response = await fetch("/cv-import", {
        method: "POST",
        headers: {
          "X-CSRF-Token": csrfToken,
        },
        body: formData,
      });

      const data = await response.json();

      if (!response.ok || !data.success) {
        setError(data.error || t("import.upload_failed"));
        setIsUploading(false);
        return;
      }

      setIsUploading(false);
      setIsProcessing(true);
      setUploadProgress(100);

      pollingRef.current = setInterval(() => {
        pollStatus(data.id, data.status_url);
      }, 2000);

      setTimeout(() => pollStatus(data.id, data.status_url), 500);
    } catch (err) {
      console.error("Upload error:", err);
      setError(t("import.connection_error"));
      setIsUploading(false);
    }
  };

  const handleClose = () => {
    if (pollingRef.current) {
      clearInterval(pollingRef.current);
    }
    setFile(null);
    setError("");
    setIsUploading(false);
    setIsProcessing(false);
    setUploadProgress(0);
    onClose();
  };

  if (!isOpen) return null;

  return createPortal(
    <div
      className="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm"
      onClick={(e) => {
        if (e.target === e.currentTarget && !isUploading && !isProcessing) {
          handleClose();
        }
      }}
    >
      <div
        className="bg-white dark:bg-[#27273A] rounded-2xl shadow-2xl w-full max-w-lg overflow-hidden"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-200 dark:border-white/10">
          <h2 className="text-lg font-semibold text-gray-900 dark:text-white">
            {t("import.title")}
          </h2>
          <button
            type="button"
            onClick={handleClose}
            disabled={isUploading || isProcessing}
            className="p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-white/10 transition-colors disabled:opacity-50"
            aria-label={t("actions.close")}
          >
            <svg className="w-5 h-5 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <div className="p-6">
          <div className="mb-6 p-4 rounded-xl bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800">
            <div className="flex gap-3">
              <svg className="w-5 h-5 text-blue-500 shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <div className="text-sm text-blue-700 dark:text-blue-300">
                <p className="font-medium mb-1">{t("import.note")}</p>
                <p>{t("import.note_text")}</p>
              </div>
            </div>
          </div>

          {error && (
            <div className="mb-6 p-4 rounded-xl bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800">
              <div className="flex gap-3">
                <svg className="w-5 h-5 text-red-500 shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                <div className="text-sm text-red-700 dark:text-red-300">{error}</div>
              </div>
            </div>
          )}

          {!isProcessing && (
            <div
              className={`relative border-2 border-dashed rounded-xl p-8 text-center transition-colors ${
                isDragOver
                  ? "border-primary bg-primary/5"
                  : file
                  ? "border-green-500 bg-green-50 dark:bg-green-900/10"
                  : "border-gray-300 dark:border-white/20 hover:border-primary hover:bg-primary/5"
              }`}
              onDragOver={handleDragOver}
              onDragLeave={handleDragLeave}
              onDrop={handleDrop}
            >
              <input
                ref={fileInputRef}
                type="file"
                accept=".pdf,application/pdf"
                onChange={handleFileSelect}
                className="hidden"
              />

              {file ? (
                <div className="space-y-3">
                  <div className="w-16 h-16 mx-auto rounded-full bg-green-100 dark:bg-green-900/30 flex items-center justify-center">
                    <svg className="w-8 h-8 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                  </div>
                  <div>
                    <p className="font-medium text-gray-900 dark:text-white">{file.name}</p>
                    <p className="text-sm text-gray-500 dark:text-gray-400">
                      {(file.size / (1024 * 1024)).toFixed(2)} MB
                    </p>
                  </div>
                  <button
                    type="button"
                    onClick={() => setFile(null)}
                    className="text-sm text-red-500 hover:text-red-600"
                  >
                    {t("import.remove_file")}
                  </button>
                </div>
              ) : (
                <div className="space-y-4">
                  <div className="w-16 h-16 mx-auto rounded-full bg-primary/10 flex items-center justify-center">
                    <svg className="w-8 h-8 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
                    </svg>
                  </div>
                  <div>
                    <p className="font-medium text-gray-900 dark:text-white mb-1">
                      {t("import.drag_drop_pdf")}
                    </p>
                    <p className="text-sm text-gray-500 dark:text-gray-400 mb-3">{t("import.or")}</p>
                    <button
                      type="button"
                      onClick={() => fileInputRef.current?.click()}
                      className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-primary text-white text-sm font-medium hover:bg-[#6A5AE0] transition-colors"
                    >
                      <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" />
                      </svg>
                      {t("import.select_file")}
                    </button>
                  </div>
                  <p className="text-xs text-gray-400 dark:text-gray-500">{t("import.pdf_only_max")}</p>
                </div>
              )}
            </div>
          )}

          {isProcessing && (
            <div className="text-center py-8">
              <div className="w-16 h-16 mx-auto mb-4 relative">
                <svg className="animate-spin w-16 h-16 text-primary" fill="none" viewBox="0 0 24 24">
                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
              </div>
              <p className="font-medium text-gray-900 dark:text-white mb-2">{t("import.analyzing")}</p>
              <p className="text-sm text-gray-500 dark:text-gray-400">{t("import.ai_extracting")}</p>
            </div>
          )}
        </div>

        {!isProcessing && (
          <div className="flex gap-3 px-6 py-4 border-t border-gray-200 dark:border-white/10 bg-gray-50 dark:bg-white/5">
            <button
              type="button"
              onClick={handleClose}
              disabled={isUploading}
              className="flex-1 px-4 py-3 rounded-xl border border-gray-300 dark:border-white/20 text-gray-700 dark:text-gray-300 font-medium hover:bg-gray-100 dark:hover:bg-white/10 transition-colors disabled:opacity-50"
            >
              {t("actions.cancel")}
            </button>
            <button
              type="button"
              onClick={handleUpload}
              disabled={!file || isUploading}
              className="flex-1 inline-flex items-center justify-center gap-2 px-4 py-3 rounded-xl bg-primary text-white font-medium hover:bg-[#6A5AE0] transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {isUploading ? (
                <>
                  <svg className="animate-spin w-4 h-4" fill="none" viewBox="0 0 24 24">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                  </svg>
                  {t("import.uploading")}
                </>
              ) : (
                <>
                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" />
                  </svg>
                  {t("import.import_button")}
                </>
              )}
            </button>
          </div>
        )}
      </div>
    </div>,
    document.body
  );
};

export default CvImportModal;
