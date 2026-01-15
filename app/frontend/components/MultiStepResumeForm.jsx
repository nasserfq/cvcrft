import React, { useState, useEffect } from "react";

// Mobile-friendly date picker component
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
  <div className="relative">
   <button
    type="button"
    onClick={() => !disabled && setIsOpen(true)}
    disabled={disabled}
    className="w-full rounded-lg border border-slate-300/70 bg-white/70 px-4 py-4 text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/40 focus:border-emerald-400 ring-1 ring-black/5 transition-all text-base text-right disabled:opacity-50 disabled:cursor-not-allowed"
    style={{
     fontSize: "16px",
     minHeight: "48px",
    }}
   >
    <div className="flex items-center justify-between">
     <span className={value ? "text-slate-900" : "text-slate-400"}>
      {formatDisplayValue(value)}
     </span>
     <svg
      className="w-5 h-5 text-slate-400"
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
    </div>
   </button>

   {isOpen && (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/25">
     <div className="bg-white rounded-t-2xl sm:rounded-2xl w-full max-w-sm max-h-[80vh] overflow-hidden shadow-2xl">
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
        className="flex-1 py-3 px-4 bg-slate-100 text-slate-700 rounded-lg font-medium hover:bg-slate-200 transition-all"
       >
        الغاء
       </button>
       <button
        onClick={handleConfirm}
        className="flex-1 py-3 px-4 bg-emerald-600 text-white rounded-lg font-medium hover:bg-emerald-700 transition-all"
       >
        تأكيد
       </button>
      </div>
     </div>
    </div>
   )}
  </div>
 );
};

const MultiStepResumeForm = ({ resume, onSubmit }) => {
 console.log("=== MultiStepResumeForm component rendered ===");
 console.log("Resume prop:", resume);
 console.log("Resume skills:", resume?.skills);
 console.log(
  "Resume skills detailed:",
  resume?.skills?.map((s) => ({
   category: s.category,
   skill_names: s.skill_names,
   types: s.skill_names?.map((name) => ({
    value: name,
    type: typeof name,
    length: name?.length,
   })),
  }))
 );
 console.log("Resume skills length:", resume?.skills?.length);
 console.log("Resume skills is array:", Array.isArray(resume?.skills));

 // Clean skills data to remove empty skill names
 const cleanSkillsData = (skills) => {
  console.log("=== cleanSkillsData called with:", skills);
  if (!skills || !Array.isArray(skills)) {
   console.log("No skills or not array, returning default");
   return [
    {
     category: "",
     skill_names: [],
    },
   ];
  }

  console.log("Processing", skills.length, "skills");
  return skills.map((skill, skillIndex) => {
   console.log(`--- Processing skill ${skillIndex}:`, {
    category: skill.category,
    skill_names: skill.skill_names,
   });
   let skillNames = skill.skill_names;

   // Handle case where skill_names might be a JSON string
   if (typeof skillNames === "string") {
    console.log("Skill names is string, parsing JSON:", skillNames);
    try {
     skillNames = JSON.parse(skillNames);
     console.log("Parsed skill_names:", skillNames);
    } catch (e) {
     console.log("JSON parse failed, setting to empty array:", e);
     skillNames = [];
    }
   }

   // Ensure skillNames is an array
   if (!Array.isArray(skillNames)) {
    console.log(
     "Skill names is not array, setting to empty array:",
     typeof skillNames,
     skillNames
    );
    skillNames = [];
   }

   console.log("Skill names before filtering:", skillNames);

   // Filter out empty, null, undefined, or whitespace-only names
   const cleanedNames = skillNames.filter((name) => {
    const isValid =
     name != null &&
     typeof name === "string" &&
     name.trim() !== "" &&
     name.trim() !== '""' &&
     name.trim() !== "''";
    console.log(`Filtering skill name: "${name}" -> isValid: ${isValid}`);
    return isValid;
   });

   console.log(`Cleaned names for skill ${skillIndex}:`, cleanedNames);

   return {
    ...skill,
    skill_names: cleanedNames,
   };
  });
 };

 const [currentStep, setCurrentStep] = useState(() => {
  // Check if we have a step parameter from URL or draft data
  const urlParams = new URLSearchParams(window.location.search);
  const stepParam = urlParams.get("step");
  if (stepParam) {
   return parseInt(stepParam, 10);
  }

  // Check if resume has draft data with current step
  if (resume?.draft_data?.current_step) {
   return parseInt(resume.draft_data.current_step, 10);
  }

  return 1;
 });
 const [formData, setFormData] = useState(() => {
  // Load draft data if available
  const draftData = resume?.draft_data;

  if (draftData) {
   return {
    complete_name: draftData.complete_name || resume?.complete_name || "",
    email: draftData.email || resume?.email || "",
    phone_number: draftData.phone_number || resume?.phone_number || "",
    city: draftData.city || resume?.city || "",
    country: draftData.country || resume?.country || "",
    professional_summary:
     draftData.professional_summary || resume?.professional_summary || "",
    professional_summary_english:
     draftData.professional_summary_english ||
     resume?.professional_summary_english ||
     "",
    skills_extracted: resume?.skills_extracted || [],
    translation_notes: resume?.translation_notes || "",
    education: (() => {
     try {
      return draftData.education
       ? JSON.parse(draftData.education)
       : resume?.education || [
          {
           degree: "",
           institution: "",
           start_date: "",
           end_date: "",
           gpa: "",
           is_current: false,
          },
         ];
     } catch {
      return (
       resume?.education || [
        {
         degree: "",
         institution: "",
         start_date: "",
         end_date: "",
         gpa: "",
         is_current: false,
        },
       ]
      );
     }
    })(),
    work_experience: (() => {
     try {
      return draftData.work_experience
       ? JSON.parse(draftData.work_experience)
       : resume?.work_experience || [
          {
           job_title: "",
           company: "",
           start_date: "",
           end_date: "",
           is_current: false,
           responsibilities: [""],
          },
         ];
     } catch {
      return (
       resume?.work_experience || [
        {
         job_title: "",
         company: "",
         start_date: "",
         end_date: "",
         is_current: false,
         responsibilities: [""],
        },
       ]
      );
     }
    })(),
    skills: (() => {
     try {
      if (draftData.skills) {
       return JSON.parse(draftData.skills);
      }
     } catch {
      // Fall through to default logic
     }

     // Default logic for skills
     if (resume?.skills && resume.skills.length > 0) {
      return resume.skills.map((skill) => ({
       ...skill,
       skill_names: (skill.skill_names || []).filter(
        (name) =>
         name &&
         typeof name === "string" &&
         name.trim() !== "" &&
         name.trim() !== '""' &&
         name.trim() !== "''"
       ),
      }));
     } else {
      return [
       {
        category: "",
        skill_names: [],
       },
      ];
     }
    })(),
    certifications: (() => {
     try {
      return draftData.certifications
       ? JSON.parse(draftData.certifications)
       : resume?.certifications || [
          {
           name: "",
           organization: "",
           date: "",
          },
         ];
     } catch {
      return (
       resume?.certifications || [
        {
         name: "",
         organization: "",
         date: "",
        },
       ]
      );
     }
    })(),
    languages: (() => {
     try {
      return draftData.languages
       ? JSON.parse(draftData.languages)
       : resume?.languages || [
          {
           language: "",
           proficiency: "",
          },
         ];
     } catch {
      return (
       resume?.languages || [
        {
         language: "",
         proficiency: "",
        },
       ]
      );
     }
    })(),
   };
  }

  // Default initialization if no draft data
  return {
   complete_name: resume?.complete_name || "",
   email: resume?.email || "",
   phone_number: resume?.phone_number || "",
   city: resume?.city || "",
   country: resume?.country || "",
   professional_summary: resume?.professional_summary || "",
   professional_summary_english: resume?.professional_summary_english || "",
   skills_extracted: resume?.skills_extracted || [],
   translation_notes: resume?.translation_notes || "",
   education: resume?.education || [
    {
     degree: "",
     institution: "",
     start_date: "",
     end_date: "",
     gpa: "",
     is_current: false,
    },
   ],
   work_experience: resume?.work_experience || [
    {
     job_title: "",
     company: "",
     start_date: "",
     end_date: "",
     is_current: false,
     responsibilities: [""],
    },
   ],
   skills: (() => {
    if (resume?.skills && resume.skills.length > 0) {
     return resume.skills.map((skill) => ({
      ...skill,
      skill_names: (skill.skill_names || []).filter(
       (name) =>
        name &&
        typeof name === "string" &&
        name.trim() !== "" &&
        name.trim() !== '""' &&
        name.trim() !== "''"
      ),
     }));
    } else {
     return [
      {
       category: "",
       skill_names: [],
      },
     ];
    }
   })(),
   certifications: resume?.certifications || [
    {
     name: "",
     organization: "",
     date: "",
    },
   ],
   languages: resume?.languages || [
    {
     language: "",
     proficiency: "",
    },
   ],
  };
 });

 const [isTranslating, setIsTranslating] = useState(false);
 const [translationError, setTranslationError] = useState("");
 const [isExporting, setIsExporting] = useState(false);
 const [exportStatus, setExportStatus] = useState("idle"); // idle, processing, completed, failed, timeout
 const [isSavingDraft, setIsSavingDraft] = useState(false);
 const [addingSkillTo, setAddingSkillTo] = useState(null);
 const [translationCount, setTranslationCount] = useState(0);
 const [maxTranslations] = useState(5);

 const totalSteps = 8;

 // Handle browser back/forward navigation to keep step in sync
 useEffect(() => {
  const handlePopState = () => {
   const urlParams = new URLSearchParams(window.location.search);
   const stepParam = urlParams.get("step");
   if (stepParam) {
    const newStep = parseInt(stepParam, 10);
    if (newStep !== currentStep && newStep >= 1 && newStep <= totalSteps) {
     setCurrentStep(newStep);
    }
   }
  };

  window.addEventListener("popstate", handlePopState);
  return () => window.removeEventListener("popstate", handlePopState);
 }, [currentStep, totalSteps]);

 // BULLETPROOF EFFECT - Continuously remove empty skill names
 React.useEffect(() => {
  setFormData((prev) => {
   const cleanedSkills = prev.skills.map((skill) => ({
    ...skill,
    skill_names: (skill.skill_names || []).filter(
     (name) =>
      name &&
      typeof name === "string" &&
      name.trim() !== "" &&
      name.trim() !== '""' &&
      name.trim() !== "''" &&
      name.trim() !== "null" &&
      name.trim() !== "undefined"
    ),
   }));

   return {
    ...prev,
    skills: cleanedSkills,
   };
  });
 }, []);

 const handleInputChange = (field, value) => {
  setFormData((prev) => ({
   ...prev,
   [field]: value,
  }));
 };

 const handleEducationChange = (index, field, value) => {
  setFormData((prev) => ({
   ...prev,
   education: prev.education.map((edu, i) =>
    i === index ? { ...edu, [field]: value } : edu
   ),
  }));
 };

 const addEducation = () => {
  setFormData((prev) => ({
   ...prev,
   education: [
    ...prev.education,
    {
     degree: "",
     institution: "",
     start_date: "",
     end_date: "",
     gpa: "",
     is_current: false,
    },
   ],
  }));
 };

 const removeEducation = (index) => {
  if (formData.education.length > 1) {
   setFormData((prev) => ({
    ...prev,
    education: prev.education.filter((_, i) => i !== index),
   }));
  }
 };

 const handleWorkExperienceChange = (index, field, value) => {
  setFormData((prev) => ({
   ...prev,
   work_experience: prev.work_experience.map((work, i) =>
    i === index ? { ...work, [field]: value } : work
   ),
  }));
 };

 const addWorkExperience = () => {
  setFormData((prev) => ({
   ...prev,
   work_experience: [
    ...prev.work_experience,
    {
     job_title: "",
     company: "",
     start_date: "",
     end_date: "",
     is_current: false,
     responsibilities: [""],
    },
   ],
  }));
 };

 const removeWorkExperience = (index) => {
  if (formData.work_experience.length > 1) {
   setFormData((prev) => ({
    ...prev,
    work_experience: prev.work_experience.filter((_, i) => i !== index),
   }));
  }
 };

 const addResponsibility = (workIndex) => {
  setFormData((prev) => ({
   ...prev,
   work_experience: prev.work_experience.map((work, i) =>
    i === workIndex
     ? { ...work, responsibilities: [...work.responsibilities, ""] }
     : work
   ),
  }));
 };

 const removeResponsibility = (workIndex, respIndex) => {
  if (formData.work_experience[workIndex].responsibilities.length > 1) {
   setFormData((prev) => ({
    ...prev,
    work_experience: prev.work_experience.map((work, i) =>
     i === workIndex
      ? {
         ...work,
         responsibilities: work.responsibilities.filter(
          (_, j) => j !== respIndex
         ),
        }
      : work
    ),
   }));
  }
 };

 const handleResponsibilityChange = (workIndex, respIndex, value) => {
  setFormData((prev) => ({
   ...prev,
   work_experience: prev.work_experience.map((work, i) =>
    i === workIndex
     ? {
        ...work,
        responsibilities: work.responsibilities.map((resp, j) =>
         j === respIndex ? value : resp
        ),
       }
     : work
   ),
  }));
 };

 const handleSkillsChange = (index, field, value) => {
  setFormData((prev) => ({
   ...prev,
   skills: prev.skills.map((skill, i) =>
    i === index ? { ...skill, [field]: value } : skill
   ),
  }));
 };

 const addSkills = () => {
  setFormData((prev) => ({
   ...prev,
   skills: [
    ...prev.skills,
    {
     category: "",
     skill_names: [], // ALWAYS empty array, never with empty strings
    },
   ],
  }));
 };

 const removeSkills = (index) => {
  if (formData.skills.length > 1) {
   setFormData((prev) => ({
    ...prev,
    skills: prev.skills.filter((_, i) => i !== index),
   }));
  }
 };

 const addSkillName = (skillIndex) => {
  setAddingSkillTo(skillIndex);
 };

 const handleNewSkillChange = (skillIndex, value) => {
  // Only add non-empty values
  if (value && value.trim() !== "") {
   setFormData((prev) => ({
    ...prev,
    skills: prev.skills.map((skill, i) =>
     i === skillIndex
      ? { ...skill, skill_names: [...skill.skill_names, value.trim()] }
      : skill
    ),
   }));
   setAddingSkillTo(null);
  }
 };

 const handleNewSkillBlur = (skillIndex, value) => {
  // Only add non-empty values
  if (value && value.trim() !== "") {
   setFormData((prev) => ({
    ...prev,
    skills: prev.skills.map((skill, i) =>
     i === skillIndex
      ? { ...skill, skill_names: [...skill.skill_names, value.trim()] }
      : skill
    ),
   }));
  }
  setAddingSkillTo(null);
 };

 const removeSkillName = (skillIndex, nameIndex) => {
  if (formData.skills[skillIndex].skill_names.length > 1) {
   setFormData((prev) => ({
    ...prev,
    skills: prev.skills.map((skill, i) =>
     i === skillIndex
      ? {
         ...skill,
         skill_names: skill.skill_names.filter((_, j) => j !== nameIndex),
        }
      : skill
    ),
   }));
  }
 };

 const handleSkillNameChange = (skillIndex, nameIndex, value) => {
  setFormData((prev) => ({
   ...prev,
   skills: prev.skills.map((skill, i) =>
    i === skillIndex
     ? {
        ...skill,
        skill_names: skill.skill_names.map((name, j) =>
         j === nameIndex ? value : name
        ),
       }
     : skill
   ),
  }));
 };

 const handleSkillNameBlur = (skillIndex, nameIndex) => {
  setFormData((prev) => ({
   ...prev,
   skills: prev.skills.map((skill, i) =>
    i === skillIndex
     ? {
        ...skill,
        skill_names: skill.skill_names.filter(
         (name, j) => j !== nameIndex || (name && name.trim() !== "")
        ),
       }
     : skill
   ),
  }));
 };

 const handleCertificationChange = (index, field, value) => {
  setFormData((prev) => ({
   ...prev,
   certifications: prev.certifications.map((cert, i) =>
    i === index ? { ...cert, [field]: value } : cert
   ),
  }));
 };

 const addCertification = () => {
  setFormData((prev) => ({
   ...prev,
   certifications: [
    ...prev.certifications,
    {
     name: "",
     organization: "",
     date: "",
    },
   ],
  }));
 };

 const removeCertification = (index) => {
  if (formData.certifications.length > 1) {
   setFormData((prev) => ({
    ...prev,
    certifications: prev.certifications.filter((_, i) => i !== index),
   }));
  }
 };

 const handleLanguageChange = (index, field, value) => {
  setFormData((prev) => ({
   ...prev,
   languages: prev.languages.map((lang, i) =>
    i === index ? { ...lang, [field]: value } : lang
   ),
  }));
 };

 const translateProfessionalSummary = async () => {
  if (!formData.professional_summary.trim()) {
   setTranslationError("يرجى إدخال الملخص المهني أولاً");
   return;
  }

  // Check translation limit
  if (translationCount >= maxTranslations) {
   setTranslationError(
    `لقد وصلت إلى الحد الأقصى من الترجمات (${maxTranslations}). يرجى المحاولة لاحقاً.`
   );
   return;
  }

  setIsTranslating(true);
  setTranslationError("");

  try {
   const response = await fetch("/api/translate_professional_summary", {
    method: "POST",
    headers: {
     "Content-Type": "application/json",
     "X-CSRF-Token": document
      .querySelector('meta[name="csrf-token"]')
      ?.getAttribute("content"),
    },
    body: JSON.stringify({
     arabic_text: formData.professional_summary,
     user_id: 1, // You might want to get this from props or context
     resume_id: resume?.id,
    }),
   });

   if (response.ok) {
    const result = await response.json();
    if (result.status === "queued" && result.job_id) {
     // Increment translation count
     setTranslationCount((prev) => prev + 1);
     // Poll for completion
     pollTranslationStatus(result.job_id);
    } else {
     setTranslationError("Unexpected response format from translation API");
     setIsTranslating(false);
    }
   } else {
    throw new Error("Translation request failed");
   }
  } catch (error) {
   console.error("Translation error:", error);
   setTranslationError("حدث خطأ في الترجمة. يرجى المحاولة مرة أخرى.");
   setIsTranslating(false);
  }
 };

 // Robust resume saving function
 const saveResumeToDatabase = async () => {
  console.log("=== SAVING RESUME TO DATABASE ===");
  console.log("Form data:", formData);

  // Validate required fields
  if (!formData.complete_name?.trim()) {
   throw new Error("الاسم الكامل مطلوب");
  }
  if (!formData.email?.trim()) {
   throw new Error("البريد الإلكتروني مطلوب");
  }

  const csrfToken = document
   .querySelector('meta[name="csrf-token"]')
   ?.getAttribute("content");
  if (!csrfToken) {
   throw new Error("رمز الأمان غير موجود");
  }

  // Prepare resume data with all fields
  const resumeData = {
   resume: {
    complete_name: formData.complete_name.trim(),
    email: formData.email.trim(),
    phone_number: formData.phone_number?.trim() || "",
    city: formData.city?.trim() || "",
    country: formData.country?.trim() || "",
    professional_summary: formData.professional_summary?.trim() || "",
    professional_summary_english:
     formData.professional_summary_english?.trim() || "",
    // Always include nested attributes, even if empty
    educations_attributes: formData.education
     .filter(
      (edu) =>
       edu.degree?.trim() && edu.institution?.trim() && edu.start_date?.trim()
     )
     .map((edu, index) => ({
      degree: edu.degree.trim(),
      institution: edu.institution.trim(),
      start_date: edu.start_date.trim(),
      end_date: edu.end_date?.trim() || "",
      gpa: edu.gpa?.trim() || "",
      is_current: edu.is_current || false,
     })),
    work_experiences_attributes: formData.work_experience
     .filter(
      (work) =>
       work.job_title?.trim() && work.company?.trim() && work.start_date?.trim()
     )
     .map((work, index) => ({
      job_title: work.job_title.trim(),
      company: work.company.trim(),
      start_date: work.start_date.trim(),
      end_date: work.end_date?.trim() || "",
      is_current: work.is_current || false,
      responsibilities:
       work.responsibilities?.filter((resp) => resp?.trim()) || [],
     })),
    skills_attributes: formData.skills
     .filter((skill) => skill.category?.trim() && skill.skill_names?.length > 0)
     .map((skill, index) => ({
      category: skill.category.trim(),
      skill_names: skill.skill_names.filter((name) => name?.trim()),
     })),
    certifications_attributes: formData.certifications
     .filter(
      (cert) =>
       cert.name?.trim() && cert.organization?.trim() && cert.date?.trim()
     )
     .map((cert, index) => ({
      name: cert.name.trim(),
      organization: cert.organization.trim(),
      date: cert.date.trim(),
     })),
    languages_attributes: formData.languages
     .filter((lang) => lang.language?.trim() && lang.proficiency?.trim())
     .map((lang, index) => ({
      language: lang.language.trim(),
      proficiency: lang.proficiency.trim(),
     })),
   },
  };

  console.log("Prepared resume data:", resumeData);

  // First try: JSON POST request
  try {
   console.log("Attempting JSON POST to /resumes...");
   const response = await fetch("/resumes", {
    method: "POST",
    headers: {
     "Content-Type": "application/json",
     "X-CSRF-Token": csrfToken,
     Accept: "application/json",
     "Cache-Control": "no-cache",
    },
    credentials: "same-origin",
    body: JSON.stringify(resumeData),
   });

   console.log("JSON POST response status:", response.status);

   if (response.ok) {
    const savedResume = await response.json();
    console.log("✅ JSON POST successful. Resume ID:", savedResume.id);
    return savedResume.id;
   } else {
    const errorText = await response.text();
    console.log("❌ JSON POST failed:", response.status, errorText);
    throw new Error(`HTTP ${response.status}: ${errorText}`);
   }
  } catch (jsonError) {
   console.log("❌ JSON POST error:", jsonError);

   // Second try: Form submission with FormData
   try {
    console.log("Attempting FormData POST to /resumes...");
    const formDataToSubmit = new FormData();

    // Add CSRF token
    formDataToSubmit.append("authenticity_token", csrfToken);

    // Add main resume fields
    formDataToSubmit.append(
     "resume[complete_name]",
     formData.complete_name.trim()
    );
    formDataToSubmit.append("resume[email]", formData.email.trim());
    formDataToSubmit.append(
     "resume[phone_number]",
     formData.phone_number?.trim() || ""
    );
    formDataToSubmit.append("resume[city]", formData.city?.trim() || "");
    formDataToSubmit.append("resume[country]", formData.country?.trim() || "");
    formDataToSubmit.append(
     "resume[professional_summary]",
     formData.professional_summary?.trim() || ""
    );
    formDataToSubmit.append(
     "resume[professional_summary_english]",
     formData.professional_summary_english?.trim() || ""
    );

    // Add nested attributes
    resumeData.resume.educations_attributes.forEach((edu, index) => {
     formDataToSubmit.append(
      `resume[educations_attributes][${index}][degree]`,
      edu.degree
     );
     formDataToSubmit.append(
      `resume[educations_attributes][${index}][institution]`,
      edu.institution
     );
     formDataToSubmit.append(
      `resume[educations_attributes][${index}][start_date]`,
      edu.start_date
     );
     if (edu.end_date)
      formDataToSubmit.append(
       `resume[educations_attributes][${index}][end_date]`,
       edu.end_date
      );
     if (edu.gpa)
      formDataToSubmit.append(
       `resume[educations_attributes][${index}][gpa]`,
       edu.gpa
      );
     formDataToSubmit.append(
      `resume[educations_attributes][${index}][is_current]`,
      edu.is_current
     );
    });

    resumeData.resume.work_experiences_attributes.forEach((work, index) => {
     formDataToSubmit.append(
      `resume[work_experiences_attributes][${index}][job_title]`,
      work.job_title
     );
     formDataToSubmit.append(
      `resume[work_experiences_attributes][${index}][company]`,
      work.company
     );
     formDataToSubmit.append(
      `resume[work_experiences_attributes][${index}][start_date]`,
      work.start_date
     );
     if (work.end_date)
      formDataToSubmit.append(
       `resume[work_experiences_attributes][${index}][end_date]`,
       work.end_date
      );
     formDataToSubmit.append(
      `resume[work_experiences_attributes][${index}][is_current]`,
      work.is_current || false
     );
     work.responsibilities.forEach((resp, respIndex) => {
      formDataToSubmit.append(
       `resume[work_experiences_attributes][${index}][responsibilities][]`,
       resp
      );
     });
    });

    resumeData.resume.skills_attributes.forEach((skill, index) => {
     formDataToSubmit.append(
      `resume[skills_attributes][${index}][category]`,
      skill.category
     );
     skill.skill_names.forEach((skillName, skillIndex) => {
      formDataToSubmit.append(
       `resume[skills_attributes][${index}][skill_names][]`,
       skillName
      );
     });
    });

    resumeData.resume.certifications_attributes.forEach((cert, index) => {
     formDataToSubmit.append(
      `resume[certifications_attributes][${index}][name]`,
      cert.name
     );
     formDataToSubmit.append(
      `resume[certifications_attributes][${index}][organization]`,
      cert.organization
     );
     formDataToSubmit.append(
      `resume[certifications_attributes][${index}][date]`,
      cert.date
     );
    });

    resumeData.resume.languages_attributes.forEach((lang, index) => {
     formDataToSubmit.append(
      `resume[languages_attributes][${index}][language]`,
      lang.language
     );
     formDataToSubmit.append(
      `resume[languages_attributes][${index}][proficiency]`,
      lang.proficiency
     );
    });

    const response = await fetch("/resumes", {
     method: "POST",
     body: formDataToSubmit,
     headers: {
      "X-CSRF-Token": csrfToken,
      Accept: "application/json",
     },
     credentials: "same-origin",
    });

    console.log("FormData POST response status:", response.status);

    if (response.ok) {
     const result = await response.json();
     console.log("✅ FormData POST successful. Resume ID:", result.id);
     return result.id;
    } else {
     const errorText = await response.text();
     console.log("❌ FormData POST failed:", response.status, errorText);
     throw new Error(`FormData HTTP ${response.status}: ${errorText}`);
    }
   } catch (formError) {
    console.log("❌ FormData POST error:", formError);
    throw new Error(
     `Both JSON and FormData submissions failed. Last error: ${formError.message}`
    );
   }
  }
 };

 const exportToPDF = async () => {
  console.log(
   "ATS-compliant PDF export button clicked! Current step:",
   currentStep
  );
  setIsExporting(true);
  setTranslationError("");

  try {
   console.log("Starting ATS-compliant PDF export process...");

   let resumeId = null;

   // Step 1: Always save the resume to database first
   try {
    console.log("Step 1: Saving resume to database...");
    resumeId = await saveResumeToDatabase();
    console.log("✅ Resume saved successfully with ID:", resumeId);

    // Show success message in console (less intrusive than alert)
    setTranslationError(""); // Clear any errors
    console.log(
     "🎉 تم حفظ السيرة الذاتية بنجاح! يمكنك الآن استخدامها لإنشاء سير ذاتية مخصصة."
    );
   } catch (saveError) {
    console.log("❌ Resume save failed:", saveError.message);

    // Validate required fields for PDF generation even if save fails
    if (!formData.complete_name?.trim() || !formData.email?.trim()) {
     alert("يرجى ملء الاسم الكامل والبريد الإلكتروني قبل التصدير");
     setIsExporting(false);
     return;
    }

    // Still try to export PDF even if save fails
    console.log("Continuing with PDF export from form data...");
   }

   // Export the PDF - either with saved resume ID or directly from form data
   console.log("Making PDF export request (background job)...");
   let response;

   if (resumeId) {
    // Use saved resume - attempt direct download first
    try {
     // Create a download link and trigger it directly - most reliable method
     const downloadUrl = `/api/export_pdf?resume_id=${resumeId}&direct_download=true&t=${Date.now()}`;

     // Use fetch + Blob approach which is more reliable for binary data
     const response = await fetch(downloadUrl);
     if (!response.ok) {
      throw new Error(`HTTP error: ${response.status}`);
     }

     // Create a Blob from the binary PDF data
     const blob = await response.blob();

     // Create a download link with the Blob URL
     const blobUrl = URL.createObjectURL(blob);
     const link = document.createElement("a");
     link.href = blobUrl;
     link.download = `resume_${resumeId}.pdf`;
     document.body.appendChild(link);
     link.click();

     // Clean up the Blob URL after download starts
     setTimeout(() => URL.revokeObjectURL(blobUrl), 100);

     // Clean up
     setTimeout(() => {
      document.body.removeChild(link);
      setExportStatus("completed");
      setIsExporting(false);
     }, 2000);

     // Return early as the download should be initiated
     return;
    } catch (e) {
     console.error("Direct download failed, falling back to JSON response:", e);
     // Fall back to the fetch + Blob approach which is more reliable in modern browsers
     response = await fetch(
      `/api/export_pdf?resume_id=${resumeId}&direct_download=true`,
      {
       method: "GET",
       headers: {
        "X-CSRF-Token": document
         .querySelector('meta[name="csrf-token"]')
         ?.getAttribute("content"),
       },
      }
     );

     // If we got binary data back, use Blob to trigger download
     if (response.ok) {
      try {
       const blob = await response.blob();
       const url = window.URL.createObjectURL(blob);
       const link = document.createElement("a");
       link.href = url;
       link.setAttribute("download", `resume_${resumeId}.pdf`);
       document.body.appendChild(link);
       link.click();
       link.parentNode.removeChild(link);
       window.URL.revokeObjectURL(url);
       setExportStatus("completed");
       setIsExporting(false);
       return;
      } catch (blobError) {
       console.error("Blob download failed:", blobError);
      }
     }
    }
   } else {
    // Export directly from form data
    response = await fetch("/api/export_pdf", {
     method: "POST",
     headers: {
      "Content-Type": "application/json",
      "X-CSRF-Token": document
       .querySelector('meta[name="csrf-token"]')
       ?.getAttribute("content"),
     },
     body: JSON.stringify({
      resume: {
       complete_name: formData.complete_name,
       email: formData.email,
       phone_number: formData.phone_number,
       city: formData.city,
       country: formData.country,
       professional_summary: formData.professional_summary,
       professional_summary_english: formData.professional_summary_english,
       educations_attributes: formData.education
        .filter(
         (edu) =>
          edu.degree.trim() !== "" &&
          edu.institution.trim() !== "" &&
          edu.start_date.trim() !== ""
        )
        .map((edu) => ({
         degree: edu.degree,
         institution: edu.institution,
         start_date: edu.start_date,
         end_date: edu.end_date,
         gpa: edu.gpa,
         is_current: edu.is_current,
        })),
       work_experiences_attributes: formData.work_experience
        .filter(
         (work) =>
          work.job_title.trim() !== "" &&
          work.company.trim() !== "" &&
          work.start_date.trim() !== ""
        )
        .map((work) => ({
         job_title: work.job_title,
         company: work.company,
         start_date: work.start_date,
         end_date: work.end_date,
         is_current: work.is_current,
         responsibilities: work.responsibilities.filter(
          (resp) => resp.trim() !== ""
         ),
        })),
       skills_attributes: formData.skills
        .filter(
         (skill) =>
          skill.category.trim() !== "" &&
          skill.skill_names.some((name) => name.trim() !== "")
        )
        .map((skill) => ({
         category: skill.category,
         skill_names: skill.skill_names.filter((name) => name.trim() !== ""),
        })),
       certifications_attributes: formData.certifications
        .filter(
         (cert) =>
          cert.name.trim() !== "" &&
          cert.organization.trim() !== "" &&
          cert.date.trim() !== ""
        )
        .map((cert) => ({
         name: cert.name,
         organization: cert.organization,
         date: cert.date,
        })),
       languages_attributes: formData.languages
        .filter(
         (lang) => lang.language.trim() !== "" && lang.proficiency.trim() !== ""
        )
        .map((lang) => ({
         language: lang.language,
         proficiency: lang.proficiency,
        })),
      },
     }),
    });
   }
   console.log("Background job response status:", response.status);

   if (response.ok) {
    // Parse the JSON response containing job information
    const jobInfo = await response.json();
    console.log("PDF generation job started:", jobInfo);

    if (jobInfo.job_id && jobInfo.token) {
     // Poll for job completion
     setExportStatus("processing");

     // Set up polling interval
     const pollingInterval = setInterval(async () => {
      try {
       const statusUrl = `/api/pdf_status?job_id=${jobInfo.job_id}&token=${jobInfo.token}`;
       console.log("Checking PDF status at:", statusUrl);

       const statusResponse = await fetch(statusUrl, {
        headers: {
         "X-CSRF-Token": document
          .querySelector('meta[name="csrf-token"]')
          ?.getAttribute("content"),
        },
       });

       if (statusResponse.ok) {
        const statusInfo = await statusResponse.json();
        console.log("PDF job status response:", statusInfo);

        if (statusInfo.status === "completed") {
         // Job is complete, download the PDF
         clearInterval(pollingInterval);

         console.log(
          "PDF is ready for download, URL:",
          statusInfo.download_url
         );

         // Trigger the download using a hidden iframe to avoid page navigation
         const downloadFrame = document.createElement("iframe");
         downloadFrame.style.display = "none";
         document.body.appendChild(downloadFrame);

         // Add event listener to clean up after download starts
         downloadFrame.onload = () => {
          // Give browser time to process the download
          setTimeout(() => {
           document.body.removeChild(downloadFrame);
          }, 2000);
         };

         // Make sure we use the complete URL as returned from the server
         // Check if the download URL is relative (starts with /) or absolute
         const downloadUrl = statusInfo.download_url.startsWith("/")
          ? `${window.location.origin}${statusInfo.download_url}`
          : statusInfo.download_url;

         console.log("Setting iframe src to:", downloadUrl);
         downloadFrame.src = downloadUrl;
         setExportStatus("completed");
         setIsExporting(false);
        } else if (statusInfo.status === "failed") {
         // Job failed
         clearInterval(pollingInterval);
         setExportStatus("failed");
         setTranslationError(
          "فشل إنشاء ملف PDF. يرجى المحاولة مرة أخرى لاحقًا."
         );
         setIsExporting(false);
        }
        // Otherwise continue polling
       } else {
        console.error(
         "Error checking job status:",
         await statusResponse.text()
        );
       }
      } catch (error) {
       console.error("Error during status polling:", error);
      }
     }, 2000); // Check every 2 seconds

     // Set timeout to stop polling after 2 minutes
     setTimeout(() => {
      clearInterval(pollingInterval);
      if (setExportStatus === "processing") {
       setExportStatus("timeout");
       setTranslationError(
        "انتهت مهلة إنشاء ملف PDF. يرجى المحاولة مرة أخرى لاحقًا."
       );
       setIsExporting(false);
      }
     }, 120000);
    } else {
     throw new Error("Job information missing from response");
    }
   } else {
    const errorText = await response.text();
    console.log("Error response:", errorText);
    throw new Error("PDF export failed");
   }
  } catch (error) {
   console.error("PDF export error:", error);
   setTranslationError("حدث خطأ في تصدير PDF. يرجى المحاولة مرة أخرى.");
  } finally {
   setIsExporting(false);
  }
 };

 const saveDraft = async (stepNumber = currentStep) => {
  setIsSavingDraft(true);
  try {
   const draftData = {
    complete_name: formData.complete_name,
    email: formData.email,
    phone_number: formData.phone_number,
    city: formData.city,
    country: formData.country,
    professional_summary: formData.professional_summary,
    professional_summary_english: formData.professional_summary_english,
    education: JSON.stringify(formData.education),
    work_experience: JSON.stringify(formData.work_experience),
    skills: JSON.stringify(formData.skills),
    certifications: JSON.stringify(formData.certifications),
    languages: JSON.stringify(formData.languages),
    current_step: stepNumber,
    saved_at: new Date().toISOString(),
   };

   const response = await fetch(`/resumes/${resume?.id || "new"}/save_draft`, {
    method: "POST",
    headers: {
     "Content-Type": "application/x-www-form-urlencoded",
     "X-CSRF-Token": document
      .querySelector('meta[name="csrf-token"]')
      .getAttribute("content"),
     Accept: "application/json",
    },
    body: new URLSearchParams(draftData),
   });

   if (response.ok) {
    const result = await response.json();
    console.log("✅ Draft saved successfully at step:", stepNumber, result);
    alert(
     `تم حفظ المسودة بنجاح في الخطوة ${stepNumber}! يمكنك العودة إليها لاحقاً.`
    );
   } else {
    console.error("❌ Failed to save draft");
    alert("حدث خطأ أثناء حفظ المسودة");
   }
  } catch (error) {
   console.error("❌ Error saving draft:", error);
   alert("حدث خطأ أثناء حفظ المسودة: " + error.message);
  } finally {
   setIsSavingDraft(false);
  }
 };

 // Helper function to render save draft button
 const renderSaveDraftButton = (stepNumber) => (
  <div className="mt-4 sm:mt-6 pt-4 border-t border-slate-200/60">
   <button
    type="button"
    onClick={() => saveDraft(stepNumber)}
    disabled={isSavingDraft}
    className="w-full sm:w-auto inline-flex items-center justify-center gap-2 rounded-lg bg-slate-600 px-6 py-3 text-sm font-medium text-white ring-1 ring-black/5 transition-all hover:bg-slate-700 hover:shadow disabled:opacity-50 disabled:cursor-not-allowed"
   >
    {isSavingDraft ? (
     <>
      <svg
       className="animate-spin -ml-1 mr-2 h-4 w-4 text-white"
       xmlns="http://www.w3.org/2000/svg"
       fill="none"
       viewBox="0 0 24 24"
      >
       <circle
        className="opacity-25"
        cx="12"
        cy="12"
        r="10"
        stroke="currentColor"
        strokeWidth="4"
       ></circle>
       <path
        className="opacity-75"
        fill="currentColor"
        d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
       ></path>
      </svg>
      جاري الحفظ...
     </>
    ) : (
     <>
      <svg
       className="w-4 h-4"
       fill="none"
       stroke="currentColor"
       viewBox="0 0 24 24"
      >
       <path
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={2}
        d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3-3m0 0l-3 3m3-3v12"
       />
      </svg>
      حفظ المسودة - الخطوة {stepNumber}
     </>
    )}
   </button>
  </div>
 );

 const pollTranslationStatus = async (jobId) => {
  const maxAttempts = 30; // 30 seconds max
  let attempts = 0;

  const poll = async () => {
   try {
    const response = await fetch(`/api/translation_status/${jobId}?user_id=1`);
    if (response.ok) {
     const status = await response.json();

     if (status.status === "completed") {
      // Convert extracted skills to the skills section format
      const extractedSkills = status.skills_extracted || [];

      // Group skills by category to avoid duplicates
      const skillsByCategory = {};
      extractedSkills.forEach((skill) => {
       const category = skill.category || "technical";
       if (!skillsByCategory[category]) {
        skillsByCategory[category] = [];
       }
       skillsByCategory[category].push(skill.name);
      });

      // Convert grouped skills to the skills section format
      const newSkills = Object.entries(skillsByCategory).map(
       ([category, skillNames]) => ({
        category: category,
        skill_names: skillNames,
       })
      );

      setFormData((prev) => {
       // Merge new skills with existing skills by category
       const existingSkills = [...prev.skills];

       newSkills.forEach((newSkill) => {
        const existingCategoryIndex = existingSkills.findIndex(
         (existing) => existing.category === newSkill.category
        );

        if (existingCategoryIndex >= 0) {
         // Merge with existing category
         const existingSkill = existingSkills[existingCategoryIndex];
         const mergedSkillNames = [
          ...new Set([...existingSkill.skill_names, ...newSkill.skill_names]),
         ];
         existingSkills[existingCategoryIndex] = {
          ...existingSkill,
          skill_names: mergedSkillNames,
         };
        } else {
         // Add new category
         existingSkills.push(newSkill);
        }
       });

       return {
        ...prev,
        professional_summary_english: status.english_text,
        skills_extracted: extractedSkills,
        translation_notes: status.translation_notes || "",
        skills: existingSkills,
       };
      });

      // Show success message about skills being added
      if (newSkills.length > 0) {
       setTranslationError(""); // Clear any previous errors
       // You could add a success state here if you want to show a success message
      }

      setIsTranslating(false);
      return;
     } else if (status.status === "failed") {
      setTranslationError("فشلت الترجمة. يرجى المحاولة مرة أخرى.");
      setIsTranslating(false);
      return;
     }
    }

    attempts++;
    if (attempts < maxAttempts) {
     setTimeout(poll, 1000); // Poll every second
    } else {
     setTranslationError("انتهت مهلة الترجمة. يرجى المحاولة مرة أخرى.");
     setIsTranslating(false);
    }
   } catch (error) {
    console.error("Polling error:", error);
    attempts++;
    if (attempts < maxAttempts) {
     setTimeout(poll, 1000);
    } else {
     setTranslationError("انتهت مهلة الترجمة. يرجى المحاولة مرة أخرى.");
     setIsTranslating(false);
    }
   }
  };

  poll();
 };

 const addLanguage = () => {
  setFormData((prev) => ({
   ...prev,
   languages: [
    ...prev.languages,
    {
     language: "",
     proficiency: "",
    },
   ],
  }));
 };

 const removeLanguage = (index) => {
  if (formData.languages.length > 1) {
   setFormData((prev) => ({
    ...prev,
    languages: prev.languages.filter((_, i) => i !== index),
   }));
  }
 };

 const nextStep = () => {
  if (currentStep < totalSteps) {
   const newStep = currentStep + 1;
   setCurrentStep(newStep);

   // Update URL with new step parameter
   const url = new URL(window.location);
   url.searchParams.set("step", newStep);
   window.history.pushState({}, "", url);
  }
 };

 const prevStep = () => {
  if (currentStep > 1) {
   const newStep = currentStep - 1;
   setCurrentStep(newStep);

   // Update URL with new step parameter
   const url = new URL(window.location);
   url.searchParams.set("step", newStep);
   window.history.pushState({}, "", url);
  }
 };

 const handleSubmit = (e) => {
  e.preventDefault();

  // Validate form data
  if (
   !formData.complete_name ||
   !formData.email ||
   !formData.phone_number ||
   !formData.city ||
   !formData.country ||
   !formData.professional_summary
  ) {
   alert("يرجى ملء جميع الحقول المطلوبة");
   return;
  }

  // Validate education data
  const hasValidEducation = formData.education.some(
   (edu) => edu.degree && edu.institution && edu.start_date
  );

  if (!hasValidEducation) {
   alert("يرجى إدخال معلومات تعليمية واحدة على الأقل");
   return;
  }

  // Validate work experience data
  const hasValidWorkExperience = formData.work_experience.some(
   (work) => work.job_title && work.company && work.start_date
  );

  if (!hasValidWorkExperience) {
   alert("يرجى إدخال خبرة عمل واحدة على الأقل");
   return;
  }

  // Validate skills data
  const hasValidSkills = formData.skills.some(
   (skill) =>
    skill.category && skill.skill_names.some((name) => name.trim() !== "")
  );

  if (!hasValidSkills) {
   alert("يرجى إدخال مهارة واحدة على الأقل");
   return;
  }

  // Validate certifications data
  const hasValidCertifications = formData.certifications.some(
   (cert) => cert.name && cert.organization && cert.date
  );

  if (!hasValidCertifications) {
   alert("يرجى إدخال شهادة واحدة على الأقل");
   return;
  }

  // Validate languages data
  const hasValidLanguages = formData.languages.some(
   (lang) => lang.language && lang.proficiency
  );

  if (!hasValidLanguages) {
   alert("يرجى إدخال لغة واحدة على الأقل");
   return;
  }

  console.log("Form data before submission:", formData);

  if (onSubmit) {
   // Transform form data to Rails parameter format
   const railsFormData = {
    "resume[complete_name]": formData.complete_name,
    "resume[email]": formData.email,
    "resume[phone_number]": formData.phone_number,
    "resume[city]": formData.city,
    "resume[country]": formData.country,
    "resume[professional_summary]": formData.professional_summary,
    "resume[professional_summary_english]":
     formData.professional_summary_english,
    "resume[educations_attributes]": formData.education
     .filter(
      (edu) =>
       edu.degree.trim() !== "" &&
       edu.institution.trim() !== "" &&
       edu.start_date.trim() !== ""
     )
     .map((edu) => ({
      degree: edu.degree,
      institution: edu.institution,
      start_date: edu.start_date,
      end_date: edu.end_date,
      gpa: edu.gpa,
      is_current: edu.is_current,
     })),
    "resume[work_experiences_attributes]": formData.work_experience
     .filter(
      (work) =>
       work.job_title.trim() !== "" &&
       work.company.trim() !== "" &&
       work.start_date.trim() !== ""
     )
     .map((work) => ({
      job_title: work.job_title,
      company: work.company,
      start_date: work.start_date,
      end_date: work.end_date,
      is_current: work.is_current,
      responsibilities: work.responsibilities.filter(
       (resp) => resp.trim() !== ""
      ),
     })),
    "resume[skills_attributes]": formData.skills
     .filter(
      (skill) =>
       skill.category.trim() !== "" &&
       skill.skill_names.some((name) => name.trim() !== "")
     )
     .map((skill) => ({
      category: skill.category,
      skill_names: skill.skill_names.filter((name) => name.trim() !== ""),
     })),
    "resume[certifications_attributes]": formData.certifications
     .filter(
      (cert) =>
       cert.name.trim() !== "" &&
       cert.organization.trim() !== "" &&
       cert.date.trim() !== ""
     )
     .map((cert) => ({
      name: cert.name,
      organization: cert.organization,
      date: cert.date,
     })),
    "resume[languages_attributes]": formData.languages
     .filter(
      (lang) => lang.language.trim() !== "" && lang.proficiency.trim() !== ""
     )
     .map((lang) => ({
      language: lang.language,
      proficiency: lang.proficiency,
     })),
   };

   console.log("Rails form data:", railsFormData);
   onSubmit(railsFormData);
  }
 };

 const renderStep1 = () => (
  <div className="space-y-6">
   <div className="text-center mb-6">
    <div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-emerald-100 text-emerald-600 mb-4">
     <svg
      className="w-8 h-8"
      fill="none"
      stroke="currentColor"
      viewBox="0 0 24 24"
     >
      <path
       strokeLinecap="round"
       strokeLinejoin="round"
       strokeWidth={2}
       d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
      />
     </svg>
    </div>
    <h2 className="text-xl font-semibold text-slate-900">المعلومات الشخصية</h2>
    <p className="text-slate-600 mt-2">ابدأ بإدخال معلوماتك الشخصية الأساسية</p>
   </div>

   <div className="grid gap-6">
    <div>
     <label className="block text-sm font-semibold text-slate-900 mb-2">
      الاسم الكامل
     </label>
     <input
      type="text"
      value={formData.complete_name}
      onChange={(e) => handleInputChange("complete_name", e.target.value)}
      className="w-full rounded-lg border border-slate-300/70 bg-white/70 px-4 py-3 text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/40 focus:border-emerald-400 ring-1 ring-black/5 transition-all"
      placeholder="مثال: Ahmed Ali"
     />
     <p className="mt-2 text-xs text-slate-500">أدخل اسمك الكامل</p>
    </div>

    <div>
     <label className="block text-sm font-semibold text-slate-900 mb-2">
      البريد الإلكتروني
     </label>
     <input
      type="email"
      value={formData.email}
      onChange={(e) => handleInputChange("email", e.target.value)}
      className="w-full rounded-lg border border-slate-300/70 bg-white/70 px-4 py-3 text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/40 focus:border-emerald-400 ring-1 ring-black/5 transition-all"
      placeholder="مثال: ahmed@example.com"
     />
     <p className="mt-2 text-xs text-slate-500">
      البريد الإلكتروني المستخدم للتواصل المهني
     </p>
    </div>

    <div>
     <label className="block text-sm font-semibold text-slate-900 mb-2">
      رقم الهاتف
     </label>
     <input
      type="tel"
      value={formData.phone_number}
      onChange={(e) => handleInputChange("phone_number", e.target.value)}
      className="w-full rounded-lg border border-slate-300/70 bg-white/70 px-4 py-3 text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/40 focus:border-emerald-400 ring-1 ring-black/5 transition-all"
      placeholder="مثال: +966501234567"
     />
     <p className="mt-2 text-xs text-slate-500">رقم الهاتف مع رمز الدولة</p>
    </div>

    <div className="grid grid-cols-2 gap-4">
     <div>
      <label className="block text-sm font-semibold text-slate-900 mb-2">
       المدينة
      </label>
      <input
       type="text"
       value={formData.city}
       onChange={(e) => handleInputChange("city", e.target.value)}
       className="w-full rounded-lg border border-slate-300/70 bg-white/70 px-4 py-3 text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/40 focus:border-emerald-400 ring-1 ring-black/5 transition-all"
       placeholder="مثال: Riyadh"
      />
     </div>

     <div>
      <label className="block text-sm font-semibold text-slate-900 mb-2">
       الدولة
      </label>
      <input
       type="text"
       value={formData.country}
       onChange={(e) => handleInputChange("country", e.target.value)}
       className="w-full rounded-lg border border-slate-300/70 bg-white/70 px-4 py-3 text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/40 focus:border-emerald-400 ring-1 ring-black/5 transition-all"
       placeholder="مثال: Saudi Arabia"
      />
     </div>
    </div>
   </div>

   {renderSaveDraftButton(1)}
  </div>
 );

 const renderStep2 = () => (
  <div className="space-y-6">
   <div className="text-center mb-6">
    <div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-emerald-100 text-emerald-600 mb-4">
     <svg
      className="w-8 h-8"
      fill="none"
      stroke="currentColor"
      viewBox="0 0 24 24"
     >
      <path
       strokeLinecap="round"
       strokeLinejoin="round"
       strokeWidth={2}
       d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
      />
     </svg>
    </div>
    <h2 className="text-xl font-semibold text-slate-900">الملخص المهني</h2>
    <p className="text-slate-600 mt-2">
     اكتب ملخصًا مهنيًا مقنعًا يصف خبراتك وأهدافك
    </p>
   </div>

   <div className="space-y-4">
    <div>
     <label className="block text-sm font-semibold text-slate-900 mb-2">
      الملخص المهني (بالعربية)
     </label>
     <textarea
      value={formData.professional_summary}
      onChange={(e) =>
       handleInputChange("professional_summary", e.target.value)
      }
      rows={6}
      className="w-full rounded-lg border border-slate-300/70 bg-white/70 px-4 py-3 text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/40 focus:border-emerald-400 ring-1 ring-black/5 transition-all resize-none"
      placeholder="اكتب ملخصًا مهنيًا مقنعًا يصف خلفيتك المهنية وخبراتك ومهاراتك وأهدافك الوظيفية. يجب أن يكون 3-5 جمل تعطي صورة واضحة عنك كمحترف..."
     />
     <p className="mt-2 text-xs text-slate-500">
      اكتب 3-5 جمل تصف خلفيتك المهنية وخبراتك ومهاراتك وأهدافك الوظيفية
     </p>
     <p className="mt-2 text-xs text-blue-600 bg-blue-50 p-2 rounded border border-blue-200">
      💡 <strong>ملاحظة:</strong> سيقوم النظام بترجمة النص العربي إلى الإنجليزية{" "}
      <strong>وإنشاء</strong> ملخص مهني شامل ومحسن لسيرتك الذاتية
     </p>
    </div>

    {/* Translation Button */}
    <div className="text-center">
     <button
      type="button"
      onClick={translateProfessionalSummary}
      disabled={
       isTranslating ||
       !formData.professional_summary.trim() ||
       translationCount >= maxTranslations
      }
      className="inline-flex items-center gap-2 rounded-lg bg-blue-600 text-white px-6 py-3 text-sm font-medium hover:bg-blue-700 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
     >
      {isTranslating ? (
       <>
        <svg
         className="animate-spin -ml-1 mr-3 h-5 w-5 text-white"
         xmlns="http://www.w3.org/2000/svg"
         fill="none"
         viewBox="0 0 24 24"
        >
         <circle
          className="opacity-25"
          cx="12"
          cy="12"
          r="10"
          stroke="currentColor"
          strokeWidth="4"
         ></circle>
         <path
          className="opacity-75"
          fill="currentColor"
          d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
         ></path>
        </svg>
        جاري الترجمة...
       </>
      ) : (
       <>
        <svg
         className="w-5 h-5"
         fill="none"
         stroke="currentColor"
         viewBox="0 0 24 24"
        >
         <path
          strokeLinecap="round"
          strokeLinejoin="round"
          strokeWidth={2}
          d="M3 5h12M9 3v2m1.048 9.5A18.022 18.022 0 016.412 9m6.088 9h7M11 21l5-10 5 10M12.751 5C11.783 10.77 8.07 15.61 3 18.129"
         />
        </svg>
        ترجم وأنشئ ملخص مهني ({maxTranslations - translationCount} متبقي)
       </>
      )}
     </button>

     {/* Translation limit info */}
     <div className="mt-2 text-xs text-slate-500">
      الترجمات المستخدمة: {translationCount} من {maxTranslations}
     </div>
    </div>

    {/* Translation Error */}
    {translationError && (
     <div className="p-3 border border-red-200 rounded-lg bg-red-50">
      <p className="text-sm text-red-600 text-center">{translationError}</p>
     </div>
    )}

    {/* English Translation Result */}
    {formData.professional_summary_english && (
     <div className="space-y-3">
      <label className="block text-sm font-semibold text-slate-900 mb-2">
       الملخص المهني (بالإنجليزية)
      </label>
      <div className="p-4 border border-slate-200/60 rounded-lg bg-slate-50/50">
       <p className="text-slate-700 leading-relaxed text-left" dir="ltr">
        {formData.professional_summary_english}
       </p>
      </div>

      {/* Skills Extracted */}
      {formData.skills_extracted && formData.skills_extracted.length > 0 && (
       <div className="space-y-2">
        <h4 className="text-sm font-medium text-slate-900">
         المهارات المستخرجة:
        </h4>
        <div className="flex flex-wrap gap-2">
         {formData.skills_extracted.map((skill, index) => (
          <span
           key={index}
           className="px-3 py-1 text-xs bg-blue-100 text-blue-800 rounded-full border border-blue-200"
          >
           {skill.name} ({skill.level})
          </span>
         ))}
        </div>
       </div>
      )}

      {/* Translation Notes */}
      {formData.translation_notes && (
       <div className="p-3 bg-amber-50 border border-amber-200 rounded-lg">
        <h4 className="text-sm font-medium text-amber-800 mb-1">
         ملاحظات الترجمة:
        </h4>
        <p className="text-xs text-amber-700">{formData.translation_notes}</p>
       </div>
      )}

      <p className="text-xs text-slate-500 text-center">
       تم ترجمة النص العربي وإنشاء هذا الملخص المهني المحسن باستخدام الذكاء
       الاصطناعي
      </p>
     </div>
    )}

    <div className="p-4 border border-slate-200/60 rounded-lg bg-slate-50/50">
     <h3 className="text-sm font-medium text-slate-900 mb-2">
      نصائح لكتابة ملخص مهني قوي:
     </h3>
     <ul className="text-xs text-slate-600 space-y-1">
      <li>• ابدأ بوصف هويتك المهنية وعدد سنوات الخبرة</li>
      <li>• اذكر مجالات التخصص والمهارات الرئيسية</li>
      <li>• وضح الإنجازات المهمة والمسؤوليات</li>
      <li>• اختتم بأهدافك الوظيفية القصيرة والطويلة المدى</li>
     </ul>
    </div>
   </div>

   {renderSaveDraftButton(2)}
  </div>
 );

 const renderStep3 = () => (
  <div className="space-y-6">
   <div className="text-center mb-6">
    <div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-emerald-100 text-emerald-600 mb-4">
     <svg
      className="w-8 h-8"
      fill="none"
      stroke="currentColor"
      viewBox="0 0 24 24"
     >
      <path
       strokeLinecap="round"
       strokeLinejoin="round"
       strokeWidth={2}
       d="M12 14l9-5-9-5-9 5 9 5z"
      />
      <path
       strokeLinecap="round"
       strokeLinejoin="round"
       strokeWidth={2}
       d="M12 14l6.16-3.422a12.083 12.083 0 01.665 6.479A11.952 11.952 0 0012 20.055a11.952 11.952 0 00-6.824-1.998 12.078 12.078 0 01.665-6.479L12 14z"
      />
      <path
       strokeLinecap="round"
       strokeLinejoin="round"
       strokeWidth={2}
       d="M12 14l9-5-9-5-9 5 9 5zm0 0l6.16-3.422a12.083 12.083 0 01.665 6.479A11.952 11.952 0 0012 20.055a11.952 11.952 0 00-6.824-1.998 12.078 12.078 0 01.665-6.479L12 14z"
      />
     </svg>
    </div>
    <h2 className="text-xl font-semibold text-slate-900">التعليم</h2>
    <p className="text-slate-600 mt-2">
     أضف معلوماتك التعليمية والخبرات الأكاديمية
    </p>
   </div>

   <div className="space-y-6">
    {formData.education.map((edu, index) => (
     <div
      key={index}
      className="p-6 border border-slate-200/60 rounded-lg bg-slate-50/50"
     >
      <div className="flex items-center justify-between mb-4">
       <h3 className="text-lg font-semibold text-slate-900">
        {index === 0 ? "التعليم الأساسي" : `التعليم الإضافي ${index + 1}`}
       </h3>
       {formData.education.length > 1 && (
        <button
         type="button"
         onClick={() => removeEducation(index)}
         className="text-red-500 hover:text-red-700 text-sm font-medium"
        >
         حذف
        </button>
       )}
      </div>

      <div className="grid gap-4">
       <div>
        <label className="block text-sm font-semibold text-slate-900 mb-2">
         الدرجة العلمية
        </label>
        <input
         type="text"
         value={edu.degree}
         onChange={(e) =>
          handleEducationChange(index, "degree", e.target.value)
         }
         className="w-full rounded-lg border border-slate-300/70 bg-white/70 px-4 py-3 text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/40 focus:border-emerald-400 ring-1 ring-black/5 transition-all"
         placeholder="مثال: Bachelor of Computer Science"
        />
       </div>

       <div>
        <label className="block text-sm font-semibold text-slate-900 mb-2">
         المؤسسة التعليمية
        </label>
        <input
         type="text"
         value={edu.institution}
         onChange={(e) =>
          handleEducationChange(index, "institution", e.target.value)
         }
         className="w-full rounded-lg border border-slate-300/70 bg-white/70 px-4 py-3 text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/40 focus:border-emerald-400 ring-1 ring-black/5 transition-all"
         placeholder="مثال: King Fahd University of Petroleum and Minerals"
        />
       </div>

       <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div>
         <label className="block text-sm font-semibold text-slate-900 mb-2">
          تاريخ البداية
         </label>
         <MobileDatePicker
          value={edu.start_date}
          onChange={(value) =>
           handleEducationChange(index, "start_date", value)
          }
          placeholder="اختر تاريخ البداية"
         />
        </div>

        <div>
         <label className="block text-sm font-semibold text-slate-900 mb-2">
          تاريخ النهاية
         </label>
         <MobileDatePicker
          value={edu.end_date}
          onChange={(value) => handleEducationChange(index, "end_date", value)}
          disabled={edu.is_current}
          placeholder="اختر تاريخ النهاية"
         />
        </div>
       </div>

       <div className="space-y-4">
        <div>
         <label className="block text-sm font-semibold text-slate-900 mb-2">
          التقدير (GPA)
         </label>
         <input
          type="text"
          value={edu.gpa}
          onChange={(e) => handleEducationChange(index, "gpa", e.target.value)}
          className="w-full rounded-lg border border-slate-300/70 bg-white/70 px-4 py-4 text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/40 focus:border-emerald-400 ring-1 ring-black/5 transition-all text-base"
          placeholder="مثال: 3.8/4.0"
          style={{
           fontSize: "16px", // Prevents zoom on iOS
           minHeight: "48px", // Better touch target
          }}
         />
        </div>

        <div className="flex items-center justify-center sm:justify-start">
         <label className="flex items-center cursor-pointer">
          <input
           type="checkbox"
           checked={edu.is_current}
           onChange={(e) =>
            handleEducationChange(index, "is_current", e.target.checked)
           }
           className="w-6 h-6 text-emerald-600 bg-white border-2 border-slate-300 rounded focus:ring-emerald-500 focus:ring-2 transition-all"
          />
          <span className="ml-4 text-base font-medium text-slate-900">
           دراسة حالية
          </span>
         </label>
        </div>
       </div>
      </div>
     </div>
    ))}

    <div className="text-center">
     <button
      type="button"
      onClick={addEducation}
      className="inline-flex items-center gap-2 rounded-lg bg-emerald-100 text-emerald-700 px-6 py-3 text-sm font-medium hover:bg-emerald-200 transition-all"
     >
      <svg
       className="w-4 h-4"
       fill="none"
       stroke="currentColor"
       viewBox="0 0 24 24"
      >
       <path
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={2}
        d="M12 6v6m0 0v6m0-6h6m-6 0H6"
       />
      </svg>
      إضافة تعليم آخر
     </button>
    </div>
   </div>

   {renderSaveDraftButton(3)}
  </div>
 );

 const renderStep4 = () => (
  <div className="space-y-6">
   <div className="text-center mb-6">
    <div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-emerald-100 text-emerald-600 mb-4">
     <svg
      className="w-8 h-8"
      fill="none"
      stroke="currentColor"
      viewBox="0 0 24 24"
     >
      <path
       strokeLinecap="round"
       strokeLinejoin="round"
       strokeWidth={2}
       d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2-2v2m8 0V6a2 2 0 012 2v6a2 2 0 01-2 2H8a2 2 0 01-2-2V8a2 2 0 012-2V6"
      />
     </svg>
    </div>
    <h2 className="text-xl font-semibold text-slate-900">الخبرات العملية</h2>
    <p className="text-slate-600 mt-2">أضف خبراتك العملية السابقة والحالية</p>
   </div>

   <div className="space-y-4 sm:space-y-6">
    {formData.work_experience.map((work, index) => (
     <div
      key={index}
      className="p-4 sm:p-6 border border-slate-200/60 rounded-lg bg-slate-50/50"
     >
      <div className="flex items-center justify-between mb-4">
       <h3 className="text-lg font-semibold text-slate-900">
        {index === 0 ? "الخبرة الأساسية" : `الخبرة الإضافية ${index + 1}`}
       </h3>
       {formData.work_experience.length > 1 && (
        <button
         type="button"
         onClick={() => removeWorkExperience(index)}
         className="text-red-500 hover:text-red-700 text-sm font-medium"
        >
         حذف
        </button>
       )}
      </div>

      <div className="grid gap-4">
       <div>
        <label className="block text-sm font-semibold text-slate-900 mb-2">
         المسمى الوظيفي
        </label>
        <input
         type="text"
         value={work.job_title}
         onChange={(e) =>
          handleWorkExperienceChange(index, "job_title", e.target.value)
         }
         className="w-full rounded-lg border border-slate-300/70 bg-white/70 px-4 py-3 text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/40 focus:border-emerald-400 ring-1 ring-black/5 transition-all"
         placeholder="مثال: Technical Product Manager"
        />
       </div>

       <div>
        <label className="block text-sm font-semibold text-slate-900 mb-2">
         اسم الشركة
        </label>
        <input
         type="text"
         value={work.company}
         onChange={(e) =>
          handleWorkExperienceChange(index, "company", e.target.value)
         }
         className="w-full rounded-lg border border-slate-300/70 bg-white/70 px-4 py-3 text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/40 focus:border-emerald-400 ring-1 ring-black/5 transition-all"
         placeholder="مثال: Advanced Technology Company"
        />
       </div>

       <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div>
         <label className="block text-sm font-semibold text-slate-900 mb-2">
          تاريخ البداية
         </label>
         <MobileDatePicker
          value={work.start_date}
          onChange={(value) =>
           handleWorkExperienceChange(index, "start_date", value)
          }
          placeholder="اختر تاريخ البداية"
         />
        </div>

        <div>
         <label className="block text-sm font-semibold text-slate-900 mb-2">
          تاريخ النهاية
         </label>
         <MobileDatePicker
          value={work.end_date}
          onChange={(value) =>
           handleWorkExperienceChange(index, "end_date", value)
          }
          disabled={work.is_current}
          placeholder="اختر تاريخ النهاية"
         />
        </div>
       </div>

       <div className="flex items-center">
        <label className="flex items-center cursor-pointer">
         <input
          type="checkbox"
          checked={work.is_current}
          onChange={(e) =>
           handleWorkExperienceChange(index, "is_current", e.target.checked)
          }
          className="w-5 h-5 text-emerald-600 bg-white border-2 border-slate-300 rounded focus:ring-emerald-500 focus:ring-2 transition-all"
         />
         <span className="ml-3 text-sm font-medium text-slate-900">
          عمل حالي
         </span>
        </label>
       </div>

       <div>
        <label className="block text-sm font-semibold text-slate-900 mb-2">
         المسؤوليات والإنجازات
        </label>
        <div className="space-y-3">
         {work.responsibilities.map((resp, respIndex) => (
          <div key={respIndex} className="flex items-start gap-2">
           <span className="text-emerald-600 text-lg mt-2 flex-shrink-0">
            •
           </span>
           <div className="flex-1 flex flex-col sm:flex-row gap-2">
            <textarea
             value={resp}
             onChange={(e) =>
              handleResponsibilityChange(index, respIndex, e.target.value)
             }
             rows={2}
             className="flex-1 rounded-lg border border-slate-300/70 bg-white/70 px-3 sm:px-4 py-3 text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/40 focus:border-emerald-400 ring-1 ring-black/5 transition-all text-base resize-vertical min-h-[48px] max-h-[200px]"
             placeholder="اكتب مسؤولية أو إنجاز..."
             style={{ overflow: "auto", resize: "vertical", fontSize: "16px" }}
            />
            {work.responsibilities.length > 1 && (
             <button
              type="button"
              onClick={() => removeResponsibility(index, respIndex)}
              className="px-3 py-2 text-red-500 hover:text-red-700 text-sm font-medium border border-red-200 rounded-lg hover:bg-red-50 transition-all flex-shrink-0"
             >
              حذف
             </button>
            )}
           </div>
          </div>
         ))}
         <button
          type="button"
          onClick={() => addResponsibility(index)}
          className="w-full sm:w-auto inline-flex items-center justify-center gap-2 px-4 py-3 text-emerald-600 hover:text-emerald-700 text-sm font-medium border border-emerald-200 rounded-lg hover:bg-emerald-50 transition-all"
         >
          <svg
           className="w-4 h-4"
           fill="none"
           stroke="currentColor"
           viewBox="0 0 24 24"
          >
           <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M12 4v16m8-8H4"
           />
          </svg>
          إضافة مسؤولية أخرى
         </button>
        </div>
       </div>
      </div>
     </div>
    ))}

    <div className="text-center">
     <button
      type="button"
      onClick={addWorkExperience}
      className="w-full sm:w-auto inline-flex items-center justify-center gap-2 rounded-lg bg-emerald-100 text-emerald-700 px-6 py-4 text-sm font-medium hover:bg-emerald-200 transition-all border border-emerald-200"
     >
      <svg
       className="w-4 h-4"
       fill="none"
       stroke="currentColor"
       viewBox="0 0 24 24"
      >
       <path
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={2}
        d="M12 6v6m0 0v6m0-6h6m-6 0H6"
       />
      </svg>
      إضافة خبرة عمل أخرى
     </button>
    </div>
   </div>

   {renderSaveDraftButton(4)}
  </div>
 );

 const renderStep5 = () => {
  console.log("=== RENDER STEP 5 (SKILLS) ===");
  console.log("Current formData.skills:", formData.skills);
  console.log(
   "formData.skills detailed:",
   formData.skills.map((s) => ({
    category: s.category,
    skill_names: s.skill_names,
    skill_names_types: s.skill_names?.map((name) => ({
     value: name,
     type: typeof name,
    })),
   }))
  );

  return (
   <div className="space-y-6">
    <div className="text-center mb-6">
     <div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-emerald-100 text-emerald-600 mb-4">
      <svg
       className="w-8 h-8"
       fill="none"
       stroke="currentColor"
       viewBox="0 0 24 24"
      >
       <path
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={2}
        d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"
       />
      </svg>
     </div>
     <h2 className="text-xl font-semibold text-slate-900">المهارات</h2>
     <p className="text-slate-600 mt-2">أضف مهاراتك التقنية والشخصية</p>
    </div>

    <div className="space-y-6">
     {formData.skills.map((skill, index) => (
      <div
       key={index}
       className="p-6 border border-slate-200/60 rounded-lg bg-slate-50/50"
      >
       <div className="flex items-center justify-between mb-4">
        <h3 className="text-lg font-semibold text-slate-900">
         {index === 0 ? "فئة المهارات الأساسية" : `فئة المهارات ${index + 1}`}
        </h3>
        {formData.skills.length > 1 && (
         <button
          type="button"
          onClick={() => removeSkills(index)}
          className="text-red-500 hover:text-red-700 text-sm font-medium"
         >
          حذف
         </button>
        )}
       </div>

       <div className="grid gap-4">
        <div>
         <label className="block text-sm font-semibold text-slate-900 mb-2">
          فئة المهارات
         </label>
         <input
          type="text"
          value={skill.category}
          onChange={(e) =>
           handleSkillsChange(index, "category", e.target.value)
          }
          className="w-full rounded-lg border border-slate-300/70 bg-white/70 px-4 py-3 text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/40 focus:border-emerald-400 ring-1 ring-black/5 transition-all"
          placeholder="مثال: Product Management & AI"
         />
        </div>

        <div>
         <label className="block text-sm font-semibold text-slate-900 mb-2">
          المهارات
         </label>
         <div className="space-y-3">
          {(() => {
           // AGGRESSIVE FILTERING - Only render non-empty skill names
           const validSkillNames = skill.skill_names.filter((skillName) => {
            return (
             skillName &&
             typeof skillName === "string" &&
             skillName.trim() !== "" &&
             skillName.trim() !== '""' &&
             skillName.trim() !== "''" &&
             skillName.trim() !== "null" &&
             skillName.trim() !== "undefined"
            );
           });

           // If no valid skill names, render nothing
           if (validSkillNames.length === 0) {
            return null;
           }

           return validSkillNames.map((skillName, nameIndex) => (
            <div key={nameIndex} className="flex items-center gap-2">
             <span className="text-emerald-600 text-lg">•</span>
             <input
              type="text"
              value={skillName}
              onChange={(e) =>
               handleSkillNameChange(index, nameIndex, e.target.value)
              }
              onBlur={() => handleSkillNameBlur(index, nameIndex)}
              className="flex-1 rounded-lg border border-slate-300/70 bg-white/70 px-4 py-2 text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/40 focus:border-emerald-400 ring-1 ring-black/5 transition-all"
              placeholder="اكتب اسم المهارة..."
             />
             {skill.skill_names.filter((name) => name && name.trim() !== "")
              .length > 1 && (
              <button
               type="button"
               onClick={() => removeSkillName(index, nameIndex)}
               className="text-red-500 hover:text-red-700 text-sm font-medium"
              >
               حذف
              </button>
             )}
            </div>
           ));
          })()}
          {addingSkillTo === index ? (
           <div className="flex items-center gap-2">
            <span className="text-emerald-600 text-lg">•</span>
            <input
             type="text"
             autoFocus
             onChange={(e) => handleNewSkillChange(index, e.target.value)}
             onBlur={(e) => handleNewSkillBlur(index, e.target.value)}
             onKeyPress={(e) => {
              if (e.key === "Enter") {
               handleNewSkillChange(index, e.target.value);
              }
             }}
             className="flex-1 rounded-lg border border-slate-300/70 bg-white/70 px-4 py-2 text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/40 focus:border-emerald-400 ring-1 ring-black/5 transition-all"
             placeholder="اكتب اسم المهارة..."
            />
           </div>
          ) : (
           <button
            type="button"
            onClick={() => addSkillName(index)}
            className="text-emerald-600 hover:text-emerald-700 text-sm font-medium"
           >
            + إضافة مهارة أخرى
           </button>
          )}
         </div>
         <p className="mt-2 text-xs text-slate-500">
          اكتب المهارات مفصولة بفواصل أو أضف كل مهارة في سطر منفصل
         </p>
        </div>
       </div>
      </div>
     ))}

     <div className="text-center">
      <button
       type="button"
       onClick={addSkills}
       className="inline-flex items-center gap-2 rounded-lg bg-emerald-100 text-emerald-700 px-6 py-3 text-sm font-medium hover:bg-emerald-200 transition-all"
      >
       <svg
        className="w-4 h-4"
        fill="none"
        stroke="currentColor"
        viewBox="0 0 24 24"
       >
        <path
         strokeLinecap="round"
         strokeLinejoin="round"
         strokeWidth={2}
         d="M12 6v6m0 0v6m0-6h6m-6 0H6"
        />
       </svg>
       إضافة فئة مهارات أخرى
      </button>
     </div>

     <div className="p-4 border border-slate-200/60 rounded-lg bg-slate-50/50">
      <h3 className="text-sm font-medium text-slate-900 mb-2">
       أمثلة على فئات المهارات:
      </h3>
      <ul className="text-xs text-slate-600 space-y-1">
       <li>
        • <strong>Product Management & AI:</strong> Product Management, AI,
        Strategic Planning, Business Analysis
       </li>
       <li>
        • <strong>Technical Development:</strong> Ruby on Rails, PostgreSQL,
        Power BI, Data Modeling
       </li>
       <li>
        • <strong>Project Management:</strong> Project Management, Agile
        Methodologies, Technical Leadership
       </li>
       <li>
        • <strong>Data Science:</strong> Data Science, Python, R, SQL
       </li>
       <li>
        • <strong>Soft Skills:</strong> Innovation, Team Collaboration, Customer
        Reach
       </li>
      </ul>
     </div>
    </div>

    {renderSaveDraftButton(5)}
   </div>
  );
 };

 const renderStep6 = () => (
  <div className="space-y-6">
   <div className="text-center mb-6">
    <div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-emerald-100 text-emerald-600 mb-4">
     <svg
      className="w-8 h-8"
      fill="none"
      stroke="currentColor"
      viewBox="0 0 24 24"
     >
      <path
       strokeLinecap="round"
       strokeLinejoin="round"
       strokeWidth={2}
       d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
      />
     </svg>
    </div>
    <h2 className="text-xl font-semibold text-slate-900">الشهادات</h2>
    <p className="text-slate-600 mt-2">أضف شهاداتك المهنية والتعليمية</p>
   </div>

   <div className="space-y-6">
    {formData.certifications.map((cert, index) => (
     <div
      key={index}
      className="p-6 border border-slate-200/60 rounded-lg bg-slate-50/50"
     >
      <div className="flex items-center justify-between mb-4">
       <h3 className="text-lg font-semibold text-slate-900">
        {index === 0 ? "الشهادة الأساسية" : `الشهادة الإضافية ${index + 1}`}
       </h3>
       {formData.certifications.length > 1 && (
        <button
         type="button"
         onClick={() => removeCertification(index)}
         className="text-red-500 hover:text-red-700 text-sm font-medium"
        >
         حذف
        </button>
       )}
      </div>

      <div className="grid gap-4">
       <div>
        <label className="block text-sm font-semibold text-slate-900 mb-2">
         اسم الشهادة
        </label>
        <input
         type="text"
         value={cert.name}
         onChange={(e) =>
          handleCertificationChange(index, "name", e.target.value)
         }
         className="w-full rounded-lg border border-slate-300/70 bg-white/70 px-4 py-3 text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/40 focus:border-emerald-400 ring-1 ring-black/5 transition-all"
         placeholder="مثال: PMP®"
        />
       </div>

       <div>
        <label className="block text-sm font-semibold text-slate-900 mb-2">
         المؤسسة المانحة
        </label>
        <input
         type="text"
         value={cert.organization}
         onChange={(e) =>
          handleCertificationChange(index, "organization", e.target.value)
         }
         className="w-full rounded-lg border border-slate-300/70 bg-white/70 px-4 py-3 text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/40 focus:border-emerald-400 ring-1 ring-black/5 transition-all"
         placeholder="مثال: PMI"
        />
       </div>

       <div>
        <label className="block text-sm font-semibold text-slate-900 mb-2">
         تاريخ الحصول
        </label>
        <MobileDatePicker
         value={cert.date}
         onChange={(value) => handleCertificationChange(index, "date", value)}
         placeholder="اختر تاريخ الحصول"
        />
       </div>
      </div>
     </div>
    ))}

    <div className="text-center">
     <button
      type="button"
      onClick={addCertification}
      className="inline-flex items-center gap-2 rounded-lg bg-emerald-100 text-emerald-700 px-6 py-3 text-sm font-medium hover:bg-emerald-200 transition-all"
     >
      <svg
       className="w-4 h-4"
       fill="none"
       stroke="currentColor"
       viewBox="0 0 24 24"
      >
       <path
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={2}
        d="M12 6v6m0 0v6m0-6h6m-6 0H6"
       />
      </svg>
      إضافة شهادة أخرى
     </button>
    </div>

    <div className="p-4 border border-slate-200/60 rounded-lg bg-slate-50/50">
     <h3 className="text-sm font-medium text-slate-900 mb-2">
      أمثلة على الشهادات:
     </h3>
     <ul className="text-xs text-slate-600 space-y-1">
      <li>
       • <strong>PMP®</strong> - PMI (Aug 2025)
      </li>
      <li>
       • <strong>Microsoft Certified: Azure AI Engineer Associate</strong> -
       Microsoft (Jul 2025)
      </li>
      <li>
       • <strong>Data Science</strong> - SDA (Dec 2020)
      </li>
     </ul>
    </div>
   </div>

   {renderSaveDraftButton(6)}
  </div>
 );

 const renderStep7 = () => (
  <div className="space-y-6">
   <div className="text-center mb-6">
    <div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-emerald-100 text-emerald-600 mb-4">
     <svg
      className="w-8 h-8"
      fill="none"
      stroke="currentColor"
      viewBox="0 0 24 24"
     >
      <path
       strokeLinecap="round"
       strokeLinejoin="round"
       strokeWidth={2}
       d="M12 14l9-5-9-5-9 5 9 5z"
      />
      <path
       strokeLinecap="round"
       strokeLinejoin="round"
       strokeWidth={2}
       d="M12 14l6.16-3.422a12.083 12.083 0 01.665 6.479A11.952 11.952 0 0012 20.055a11.952 11.952 0 00-6.824-1.998 12.078 12.078 0 01.665-6.479L12 14z"
      />
      <path
       strokeLinecap="round"
       strokeLinejoin="round"
       strokeWidth={2}
       d="M12 14l9-5-9-5-9 5 9 5zm0 0l6.16-3.422a12.083 12.083 0 01.665 6.479A11.952 11.952 0 0012 20.055a11.952 11.952 0 00-6.824-1.998 12.078 12.078 0 01.665-6.479L12 14z"
      />
     </svg>
    </div>
    <h2 className="text-xl font-semibold text-slate-900">اللغات</h2>
    <p className="text-slate-600 mt-2">أضف اللغات التي تتحدثها ومستواها</p>
   </div>

   <div className="space-y-6">
    {formData.languages.map((lang, index) => (
     <div
      key={index}
      className="p-6 border border-slate-200/60 rounded-lg bg-slate-50/50"
     >
      <div className="flex items-center justify-between mb-4">
       <h3 className="text-lg font-semibold text-slate-900">
        {index === 0 ? "اللغة الأساسية" : `اللغة الإضافية ${index + 1}`}
       </h3>
       {formData.languages.length > 1 && (
        <button
         type="button"
         onClick={() => removeLanguage(index)}
         className="text-red-500 hover:text-red-700 text-sm font-medium"
        >
         حذف
        </button>
       )}
      </div>

      <div className="grid gap-4">
       <div>
        <label className="block text-sm font-semibold text-slate-900 mb-2">
         اللغة
        </label>
        <input
         type="text"
         value={lang.language}
         onChange={(e) =>
          handleLanguageChange(index, "language", e.target.value)
         }
         className="w-full rounded-lg border border-slate-300/70 bg-white/70 px-4 py-3 text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/40 focus:border-emerald-400 ring-1 ring-black/5 transition-all"
         placeholder="مثال: Arabic"
        />
       </div>

       <div>
        <label className="block text-sm font-semibold text-slate-900 mb-2">
         مستوى الإتقان
        </label>
        <select
         value={lang.proficiency}
         onChange={(e) =>
          handleLanguageChange(index, "proficiency", e.target.value)
         }
         className="w-full rounded-lg border border-slate-300/70 bg-white/70 px-4 py-3 text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/40 focus:border-emerald-400 ring-1 ring-black/5 transition-all"
        >
         <option value="">اختر مستوى الإتقان</option>
         <option value="Native">أمية</option>
         <option value="Fluent">إتقان كامل</option>
         <option value="Advanced">متقدم</option>
         <option value="Intermediate">متوسط</option>
         <option value="Beginner">مبتدئ</option>
        </select>
       </div>
      </div>
     </div>
    ))}

    <div className="text-center">
     <button
      type="button"
      onClick={addLanguage}
      className="inline-flex items-center gap-2 rounded-lg bg-emerald-100 text-emerald-700 px-6 py-3 text-sm font-medium hover:bg-emerald-200 transition-all"
     >
      <svg
       className="w-4 h-4"
       fill="none"
       stroke="currentColor"
       viewBox="0 0 24 24"
      >
       <path
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={2}
        d="M12 6v6m0 0v6m0-6h6m-6 0H6"
       />
      </svg>
      إضافة لغة أخرى
     </button>
    </div>

    <div className="p-4 border border-slate-200/60 rounded-lg bg-slate-50/50">
     <h3 className="text-sm font-medium text-slate-900 mb-2">
      أمثلة على اللغات:
     </h3>
     <ul className="text-xs text-slate-600 space-y-1">
      <li>
       • <strong>Arabic:</strong> Native, Fluent
      </li>
      <li>
       • <strong>English:</strong> Fluent, Advanced
      </li>
      <li>
       • <strong>French:</strong> Advanced
      </li>
     </ul>
    </div>
   </div>

   {renderSaveDraftButton(7)}
  </div>
 );

 const renderStep8 = () => (
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
      {formData.city &&
       formData.country &&
       ` | ${formData.city}, ${formData.country}`}
     </div>
    </div>

    {/* Professional Summary */}
    {(formData.professional_summary_english ||
     formData.professional_summary) && (
     <div className="mb-4">
      <h2
       className="text-lg font-bold text-gray-900 mb-1 pb-1 border-b border-gray-900 text-left uppercase tracking-wide"
       style={{ fontSize: "12pt" }}
      >
       Professional Summary
      </h2>
      <p
       className="text-gray-700 leading-relaxed text-left"
       style={{ fontSize: "11pt" }}
      >
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
         edu.degree &&
         edu.institution && (
          <div key={index} className="flex justify-between items-start">
           <div className="text-left">
            <div
             className="font-semibold text-gray-900"
             style={{ fontSize: "11pt" }}
            >
             {edu.degree}
            </div>
            <div className="text-gray-600" style={{ fontSize: "10pt" }}>
             {edu.institution}
            </div>
           </div>
           <div
            className="text-right text-gray-500"
            style={{ fontSize: "10pt" }}
           >
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
    {formData.work_experience.some(
     (work) => work.job_title && work.company
    ) && (
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
         // Sort by start_date in descending order (newest first)
         // But prioritize current jobs (is_current or end_date is blank) at the top
         if (!a.start_date && !b.start_date) return 0;
         if (!a.start_date) return 1;
         if (!b.start_date) return -1;

         // Check if jobs are current (Present)
         const aIsCurrent = a.is_current || !a.end_date;
         const bIsCurrent = b.is_current || !b.end_date;

         // If one is current and the other isn't, current job goes first
         if (aIsCurrent && !bIsCurrent) return -1;
         if (!aIsCurrent && bIsCurrent) return 1;

         // If both are current or both are not current, sort by start_date
         return new Date(b.start_date) - new Date(a.start_date);
        })
        .map((work, index) => (
         <div key={index} className="mb-2">
          <div className="flex justify-between items-start mb-1">
           <div
            className="text-left font-semibold text-gray-900"
            style={{ fontSize: "11pt" }}
           >
            {work.job_title}
           </div>
           <div
            className="text-right text-gray-500"
            style={{ fontSize: "10pt" }}
           >
            {work.start_date && (
             <>
              {work.start_date}
              {work.end_date && !work.is_current && ` - ${work.end_date}`}
              {work.is_current && " - Present"}
             </>
            )}
           </div>
          </div>
          <div
           className="text-left text-gray-600 mb-1"
           style={{ fontSize: "10pt" }}
          >
           {work.company}
          </div>
          {work.responsibilities.some((resp) => resp.trim()) && (
           <div
            className="text-gray-700 text-left"
            style={{
             fontSize: "10pt",
             lineHeight: "1.1",
             margin: "1pt 0",
            }}
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
         skill.category &&
         skill.skill_names.some((name) => name.trim()) && (
          <div key={index} className="mb-1 text-left">
           <span
            className="font-semibold text-gray-900"
            style={{ fontSize: "10pt" }}
           >
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
         cert.name &&
         cert.organization && (
          <div key={index} className="flex justify-between items-start">
           <div className="text-left">
            <span
             className="font-semibold text-gray-900"
             style={{ fontSize: "11pt" }}
            >
             {cert.name}
            </span>
            <span className="text-gray-600 ml-2" style={{ fontSize: "10pt" }}>
             {cert.organization}
            </span>
           </div>
           <span
            className="text-right text-gray-500"
            style={{ fontSize: "10pt" }}
           >
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
         lang.language &&
         lang.proficiency && (
          <div key={index} className="flex justify-between items-start">
           <span
            className="text-left font-semibold text-gray-900"
            style={{ fontSize: "10pt" }}
           >
            {lang.language}
           </span>
           <span
            className="text-right text-gray-500"
            style={{ fontSize: "10pt" }}
           >
            {lang.proficiency}
           </span>
          </div>
         )
       )}
      </div>
     </div>
    )}
   </div>

   {renderSaveDraftButton(8)}
  </div>
 );

 const renderStepContent = () => {
  switch (currentStep) {
   case 1:
    return renderStep1();
   case 2:
    return renderStep2();
   case 3:
    return renderStep3();
   case 4:
    return renderStep4();
   case 5:
    return renderStep5();
   case 6:
    return renderStep6();
   case 7:
    return renderStep7();
   case 8:
    return renderStep8();
   default:
    return renderStep1();
  }
 };

 return (
  <div className="min-h-screen bg-gradient-to-br from-slate-50 to-slate-100 py-2 sm:py-8">
   <div className="max-w-4xl mx-auto px-2 sm:px-4">
    <div className="bg-white rounded-lg sm:rounded-2xl shadow-xl border border-slate-200/60 overflow-hidden">
     <div className="bg-gradient-to-r from-emerald-500 to-emerald-600 px-4 sm:px-8 py-4 sm:py-6">
      <h1 className="text-xl sm:text-3xl font-bold text-white text-center">
       بناء السيرة الذاتية
      </h1>
      <p className="text-emerald-100 text-center mt-1 sm:mt-2 text-sm sm:text-base">
       خطوة {currentStep} من 8
      </p>
     </div>
     {/* Progress Bar */}
     <div className="px-4 sm:px-8 py-4" dir="rtl">
      <div className="flex items-center justify-between mb-3 sm:mb-4">
       <h1 className="text-lg sm:text-2xl font-bold text-slate-900">
        إنشاء سيرة ذاتية جديدة
       </h1>
       <span className="text-xs sm:text-sm text-slate-500">
        الخطوة {currentStep} من {totalSteps}
       </span>
      </div>
      <div className="w-full bg-slate-200 rounded-full h-2">
       <div
        className="bg-emerald-600 h-2 rounded-full transition-all duration-300"
        style={{ width: `${(currentStep / totalSteps) * 100}%` }}
       ></div>
      </div>
     </div>

     {/* Step Content */}
     <div className="px-4 sm:px-8 pb-4">{renderStepContent()}</div>

     {/* Navigation Buttons */}
     <div
      className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-3 px-4 sm:px-8 py-4 border-t border-slate-200/60 bg-slate-50/50"
      dir="rtl"
     >
      <div className="flex items-center justify-center sm:justify-start gap-2 sm:gap-3 order-2 sm:order-1">
       {currentStep > 1 && (
        <button
         type="button"
         onClick={prevStep}
         className="flex-1 sm:flex-none inline-flex items-center justify-center gap-2 rounded-lg px-4 py-3 text-sm font-medium text-slate-700 ring-1 ring-slate-300/70 transition-all hover:bg-slate-50 hover:ring-slate-400/70"
        >
         <svg
          className="w-4 h-4"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
         >
          <path
           strokeLinecap="round"
           strokeLinejoin="round"
           strokeWidth={2}
           d="M9 5l7 7-7 7"
          />
         </svg>
         السابق
        </button>
       )}
      </div>

      <div className="flex items-center justify-center sm:justify-end gap-2 sm:gap-3 order-1 sm:order-2">
       <a
        href="/resumes"
        className="flex-1 sm:flex-none inline-flex items-center justify-center gap-2 rounded-lg px-4 py-3 text-sm font-medium text-slate-700 ring-1 ring-slate-300/70 transition-all hover:bg-slate-50 hover:ring-slate-400/70"
       >
        <svg
         className="w-4 h-4"
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
        إلغاء
       </a>

       {currentStep < totalSteps ? (
        <button
         type="button"
         onClick={nextStep}
         className="flex-1 sm:flex-none inline-flex items-center justify-center gap-2 rounded-lg bg-emerald-600 px-6 py-3 text-sm font-medium text-white ring-1 ring-black/5 transition-all hover:bg-emerald-700 hover:shadow"
        >
         التالي
         <svg
          className="w-4 h-4"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
         >
          <path
           strokeLinecap="round"
           strokeLinejoin="round"
           strokeWidth={2}
           d="M15 19l-7-7 7-7"
          />
         </svg>
        </button>
       ) : (
        <button
         type="button"
         onClick={exportToPDF}
         disabled={isExporting}
         className="flex-1 sm:flex-none inline-flex items-center justify-center gap-2 rounded-lg bg-emerald-600 px-6 py-3 text-sm font-medium text-white ring-1 ring-black/5 transition-all hover:bg-emerald-700 hover:shadow disabled:opacity-50 disabled:cursor-not-allowed"
        >
         {isExporting ? (
          <>
           <svg
            className="animate-spin -ml-1 mr-2 h-4 w-4 text-white"
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
           >
            <circle
             className="opacity-25"
             cx="12"
             cy="12"
             r="10"
             stroke="currentColor"
             strokeWidth="4"
            ></circle>
            <path
             className="opacity-75"
             fill="currentColor"
             d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
            ></path>
           </svg>
           جاري التصدير...
          </>
         ) : (
          <>
            إنشاء السيرة الذاتية و تحميلها
           <svg
            className="w-4 h-4"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
           >
            <path
             strokeLinecap="round"
             strokeLinejoin="round"
             strokeWidth={2}
             d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
            />
           </svg>
          </>
         )}
        </button>
       )}
      </div>
     </div>
    </div>
   </div>
  </div>
 );
};

export default MultiStepResumeForm;
