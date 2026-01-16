import React, { memo } from "react";

const ReviewStep = ({ formData, renderSaveDraftButton }) => {
  return (
    <div className="space-y-6">
      <div className="text-center mb-6">
        <h2 className="text-xl font-semibold text-slate-900">
          معاينة السيرة الذاتية
        </h2>
        <p className="text-slate-600 mt-2">
          تصفح السيرة الذاتية التي قمت بإنشائها للتأكد من أن كل المعلومات صحيحة.
        </p>
      </div>

      {/* Resume Preview */}
      <div
        className="bg-white border border-gray-200 rounded-lg shadow-sm p-8 max-w-4xl mx-auto"
        dir="ltr"
        style={{
          fontFamily: "Arial, sans-serif",
          fontSize: "11pt",
          lineHeight: "1.3",
        }}
      >
        {/* Header */}
        <div className="text-center mb-4 pb-2 border-b border-gray-900">
          <h1
            className="text-2xl font-bold text-gray-900 mb-1"
            style={{ fontSize: "18pt" }}
          >
            {formData.complete_name || "Your Name"}
          </h1>
          <div className="text-gray-600" style={{ fontSize: "11pt" }}>
            {formData.email && `${formData.email}`}
            {formData.phone_number && ` | ${formData.phone_number}`}
            {formData.city && formData.country && ` | ${formData.city}, ${formData.country}`}
          </div>
        </div>

        {/* Professional Summary */}
        {(formData.professional_summary_english || formData.professional_summary) && (
          <div className="mb-4">
            <h2
              className="text-lg font-bold text-gray-900 mb-1 pb-1 border-b border-gray-900 text-left uppercase tracking-wide"
              style={{ fontSize: "12pt" }}
            >
              Professional Summary
            </h2>
            <p className="text-gray-700 leading-relaxed text-left" style={{ fontSize: "11pt" }}>
              {formData.professional_summary_english || formData.professional_summary}
            </p>
          </div>
        )}

        {/* Education */}
        {formData.education.some((edu) => edu.degree && edu.institution) && (
          <div className="mb-4">
            <h2
              className="text-lg font-bold text-gray-900 mb-1 pb-1 border-b border-gray-900 text-left uppercase tracking-wide"
              style={{ fontSize: "12pt" }}
            >
              Education
            </h2>
            <div className="space-y-2">
              {formData.education.map(
                (edu, index) =>
                  edu.degree && edu.institution && (
                    <div key={index} className="flex justify-between items-start">
                      <div className="text-left">
                        <div className="font-semibold text-gray-900" style={{ fontSize: "11pt" }}>
                          {edu.degree}
                        </div>
                        <div className="text-gray-600" style={{ fontSize: "10pt" }}>
                          {edu.institution}
                        </div>
                      </div>
                      <div className="text-right text-gray-500" style={{ fontSize: "10pt" }}>
                        {edu.start_date && (
                          <>
                            {edu.start_date}
                            {edu.end_date && !edu.is_current && ` - ${edu.end_date}`}
                            {edu.is_current && " - Present"}
                          </>
                        )}
                        {edu.gpa && <div className="mt-1">(GPA: {edu.gpa})</div>}
                      </div>
                    </div>
                  )
              )}
            </div>
          </div>
        )}

        {/* Work Experience */}
        {formData.work_experience.some((work) => work.job_title && work.company) && (
          <div className="mb-4">
            <h2
              className="text-lg font-bold text-gray-900 mb-1 pb-1 border-b border-gray-900 text-left uppercase tracking-wide"
              style={{ fontSize: "12pt" }}
            >
              Work Experience
            </h2>
            <div className="space-y-2">
              {formData.work_experience
                .filter((work) => work.job_title && work.company)
                .sort((a, b) => {
                  if (!a.start_date && !b.start_date) return 0;
                  if (!a.start_date) return 1;
                  if (!b.start_date) return -1;
                  const aIsCurrent = a.is_current || !a.end_date;
                  const bIsCurrent = b.is_current || !b.end_date;
                  if (aIsCurrent && !bIsCurrent) return -1;
                  if (!aIsCurrent && bIsCurrent) return 1;
                  return new Date(b.start_date) - new Date(a.start_date);
                })
                .map((work, index) => (
                  <div key={index} className="mb-2">
                    <div className="flex justify-between items-start mb-1">
                      <div className="text-left font-semibold text-gray-900" style={{ fontSize: "11pt" }}>
                        {work.job_title}
                      </div>
                      <div className="text-right text-gray-500" style={{ fontSize: "10pt" }}>
                        {work.start_date && (
                          <>
                            {work.start_date}
                            {work.end_date && !work.is_current && ` - ${work.end_date}`}
                            {work.is_current && " - Present"}
                          </>
                        )}
                      </div>
                    </div>
                    <div className="text-left text-gray-600 mb-1" style={{ fontSize: "10pt" }}>
                      {work.company}
                    </div>
                    {work.responsibilities.some((resp) => resp.trim()) && (
                      <div
                        className="text-gray-700 text-left"
                        style={{ fontSize: "10pt", lineHeight: "1.1", margin: "1pt 0" }}
                      >
                        {work.responsibilities
                          .filter((resp) => resp.trim())
                          .map((resp, respIndex) => (
                            <div
                              key={respIndex}
                              className="bullet-point"
                              style={{
                                marginBottom: "1pt",
                                fontSize: "10pt",
                                lineHeight: "1.1",
                                wordWrap: "break-word",
                                overflowWrap: "break-word",
                                hyphens: "auto",
                                maxWidth: "100%",
                                clear: "both",
                                textAlign: "justify",
                                paddingLeft: "0pt",
                                marginLeft: "0pt",
                                textIndent: "0pt",
                              }}
                            >
                              • {resp}
                            </div>
                          ))}
                      </div>
                    )}
                  </div>
                ))}
            </div>
          </div>
        )}

        {/* Skills */}
        {formData.skills.some(
          (skill) => skill.category && skill.skill_names.some((name) => name.trim())
        ) && (
          <div className="mb-4">
            <h2
              className="text-lg font-bold text-gray-900 mb-1 pb-1 border-b border-gray-900 text-left uppercase tracking-wide"
              style={{ fontSize: "12pt" }}
            >
              Skills
            </h2>
            <div className="space-y-1">
              {formData.skills.map(
                (skill, index) =>
                  skill.category && skill.skill_names.some((name) => name.trim()) && (
                    <div key={index} className="mb-1 text-left">
                      <span className="font-semibold text-gray-900" style={{ fontSize: "10pt" }}>
                        {skill.category}:
                      </span>
                      <span
                        className="text-gray-700 ml-2"
                        style={{ fontSize: "10pt", lineHeight: "1.2" }}
                      >
                        {skill.skill_names.filter((name) => name.trim()).join(", ")}
                      </span>
                    </div>
                  )
              )}
            </div>
          </div>
        )}

        {/* Certificates */}
        {formData.certifications.some((cert) => cert.name && cert.organization) && (
          <div className="mb-4">
            <h2
              className="text-lg font-bold text-gray-900 mb-1 pb-1 border-b border-gray-900 text-left uppercase tracking-wide"
              style={{ fontSize: "12pt" }}
            >
              Certificates
            </h2>
            <div className="space-y-1">
              {formData.certifications.map(
                (cert, index) =>
                  cert.name && cert.organization && (
                    <div key={index} className="flex justify-between items-start">
                      <div className="text-left">
                        <span className="font-semibold text-gray-900" style={{ fontSize: "11pt" }}>
                          {cert.name}
                        </span>
                        <span className="text-gray-600 ml-2" style={{ fontSize: "10pt" }}>
                          {cert.organization}
                        </span>
                      </div>
                      <span className="text-right text-gray-500" style={{ fontSize: "10pt" }}>
                        {cert.date}
                      </span>
                    </div>
                  )
              )}
            </div>
          </div>
        )}

        {/* Languages */}
        {formData.languages.some((lang) => lang.language && lang.proficiency) && (
          <div className="mb-4">
            <h2
              className="text-lg font-bold text-gray-900 mb-1 pb-1 border-b border-gray-900 text-left uppercase tracking-wide"
              style={{ fontSize: "12pt" }}
            >
              Languages
            </h2>
            <div className="space-y-1">
              {formData.languages.map(
                (lang, index) =>
                  lang.language && lang.proficiency && (
                    <div key={index} className="flex justify-between items-start">
                      <span
                        className="text-left font-semibold text-gray-900"
                        style={{ fontSize: "10pt" }}
                      >
                        {lang.language}
                      </span>
                      <span className="text-right text-gray-500" style={{ fontSize: "10pt" }}>
                        {lang.proficiency}
                      </span>
                    </div>
                  )
              )}
            </div>
          </div>
        )}
      </div>

      {renderSaveDraftButton(4)}
    </div>
  );
};

export default memo(ReviewStep);
