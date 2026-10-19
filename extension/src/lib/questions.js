// PURE: turns field descriptors (read from the DOM by fill.js) into the
// question objects of the HTTP contract, and decides how an answer is applied.
(function (root) {
  "use strict";

  const lib = (root.SeeraLib = root.SeeraLib || {});

  const TYPES = ["text", "textarea", "select", "radio", "checkbox", "number", "date", "url", "email", "tel"];
  const MAX_LABEL = 300;
  const MAX_OPTIONS = 50;
  const MAX_TEXT = 5000;
  const PLACEHOLDER_OPTION = /^(-+|select( one| an option)?(\.\.\.|…)?|please select(\.\.\.|…)?|choose( one| an option)?(\.\.\.|…)?|اختر.*|--.*--)$/i;
  const REQUIRED_MARK = /[*✱]\s*$|\(required\)\s*$/i;

  function cleanLabel(raw) {
    return String(raw || "")
      .replace(/\s+/g, " ")
      .replace(/\s*[*✱]\s*$/, "")
      .replace(/\s*\(required\)\s*$/i, "")
      .trim()
      .slice(0, MAX_LABEL);
  }

  function questionType(desc) {
    const tag = String(desc.tag || "").toLowerCase();
    const type = String(desc.type || "").toLowerCase();
    if (tag === "textarea") return "textarea";
    if (tag === "select") return "select";
    if (TYPES.includes(type)) return type;
    return "text";
  }

  function cleanOptions(options) {
    const seen = new Set();
    const out = [];
    for (const raw of options || []) {
      const text = String(raw === null || raw === undefined ? "" : raw).replace(/\s+/g, " ").trim();
      if (!text || PLACEHOLDER_OPTION.test(text) || seen.has(text)) continue;
      seen.add(text);
      out.push(text.slice(0, MAX_LABEL));
      if (out.length >= MAX_OPTIONS) break;
    }
    return out;
  }

  // desc: {key, label, tag, type, options, required, ariaRequired}
  // key is the number fill.js stamped on the element as data-seera-q, so the
  // id is stable for the same element across calls.
  function toQuestion(desc) {
    const d = desc || {};
    const rawLabel = String(d.label || "").replace(/\s+/g, " ").trim();
    const type = questionType(d);
    const required =
      Boolean(d.required) ||
      d.ariaRequired === true ||
      String(d.ariaRequired).toLowerCase() === "true" ||
      REQUIRED_MARK.test(rawLabel);
    const options = ["select", "radio", "checkbox"].includes(type) ? cleanOptions(d.options) : [];
    return {
      id: "q" + String(d.key),
      label: cleanLabel(rawLabel) || String(d.name || "").slice(0, MAX_LABEL),
      type,
      options,
      required,
    };
  }

  function isBlank(value) {
    if (value === null || value === undefined) return true;
    if (Array.isArray(value)) return value.length === 0;
    return String(value).trim() === "";
  }

  // How to apply one answer to one question.
  // -> {kind: "skip"} | {kind: "text", value} | {kind: "choose", values: [...]}
  // Selects, radios and checkboxes only take option text that matches exactly.
  function planAnswer(question, value) {
    if (!question || isBlank(value)) return { kind: "skip" };
    const type = question.type;
    if (type === "select" || type === "radio") {
      const v = Array.isArray(value) ? value[0] : value;
      if (typeof v !== "string" || !question.options.includes(v)) return { kind: "skip" };
      return { kind: "choose", values: [v] };
    }
    if (type === "checkbox") {
      const list = (Array.isArray(value) ? value : [value]).filter(
        (v) => typeof v === "string" && question.options.includes(v),
      );
      if (list.length === 0) return { kind: "skip" };
      return { kind: "choose", values: Array.from(new Set(list)) };
    }
    const text = Array.isArray(value) ? value.join(", ") : String(value);
    if (type === "number") {
      const n = text.replace(/,/g, "").match(/-?\d+(\.\d+)?/);
      if (!n) return { kind: "skip" };
      return { kind: "text", value: n[0] };
    }
    return { kind: "text", value: text.slice(0, MAX_TEXT) };
  }

  // answers: [{id, value}] from the server. -> Map id -> value, only known ids.
  function indexAnswers(questions, answers) {
    const known = new Set((questions || []).map((q) => q.id));
    const out = new Map();
    for (const a of answers || []) {
      if (a && known.has(a.id) && !out.has(a.id)) out.set(a.id, a.value);
    }
    return out;
  }

  lib.questions = { toQuestion, planAnswer, indexAnswers, cleanLabel, cleanOptions, isBlank, TYPES };
})(globalThis);
