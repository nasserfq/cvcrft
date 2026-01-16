import React, { useState, useEffect } from "react";
import { createPortal } from "react-dom";

const MobileDatePicker = ({
  value,
  onChange,
  disabled = false,
  placeholder = "اختر التاريخ",
}) => {
  const [isOpen, setIsOpen] = useState(false);
  const [selectedYear, setSelectedYear] = useState(new Date().getFullYear());
  const [selectedMonth, setSelectedMonth] = useState(new Date().getMonth() + 1);

  useEffect(() => {
    if (value) {
      const [year, month] = value.split("-");
      if (year && month) {
        setSelectedYear(parseInt(year));
        setSelectedMonth(parseInt(month));
      }
    }
  }, [value]);

  const months = [
    { value: 1, label: "يناير" },
    { value: 2, label: "فبراير" },
    { value: 3, label: "مارس" },
    { value: 4, label: "أبريل" },
    { value: 5, label: "مايو" },
    { value: 6, label: "يونيو" },
    { value: 7, label: "يوليو" },
    { value: 8, label: "أغسطس" },
    { value: 9, label: "سبتمبر" },
    { value: 10, label: "أكتوبر" },
    { value: 11, label: "نوفمبر" },
    { value: 12, label: "ديسمبر" },
  ];

  const years = Array.from({ length: 91 }, (_, i) => 1960 + i);

  const handleConfirm = () => {
    const formattedValue = `${selectedYear}-${selectedMonth
      .toString()
      .padStart(2, "0")}`;
    onChange(formattedValue);
    setIsOpen(false);
  };

  const handleClear = () => {
    onChange("");
    setIsOpen(false);
  };

  const formatDisplayValue = (value) => {
    if (!value) return placeholder;
    const [year, month] = value.split("-");
    const monthObj = months.find((m) => m.value === parseInt(month));
    return monthObj ? `${monthObj.label} ${year}` : placeholder;
  };

  return (
    <div className="relative w-full">
      <button
        type="button"
        onClick={() => !disabled && setIsOpen(true)}
        disabled={disabled}
        className="w-full rounded-lg border border-slate-300/70 bg-white px-3 py-3 text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/40 focus:border-emerald-400 transition-all text-right disabled:opacity-50 disabled:cursor-not-allowed"
        style={{
          fontSize: "16px",
          minHeight: "48px",
        }}
      >
        <div className="flex items-center justify-between gap-1">
          <svg
            className="w-4 h-4 text-slate-400 flex-shrink-0"
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
          <span className={`flex-1 text-sm truncate ${value ? "text-slate-900" : "text-slate-400"}`}>
            {formatDisplayValue(value)}
          </span>
        </div>
      </button>

      {isOpen && createPortal(
        <div 
          className="fixed inset-0 z-[9999] flex items-center justify-center bg-black/25"
          style={{ 
            padding: 'max(1rem, env(safe-area-inset-top)) max(1rem, env(safe-area-inset-right)) max(1rem, env(safe-area-inset-bottom)) max(1rem, env(safe-area-inset-left))'
          }}
          onClick={(e) => { if (e.target === e.currentTarget) setIsOpen(false); }}
        >
          <div className="bg-white rounded-2xl w-full max-w-sm max-h-[85vh] overflow-hidden shadow-2xl">
            {/* Header */}
            <div className="bg-emerald-600 text-white px-6 py-4 flex items-center justify-between">
              <h3 className="text-lg font-semibold">اختر التاريخ</h3>
              <button
                onClick={() => setIsOpen(false)}
                className="text-white hover:text-emerald-200 transition-colors"
              >
                <svg
                  className="w-6 h-6"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M6 18L18 6M6 6l12 12"
                  />
                </svg>
              </button>
            </div>

            {/* Content */}
            <div className="p-4 sm:p-6 overflow-y-auto max-h-[65vh]" style={{ WebkitOverflowScrolling: 'touch' }}>
              {/* Year Selector */}
              <div className="mb-4 sm:mb-6">
                <label className="block text-sm font-semibold text-slate-900 mb-2 sm:mb-3">
                  السنة (اسحب لرؤية المزيد)
                </label>
                <div 
                  className="max-h-48 sm:max-h-72 overflow-y-auto border border-slate-200 rounded-lg p-2 scrollbar-thin scrollbar-thumb-slate-300 scrollbar-track-slate-100"
                  style={{ WebkitOverflowScrolling: 'touch' }}
                >
                  <div className="grid grid-cols-3 sm:grid-cols-4 gap-2">
                    {years.map((year) => (
                      <button
                        key={year}
                        onClick={() => setSelectedYear(year)}
                        className={`py-3 sm:py-3 px-2 rounded-lg text-base sm:text-sm font-medium transition-all active:scale-95 ${
                          selectedYear === year
                            ? "bg-emerald-600 text-white shadow-md"
                            : "bg-slate-100 text-slate-700 hover:bg-slate-200 active:bg-slate-300"
                        }`}
                        style={{ minHeight: '44px' }}
                      >
                        {year}
                      </button>
                    ))}
                  </div>
                </div>
              </div>

              {/* Month Selector */}
              <div className="mb-2 sm:mb-6">
                <label className="block text-sm font-semibold text-slate-900 mb-2 sm:mb-3">
                  الشهر
                </label>
                <div className="grid grid-cols-3 gap-2">
                  {months.map((month) => (
                    <button
                      key={month.value}
                      onClick={() => setSelectedMonth(month.value)}
                      className={`py-3 px-2 rounded-lg text-base sm:text-sm font-medium transition-all active:scale-95 ${
                        selectedMonth === month.value
                          ? "bg-emerald-600 text-white shadow-md"
                          : "bg-slate-100 text-slate-700 hover:bg-slate-200 active:bg-slate-300"
                      }`}
                      style={{ minHeight: '44px' }}
                    >
                      {month.label}
                    </button>
                  ))}
                </div>
              </div>
            </div>

            {/* Actions */}
            <div className="flex gap-3 p-6 bg-white border-t border-slate-200">
              <button
                onClick={handleClear}
                className="flex-1 py-3 px-4 bg-slate-100 text-slate-700 rounded-lg font-medium hover:bg-slate-200 active:bg-slate-300 active:scale-[0.98] transition-all touch-manipulation"
              >
                الغاء
              </button>
              <button
                onClick={handleConfirm}
                className="flex-1 py-3 px-4 bg-emerald-600 text-white rounded-lg font-medium hover:bg-emerald-700 active:bg-emerald-800 active:scale-[0.98] transition-all touch-manipulation"
              >
                تأكيد
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
