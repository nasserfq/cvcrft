import { test } from "node:test";
import assert from "node:assert/strict";
import "../src/lib/labels.js";

const { matchStandardField, normalise } = globalThis.SeeraLib.labels;

test("normalise strips markers, punctuation and Arabic variants", () => {
  assert.equal(normalise("First Name*"), "first name");
  assert.equal(normalise("E-mail address:"), "e mail address");
  assert.equal(normalise("job_application[firstName]"), "job application first name");
  assert.equal(normalise("الاسم الأول"), "الاسم الاول");
  assert.equal(normalise(null), "");
});

test("maps the common labels", () => {
  const cases = {
    "First Name*": "first_name",
    "الاسم الأول": "first_name",
    "Last Name": "last_name",
    Surname: "last_name",
    "Full name": "full_name",
    Name: "full_name",
    "E-mail address": "email",
    "Email *": "email",
    "البريد الإلكتروني": "email",
    Mobile: "phone",
    "Phone number": "phone",
    "رقم الجوال": "phone",
    "LinkedIn Profile": "linkedin",
    "Resume/CV": "resume",
    "السيرة الذاتية": "resume",
    "Cover Letter": "cover_letter",
    City: "city",
    Country: "country",
    "Current location": "location",
  };
  for (const [label, field] of Object.entries(cases)) {
    assert.equal(matchStandardField(label, {}), field, label);
  }
});

test("does not map fields about other people or other things", () => {
  assert.equal(matchStandardField("Emergency contact phone", { type: "tel" }), null);
  assert.equal(matchStandardField("Reference email", { type: "email" }), null);
  assert.equal(matchStandardField("How did you hear about us?", {}), null);
  assert.equal(matchStandardField("Years of experience with SQL", {}), null);
  assert.equal(matchStandardField("Nationality / country of citizenship", {}), null);
});

test("falls back to autocomplete, name/id, placeholder and type", () => {
  assert.equal(matchStandardField("", { autocomplete: "given-name" }), "first_name");
  assert.equal(matchStandardField("", { autocomplete: "section-x family-name" }), "last_name");
  assert.equal(matchStandardField("", { name: "job_application[first_name]" }), "first_name");
  assert.equal(matchStandardField("", { id: "last_name" }), "last_name");
  assert.equal(matchStandardField("", { name: "name" }), "full_name");
  assert.equal(matchStandardField("", { name: "urls[LinkedIn]" }), "linkedin");
  assert.equal(matchStandardField("", { name: "resume", type: "file" }), "resume");
  assert.equal(matchStandardField("", { placeholder: "Your email" }), "email");
  assert.equal(matchStandardField("Contact", { type: "email" }), "email");
  assert.equal(matchStandardField("Reach you at", { type: "tel" }), "phone");
  assert.equal(matchStandardField("", { name: "emergency_phone", type: "tel" }), null);
  assert.equal(matchStandardField("", { name: "org" }), null);
});
