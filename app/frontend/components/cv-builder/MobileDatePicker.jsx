import React, { useState, useEffect, useMemo } from "react";
import { createPortal } from "react-dom";
import { useTranslation } from "react-i18next";

const MobileDatePicker = ({
  value,
  onChange,
  disabled = false,
  placeholder,
}) => {
  const { t, i18n } = useTranslation();
  const resolvedPlaceholder = placeholder || t("experience.start_date");
  const [isOpen, setIsOpen] = useState(false);
  const [selectedYear, setSelectedYear] = useState(new Date().getFullYear());
  const [selectedMonth, setSelectedMonth] = useState(new Date().getMonth() + 1);

  const months = useMemo(
    () =>
      Array.from({ length: 12 }, (_, index) => ({
        value: index + 1,
        label: t(`dates.months.${index + 1}`),
      })),
    [t, i18n.language]
  );

  useEffect(() => {
    if (value) {
      const [year, month] = value.split("-");
      if (year && month) {
        setSelectedYear(parseInt(year, 10));
        setSelectedMonth(parseInt(month, 10));
      }
    }
  }, [value]);

  const years = Array.from({ length: 91 }, (_, i) => 1960 + i);

  const handleConfirm = () => {
    const formattedValue = `${selectedYear}-${selectedMonth.toString().padStart(2, "0")}`;
    onChange(formattedValue);
    setIsOpen(false);
  };

  const handleClear = () => {
    onChange("");
    setIsOpen(false);
  };

  const formatDisplayValue = (dateValue) => {
    if (!dateValue) return resolvedPlaceholder;
    const [year, month] = dateValue.split("-");
    const monthObj = months.find((m) => m.value === parseInt(month, 10));
    return monthObj ? `${monthObj.label} ${year}` : resolvedPlaceholder;
  };

  return (
    <div className="relative w-full">
      <button
        type="button"
        onClick={() => !disabled && setIsOpen(true)}
        disabled={disabled}
        className="w-full rounded-xl border border-borderLight dark:border-white/10 bg-white dark:bg-darkCard px-3 py-3 text-gray-900 dark:text-white placeholder:text-gray-400 dark:placeholder:text-gray-500 focus:outline-none focus:ring-2 focus:ring-primary/40 focus:border-primary transition-all text-right disabled:opacity-50 disabled:cursor-not-allowed"
        style={{
          fontSize: "16px",
          minHeight: "48px",
        }}
      >
        <div className="flex items-center justify-between gap-1">
          <svg
            className="w-4 h-4 text-gray-400 dark:text-gray-500 flex-shrink-0"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
            />
          </svg>
          <span
            className={`flex-1 text-sm truncate ${value ? "text-gray-900 dark:text-white" : "text-gray-400 dark:text-gray-500"}`}
          >
            {formatDisplayValue(value)}
          </span>
        </div>
      </button>

      {isOpen &&
        createPortal(
          <div
            className="fixed inset-0 z-[9999] flex items-center justify-center bg-black/25"
            style={{
              padding:
                "max(1rem, env(safe-area-inset-top)) max(1rem, env(safe-area-inset-right)) max(1rem, env(safe-area-inset-bottom)) max(1rem, env(safe-area-inset-left))",
            }}
            onClick={(e) => {
              if (e.target === e.currentTarget) setIsOpen(false);
            }}
          >
            <div className="bg-white dark:bg-gray-800 rounded-2xl w-full max-w-sm max-h-[85vh] overflow-hidden shadow-2xl">
              <div className="bg-primary text-white px-6 py-4 flex items-center justify-between">
                <h3 className="text-lg font-semibold">{t("dates.select_title")}</h3>
                <button
                  type="button"
                  onClick={() => setIsOpen(false)}
                  className="text-white hover:text-white/70 transition-colors"
                  aria-label={t("actions.close")}
                >
                  <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>

              <div
                className="p-4 sm:p-6 overflow-y-auto max-h-[65vh]"
                style={{ WebkitOverflowScrolling: "touch" }}
              >
                <div className="mb-4 sm:mb-6">
                  <label className="block text-sm font-semibold text-gray-900 dark:text-white mb-2 sm:mb-3">
                    {t("dates.year_label")}
                  </label>
                  <div
                    className="max-h-48 sm:max-h-72 overflow-y-auto border border-borderLight dark:border-gray-600 rounded-xl p-2 scrollbar-thin scrollbar-thumb-gray-300 scrollbar-track-gray-100"
                    style={{ WebkitOverflowScrolling: "touch" }}
                  >
                    <div className="grid grid-cols-3 sm:grid-cols-4 gap-2">
                      {years.map((year) => (
                        <button
                          key={year}
                          type="button"
                          onClick={() => setSelectedYear(year)}
                          className={`py-3 sm:py-3 px-2 rounded-xl text-base sm:text-sm font-medium transition-all active:scale-95 ${
                            selectedYear === year
                              ? "bg-primary text-white shadow-md"
                              : "bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-200 hover:bg-gray-200 dark:hover:bg-gray-600 active:bg-gray-300"
                          }`}
                          style={{ minHeight: "44px" }}
                        >
                          {year}
                        </button>
                      ))}
                    </div>
                  </div>
                </div>

                <div className="mb-2 sm:mb-6">
                  <label className="block text-sm font-semibold text-gray-900 dark:text-white mb-2 sm:mb-3">
                    {t("dates.month_label")}
                  </label>
                  <div className="grid grid-cols-3 gap-2">
                    {months.map((month) => (
                      <button
                        key={month.value}
                        type="button"
                        onClick={() => setSelectedMonth(month.value)}
                        className={`py-3 px-2 rounded-xl text-base sm:text-sm font-medium transition-all active:scale-95 ${
                          selectedMonth === month.value
                            ? "bg-primary text-white shadow-md"
                            : "bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-200 hover:bg-gray-200 dark:hover:bg-gray-600 active:bg-gray-300"
                        }`}
                        style={{ minHeight: "44px" }}
                      >
                        {month.label}
                      </button>
                    ))}
                  </div>
                </div>
              </div>

              <div className="flex gap-3 p-6 bg-white dark:bg-gray-800 border-t border-borderLight dark:border-gray-600">
                <button
                  type="button"
                  onClick={handleClear}
                  className="flex-1 py-3 px-4 bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-200 rounded-xl font-medium hover:bg-gray-200 dark:hover:bg-gray-600 active:bg-gray-300 active:scale-[0.98] transition-all touch-manipulation"
                >
                  {t("actions.cancel")}
                </button>
                <button
                  type="button"
                  onClick={handleConfirm}
                  className="flex-1 py-3 px-4 bg-primary text-white rounded-xl font-medium hover:bg-primaryHover active:scale-[0.98] transition-all touch-manipulation shadow-[0_0_20px_-5px_rgba(124,108,242,0.4)]"
                >
                  {t("actions.confirm")}
                </button>
              </div>
            </div>
          </div>,
          document.body
        )}
    </div>
  );
};

export default React.memo(MobileDatePicker);
