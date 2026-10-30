import React, { useState, useCallback, useRef, useEffect } from "react";
import { trackEvent } from "../lib/posthog";
import i18n from "../lib/i18n";

// Translation helper function
const t = (key, options) => i18n.t(key, options);

// Editable field component using input elements for proper LTR handling
const EditableField = ({ value, onChange, placeholder, className = "", multiline = false, bold = false, center = false, inline = false }) => {
  const [localValue, setLocalValue] = useState(value || "");
  
  // Sync with parent value on initial load
  useEffect(() => {
    setLocalValue(value || "");
  }, [value]);

  const handleChange = useCallback((e) => {
    const newValue = e.target.value;
    setLocalValue(newValue);
    onChange(newValue);
  }, [onChange]);

  const textAlign = center ? "center" : "left";
  const widthClass = inline ? "" : "w-full";
  const paddingClass = inline ? "px-0" : "px-1";
  const baseClassName = `bg-transparent border-none transition-colors rounded-lg hover:bg-white/[0.04] focus:bg-white/[0.06] max-sm:!text-base ${paddingClass} ${widthClass} ${bold ? "font-bold" : ""} ${className}`;

  if (multiline) {
    return (
      <textarea
        value={localValue}
        onChange={handleChange}
        placeholder={placeholder}
        dir="ltr"
        className={`${baseClassName} resize-none min-h-[3em]`}
        style={{ textAlign }}
        rows={3}
      />
    );
  }

  return (
    <input
      type="text"
      value={localValue}
      onChange={handleChange}
      placeholder={placeholder}
      dir="ltr"
      className={baseClassName}
      style={{ textAlign, width: inline ? `${Math.max((localValue || placeholder || "").length, 2)}ch` : undefined }}
    />
  );
};

// Editable bullet point for responsibilities
const EditableBullet = ({ value, onChange, onRemove, onAddAfter }) => {
  const [localValue, setLocalValue] = useState(value || "");
  const textareaRef = useRef(null);
  
  useEffect(() => {
    setLocalValue(value || "");
  }, [value]);

  // Auto-resize textarea
  useEffect(() => {
    if (textareaRef.current) {
      textareaRef.current.style.height = "auto";
      textareaRef.current.style.height = textareaRef.current.scrollHeight + "px";
    }
  }, [localValue]);

  const handleChange = useCallback((e) => {
    const newValue = e.target.value;
    setLocalValue(newValue);
    onChange(newValue);
  }, [onChange]);

  const handleKeyDown = useCallback((e) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      onAddAfter();
    }
    if (e.key === "Backspace" && !localValue) {
      e.preventDefault();
      onRemove();
    }
  }, [localValue, onAddAfter, onRemove]);

  return (
    <div className="flex items-start gap-2 group">
      <span className="text-mist/70 mt-0.5">•</span>
      <textarea
        ref={textareaRef}
        value={localValue}
        onChange={handleChange}
        onKeyDown={handleKeyDown}
        dir="ltr"
        rows={1}
        placeholder="Add responsibility..."
        className="flex-1 bg-transparent border-none transition-colors rounded-lg px-1 resize-none overflow-hidden hover:bg-white/[0.04] focus:bg-white/[0.06] max-sm:!text-base"
        style={{ textAlign: "left", minHeight: "1.5rem" }}
      />
      <button
        onClick={onRemove}
        className="shrink-0 w-11 h-11 inline-flex items-center justify-center rounded-xl sm:opacity-0 sm:group-hover:opacity-100 focus-visible:opacity-100 text-red-300 hover:text-red-200 hover:bg-red-500/10 transition-opacity"
        title="Remove"
      >
        ×
      </button>
    </div>
  );
};

// Section header component
const SectionHeader = ({ title }) => (
  <div className="mb-3">
    <h2 className="text-lg font-semibold text-gold tracking-wide">{title}</h2>
    <hr className="border-0 h-px bg-gradient-to-r from-gold/50 via-white/10 to-transparent" />
  </div>
);

// Main Structured CV Editor Component
const StructuredCvEditor = ({ importId, initialData, updateUrl, saveToResumeUrl, csrfToken }) => {
  const [data, setData] = useState(initialData);
  const [saving, setSaving] = useState(false);
  const [lastSaved, setLastSaved] = useState(null);
  const [savingToResume, setSavingToResume] = useState(false);
  const saveTimeoutRef = useRef(null);
  const dataRef = useRef(data);
  
  // Track editor page view on mount
  useEffect(() => {
    if (importId) {
      trackEvent("linkedin_cv_editor_viewed", { import_id: importId });
    }
  }, [importId]);
  
  // Keep dataRef in sync with data
  useEffect(() => {
    dataRef.current = data;
  }, [data]);

  // Auto-save on changes (debounced)
  const autoSave = useCallback(() => {
    if (saveTimeoutRef.current) {
      clearTimeout(saveTimeoutRef.current);
    }
    saveTimeoutRef.current = setTimeout(async () => {
      setSaving(true);
      try {
        const response = await fetch(updateUrl, {
          method: "PATCH",
          headers: {
            "Content-Type": "application/json",
            "X-CSRF-Token": csrfToken,
          },
          body: JSON.stringify({ parsed_data: dataRef.current }),
        });
        if (response.ok) {
          setLastSaved(new Date());
        }
      } catch (error) {
        console.error("Auto-save failed:", error);
      } finally {
        setSaving(false);
      }
    }, 1500);
  }, [updateUrl, csrfToken]);

  // Update field helpers
  const updateField = useCallback((field, value) => {
    setData(prev => ({ ...prev, [field]: value }));
    autoSave();
  }, [autoSave]);

  const updateWorkExperience = useCallback((index, field, value) => {
    setData(prev => {
      const newExperiences = [...prev.work_experiences];
      newExperiences[index] = { ...newExperiences[index], [field]: value };
      return { ...prev, work_experiences: newExperiences };
    });
    autoSave();
  }, [autoSave]);

  const updateResponsibility = useCallback((expIndex, respIndex, value) => {
    setData(prev => {
      const newExperiences = [...prev.work_experiences];
      const newResp = [...(newExperiences[expIndex].responsibilities || [])];
      newResp[respIndex] = value;
      newExperiences[expIndex] = { ...newExperiences[expIndex], responsibilities: newResp };
      return { ...prev, work_experiences: newExperiences };
    });
    autoSave();
  }, [autoSave]);

  const addResponsibility = useCallback((expIndex, afterIndex) => {
    setData(prev => {
      const newExperiences = [...prev.work_experiences];
      const newResp = [...(newExperiences[expIndex].responsibilities || [])];
      newResp.splice(afterIndex + 1, 0, "");
      newExperiences[expIndex] = { ...newExperiences[expIndex], responsibilities: newResp };
      return { ...prev, work_experiences: newExperiences };
    });
  }, []);

  const removeResponsibility = useCallback((expIndex, respIndex) => {
    setData(prev => {
      const newExperiences = [...prev.work_experiences];
      const newResp = [...(newExperiences[expIndex].responsibilities || [])];
      newResp.splice(respIndex, 1);
      newExperiences[expIndex] = { ...newExperiences[expIndex], responsibilities: newResp };
      return { ...prev, work_experiences: newExperiences };
    });
    autoSave();
  }, [autoSave]);

  const updateEducation = useCallback((index, field, value) => {
    setData(prev => {
      const newEducations = [...prev.educations];
      newEducations[index] = { ...newEducations[index], [field]: value };
      return { ...prev, educations: newEducations };
    });
    autoSave();
  }, [autoSave]);

  const updateSkillGroup = useCallback((index, field, value) => {
    setData(prev => {
      const newSkills = [...prev.skills];
      newSkills[index] = { ...newSkills[index], [field]: value };
      return { ...prev, skills: newSkills };
    });
    autoSave();
  }, [autoSave]);

  const updateCertification = useCallback((index, field, value) => {
    setData(prev => {
      const newCerts = [...prev.certifications];
      newCerts[index] = { ...newCerts[index], [field]: value };
      return { ...prev, certifications: newCerts };
    });
    autoSave();
  }, [autoSave]);

  const updateLanguage = useCallback((index, field, value) => {
    setData(prev => {
      const newLangs = [...prev.languages];
      newLangs[index] = { ...newLangs[index], [field]: value };
      return { ...prev, languages: newLangs };
    });
    autoSave();
  }, [autoSave]);

  // Add/Remove section items
  const addWorkExperience = useCallback(() => {
    setData(prev => ({
      ...prev,
      work_experiences: [...prev.work_experiences, {
        job_title: "",
        company: "",
        start_date: "",
        end_date: "",
        is_current: false,
        responsibilities: [""]
      }]
    }));
  }, []);

  const removeWorkExperience = useCallback((index) => {
    setData(prev => ({
      ...prev,
      work_experiences: prev.work_experiences.filter((_, i) => i !== index)
    }));
    autoSave();
  }, [autoSave]);

  const addEducation = useCallback(() => {
    setData(prev => ({
      ...prev,
      educations: [...prev.educations, {
        degree: "",
        institution: "",
        start_date: "",
        end_date: "",
        gpa: "",
        is_current: false
      }]
    }));
  }, []);

  const removeEducation = useCallback((index) => {
    setData(prev => ({
      ...prev,
      educations: prev.educations.filter((_, i) => i !== index)
    }));
    autoSave();
  }, [autoSave]);

  const addSkillGroup = useCallback(() => {
    setData(prev => ({
      ...prev,
      skills: [...prev.skills, { category: "", skill_names: [] }]
    }));
  }, []);

  const removeSkillGroup = useCallback((index) => {
    setData(prev => ({
      ...prev,
      skills: prev.skills.filter((_, i) => i !== index)
    }));
    autoSave();
  }, [autoSave]);

  const addCertification = useCallback(() => {
    setData(prev => ({
      ...prev,
      certifications: [...prev.certifications, { name: "", organization: "", date: "" }]
    }));
  }, []);

  const removeCertification = useCallback((index) => {
    setData(prev => ({
      ...prev,
      certifications: prev.certifications.filter((_, i) => i !== index)
    }));
    autoSave();
  }, [autoSave]);

  const addLanguage = useCallback(() => {
    setData(prev => ({
      ...prev,
      languages: [...prev.languages, { language: "", proficiency: "" }]
    }));
  }, []);

  const removeLanguage = useCallback((index) => {
    setData(prev => ({
      ...prev,
      languages: prev.languages.filter((_, i) => i !== index)
    }));
    autoSave();
  }, [autoSave]);

  // Save to Resume (create actual resume)
  const handleSaveToResume = useCallback(async () => {
    setSavingToResume(true);
    trackEvent("linkedin_cv_save_started", { import_id: importId });
    try {
      const response = await fetch(saveToResumeUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken,
        },
      });
      const result = await response.json();
      if (result.success) {
        trackEvent("linkedin_cv_save_completed", { import_id: importId, resume_id: result.resume_id });
        // Redirect to PDF generation/download
        window.location.href = `/resumes/${result.resume_id}/generate_pdf`;
      } else {
        trackEvent("linkedin_cv_save_failed", { import_id: importId, error: result.error });
        alert("فشل في حفظ السيرة الذاتية: " + (result.error || "خطأ غير متوقع"));
      }
    } catch (error) {
      console.error("Save to resume failed:", error);
      trackEvent("linkedin_cv_save_failed", { import_id: importId, error: error.message });
      alert("فشل في حفظ السيرة الذاتية");
    } finally {
      setSavingToResume(false);
    }
  }, [saveToResumeUrl, csrfToken, importId]);

  return (
    <div className="max-w-4xl mx-auto">
      {/* Toolbar */}
      <div className="glass sticky top-3 z-10 rounded-[24px] py-3 px-4 mb-6 flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-4">
          <span className="text-sm text-mist/55">
            {saving ? (
              <span className="flex items-center gap-2">
                <svg className="animate-spin w-4 h-4" fill="none" viewBox="0 0 24 24">
                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
                {t('form.saving')}
              </span>
            ) : lastSaved ? (
              `${t('actions.saved')} ${lastSaved.toLocaleTimeString()}`
            ) : (
              t('form.start_editing')
            )}
          </span>
        </div>
        <button
          onClick={handleSaveToResume}
          disabled={savingToResume}
          className="sr-btn sr-primary min-h-[48px] px-6 rounded-2xl font-semibold text-[15px] shadow-glow disabled:opacity-50 flex items-center gap-2"
        >
          {savingToResume ? (
            <>
              <svg className="animate-spin w-4 h-4" fill="none" viewBox="0 0 24 24">
                <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              {t('form.saving')}
            </>
          ) : (
            <>
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3 3m0 0l-3-3m3 3V4" />
              </svg>
              {t('form.save_export_pdf')}
            </>
          )}
        </button>
      </div>

      {/* CV Preview/Editor - Looks like actual PDF */}
      <div className="glass rounded-[32px] p-5 sm:p-8 min-h-dvh text-mist" dir="ltr">
        {/* Header */}
        <div className="text-center mb-6">
          <EditableField
            value={data.complete_name}
            onChange={(v) => updateField("complete_name", v)}
            placeholder="Your Full Name"
            className="text-2xl text-mist"
            bold
            center
          />
          <div className="text-sm text-mist/70 mt-1 flex items-center justify-center flex-wrap">
            <span
              contentEditable
              suppressContentEditableWarning
              dir="ltr"
              onBlur={(e) => updateField("email", e.target.innerText)}
              className="outline-none"
            >{data.email || "email@example.com"}</span>
            <span className="px-2">|</span>
            <span
              contentEditable
              suppressContentEditableWarning
              dir="ltr"
              onBlur={(e) => updateField("phone_number", e.target.innerText)}
              className="outline-none"
            >{data.phone_number || "+1234567890"}</span>
            <span className="px-2">|</span>
            <span
              contentEditable
              suppressContentEditableWarning
              dir="ltr"
              onBlur={(e) => updateField("city", e.target.innerText)}
              className="outline-none"
            >{data.city || "City"}</span>
            <span>, </span>
            <span
              contentEditable
              suppressContentEditableWarning
              dir="ltr"
              onBlur={(e) => updateField("country", e.target.innerText)}
              className="outline-none"
            >{data.country || "Country"}</span>
          </div>
        </div>

        {/* Professional Summary */}
        <div className="mb-6">
          <SectionHeader title="PROFESSIONAL SUMMARY" />
          <EditableField
            value={data.professional_summary}
            onChange={(v) => updateField("professional_summary", v)}
            placeholder="Write a professional summary..."
            className="text-sm text-mist/70 leading-relaxed"
            multiline
          />
        </div>

        {/* Education */}
        <div className="mb-6">
          <SectionHeader title="EDUCATION" />
          {(data.educations || []).map((edu, index) => (
            <div key={index} className="mb-4 group">
              <div className="flex justify-between items-start">
                <div className="flex-1">
                  <EditableField
                    value={edu.degree}
                    onChange={(v) => updateEducation(index, "degree", v)}
                    placeholder="Degree"
                    className="text-sm text-mist"
                    bold
                  />
                </div>
                <div className="text-sm text-mist/70 flex items-center shrink-0">
                  {(edu.start_date || edu.end_date) && (
                    <>
                      <EditableField
                        value={edu.start_date || ""}
                        onChange={(v) => updateEducation(index, "start_date", v)}
                        placeholder="Start"
                        inline
                      />
                      <span>-</span>
                      <EditableField
                        value={edu.end_date || ""}
                        onChange={(v) => updateEducation(index, "end_date", v)}
                        placeholder="End"
                        inline
                      />
                    </>
                  )}
                  {!edu.start_date && !edu.end_date && (
                    <EditableField
                      value=""
                      onChange={(v) => updateEducation(index, "end_date", v)}
                      placeholder="Year"
                      inline
                    />
                  )}
                  <button
                    onClick={() => removeEducation(index)}
                    className="shrink-0 w-11 h-11 inline-flex items-center justify-center rounded-xl sm:opacity-0 sm:group-hover:opacity-100 focus-visible:opacity-100 text-red-300 hover:text-red-200 hover:bg-red-500/10 transition-opacity text-lg leading-none ms-2"
                    title="Remove education"
                  >
                    ×
                  </button>
                </div>
              </div>
              <EditableField
                value={edu.institution}
                onChange={(v) => updateEducation(index, "institution", v)}
                placeholder="University/Institution Name"
                className="text-sm text-mist/70"
              />
            </div>
          ))}
          <button
            onClick={addEducation}
            className="text-sm text-primary-soft hover:text-mist flex items-center gap-1 mt-2 min-h-[44px] px-1 rounded-xl transition-colors"
          >
            <span>+</span> Add Education
          </button>
        </div>

        {/* Work Experience */}
        <div className="mb-6">
          <SectionHeader title="WORK EXPERIENCE" />
          {(data.work_experiences || []).map((exp, expIndex) => (
            <div key={expIndex} className="mb-6 group">
              <div className="flex justify-between items-start">
                <div className="flex-1">
                  <EditableField
                    value={exp.job_title}
                    onChange={(v) => updateWorkExperience(expIndex, "job_title", v)}
                    placeholder="Job Title"
                    className="text-sm text-mist"
                    bold
                  />
                </div>
                <div className="text-sm text-mist/70 flex items-center shrink-0">
                  <EditableField
                    value={exp.start_date}
                    onChange={(v) => updateWorkExperience(expIndex, "start_date", v)}
                    placeholder="2020-01"
                    inline
                  />
                  <span>-</span>
                  <EditableField
                    value={exp.is_current ? "Present" : exp.end_date}
                    onChange={(v) => {
                      if (v === "Present") {
                        updateWorkExperience(expIndex, "is_current", true);
                      } else {
                        updateWorkExperience(expIndex, "is_current", false);
                        updateWorkExperience(expIndex, "end_date", v);
                      }
                    }}
                    placeholder="Present"
                    inline
                  />
                  <button
                    onClick={() => removeWorkExperience(expIndex)}
                    className="shrink-0 w-11 h-11 inline-flex items-center justify-center rounded-xl sm:opacity-0 sm:group-hover:opacity-100 focus-visible:opacity-100 text-red-300 hover:text-red-200 hover:bg-red-500/10 transition-opacity text-lg leading-none ms-2"
                    title="Remove experience"
                  >
                    ×
                  </button>
                </div>
              </div>
              <EditableField
                value={exp.company}
                onChange={(v) => updateWorkExperience(expIndex, "company", v)}
                placeholder="Company Name"
                className="text-sm text-mist/70"
              />
              <div className="mt-2 space-y-1">
                {(exp.responsibilities || []).map((resp, respIndex) => (
                  <EditableBullet
                    key={respIndex}
                    value={resp}
                    onChange={(v) => updateResponsibility(expIndex, respIndex, v)}
                    onRemove={() => removeResponsibility(expIndex, respIndex)}
                    onAddAfter={() => addResponsibility(expIndex, respIndex)}
                  />
                ))}
                <button
                  onClick={() => addResponsibility(expIndex, (exp.responsibilities || []).length - 1)}
                  className="text-sm text-mist/55 hover:text-mist flex items-center gap-1 ms-4 min-h-[44px]"
                >
                  <span>+</span> Add bullet point
                </button>
              </div>
            </div>
          ))}
          <button
            onClick={addWorkExperience}
            className="text-sm text-primary-soft hover:text-mist flex items-center gap-1 mt-2 min-h-[44px] px-1 rounded-xl transition-colors"
          >
            <span>+</span> Add Work Experience
          </button>
        </div>

        {/* Skills */}
        <div className="mb-6">
          <SectionHeader title="SKILLS" />
          {(data.skills || []).map((skillGroup, index) => (
            <div key={index} className="mb-3 group">
              <div className="flex justify-between items-start">
                <div className="text-sm flex-1">
                <div className="font-bold text-mist">
                  <span
                    contentEditable
                    suppressContentEditableWarning
                    dir="ltr"
                    onBlur={(e) => updateSkillGroup(index, "category", e.target.innerText)}
                    className="outline-none"
                    style={{ minWidth: '20px', display: 'inline-block' }}
                  >{skillGroup.category || "Category"}</span>:
                </div>
                <div className="text-mist/70 ms-4">
                  <textarea
                    value={(skillGroup.skill_names || []).join(", ")}
                    onChange={(e) => updateSkillGroup(index, "skill_names", e.target.value.split(",").map(s => s.trim()).filter(Boolean))}
                    placeholder="Skill 1, Skill 2, Skill 3"
                    dir="ltr"
                    className="w-full bg-transparent border-none rounded-lg resize-none hover:bg-white/[0.04] focus:bg-white/[0.06] max-sm:!text-base"
                    style={{ padding: '0', margin: '0' }}
                    rows={2}
                  />
                </div>
              </div>
              <button
                onClick={() => removeSkillGroup(index)}
                className="shrink-0 w-11 h-11 inline-flex items-center justify-center rounded-xl sm:opacity-0 sm:group-hover:opacity-100 focus-visible:opacity-100 text-red-300 hover:text-red-200 hover:bg-red-500/10 transition-opacity text-lg leading-none ms-2"
                title="Remove skill group"
              >
                ×
              </button>
            </div>
          </div>
          ))}
          <button
            onClick={addSkillGroup}
            className="text-sm text-primary-soft hover:text-mist flex items-center gap-1 mt-2 min-h-[44px] px-1 rounded-xl transition-colors"
          >
            <span>+</span> Add Skill Category
          </button>
        </div>

        {/* Certifications */}
        <div className="mb-6">
          <SectionHeader title="CERTIFICATIONS" />
          {(data.certifications || []).filter(cert => cert.name).map((cert, index) => (
            <div key={index} className="mb-2 group">
              <div className="flex justify-between items-center gap-2">
                <div className="flex items-center gap-2 flex-1">
                  <EditableField
                    value={cert.name}
                    onChange={(v) => updateCertification(index, "name", v)}
                    placeholder="Certification Name"
                    className="text-sm text-mist"
                    bold
                    inline
                  />
                  <EditableField
                    value={cert.organization || ""}
                    onChange={(v) => updateCertification(index, "organization", v)}
                    placeholder="Organization"
                    className="text-sm text-mist/70"
                    inline
                  />
                </div>
                <div className="flex items-center gap-2">
                  <EditableField
                    value={cert.date || ""}
                    onChange={(v) => updateCertification(index, "date", v)}
                    placeholder="Date"
                    className="text-sm text-mist/70 shrink-0"
                    inline
                  />
                  <button
                    onClick={() => removeCertification(index)}
                    className="shrink-0 w-11 h-11 inline-flex items-center justify-center rounded-xl sm:opacity-0 sm:group-hover:opacity-100 focus-visible:opacity-100 text-red-300 hover:text-red-200 hover:bg-red-500/10 transition-opacity text-lg leading-none"
                    title="Remove certification"
                  >
                    ×
                  </button>
                </div>
              </div>
            </div>
          ))}
          <button
            onClick={addCertification}
            className="text-sm text-primary-soft hover:text-mist flex items-center gap-1 mt-2 min-h-[44px] px-1 rounded-xl transition-colors"
          >
            <span>+</span> Add Certification
          </button>
        </div>

        {/* Languages */}
        <div className="mb-6">
          <SectionHeader title="LANGUAGES" />
          {(data.languages || []).map((lang, index) => (
            <div key={index} className="mb-2 group">
              <div className="flex justify-between items-center gap-2">
                <EditableField
                  value={lang.language}
                  onChange={(v) => updateLanguage(index, "language", v)}
                  placeholder="Language"
                  className="text-sm text-mist"
                  bold
                  inline
                />
                <div className="flex items-center gap-2">
                  <EditableField
                    value={lang.proficiency}
                    onChange={(v) => updateLanguage(index, "proficiency", v)}
                    placeholder="Fluent"
                    className="text-sm text-mist/70"
                    inline
                  />
                  <button
                    onClick={() => removeLanguage(index)}
                    className="shrink-0 w-11 h-11 inline-flex items-center justify-center rounded-xl sm:opacity-0 sm:group-hover:opacity-100 focus-visible:opacity-100 text-red-300 hover:text-red-200 hover:bg-red-500/10 transition-opacity text-lg leading-none"
                    title="Remove language"
                  >
                    ×
                  </button>
                </div>
              </div>
            </div>
          ))}
          <button
            onClick={addLanguage}
            className="text-sm text-primary-soft hover:text-mist flex items-center gap-1 mt-2 min-h-[44px] px-1 rounded-xl transition-colors"
          >
            <span>+</span> Add Language
          </button>
        </div>
      </div>
    </div>
  );
};

export default StructuredCvEditor;
