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
        className="w-full rounded-xl border border-white/10 bg-white/[0.06] px-3 py-3 text-mist transition-colors duration-300 hover:bg-white/[0.08] text-start disabled:opacity-50 disabled:cursor-not-allowed"
        style={{
          fontSize: "16px",
          minHeight: "48px",
        }}
      >
        <div className="flex items-center justify-between gap-1">
          <svg
            className="w-4 h-4 text-mist/55 flex-shrink-0"
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
            className={`flex-1 text-base truncate ${value ? "text-mist" : "text-mist/40"}`}
          >
            {formatDisplayValue(value)}
          </span>
        </div>
      </button>

      {isOpen &&
        createPortal(
          <div
            className="fixed inset-0 z-[9999] flex items-center justify-center bg-black/60 backdrop-blur-sm"
            style={{
              padding:
                "max(1rem, env(safe-area-inset-top)) max(1rem, env(safe-area-inset-right)) max(1rem, env(safe-area-inset-bottom)) max(1rem, env(safe-area-inset-left))",
            }}
            onClick={(e) => {
              if (e.target === e.currentTarget) setIsOpen(false);
            }}
          >
            <div role="dialog" aria-modal="true" className="glass sr-up rounded-[28px] w-full max-w-sm max-h-[85dvh] overflow-hidden text-mist" style={{ animationDuration: ".5s" }}>
              <div className="px-5 sm:px-6 py-4 flex items-center justify-between gap-3 border-b border-white/10">
                <h3 className="m-0 flex items-center gap-2.5 text-lg font-semibold"><span className="sr-dot w-2 h-2 rounded-full bg-primary"></span>{t("dates.select_title")}</h3>
                <button
                  type="button"
                  onClick={() => setIsOpen(false)}
                  className="glass-soft shrink-0 w-11 h-11 inline-flex items-center justify-center rounded-xl text-mist/80 hover:text-mist transition-colors"
                  aria-label={t("actions.close")}
                >
                  <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>

              <div
                className="p-4 sm:p-6 overflow-y-auto max-h-[65dvh]"
                style={{ WebkitOverflowScrolling: "touch" }}
              >
                <div className="mb-4 sm:mb-6">
                  <label className="block text-sm font-medium text-mist/90 mb-2 sm:mb-3">
                    {t("dates.year_label")}
                  </label>
                  <div
                    className="max-h-48 sm:max-h-72 overflow-y-auto border border-white/10 bg-white/[0.03] rounded-2xl p-2"
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
                              ? "sr-primary shadow-glow"
                              : "bg-white/[0.06] text-mist/80 hover:bg-white/10 hover:text-mist"
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
                  <label className="block text-sm font-medium text-mist/90 mb-2 sm:mb-3">
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
                            ? "sr-primary shadow-glow"
                            : "bg-white/[0.06] text-mist/80 hover:bg-white/10 hover:text-mist"
                        }`}
                        style={{ minHeight: "44px" }}
                      >
                        {month.label}
                      </button>
                    ))}
                  </div>
                </div>
              </div>

              <div className="flex gap-3 p-4 sm:p-6 border-t border-white/10" style={{ paddingBottom: "max(1rem, env(safe-area-inset-bottom))" }}>
                <button
                  type="button"
                  onClick={handleClear}
                  className="sr-btn glass-soft flex-1 min-h-[48px] py-3 px-4 text-mist rounded-2xl font-medium touch-manipulation"
                >
                  {t("actions.cancel")}
                </button>
                <button
                  type="button"
                  onClick={handleConfirm}
                  className="sr-btn sr-primary flex-1 min-h-[48px] py-3 px-4 rounded-2xl font-semibold touch-manipulation shadow-glow"
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
