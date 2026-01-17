import React, { useState, useEffect, Suspense, lazy, memo } from "react";
import { createPortal } from "react-dom";

// Lazy load step components for better initial load performance
const CombinedStep1 = lazy(() => import("./cv-builder/CombinedStep1"));
const CombinedStep2 = lazy(() => import("./cv-builder/CombinedStep2"));
const CombinedStep3 = lazy(() => import("./cv-builder/CombinedStep3"));
const ReviewStep = lazy(() => import("./cv-builder/ReviewStep"));

// Memoized skeleton loading for steps - prevents re-renders
const StepLoadingSkeleton = memo(() => (
 <div className="animate-pulse space-y-6">
  <div className="text-center mb-6">
   <div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-slate-200 mb-4" />
   <div className="h-6 bg-slate-200 rounded w-1/2 mx-auto mb-2" />
   <div className="h-4 bg-slate-200 rounded w-2/3 mx-auto" />
  </div>
  <div className="p-6 border border-slate-200 rounded-lg bg-slate-50">
   <div className="h-5 bg-slate-200 rounded w-1/4 mb-4" />
   <div className="space-y-3">
    <div className="h-10 bg-slate-200 rounded" />
    <div className="h-10 bg-slate-200 rounded" />
    <div className="grid grid-cols-2 gap-4">
     <div className="h-10 bg-slate-200 rounded" />
     <div className="h-10 bg-slate-200 rounded" />
    </div>
   </div>
  </div>
 </div>
));

const MultiStepResumeForm = ({ resume, onSubmit }) => {
 // Clean skills data to remove empty skill names

 // Clean skills data to remove empty skill names
 const cleanSkillsData = (skills) => {
  if (!skills || !Array.isArray(skills)) {
   return [
    {
     category: "",
     skill_names: [],
    },
   ];
  }

  return skills.map((skill, skillIndex) => {
   let skillNames = skill.skill_names;

   // Handle case where skill_names might be a JSON string
   if (typeof skillNames === "string") {
    try {
     skillNames = JSON.parse(skillNames);
    } catch (e) {
     skillNames = [];
    }
   }

   // Ensure skillNames is an array
   if (!Array.isArray(skillNames)) {
    skillNames = [];
   }


   // Filter out empty, null, undefined, or whitespace-only names
   const cleanedNames = skillNames.filter((name) => {
    const isValid =
     name != null &&
     typeof name === "string" &&
     name.trim() !== "" &&
     name.trim() !== '""' &&
     name.trim() !== "''";
    return isValid;
   });


   return {
    ...skill,
    skill_names: cleanedNames,
   };
  });
 };

 // Progressive loading state for each section
 const [sectionsLoaded, setSectionsLoaded] = useState({
  header: !!resume?.id,
  experiences: false,
  skills: false,
  educations: false,
  certifications: false,
  languages: false,
 });

 const [isLoading, setIsLoading] = useState(true);
 
 // Progressive section data
 const [loadedExperiences, setLoadedExperiences] = useState([]);
 const [loadedSkills, setLoadedSkills] = useState([]);
 const [loadedEducations, setLoadedEducations] = useState([]);
 const [loadedCertifications, setLoadedCertifications] = useState([]);
 const [loadedLanguages, setLoadedLanguages] = useState([]);

 // Fetch sections in parallel on mount (progressive loading)
 useEffect(() => {
  const resumeId = resume?.id;
  if (!resumeId) {
   // New resume - no sections to load
   setIsLoading(false);
   return;
  }

  // Fetch all sections in parallel
  const fetchSection = async (endpoint, setter, sectionName) => {
   try {
    const response = await fetch(`/resumes/${resumeId}/${endpoint}`);
    if (response.ok) {
     const data = await response.json();
     setter(data);
    }
   } catch (e) {
    console.error(`Failed to load ${sectionName}:`, e);
   } finally {
    setSectionsLoaded(prev => ({ ...prev, [sectionName]: true }));
   }
  };

  // Fire all requests in parallel
  Promise.all([
   fetchSection('experiences', setLoadedExperiences, 'experiences'),
   fetchSection('skills_section', setLoadedSkills, 'skills'),
   fetchSection('educations', setLoadedEducations, 'educations'),
   fetchSection('certifications_section', setLoadedCertifications, 'certifications'),
   fetchSection('languages_section', setLoadedLanguages, 'languages'),
  ]).then(() => {
   setIsLoading(false);
  });
 }, [resume?.id]);

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
 const [autoSaveStatus, setAutoSaveStatus] = useState("idle"); // idle, saving, saved, error
 const [lastSavedAt, setLastSavedAt] = useState(null);

 const totalSteps = 4;

 // Hydrate formData with progressively loaded sections
 useEffect(() => {
  if (loadedExperiences.length > 0) {
   setFormData(prev => ({
    ...prev,
    work_experience: loadedExperiences.map(exp => ({
     job_title: exp.job_title || "",
     company: exp.company || "",
     start_date: exp.start_date || "",
     end_date: exp.end_date || "",
     is_current: exp.is_current || false,
     responsibilities: exp.responsibilities || [""],
    })),
   }));
  }
 }, [loadedExperiences]);

 useEffect(() => {
  if (loadedSkills.length > 0) {
   setFormData(prev => ({
    ...prev,
    skills: loadedSkills.map(skill => ({
     category: skill.category || "",
     skill_names: (skill.skill_names || []).filter(n => n && n.trim() !== ""),
    })),
   }));
  }
 }, [loadedSkills]);

 useEffect(() => {
  if (loadedEducations.length > 0) {
   setFormData(prev => ({
    ...prev,
    education: loadedEducations.map(edu => ({
     degree: edu.degree || "",
     institution: edu.institution || "",
     start_date: edu.start_date || "",
     end_date: edu.end_date || "",
     gpa: edu.gpa || "",
     is_current: edu.is_current || false,
    })),
   }));
  }
 }, [loadedEducations]);

 useEffect(() => {
  if (loadedCertifications.length > 0) {
   setFormData(prev => ({
    ...prev,
    certifications: loadedCertifications.map(cert => ({
     name: cert.name || "",
     organization: cert.organization || "",
     date: cert.date || "",
    })),
   }));
  }
 }, [loadedCertifications]);

 useEffect(() => {
  if (loadedLanguages.length > 0) {
   setFormData(prev => ({
    ...prev,
    languages: loadedLanguages.map(lang => ({
     language: lang.language || "",
     proficiency: lang.proficiency || "",
    })),
   }));
  }
 }, [loadedLanguages]);

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


  // First try: JSON POST request
  try {
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


   if (response.ok) {
    const savedResume = await response.json();
    return savedResume.id;
   } else {
    const errorText = await response.text();
    throw new Error(`HTTP ${response.status}: ${errorText}`);
   }
  } catch (jsonError) {

   // Second try: Form submission with FormData
   try {
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


    if (response.ok) {
     const result = await response.json();
     return result.id;
    } else {
     const errorText = await response.text();
     throw new Error(`FormData HTTP ${response.status}: ${errorText}`);
    }
   } catch (formError) {
    throw new Error(
     `Both JSON and FormData submissions failed. Last error: ${formError.message}`
    );
   }
  }
 };

 const exportToPDF = async () => {
  setIsExporting(true);
  setTranslationError("");

  try {

   let resumeId = null;

   // Step 1: Always save the resume to database first
   try {
    resumeId = await saveResumeToDatabase();

    // Show success message in console (less intrusive than alert)
    setTranslationError(""); // Clear any errors
   } catch (saveError) {

    // Validate required fields for PDF generation even if save fails
    if (!formData.complete_name?.trim() || !formData.email?.trim()) {
     alert("يرجى ملء الاسم الكامل والبريد الإلكتروني قبل التصدير");
     setIsExporting(false);
     return;
    }

    // Still try to export PDF even if save fails
   }

   // Export the PDF - either with saved resume ID or directly from form data
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

   if (response.ok) {
    // Parse the JSON response containing job information
    const jobInfo = await response.json();

    if (jobInfo.job_id && jobInfo.token) {
     // Poll for job completion
     setExportStatus("processing");

     // Set up polling interval
     const pollingInterval = setInterval(async () => {
      try {
       const statusUrl = `/api/pdf_status?job_id=${jobInfo.job_id}&token=${jobInfo.token}`;

       const statusResponse = await fetch(statusUrl, {
        headers: {
         "X-CSRF-Token": document
          .querySelector('meta[name="csrf-token"]')
          ?.getAttribute("content"),
        },
       });

       if (statusResponse.ok) {
        const statusInfo = await statusResponse.json();

        if (statusInfo.status === "completed") {
         // Job is complete, download the PDF
         clearInterval(pollingInterval);


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
    throw new Error("PDF export failed");
   }
  } catch (error) {
   console.error("PDF export error:", error);
   setTranslationError("حدث خطأ في تصدير PDF. يرجى المحاولة مرة أخرى.");
  } finally {
   setIsExporting(false);
  }
 };

 const saveDraft = async (stepNumber = currentStep, silent = false) => {
  if (silent) {
   setAutoSaveStatus("saving");
  } else {
   setIsSavingDraft(true);
  }
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
    if (silent) {
     setAutoSaveStatus("saved");
     setLastSavedAt(new Date());
     // Reset status after 3 seconds
     setTimeout(() => setAutoSaveStatus("idle"), 3000);
    } else {
     alert(`تم حفظ المسودة بنجاح في الخطوة ${stepNumber}! يمكنك العودة إليها لاحقاً.`);
    }
   } else {
    console.error("❌ Failed to save draft");
    if (silent) {
     setAutoSaveStatus("error");
     setTimeout(() => setAutoSaveStatus("idle"), 3000);
    } else {
     alert("حدث خطأ أثناء حفظ المسودة");
    }
   }
  } catch (error) {
   console.error("❌ Error saving draft:", error);
   if (silent) {
    setAutoSaveStatus("error");
    setTimeout(() => setAutoSaveStatus("idle"), 3000);
   } else {
    alert("حدث خطأ أثناء حفظ المسودة: " + error.message);
   }
  } finally {
   setIsSavingDraft(false);
  }
 };

 // Auto-save effect - triggers 2 seconds after form data changes
 useEffect(() => {
  // Skip auto-save if no resume ID (new unsaved resume)
  if (!resume?.id) return;
  
  const autoSaveTimer = setTimeout(() => {
   saveDraft(currentStep, true); // silent save
  }, 2000);

  return () => clearTimeout(autoSaveTimer);
 }, [formData, currentStep]);

 // Helper function to render save draft button (now a subtle manual backup option)
 const renderSaveDraftButton = (stepNumber) => (
  <div className="mt-4 sm:mt-6 pt-4 border-t border-slate-200/60 flex items-center justify-between">
   <p className="text-xs text-slate-400 flex items-center gap-1">
    <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
     <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
    </svg>
    يتم الحفظ تلقائياً
   </p>
   <button
    type="button"
    onClick={() => saveDraft(stepNumber)}
    disabled={isSavingDraft}
    className="text-xs text-slate-500 hover:text-slate-700 active:text-slate-800 underline disabled:opacity-50 py-1 px-2 rounded active:bg-slate-100 transition-all touch-manipulation"
   >
    {isSavingDraft ? "جاري الحفظ..." : "حفظ يدوي"}
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
   // Auto-save current step before moving to next
   if (resume?.id) {
    saveDraft(currentStep, true);
   }
   
   const newStep = currentStep + 1;
   setCurrentStep(newStep);

   // Update URL with new step parameter
   const url = new URL(window.location);
   url.searchParams.set("step", newStep);
   window.history.pushState({}, "", url);
   
   // Scroll to center of viewport
   setTimeout(() => {
    const formCard = document.querySelector('[data-form-card]');
    if (formCard) {
     formCard.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }
   }, 100);
  }
 };

 const prevStep = () => {
  if (currentStep > 1) {
   // Auto-save current step before moving back
   if (resume?.id) {
    saveDraft(currentStep, true);
   }
   
   const newStep = currentStep - 1;
   setCurrentStep(newStep);

   // Update URL with new step parameter
   const url = new URL(window.location);
   url.searchParams.set("step", newStep);
   window.history.pushState({}, "", url);
   
   // Scroll to center of viewport
   setTimeout(() => {
    const formCard = document.querySelector('[data-form-card]');
    if (formCard) {
     formCard.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }
   }, 100);
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

   onSubmit(railsFormData);
  }
 };


 const renderStepContent = () => {
  if (isLoading) return <StepLoadingSkeleton />;
  const stepProps = {
   formData,
   handleInputChange,
   translateProfessionalSummary,
   isTranslating,
   translationError,
   translationCount,
   maxTranslations,
   renderSaveDraftButton,
   // Step 2 props
   handleEducationChange,
   addEducation,
   removeEducation,
   handleWorkExperienceChange,
   addWorkExperience,
   removeWorkExperience,
   handleResponsibilityChange,
   addResponsibility,
   removeResponsibility,
   // Step 3 props
   handleSkillsChange,
   addSkills,
   removeSkills,
   handleSkillNameChange,
   handleSkillNameBlur,
   addSkillName,
   removeSkillName,
   addingSkillTo,
   handleNewSkillChange,
   handleNewSkillBlur,
   handleCertificationChange,
   addCertification,
   removeCertification,
   handleLanguageChange,
   addLanguage,
   removeLanguage,
  };

  return (
   <Suspense fallback={<StepLoadingSkeleton />}>
    {currentStep === 1 && <CombinedStep1 {...stepProps} />}
    {currentStep === 2 && <CombinedStep2 {...stepProps} />}
    {currentStep === 3 && <CombinedStep3 {...stepProps} />}
    {currentStep === 4 && <ReviewStep {...stepProps} />}
   </Suspense>
  );
 };

 // Initial skeleton loading - reduced to 300ms for faster perceived load
 useEffect(() => {
  const timer = setTimeout(() => setIsLoading(false), 300);
  return () => clearTimeout(timer);
 }, []);

 // Show skeleton when changing steps - reduced to 200ms
 const handleStepChange = (step) => {
  setIsLoading(true);
  setTimeout(() => {
   setCurrentStep(step);
   setIsLoading(false);
  }, 200);
 };

 return (
  <div data-turbo="false" className="min-h-screen bg-gradient-to-br from-slate-50 to-slate-100 py-2 sm:py-8 overflow-x-hidden w-full max-w-full">
   <div className="max-w-4xl mx-auto px-2 sm:px-4 w-full">
    <div data-form-card className="bg-white rounded-lg sm:rounded-2xl shadow-xl border border-slate-200/60 overflow-hidden w-full">
     <div className="bg-gradient-to-r from-emerald-500 to-emerald-600 px-4 sm:px-8 py-4 sm:py-6">
      <h1 className="text-xl sm:text-3xl font-bold text-white text-center">
       بناء السيرة الذاتية
      </h1>
      <p className="text-emerald-100 text-center mt-1 sm:mt-2 text-sm sm:text-base">
       خطوة {currentStep} من 4
      </p>
     </div>
     {/* Progress Bar */}
     <div className="px-4 sm:px-8 py-4" dir="rtl">
      <div className="flex items-center justify-between mb-3 sm:mb-4">
       <h1 className="text-lg sm:text-2xl font-bold text-slate-900">
        إنشاء سيرة ذاتية جديدة
       </h1>
       <div className="flex items-center gap-3">
        {/* Auto-save indicator */}
        {autoSaveStatus !== "idle" && (
         <span className={`text-xs flex items-center gap-1 ${
          autoSaveStatus === "saving" ? "text-blue-600" :
          autoSaveStatus === "saved" ? "text-emerald-600" :
          "text-red-500"
         }`}>
          {autoSaveStatus === "saving" && (
           <>
            <svg className="animate-spin h-3 w-3" fill="none" viewBox="0 0 24 24">
             <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
             <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            جاري الحفظ...
           </>
          )}
          {autoSaveStatus === "saved" && (
           <>
            <svg className="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
             <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
            </svg>
            تم الحفظ تلقائياً
           </>
          )}
          {autoSaveStatus === "error" && (
           <>
            <svg className="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
             <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            خطأ في الحفظ
           </>
          )}
         </span>
        )}
        <span className="text-xs sm:text-sm text-slate-500">
         الخطوة {currentStep} من {totalSteps}
        </span>
       </div>
      </div>
      <div className="w-full bg-slate-200 rounded-full h-2">
       <div
        className="bg-emerald-600 h-2 rounded-full transition-all duration-300"
        style={{ width: `${(currentStep / totalSteps) * 100}%` }}
       ></div>
      </div>
     </div>

     {/* Step Content */}
     <div className="px-4 sm:px-8 pb-4 overflow-x-hidden">{renderStepContent()}</div>

     {/* Navigation Buttons - Mobile Optimized with Safe Area */}
     <div 
      className="px-4 sm:px-8 py-4 border-t border-slate-200/60 bg-slate-50/50" 
      dir="rtl"
      style={{ paddingBottom: 'max(1rem, env(safe-area-inset-bottom))' }}
     >
      <div className="flex flex-col gap-3">
       {/* Primary actions row */}
       <div className="flex gap-2">
        {currentStep < totalSteps ? (
         <button
          type="button"
          onClick={nextStep}
          className="flex-1 inline-flex items-center justify-center gap-2 rounded-lg bg-emerald-600 px-4 py-3 text-sm font-medium text-white transition-all hover:bg-emerald-700 active:bg-emerald-800 active:scale-[0.98] touch-manipulation"
         >
          التالي
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
           <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
          </svg>
         </button>
        ) : (
         <button
          type="button"
          onClick={exportToPDF}
          disabled={isExporting}
          className="flex-1 inline-flex items-center justify-center gap-2 rounded-lg bg-emerald-600 px-4 py-3 text-sm font-medium text-white transition-all hover:bg-emerald-700 active:bg-emerald-800 active:scale-[0.98] disabled:opacity-50 disabled:active:scale-100 touch-manipulation"
         >
          {isExporting ? (
           <>
            <svg className="animate-spin h-4 w-4" fill="none" viewBox="0 0 24 24">
             <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
             <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            جاري التصدير...
           </>
          ) : (
           <>إنشاء وتحميل</>
          )}
         </button>
        )}
        <a href="/resumes" className="px-4 py-3 rounded-lg text-sm font-medium text-slate-600 ring-1 ring-slate-300 hover:bg-slate-50 active:bg-slate-100 active:scale-[0.98] transition-all touch-manipulation">
         إلغاء
        </a>
       </div>
       {currentStep > 1 && (
        <button
         type="button"
         onClick={prevStep}
         className="w-full py-3 rounded-lg text-sm font-medium text-slate-600 ring-1 ring-slate-300 hover:bg-slate-50 active:bg-slate-100 active:scale-[0.98] flex items-center justify-center gap-2 transition-all touch-manipulation"
        >
         <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
         </svg>
         السابق
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
