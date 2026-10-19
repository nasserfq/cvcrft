// PURE: maps a form field's label and attributes to a standard profile field.
// Plain script (no import/export): it is injected as a content script and also
// imported by the service worker and the node tests, which read
// globalThis.SeeraLib.labels.
(function (root) {
  "use strict";

  const lib = (root.SeeraLib = root.SeeraLib || {});

  // Arabic letter variants folded the same way the server does it.
  function normaliseArabic(text) {
    return text
      .replace(/[أإآ]/g, "ا") // أ إ آ -> ا
      .replace(/ة/g, "ه") // ة -> ه
      .replace(/ـ/g, "") // tatweel
      .replace(/[ً-ْ]/g, ""); // harakat / tanween
  }

  // Lowercase, split camelCase and snake/bracket names, drop punctuation and
  // required markers, collapse whitespace.
  function normalise(label) {
    if (label === null || label === undefined) return "";
    let text = String(label)
      .replace(/([a-z])([A-Z])/g, "$1 $2")
      .toLowerCase();
    text = normaliseArabic(text);
    text = text
      .replace(/\(required\)|\(optional\)/g, " ")
      .replace(/[*✱]/g, " ")
      .replace(/[_\-[\]().,:;/\\|?!"'`]+/g, " ")
      .replace(/\s+/g, " ")
      .trim();
    return text;
  }

  // Labels that mention a standard field but are about someone or something
  // else ("Emergency contact phone", "Referrer email").
  const NEGATIVE =
    /\b(emergency|reference|referee|referr?er|referral|referred|manager|supervisor|spouse|guardian|parent|recruiter|hear about|heard about|nationality|citizenship|visa|previous|former|company|employer)\b/;

  const AUTOCOMPLETE = {
    "given-name": "first_name",
    "family-name": "last_name",
    name: "full_name",
    email: "email",
    tel: "phone",
    "tel-national": "phone",
    "address-level2": "city",
    country: "country",
    "country-name": "country",
  };

  // Order matters: more specific fields first.
  const RULES = [
    ["cover_letter", /\b(cover ?letter|motivation letter|covering letter)\b|خطاب التقديم|رساله تغطيه|خطاب تغطيه/],
    ["resume", /\b(resume|résumé|cv|curriculum vitae)\b|السيره الذاتيه/],
    ["linkedin", /linked ?in|لينكد/],
    ["email", /\be ?mail\b|البريد الالكتروني|البريد/],
    ["phone", /\b(phone|mobile|telephone|tel|cell|cellphone|phone number)\b|جوال|هاتف|رقم الهاتف|رقم الجوال/],
    ["first_name", /\b(first name|firstname|given name|forename|fname)\b|الاسم الاول/],
    ["last_name", /\b(last name|lastname|surname|family name|lname)\b|اسم العائله|الاسم الاخير|اسم العائلة/],
    ["full_name", /^(full )?name$|\b(full name|fullname|your name|legal name|candidate name)\b|^الاسم( الكامل)?$|الاسم الكامل/],
    ["city", /\b(city|town)\b|المدينه/],
    ["country", /\b(country|country of residence)\b|الدوله|البلد/],
    ["location", /\b(location|current location|where are you based|address)\b|الموقع|العنوان/],
  ];

  function matchText(text) {
    if (!text) return null;
    for (const [field, pattern] of RULES) {
      if (pattern.test(text)) return field;
    }
    return null;
  }

  // label: visible label text. attrs: {name, id, autocomplete, ariaLabel,
  // placeholder, type}. Returns a field name or null.
  function matchStandardField(label, attrs) {
    const a = attrs || {};
    const labelText = normalise([label, a.ariaLabel].filter(Boolean).join(" "));
    const attrText = normalise([a.name, a.id].filter(Boolean).join(" "));

    if (NEGATIVE.test(labelText) || NEGATIVE.test(attrText)) return null;

    const auto = String(a.autocomplete || "").toLowerCase().trim().split(/\s+/).pop();
    if (auto && AUTOCOMPLETE[auto]) return AUTOCOMPLETE[auto];

    const fromLabel = matchText(labelText);
    if (fromLabel) return fromLabel;

    if (!labelText) {
      const fromPlaceholder = matchText(normalise(a.placeholder));
      if (fromPlaceholder) return fromPlaceholder;
    }

    const fromAttrs = matchText(attrText);
    if (fromAttrs) return fromAttrs;

    const type = String(a.type || "").toLowerCase();
    if (type === "email") return "email";
    if (type === "tel") return "phone";
    return null;
  }

  lib.labels = { normalise, normaliseArabic, matchStandardField };
})(globalThis);
