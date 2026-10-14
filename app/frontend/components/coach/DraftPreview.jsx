import React from "react";
import { useTranslation } from "react-i18next";

const muted = { color: "rgba(238,243,238,0.7)" };
const accent = { color: "#d6b877" };

const dates = (entry, t) =>
  [entry.start_date, entry.is_current ? t("coach.preview.present") : entry.end_date].filter(Boolean).join(" – ");

// Read-only view of the chat's draft; the coach fills it through save_section.
export default function DraftPreview({ draft }) {
  const { t } = useTranslation();
  const list = (key) => (Array.isArray(draft[key]) ? draft[key] : []);
  const contact = ["email", "phone_number", "city", "country"].map((key) => draft[key]).filter(Boolean);
  const empty =
    !draft.complete_name && contact.length === 0 && !draft.professional_summary &&
    ["work_experience", "education", "skills", "certifications", "languages"].every((key) => list(key).length === 0);

  return (
    <aside className="glass sr-up rounded-[32px] p-5 sm:p-6 flex flex-col gap-5 lg:sticky lg:top-6" style={{ animationDelay: ".1s" }}>
      <header className="flex items-center gap-2.5">
        <span className="sr-dot w-2 h-2 rounded-full bg-primary"></span>
        <h2 className="m-0 text-[18px] font-semibold">{t("coach.preview.title")}</h2>
      </header>

      {empty ? (
        <p className="glass-soft m-0 rounded-2xl px-5 py-4 text-[15px]" style={muted}>{t("coach.preview.empty")}</p>
      ) : (
        <div dir="auto" className="flex flex-col gap-5 text-[14px] break-words">
          {(draft.complete_name || contact.length > 0) && (
            <div>
              {draft.complete_name && <p className="m-0 text-[20px] font-semibold">{draft.complete_name}</p>}
              {contact.length > 0 && <p className="m-0 mt-1" style={muted}>{contact.join(" · ")}</p>}
            </div>
          )}

          {draft.professional_summary && (
            <Section title={t("coach.preview.professional_summary")}>
              <p className="m-0 whitespace-pre-wrap">{draft.professional_summary}</p>
            </Section>
          )}

          <Section title={t("coach.preview.work_experience")} items={list("work_experience")}>
            {(job) => (
              <>
                <p className="m-0 font-semibold">{[job.job_title, job.company].filter(Boolean).join(" · ")}</p>
                <p className="m-0 sr-mono text-[12px]" style={muted}>{dates(job, t)}</p>
                {Array.isArray(job.responsibilities) && job.responsibilities.length > 0 && (
                  <ul className="m-0 mt-1 ps-5 list-disc">
                    {job.responsibilities.map((line, i) => <li key={i}>{line}</li>)}
                  </ul>
                )}
              </>
            )}
          </Section>

          <Section title={t("coach.preview.education")} items={list("education")}>
            {(school) => (
              <>
                <p className="m-0 font-semibold">{[school.degree, school.institution].filter(Boolean).join(" · ")}</p>
                <p className="m-0 sr-mono text-[12px]" style={muted}>
                  {[dates(school, t), school.gpa && `${t("coach.preview.gpa")} ${school.gpa}`].filter(Boolean).join(" · ")}
                </p>
              </>
            )}
          </Section>

          <Section title={t("coach.preview.skills")} items={list("skills")}>
            {(skill) => (
              <p className="m-0">
                <span className="font-semibold">{skill.category}</span>
                {": "}
                {Array.isArray(skill.skill_names) ? skill.skill_names.join(" · ") : ""}
              </p>
            )}
          </Section>

          <Section title={t("coach.preview.certifications")} items={list("certifications")}>
            {(cert) => (
              <p className="m-0">
                <span className="font-semibold">{cert.name}</span>
                <span style={muted}>{[cert.organization, cert.date].filter(Boolean).map((part) => ` · ${part}`).join("")}</span>
              </p>
            )}
          </Section>

          <Section title={t("coach.preview.languages")} items={list("languages")}>
            {(lang) => (
              <p className="m-0">
                <span className="font-semibold">{lang.language}</span>
                <span style={muted}>{lang.proficiency && ` · ${lang.proficiency}`}</span>
              </p>
            )}
          </Section>
        </div>
      )}
    </aside>
  );
}

function Section({ title, items, children }) {
  if (items && items.length === 0) return null;

  return (
    <section className="flex flex-col gap-2">
      <h3 className="m-0 text-[12px] font-semibold uppercase tracking-wide" style={accent}>{title}</h3>
      {items ? (
        <ul className="list-none m-0 p-0 flex flex-col gap-3">
          {items.map((item, i) => <li key={i} className="glass-soft rounded-2xl px-4 py-3">{children(item)}</li>)}
        </ul>
      ) : (
        children
      )}
    </section>
  );
}
