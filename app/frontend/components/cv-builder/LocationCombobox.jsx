import React, { useEffect, useId, useMemo, useRef, useState } from "react";
import { useTranslation } from "react-i18next";
import { filterOptions, findOption } from "./locationData";

// A text input with a searchable dropdown of suggestions. Users can type in
// Arabic or English; picking a suggestion stores its English value, which is
// what the CV prints. Free text is still accepted for places not in the list.
export default function LocationCombobox({ value, onChange, onPick, options, className, placeholder }) {
  const { i18n } = useTranslation();
  const isArabic = (i18n.language || "").startsWith("ar");
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState(null); // null: show everything, not filtered by the stored value
  const [active, setActive] = useState(0);
  const listId = useId();
  const listRef = useRef(null);

  const results = useMemo(() => filterOptions(options, query ?? ""), [options, query]);
  // Name the country next to a city only when the list mixes countries.
  const mixedCountries = useMemo(() => new Set(options.map((o) => o.country)).size > 1, [options]);

  useEffect(() => {
    setActive(0);
  }, [query, open]);

  useEffect(() => {
    if (!open || !listRef.current) return;
    listRef.current.querySelector(`[data-index="${active}"]`)?.scrollIntoView({ block: "nearest" });
  }, [active, open]);

  const pick = (option) => {
    onChange(option.value);
    onPick?.(option);
    setQuery(null);
    setOpen(false);
  };

  const handleBlur = () => {
    setOpen(false);
    setQuery(null);
    // Typed "الرياض" and left the field: store the English name.
    const match = value && findOption(options, value);
    if (match && match.value !== value) pick(match);
  };

  const handleKeyDown = (e) => {
    if (e.key === "ArrowDown") {
      e.preventDefault();
      if (!open) setOpen(true);
      else setActive((i) => Math.min(i + 1, results.length - 1));
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      setActive((i) => Math.max(i - 1, 0));
    } else if (e.key === "Enter" && open && results[active]) {
      e.preventDefault();
      pick(results[active]);
    } else if (e.key === "Escape" && open) {
      e.preventDefault();
      setOpen(false);
    }
  };

  const showList = open && results.length > 0;

  return (
    <div className="relative">
      <input
        type="text"
        role="combobox"
        aria-expanded={showList}
        aria-controls={listId}
        aria-autocomplete="list"
        aria-activedescendant={showList ? `${listId}-${active}` : undefined}
        autoComplete="off"
        value={value}
        onChange={(e) => {
          onChange(e.target.value);
          setQuery(e.target.value);
          setOpen(true);
        }}
        onFocus={() => setOpen(true)}
        onClick={() => setOpen(true)}
        onBlur={handleBlur}
        onKeyDown={handleKeyDown}
        className={`${className} pe-11`}
        placeholder={placeholder}
      />
      <button
        type="button"
        tabIndex={-1}
        aria-hidden="true"
        onMouseDown={(e) => {
          e.preventDefault();
          e.currentTarget.previousSibling.focus();
          setQuery(null);
          setOpen((o) => !o);
        }}
        className="absolute inset-y-0 end-0 flex items-center px-3 text-gray-400 dark:text-white/50"
      >
        <svg className={`w-5 h-5 transition-transform ${showList ? "rotate-180" : ""}`} fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" d="M6 9l6 6 6-6" />
        </svg>
      </button>
      {showList && (
        <ul
          id={listId}
          ref={listRef}
          role="listbox"
          className="absolute z-30 mt-2 w-full max-h-64 overflow-auto rounded-xl border border-borderLight dark:border-white/10 bg-white dark:bg-[#0f2219] p-1 shadow-xl"
        >
          {results.map((option, i) => {
            const primary = isArabic ? option.ar : option.value;
            const secondary = isArabic ? option.value : option.ar;
            const place = mixedCountries && (isArabic ? option.countryAr : option.country);
            return (
              <li
                key={option.code}
                id={`${listId}-${i}`}
                data-index={i}
                role="option"
                aria-selected={i === active}
                onMouseDown={(e) => {
                  e.preventDefault();
                  pick(option);
                }}
                onMouseEnter={() => setActive(i)}
                className={`flex items-baseline justify-between gap-3 rounded-lg px-3 py-2.5 cursor-pointer ${
                  i === active ? "bg-primary/15 text-gray-900 dark:text-white" : "text-gray-700 dark:text-white/85"
                }`}
              >
                <span>
                  {primary}
                  {place && <span className="text-xs text-gray-500 dark:text-white/45">{isArabic ? "، " : ", "}{place}</span>}
                </span>
                {secondary !== primary && <span className="text-xs text-gray-500 dark:text-white/45" dir="auto">{secondary}</span>}
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );
}
