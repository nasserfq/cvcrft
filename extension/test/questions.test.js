import { test } from "node:test";
import assert from "node:assert/strict";
import "../src/lib/questions.js";

const { toQuestion, planAnswer, indexAnswers } = globalThis.SeeraLib.questions;

test("select options are extracted without placeholders or duplicates", () => {
  const q = toQuestion({
    key: 3,
    label: "Are you legally authorised to work in Saudi Arabia?",
    tag: "SELECT",
    options: ["Select...", " Yes ", "No", "No", "", "--"],
  });
  assert.deepEqual(q, {
    id: "q3",
    label: "Are you legally authorised to work in Saudi Arabia?",
    type: "select",
    options: ["Yes", "No"],
    required: false,
  });
});

test("required comes from required, aria-required or an asterisk", () => {
  assert.equal(toQuestion({ key: 1, label: "SQL years", tag: "INPUT", type: "text", required: true }).required, true);
  assert.equal(toQuestion({ key: 2, label: "SQL years", tag: "INPUT", type: "text", ariaRequired: "true" }).required, true);
  const starred = toQuestion({ key: 3, label: "SQL years *", tag: "INPUT", type: "text" });
  assert.equal(starred.required, true);
  assert.equal(starred.label, "SQL years");
  assert.equal(toQuestion({ key: 4, label: "Notes ✱", tag: "TEXTAREA" }).required, true);
  assert.equal(toQuestion({ key: 5, label: "Notes", tag: "TEXTAREA", ariaRequired: "false" }).required, false);
});

test("ids are stable and types are mapped", () => {
  const desc = { key: 7, label: "Website", tag: "INPUT", type: "url" };
  assert.equal(toQuestion(desc).id, toQuestion({ ...desc }).id);
  assert.equal(toQuestion(desc).id, "q7");
  assert.equal(toQuestion(desc).type, "url");
  assert.equal(toQuestion({ key: 8, label: "Bio", tag: "TEXTAREA" }).type, "textarea");
  assert.equal(toQuestion({ key: 9, label: "X", tag: "INPUT", type: "weird" }).type, "text");
  assert.deepEqual(toQuestion({ key: 10, label: "Pick", tag: "INPUT", type: "radio", options: ["A", "B"] }).options, ["A", "B"]);
  assert.deepEqual(toQuestion({ key: 11, label: "Free", tag: "INPUT", type: "text", options: ["A"] }).options, []);
});

test("labels and options are capped", () => {
  const q = toQuestion({ key: 1, label: "x".repeat(400), tag: "SELECT", options: Array.from({ length: 80 }, (_, i) => "o" + i) });
  assert.equal(q.label.length, 300);
  assert.equal(q.options.length, 50);
});

test("planAnswer only takes exact options for choices", () => {
  const select = { id: "q1", type: "select", options: ["Yes", "No"] };
  assert.deepEqual(planAnswer(select, "Yes"), { kind: "choose", values: ["Yes"] });
  assert.deepEqual(planAnswer(select, "yes"), { kind: "skip" });
  assert.deepEqual(planAnswer(select, null), { kind: "skip" });
  const boxes = { id: "q2", type: "checkbox", options: ["Arabic", "English", "French"] };
  assert.deepEqual(planAnswer(boxes, ["Arabic", "German", "English"]), { kind: "choose", values: ["Arabic", "English"] });
  assert.deepEqual(planAnswer(boxes, ["German"]), { kind: "skip" });
  assert.deepEqual(planAnswer(boxes, "French"), { kind: "choose", values: ["French"] });
});

test("planAnswer for text and numbers", () => {
  assert.deepEqual(planAnswer({ type: "text", options: [] }, "4"), { kind: "text", value: "4" });
  assert.deepEqual(planAnswer({ type: "text", options: [] }, "  "), { kind: "skip" });
  assert.deepEqual(planAnswer({ type: "number", options: [] }, "about 4 years"), { kind: "text", value: "4" });
  assert.deepEqual(planAnswer({ type: "number", options: [] }, "n/a"), { kind: "skip" });
  assert.equal(planAnswer({ type: "textarea", options: [] }, "y".repeat(6000)).value.length, 5000);
});

test("indexAnswers drops unknown ids and keeps the first value", () => {
  const index = indexAnswers(
    [{ id: "q1" }, { id: "q2" }],
    [{ id: "q1", value: "a" }, { id: "q9", value: "x" }, { id: "q1", value: "b" }, null],
  );
  assert.deepEqual([...index.entries()], [["q1", "a"]]);
});
