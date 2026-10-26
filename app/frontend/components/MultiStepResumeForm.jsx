import React, { useState, useEffect, useMemo, useRef, Suspense, lazy, memo } from "react";
import { useTranslation } from "react-i18next";
import { createPortal } from "react-dom";
import i18n from "../lib/i18n";
import { trackEvent } from "../lib/posthog";
import CvImportModal from "./cv-builder/CvImportModal";

// Simple translation function using i18n directly (avoids hook issues)
const t = (key, options) => i18n.t(key, options);

// Helper to check if text is primarily English (allows numbers, punctuation, spaces)
// Returns true if text contains mostly English letters (Latin characters)
const isEnglishText = (text) => {
 if (!text || typeof text !== 'string') return true; // Empty is OK
 const trimmed = text.trim();
 if (!trimmed) return true; // Empty after trim is OK
 
 // Remove numbers, punctuation, spaces - keep only letters
 const lettersOnly = trimmed.replace(/[0-9\s\-_.,;:!?@#$%^&*()+=\[\]{}|\\/<>"'`~]/g, '');
 if (!lettersOnly) return true; // Only numbers/punctuation is OK
 
 // Check if letters are primarily Latin (English)
 // Arabic characters are in range \u0600-\u06FF
 const arabicLetters = lettersOnly.match(/[\u0600-\u06FF]/g) || [];
 const latinLetters = lettersOnly.match(/[a-zA-Z]/g) || [];
 
 // If there are Arabic letters and no/few Latin letters, it's not English
 if (arabicLetters.length > 0 && latinLetters.length < arabicLetters.length) {
  return false;
 }
 
 return true;
};

// The professional summary and work duties may be typed in Arabic, but the CV
// is English only and the PDF fonts cannot draw Arabic, so those two must go
// through the AI translate buttons before the user can move on.
const hasArabic = (text) => /[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]/.test(text || "");

// The AI translation, or the summary itself when the user wrote it in English
// (Arabic still has to go through the AI translation).
const englishSummary = (data) =>
 data.professional_summary_english?.trim() ||
 (hasArabic(data.professional_summary) ? "" : data.professional_summary?.trim() || "");

// A translation-limit message that says how to move on: replace the Arabic
// with English typed by hand, or (only where billing is on, so /credits
// exists) get more credits. Rendered wherever the error strings are rendered.
const TranslationLimitNotice = ({ message, translate, billingEnabled }) => (
 <span>
  {message} {translate("translation.limit_replace_hint")}
  {billingEnabled && (
   <>
    {" "}
    <a
     href="/credits"
     className="font-semibold underline underline-offset-2 whitespace-nowrap hover:opacity-80"
    >
     {translate("translation.limit_get_credits")}
    </a>
   </>
  )}
 </span>
);

// Note: ENGLISH_VALIDATION_MSG is now handled via i18n t('validation.english_only')

// Step components are lazy loaded, and all of them are prefetched once the
// form is idle so a later offline blip on Next does not matter. A chunk can
// still fail to load, so the lazy components are rebuilt from these loaders on
// Retry. Browsers remember a failed import() of a URL, so a failed chunk is
// fetched again under a fresh query string; if one of its own imports failed
// too, only a page reload clears it (see retryStepLoad).
const importFresh = (load) =>
 load().catch((error) => {
  const url = String(error?.message).match(/https?:\/\/\S+?\.js/)?.[0];
  if (!url) throw error;
  return import(/* @vite-ignore */ `${url}?retry=${Date.now()}`);
 });
const STEP_LOADERS = {
 1: () => import("./cv-builder/CombinedStep1"),
 2: () => import("./cv-builder/CombinedStep2"),
 3: () => import("./cv-builder/CombinedStep3"),
 4: () => import("./cv-builder/ReviewStep"),
};
const buildLazySteps = () =>
 Object.fromEntries(Object.entries(STEP_LOADERS).map(([step, load]) => [step, lazy(() => importFresh(load))]));

// Catches a failed step chunk (or a step render error) without unmounting the
// form, so everything the user typed stays in the parent's state.
class StepErrorBoundary extends React.Component {
 constructor(props) {
  super(props);
  this.state = { failed: false };
 }

 static getDerivedStateFromError() {
  return { failed: true };
 }

 componentDidCatch(error) {
  console.error("Step failed to load:", error);
 }

 render() {
  if (!this.state.failed) return this.props.children;
  return (
   <div role="alert" data-error className="py-10 flex flex-col items-center gap-4 text-center">
    <p className="text-sm text-red-300">{t("form.step_load_failed")}</p>
    <button
     type="button"
     onClick={this.props.onRetry}
     className="sr-btn glass-soft min-h-[44px] px-5 rounded-2xl text-sm font-medium text-mist touch-manipulation"
    >
     {t("actions.retry")}
    </button>
   </div>
  );
 }
}

// Server rule (WorkExperience): start not after the current month, end after
// start. Dates are "YYYY-MM", so string comparison orders them.
const currentMonth = () => {
 const now = new Date();
 return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;
};
const isYearMonth = (value) => /^\d{4}-\d{2}/.test(value || "");
const workDateErrors = (exp) => {
 const errors = {};
 if (isYearMonth(exp.start_date) && exp.start_date > currentMonth()) {
  errors.start = t("validation.experience_start_future");
 }
 if (!exp.is_current && isYearMonth(exp.start_date) && isYearMonth(exp.end_date) && exp.end_date <= exp.start_date) {
  errors.end = t("validation.experience_end_before_start");
 }
 return errors;
};

// The draft fields that save_draft stores (current_step and saved_at aside).
const draftFields = (data) => ({
 complete_name: data.complete_name,
 email: data.email,
 phone_number: data.phone_number,
 city: data.city,
 country: data.country,
 professional_summary: data.professional_summary,
 professional_summary_english: englishSummary(data),
 education: JSON.stringify(data.education),
 work_experience: JSON.stringify(data.work_experience),
 skills: JSON.stringify(data.skills),
 certifications: JSON.stringify(data.certifications),
 languages: JSON.stringify(data.languages),
});

const AUTOSAVE_DELAY_MS = 1500;
const RETRY_DELAYS_MS = [3000, 6000, 12000, 30000];
const SAVE_TIMEOUT_MS = 15000;

// Memoized skeleton loading for steps - prevents re-renders
const StepLoadingSkeleton = memo(() => (
 <div className="animate-pulse space-y-6">
  <div className="text-center mb-6">
   <div className="inline-flex items-center justify-center w-16 h-16 rounded-[22px] bg-white/[0.06] mb-4" />
   <div className="h-6 bg-primary/10 rounded-lg w-1/2 mx-auto mb-2" />
   <div className="h-4 bg-white/10 rounded-lg w-2/3 mx-auto" />
  </div>
  <div className="glass-soft p-6 rounded-[24px]">
   <div className="h-5 bg-primary/10 rounded-lg w-1/4 mb-4" />
   <div className="space-y-3">
    <div className="h-12 bg-white/[0.06] rounded-xl" />
    <div className="h-12 bg-white/[0.06] rounded-xl" />
    <div className="grid grid-cols-2 gap-4">
     <div className="h-12 bg-white/[0.06] rounded-xl" />
     <div className="h-12 bg-white/[0.06] rounded-xl" />
    </div>
   </div>
  </div>
 </div>
));

const ATS_TEMPLATE_KEYS = [
 "original_classic",
 "harvard_classic",
 "white_black_engineering",
 "simple_clean_gray",
 "minimalist_real_estate",
 "two_column_corporate",
 "blue_minimal_professional",
 "black_white_corporate",
 "infographic_light",
 "clean_single_column",
 "business_admin_modern",
];

const MultiStepResumeForm = ({ resume, onSubmit, billingEnabled = false }) => {
 const { t: translate, i18n: i18nInstance } = useTranslation();
 const ENGLISH_VALIDATION_MSG = translate("validation.english_only");
 const limitNotice = (message) => <TranslationLimitNotice message={message} translate={translate} billingEnabled={billingEnabled} />;

 const templateOptions = useMemo(
  () =>
   ATS_TEMPLATE_KEYS.map((key) => ({
    key,
    name: translate(`templates.ats.${key}.name`),
    description: translate(`templates.ats.${key}.description`),
   })),
  [translate, i18nInstance.language]
 );
 
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

 // Fetch translation limit on mount
 useEffect(() => {
  const fetchTranslationLimit = async () => {
   try {
    const response = await fetch("/api/translation_limit", {
     headers: {
      "X-CSRF-Token": document
       .querySelector('meta[name="csrf-token"]')
       ?.getAttribute("content"),
     },
    });
    if (response.ok) {
     const data = await response.json();
     // Use separate limits for summary and job descriptions
     setUnlimitedUsage(data.unlimited ?? false);
     setRemainingSummaryTranslations(data.unlimited ? null : (data.remaining_summary ?? 5));
     setRemainingJobsTranslations(data.unlimited ? null : (data.remaining_jobs ?? 5));
     setMaxSummaryTranslations(data.unlimited ? null : (data.max_summary ?? 5));
     setMaxJobsTranslations(data.unlimited ? null : (data.max_jobs ?? 5));
     // CV Builder generation limit
     setTranslationLimitLoaded(true);
    }
   } catch (e) {
    console.error("Failed to fetch translation limit:", e);
    setTranslationLimitLoaded(true); // Continue with default
   }
  };
  fetchTranslationLimit();
 }, []);

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
     // Helper to ensure responsibilities is always an array
     const parseResponsibilities = (resp) => {
      if (!resp) return [""];
      if (Array.isArray(resp)) return resp.length > 0 ? resp : [""];
      if (typeof resp === 'string') {
       try {
        const parsed = JSON.parse(resp);
        return Array.isArray(parsed) && parsed.length > 0 ? parsed : [""];
       } catch {
        return [""];
       }
      }
      return [""];
     };
     
     try {
      const workExp = draftData.work_experience
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
      // Ensure each work experience has responsibilities as an array
      return workExp.map(work => ({
       ...work,
       responsibilities: parseResponsibilities(work.responsibilities),
      }));
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
   work_experience: (() => {
    // Helper to ensure responsibilities is always an array
    const parseResponsibilities = (resp) => {
     if (!resp) return [""];
     if (Array.isArray(resp)) return resp.length > 0 ? resp : [""];
     if (typeof resp === 'string') {
      try {
       const parsed = JSON.parse(resp);
       return Array.isArray(parsed) && parsed.length > 0 ? parsed : [""];
      } catch {
       return [""];
      }
     }
     return [""];
    };
    
    if (resume?.work_experience && resume.work_experience.length > 0) {
     return resume.work_experience.map(work => ({
      ...work,
      responsibilities: parseResponsibilities(work.responsibilities),
     }));
    }
    return [
     {
      job_title: "",
      company: "",
      start_date: "",
      end_date: "",
      is_current: false,
      responsibilities: [""],
     },
    ];
   })(),
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
 const [isTranslatingJobs, setIsTranslatingJobs] = useState(false);
 const [jobTranslationError, setJobTranslationError] = useState("");
 const [jobTranslationSuccess, setJobTranslationSuccess] = useState(false);
 const [isExporting, setIsExporting] = useState(false);
 const [exportStatus, setExportStatus] = useState("idle"); // idle, processing, completed, failed, timeout
 const [isSavingDraft, setIsSavingDraft] = useState(false);
 const [addingSkillTo, setAddingSkillTo] = useState(null);
 // Separate translation limits for summary and job descriptions
 const [remainingSummaryTranslations, setRemainingSummaryTranslations] = useState(5);
 const [remainingJobsTranslations, setRemainingJobsTranslations] = useState(5);
 const [maxSummaryTranslations, setMaxSummaryTranslations] = useState(5);
 const [maxJobsTranslations, setMaxJobsTranslations] = useState(5);
 const [unlimitedUsage, setUnlimitedUsage] = useState(false);
 const [translationLimitLoaded, setTranslationLimitLoaded] = useState(false);
 // CV Builder generation limit
 const [autoSaveStatus, setAutoSaveStatus] = useState("idle"); // idle, saving, saved, error
 const [lastSavedAt, setLastSavedAt] = useState(null);
 const [validationErrors, setValidationErrors] = useState({});
 const [touchedFields, setTouchedFields] = useState({}); // Track which fields user has interacted with
 const [showImportModal, setShowImportModal] = useState(false); // CV Import modal state
 const [pdfPreviewUrl, setPdfPreviewUrl] = useState("");
 const [isPdfPreviewLoading, setIsPdfPreviewLoading] = useState(false);
 const [pdfPreviewError, setPdfPreviewError] = useState("");
 const [selectedAtsTemplate, setSelectedAtsTemplate] = useState("harvard_classic");
 const [resumeId, setResumeId] = useState(resume?.id || null);

 useEffect(() => {
  if (resume?.id) {
   setResumeId(resume.id);
  }
 }, [resume?.id]);

 useEffect(() => {
  if (currentStep !== 4) return;
  if (!resumeId) {
   setPdfPreviewUrl("");
   setPdfPreviewError(t("preview.resume_required_for_live"));
   return;
  }

  let cancelled = false;

  const loadPreview = async () => {
   setIsPdfPreviewLoading(true);
   setPdfPreviewError("");
   setPdfPreviewUrl("");

   const saved = await saveDraft(4, true);
   if (cancelled) return;

   if (!saved) {
    setPdfPreviewError(t("preview.error"));
    setIsPdfPreviewLoading(false);
    return;
   }

   const url = `/resumes/${resumeId}/generate_pdf?preview=true&template=${encodeURIComponent(selectedAtsTemplate)}&_ts=${Date.now()}`;
   setPdfPreviewUrl(url);
  };

  loadPreview();

  return () => {
   cancelled = true;
  };
 }, [currentStep, resumeId, selectedAtsTemplate]);

 // Mark a field as touched
 const markFieldTouched = (fieldName) => {
  setTouchedFields(prev => ({ ...prev, [fieldName]: true }));
 };

 const totalSteps = 4;

 // Validation functions for each step
 const validateStep1 = () => {
  const errors = {};
  
  if (!formData.complete_name?.trim()) {
   errors.complete_name = translate("validation.name_required");
  } else if (!isEnglishText(formData.complete_name)) {
   errors.complete_name = ENGLISH_VALIDATION_MSG;
  }
  
  if (!formData.email?.trim()) {
   errors.email = translate("validation.email_required");
  } else if (!/^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/.test(formData.email.trim())) {
   errors.email = translate("validation.invalid_email");
  }
  
  if (!formData.phone_number?.trim()) {
   errors.phone_number = translate("validation.phone_required");
  } else if (!/^\+?[0-9]+$/.test(formData.phone_number.trim())) {
   errors.phone_number = translate("validation.phone_invalid");
  }
  
  if (!formData.city?.trim()) {
   errors.city = translate("validation.city_required");
  } else if (!isEnglishText(formData.city)) {
   errors.city = ENGLISH_VALIDATION_MSG;
  }
  
  if (!formData.country?.trim()) {
   errors.country = translate("validation.country_required");
  } else if (!isEnglishText(formData.country)) {
   errors.country = ENGLISH_VALIDATION_MSG;
  }
  
  // Professional summary - NO English validation (Arabic allowed)
  if (!formData.professional_summary?.trim()) {
   errors.professional_summary = translate("validation.summary_required");
  } else if (formData.professional_summary.trim().length < 5) {
   errors.professional_summary = translate("validation.summary_min_length");
  } else if (!englishSummary(formData) || hasArabic(englishSummary(formData))) {
   errors.professional_summary = !unlimitedUsage && remainingSummaryTranslations <= 0
    ? limitNotice(translate("translation.summary_limit_reached", { max: maxSummaryTranslations }))
    : translate("validation.summary_translate_required");
  }
  
  return errors;
 };

 const validateStep2 = () => {
  const errors = {};
  
  // Validate education - at least one valid entry
  const validEducation = formData.education.filter(
   edu => edu.degree?.trim() && edu.institution?.trim() && edu.start_date?.trim()
  );
  if (validEducation.length === 0) {
   errors.education = translate("validation.education_required");
  } else {
   // Check English validation for education fields
   for (let i = 0; i < formData.education.length; i++) {
    const edu = formData.education[i];
    if (edu.degree?.trim() && !isEnglishText(edu.degree)) {
     errors.education = translate("validation.education_entry_english", {
      n: i + 1,
      field: translate("education.degree"),
      message: ENGLISH_VALIDATION_MSG,
     });
     break;
    }
    if (edu.institution?.trim() && !isEnglishText(edu.institution)) {
     errors.education = translate("validation.education_entry_english", {
      n: i + 1,
      field: translate("education.institution"),
      message: ENGLISH_VALIDATION_MSG,
     });
     break;
    }
   }
  }
  
  // Validate work experience - at least one valid entry
  const validWorkExp = formData.work_experience.filter(
   exp => exp.job_title?.trim() && exp.company?.trim() && exp.start_date?.trim()
  );
  if (validWorkExp.length === 0) {
   errors.work_experience = translate("validation.experience_required");
  } else {
   // Check English validation for work experience fields (NOT responsibilities)
   for (let i = 0; i < formData.work_experience.length; i++) {
    const exp = formData.work_experience[i];
    if (exp.job_title?.trim() && !isEnglishText(exp.job_title)) {
     errors.work_experience = translate("validation.experience_entry_english", {
      n: i + 1,
      field: translate("experience.position"),
      message: ENGLISH_VALIDATION_MSG,
     });
     break;
    }
    if (exp.company?.trim() && !isEnglishText(exp.company)) {
     errors.work_experience = translate("validation.experience_entry_english", {
      n: i + 1,
      field: translate("experience.company"),
      message: ENGLISH_VALIDATION_MSG,
     });
     break;
    }
   }
   // Responsibilities may be typed in Arabic, but must be translated with AI.
   if (!errors.work_experience) {
    const untranslated = formData.work_experience.findIndex(
     exp => (exp.responsibilities || []).some(resp => hasArabic(resp))
    );
    if (untranslated !== -1) {
     errors.work_experience = !unlimitedUsage && remainingJobsTranslations <= 0
      ? limitNotice(translate("translation.jobs_limit_reached", { max: maxJobsTranslations }))
      : translate("validation.responsibilities_translate_required", { n: untranslated + 1 });
    }
   }
  }

  formData.work_experience.forEach((exp, i) => {
   const dateErrors = workDateErrors(exp);
   if (dateErrors.start) errors[`work_start_date_${i}`] = dateErrors.start;
   if (dateErrors.end) errors[`work_end_date_${i}`] = dateErrors.end;
  });
  
  return errors;
 };

 const validateStep3 = () => {
  const errors = {};
  
  // Validate skills - at least one category with skills
  const validSkills = formData.skills.filter(
   skill => skill.category?.trim() && skill.skill_names?.some(name => name?.trim())
  );
  if (validSkills.length === 0) {
   errors.skills = translate("validation.skills_required");
  } else {
   // Check English validation for skills
   for (let i = 0; i < formData.skills.length; i++) {
    const skill = formData.skills[i];
    if (skill.category?.trim() && !isEnglishText(skill.category)) {
     errors.skills = translate("validation.skill_entry_english", {
      n: i + 1,
      field: translate("skills.category"),
      message: ENGLISH_VALIDATION_MSG,
     });
     break;
    }
    // Check each skill name
    const nonEnglishSkill = skill.skill_names?.find(name => name?.trim() && !isEnglishText(name));
    if (nonEnglishSkill) {
     errors.skills = translate("validation.skill_name_english", {
      n: i + 1,
      value: nonEnglishSkill,
      message: ENGLISH_VALIDATION_MSG,
     });
     break;
    }
   }
  }
  
  // Validate certifications - check English
  for (let i = 0; i < (formData.certifications || []).length; i++) {
   const cert = formData.certifications[i];
   if (cert.name?.trim() && !isEnglishText(cert.name)) {
    errors.certifications = translate("validation.cert_entry_english", {
     n: i + 1,
     field: translate("certifications.name"),
     message: ENGLISH_VALIDATION_MSG,
    });
    break;
   }
   if (cert.organization?.trim() && !isEnglishText(cert.organization)) {
    errors.certifications = translate("validation.cert_entry_english", {
     n: i + 1,
     field: translate("certifications.issuer"),
     message: ENGLISH_VALIDATION_MSG,
    });
    break;
   }
  }
  
  // Validate languages - at least one language
  const validLanguages = formData.languages.filter(
   lang => lang.language?.trim() && lang.proficiency?.trim()
  );
  if (validLanguages.length === 0) {
   errors.languages = translate("validation.languages_required");
  } else {
   // Check English validation for language names
   for (let i = 0; i < formData.languages.length; i++) {
    const lang = formData.languages[i];
    if (lang.language?.trim() && !isEnglishText(lang.language)) {
     errors.languages = translate("validation.language_entry_english", {
      n: i + 1,
      field: translate("languages.name"),
      message: ENGLISH_VALIDATION_MSG,
     });
     break;
    }
   }
  }
  
  return errors;
 };

 const validateCurrentStep = () => {
  let errors = {};
  
  switch (currentStep) {
   case 1:
    errors = validateStep1();
    break;
   case 2:
    errors = validateStep2();
    break;
   case 3:
    errors = validateStep3();
    break;
   default:
    break;
  }
  
  setValidationErrors(errors);
  return Object.keys(errors).length === 0;
 };

 // Live validation - validate a single field and update errors immediately
 const validateFieldLive = (fieldName, value, extraContext = {}) => {
  let error = null;
  
  // Step 1 fields
  if (fieldName === 'complete_name') {
   if (!value?.trim()) {
    error = translate("validation.name_required");
   } else if (!isEnglishText(value)) {
    error = ENGLISH_VALIDATION_MSG;
   }
  } else if (fieldName === 'email') {
   if (!value?.trim()) {
    error = translate("validation.email_required");
   } else if (!/^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/.test(value.trim())) {
    error = translate("validation.invalid_email");
   }
  } else if (fieldName === 'phone_number') {
   if (!value?.trim()) {
    error = translate("validation.phone_required");
   } else if (!/^\+?[0-9]+$/.test(value.trim())) {
    error = translate("validation.phone_invalid");
   }
  } else if (fieldName === 'city') {
   if (!value?.trim()) {
    error = translate("validation.city_required");
   } else if (!isEnglishText(value)) {
    error = ENGLISH_VALIDATION_MSG;
   }
  } else if (fieldName === 'country') {
   if (!value?.trim()) {
    error = translate("validation.country_required");
   } else if (!isEnglishText(value)) {
    error = ENGLISH_VALIDATION_MSG;
   }
  } else if (fieldName === 'professional_summary') {
   if (!value?.trim()) {
    error = translate("validation.summary_required");
   } else if (value.trim().length < 5) {
    error = translate("validation.summary_min_length");
   }
   // No English check for professional_summary
  }
  // Step 2 fields - education
  else if (fieldName === 'education_degree') {
   if (value?.trim() && !isEnglishText(value)) {
    error = ENGLISH_VALIDATION_MSG;
   }
  } else if (fieldName === 'education_institution') {
   if (value?.trim() && !isEnglishText(value)) {
    error = ENGLISH_VALIDATION_MSG;
   }
  }
  // Step 2 fields - work experience
  else if (fieldName === 'work_job_title') {
   if (value?.trim() && !isEnglishText(value)) {
    error = ENGLISH_VALIDATION_MSG;
   }
  } else if (fieldName === 'work_company') {
   if (value?.trim() && !isEnglishText(value)) {
    error = ENGLISH_VALIDATION_MSG;
   }
  }
  // Step 3 fields - skills
  else if (fieldName === 'skill_category') {
   if (value?.trim() && !isEnglishText(value)) {
    error = ENGLISH_VALIDATION_MSG;
   }
  } else if (fieldName === 'skill_name') {
   if (value?.trim() && !isEnglishText(value)) {
    error = ENGLISH_VALIDATION_MSG;
   }
  }
  // Step 3 fields - certifications
  else if (fieldName === 'cert_name') {
   if (value?.trim() && !isEnglishText(value)) {
    error = ENGLISH_VALIDATION_MSG;
   }
  } else if (fieldName === 'cert_organization') {
   if (value?.trim() && !isEnglishText(value)) {
    error = ENGLISH_VALIDATION_MSG;
   }
  }
  // Step 3 fields - languages
  else if (fieldName === 'language_name') {
   if (value?.trim() && !isEnglishText(value)) {
    error = ENGLISH_VALIDATION_MSG;
   }
  }
  
  // Update errors
  setValidationErrors(prev => {
   const newErrors = { ...prev };
   const errorKey = extraContext.index !== undefined ? `${fieldName}_${extraContext.index}` : fieldName;
   if (error) {
    newErrors[errorKey] = error;
   } else {
    delete newErrors[errorKey];
   }
   return newErrors;
  });
  
  return error;
 };

 // Helper to ensure responsibilities is always an array
 const parseResponsibilities = (resp) => {
  if (!resp) return [""];
  if (Array.isArray(resp)) return resp.length > 0 ? resp : [""];
  if (typeof resp === 'string') {
   try {
    const parsed = JSON.parse(resp);
    return Array.isArray(parsed) && parsed.length > 0 ? parsed : [""];
   } catch {
    return [""];
   }
  }
  return [""];
 };

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
     responsibilities: parseResponsibilities(exp.responsibilities),
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
  // Live validation
  markFieldTouched(field);
  validateFieldLive(field, value);
 };

 const handleEducationChange = (index, field, value) => {
  setFormData((prev) => ({
   ...prev,
   education: prev.education.map((edu, i) =>
    i === index ? { ...edu, [field]: value } : edu
   ),
  }));
  // Live validation for education fields
  const fieldKey = `education_${field}_${index}`;
  markFieldTouched(fieldKey);
  if (field === 'degree') {
   validateFieldLive('education_degree', value, { index });
  } else if (field === 'institution') {
   validateFieldLive('education_institution', value, { index });
  }
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
  const current = formData.work_experience[index] || {};
  // A current job has no end date (the picker is disabled), so drop it.
  const updated = field === "is_current" && value
   ? { ...current, is_current: true, end_date: "" }
   : { ...current, [field]: value };
  setFormData((prev) => ({
   ...prev,
   work_experience: prev.work_experience.map((work, i) =>
    i === index ? { ...work, ...(field === "is_current" && value ? { is_current: true, end_date: "" } : { [field]: value }) } : work
   ),
  }));
  // Live validation for work experience fields (NOT responsibilities)
  const fieldKey = `work_${field}_${index}`;
  markFieldTouched(fieldKey);
  if (["start_date", "end_date", "is_current"].includes(field)) {
   const dateErrors = workDateErrors(updated);
   setValidationErrors((prev) => {
    const next = { ...prev };
    delete next[`work_start_date_${index}`];
    delete next[`work_end_date_${index}`];
    if (dateErrors.start) next[`work_start_date_${index}`] = dateErrors.start;
    if (dateErrors.end) next[`work_end_date_${index}`] = dateErrors.end;
    return next;
   });
  } else if (field === 'job_title') {
   validateFieldLive('work_job_title', value, { index });
  } else if (field === 'company') {
   validateFieldLive('work_company', value, { index });
  }
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
  // Live validation for skill fields
  const fieldKey = `skill_${field}_${index}`;
  markFieldTouched(fieldKey);
  if (field === 'category') {
   validateFieldLive('skill_category', value, { index });
  }
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

 // The new-skill box only validates while typing; the skill is added on Enter
 // (the box stays open and focused for the next one) or when the box loses
 // focus.
 const handleNewSkillChange = (skillIndex, value) => {
  markFieldTouched(`skill_name_${skillIndex}_new`);
  validateFieldLive('skill_name', value, { index: `${skillIndex}_new` });
 };

 const commitNewSkill = (skillIndex, value) => {
  const name = value?.trim();
  if (!name || !isEnglishText(name)) return false;
  setFormData((prev) => ({
   ...prev,
   skills: prev.skills.map((skill, i) =>
    i === skillIndex
     ? { ...skill, skill_names: [...skill.skill_names, name] }
     : skill
   ),
  }));
  setValidationErrors(prev => {
   const newErrors = { ...prev };
   delete newErrors[`skill_name_${skillIndex}_new`];
   return newErrors;
  });
  return true;
 };

 const handleNewSkillKeyDown = (skillIndex, event) => {
  if (event.key !== "Enter" || event.nativeEvent?.isComposing) return;
  event.preventDefault();
  if (commitNewSkill(skillIndex, event.target.value)) event.target.value = "";
 };

 const handleNewSkillBlur = (skillIndex, value) => {
  // Keep the box open while what is typed is not valid, so it is not lost.
  if (value?.trim() && !commitNewSkill(skillIndex, value)) return;
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
  // Live validation for skill name
  const fieldKey = `skill_name_${skillIndex}_${nameIndex}`;
  markFieldTouched(fieldKey);
  validateFieldLive('skill_name', value, { index: `${skillIndex}_${nameIndex}` });
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
  // Live validation for certification fields
  const fieldKey = `cert_${field}_${index}`;
  markFieldTouched(fieldKey);
  if (field === 'name') {
   validateFieldLive('cert_name', value, { index });
  } else if (field === 'organization') {
   validateFieldLive('cert_organization', value, { index });
  }
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
  // Live validation for language name
  const fieldKey = `language_${field}_${index}`;
  markFieldTouched(fieldKey);
  if (field === 'language') {
   validateFieldLive('language_name', value, { index });
  }
 };

 const translateProfessionalSummary = async () => {
  if (!formData.professional_summary.trim()) {
   setTranslationError(translate("translation.summary_required"));
   return;
  }

  // Minimum 5 characters required
  if (formData.professional_summary.trim().length < 5) {
   setTranslationError(translate("translation.summary_min_chars"));
   return;
  }

  // Check translation limit for summary
  if (!unlimitedUsage && remainingSummaryTranslations <= 0) {
   setTranslationError(
    limitNotice(translate("translation.summary_limit_reached", { max: maxSummaryTranslations }))
   );
   return;
  }

  // Track translation attempt
  trackEvent("translation_started", { type: "professional_summary" });

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
     resume_id: resume?.id,
    }),
   });

   if (response.ok) {
    const result = await response.json();
    if (result.status === "queued" && result.job_id) {
     // Update remaining summary translations from server
     if (result.unlimited) {
      setUnlimitedUsage(true);
     } else if (result.remaining_summary !== undefined) {
      setRemainingSummaryTranslations(result.remaining_summary);
     }
     // Poll for completion
     pollTranslationStatus(result.job_id);
    } else {
     setTranslationError(translate("translation.unexpected_api"));
     setIsTranslating(false);
    }
   } else if (response.status === 429) {
    const result = await response.json();
    setTranslationError(
     limitNotice(result.error || translate("translation.summary_limit_reached", { max: maxSummaryTranslations }))
    );
    setRemainingSummaryTranslations(0);
    setIsTranslating(false);
   } else {
    throw new Error("Translation request failed");
   }
  } catch (error) {
   console.error("Translation error:", error);
   setTranslationError(translate("translation.generic_error"));
   setIsTranslating(false);
  }
 };

 // Translate all job descriptions at once
 const translateJobDescriptions = async () => {
  // Filter jobs with responsibilities
  const jobsWithResponsibilities = formData.work_experience
   .map((work, index) => ({
    index,
    job_title: work.job_title,
    company: work.company,
    responsibilities: work.responsibilities?.filter(r => r?.trim()) || []
   }))
   .filter(job => job.responsibilities.length > 0);

  if (jobsWithResponsibilities.length === 0) {
   setJobTranslationError(translate("translation.no_responsibilities"));
   return;
  }

  // Check translation limit for job descriptions
  if (!unlimitedUsage && remainingJobsTranslations <= 0) {
   setJobTranslationError(
    limitNotice(translate("translation.jobs_limit_reached", { max: maxJobsTranslations }))
   );
   return;
  }

  // Track translation attempt
  trackEvent("translation_started", { type: "job_descriptions", job_count: jobsWithResponsibilities.length });

  setIsTranslatingJobs(true);
  setJobTranslationError("");
  setJobTranslationSuccess(false);

  try {
   const response = await fetch("/api/translate_job_descriptions", {
    method: "POST",
    headers: {
     "Content-Type": "application/json",
     "X-CSRF-Token": document
      .querySelector('meta[name="csrf-token"]')
      ?.getAttribute("content"),
    },
    body: JSON.stringify({
     job_descriptions: jobsWithResponsibilities,
     resume_id: resume?.id,
    }),
   });

   if (response.ok) {
    const result = await response.json();
    if (result.status === "queued" && result.job_id) {
     // Update remaining job translations from server
     if (result.unlimited) {
      setUnlimitedUsage(true);
     } else if (result.remaining_jobs !== undefined) {
      setRemainingJobsTranslations(result.remaining_jobs);
     }
     // Poll for completion
     pollJobTranslationStatus(result.job_id, jobsWithResponsibilities);
    } else {
     setJobTranslationError(translate("translation.unexpected_api"));
     setIsTranslatingJobs(false);
    }
   } else if (response.status === 429) {
    const result = await response.json();
    setJobTranslationError(
     limitNotice(result.error || translate("translation.jobs_limit_reached", { max: maxJobsTranslations }))
    );
    setRemainingJobsTranslations(0);
    setIsTranslatingJobs(false);
   } else {
    throw new Error("Translation request failed");
   }
  } catch (error) {
   console.error("Job translation error:", error);
   setJobTranslationError(translate("translation.generic_error"));
   setIsTranslatingJobs(false);
  }
 };

 // Poll for job descriptions translation status
 const pollJobTranslationStatus = async (jobId, originalJobs) => {
  const maxAttempts = 60; // 60 seconds max for multiple jobs
  let attempts = 0;

  const poll = async () => {
   try {
    const response = await fetch(`/api/translation_status/${jobId}`);
    if (response.ok) {
     const status = await response.json();

     if (status.status === "completed" && status.jobs) {
      // Update work experience with translated responsibilities - REPLACE the Arabic with English
      setFormData((prev) => {
       const updatedExperience = [...prev.work_experience];
       
       // Map translated jobs back to original indices
       status.jobs.forEach((translatedJob, idx) => {
        const originalIndex = originalJobs[idx]?.index;
        if (originalIndex !== undefined && updatedExperience[originalIndex]) {
         const englishResponsibilities = translatedJob.responsibilities_english || [];
         // Replace Arabic responsibilities with English translations
         if (englishResponsibilities.length > 0) {
          updatedExperience[originalIndex] = {
           ...updatedExperience[originalIndex],
           responsibilities: englishResponsibilities,
           responsibilities_arabic: updatedExperience[originalIndex].responsibilities, // Keep original
          };
         }
        }
       });

       return {
        ...prev,
        work_experience: updatedExperience,
       };
      });

      // Extract skills from job descriptions
      if (status.skills_extracted?.length > 0) {
       const extractedSkills = status.skills_extracted;
       const skillsByCategory = {};
       extractedSkills.forEach((skill) => {
        const category = skill.category || "technical";
        if (!skillsByCategory[category]) {
         skillsByCategory[category] = [];
        }
        skillsByCategory[category].push(skill.name);
       });

       const newSkills = Object.entries(skillsByCategory).map(
        ([category, skillNames]) => ({
         category: category,
         skill_names: skillNames,
        })
       );

       setFormData((prev) => {
        const existingSkills = [...prev.skills];
        newSkills.forEach((newSkill) => {
         const existingCategoryIndex = existingSkills.findIndex(
          (existing) => existing.category === newSkill.category
         );
         if (existingCategoryIndex >= 0) {
          const existingSkill = existingSkills[existingCategoryIndex];
          const mergedSkillNames = [
           ...new Set([...existingSkill.skill_names, ...newSkill.skill_names]),
          ];
          existingSkills[existingCategoryIndex] = {
           ...existingSkill,
           skill_names: mergedSkillNames,
          };
         } else {
          existingSkills.push(newSkill);
         }
        });
        return { ...prev, skills: existingSkills };
       });
      }

      setIsTranslatingJobs(false);
      setJobTranslationSuccess(true);
      return;
     } else if (status.status === "failed") {
      setJobTranslationError(
       status.error_code
        ? `${translate("translation.failed")} (${status.error_code})`
        : translate("translation.failed")
      );
      setIsTranslatingJobs(false);
      return;
     }
    }

    attempts++;
    if (attempts < maxAttempts) {
     setTimeout(poll, 1000);
    } else {
     setJobTranslationError(translate("translation.timeout"));
     setIsTranslatingJobs(false);
    }
   } catch (error) {
    console.error("Polling error:", error);
    attempts++;
    if (attempts < maxAttempts) {
     setTimeout(poll, 1000);
    } else {
     setJobTranslationError(translate("translation.timeout"));
     setIsTranslatingJobs(false);
    }
   }
  };

  poll();
 };

 // Robust resume saving function
 const saveResumeToDatabase = async () => {

  // Validate required fields
  if (!formData.complete_name?.trim()) {
   throw new Error(translate("validation.name_required"));
  }
  if (!formData.email?.trim()) {
   throw new Error(translate("validation.email_required"));
  }

  const csrfToken = document
   .querySelector('meta[name="csrf-token"]')
   ?.getAttribute("content");
  if (!csrfToken) {
   throw new Error(translate("security.csrf_missing"));
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
    professional_summary_english: englishSummary(formData),
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
     // The issue date is optional; a certification without one is kept.
     .filter((cert) => cert.name?.trim() && cert.organization?.trim())
     .map((cert, index) => ({
      name: cert.name.trim(),
      organization: cert.organization.trim(),
      date: cert.date?.trim() || "",
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
     englishSummary(formData)
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
  // A draft can open straight on the review step, so check the AI translation
  // rule here too and send the user back to the step that still needs it.
  const step1Errors = validateStep1();
  const step2Errors = validateStep2();
  if (Object.keys(step1Errors).length > 0 || Object.keys(step2Errors).length > 0) {
   setValidationErrors(Object.keys(step1Errors).length > 0 ? step1Errors : step2Errors);
   handleStepChange(Object.keys(step1Errors).length > 0 ? 1 : 2);
   return;
  }

  setIsExporting(true);
  setTranslationError("");

  // Track PDF export attempt
  trackEvent("pdf_export_started", { resume_id: resume?.id, template: selectedAtsTemplate });

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
     alert(translate("export.name_email_required"));
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
     const downloadUrl = `/api/export_pdf?resume_id=${resumeId}&direct_download=true&template=${selectedAtsTemplate}&t=${Date.now()}`;

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
      `/api/export_pdf?resume_id=${resumeId}&direct_download=true&template=${selectedAtsTemplate}`,
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
      template: selectedAtsTemplate,
      resume: {
       complete_name: formData.complete_name,
       email: formData.email,
       phone_number: formData.phone_number,
       city: formData.city,
       country: formData.country,
       professional_summary: formData.professional_summary,
       professional_summary_english: englishSummary(formData),
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
         setTranslationError(translate("export.pdf_failed"));
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
       setTranslationError(translate("export.pdf_timeout"));
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
   setTranslationError(translate("export.pdf_error"));
  } finally {
   setIsExporting(false);
  }
 };

 // Draft saving. Every save goes through one queue so two never run at once;
 // an autosave that is already queued is not queued again, and it reads the
 // latest form data when it starts, so it acts as the trailing save.
 const formDataRef = useRef(formData);
 formDataRef.current = formData;
 const currentStepRef = useRef(currentStep);
 currentStepRef.current = currentStep;
 const resumeIdRef = useRef(resumeId);
 resumeIdRef.current = resumeId;
 const saveQueueRef = useRef(Promise.resolve());
 const autoSaveQueuedRef = useRef(false);
 const savesInFlightRef = useRef(0);
 const autoSaveTimerRef = useRef(null);
 const retryTimerRef = useRef(null);
 const retryCountRef = useRef(0);
 // The last updated_at this tab knows for the draft. The server refuses a
 // save based on an older one (another tab saved since) with 409 "stale";
 // then this tab stops saving until it is reloaded.
 const baseUpdatedAtRef = useRef(resume?.updated_at || null);
 const staleRef = useRef(false);
 // saved_at of saves that got no answer: the server may still have stored
 // them, so a 409 naming one of them is this tab's own write, not another's.
 const unansweredSavesRef = useRef(new Set());
 const [isStale, setIsStale] = useState(false);
 // Until the user edits something, form changes (draft hydration, sections
 // loading) only move the baseline and do not count as unsaved.
 const userEditedRef = useRef(false);
 const draftKey = useMemo(() => JSON.stringify(draftFields(formData)), [formData]);
 const savedDraftKeyRef = useRef(draftKey);
 const [savedDraftKey, setSavedDraftKey] = useState(draftKey);
 const hasUnsavedChanges = draftKey !== savedDraftKey;
 const isDirtyNow = () =>
  userEditedRef.current &&
  JSON.stringify(draftFields(formDataRef.current)) !== savedDraftKeyRef.current;
 // A failed save is retried even when the fields match the last saved ones
 // (it may have carried only the step change).
 const lastSaveFailedRef = useRef(false);
 const needsSave = () => isDirtyNow() || lastSaveFailedRef.current;

 const markSaved = (key) => {
  savedDraftKeyRef.current = key;
  setSavedDraftKey(key);
 };

 const runSave = async (stepNumber, { keepalive = false } = {}) => {
  const fields = draftFields(formDataRef.current);
  const key = JSON.stringify(fields);
  if (staleRef.current) return false;
  const savedAt = new Date().toISOString();
  const body = new URLSearchParams({
   ...fields,
   current_step: stepNumber,
   saved_at: savedAt,
  });
  if (baseUpdatedAtRef.current) body.set("base_updated_at", baseUpdatedAtRef.current);
  savesInFlightRef.current += 1;
  // After a failed save, keep "Not saved. Retrying…" until one succeeds.
  setAutoSaveStatus(lastSaveFailedRef.current ? "error" : "saving");
  // A save that never answers counts as failed, so the queue moves on.
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), SAVE_TIMEOUT_MS);
  try {
   const response = await fetch(`/resumes/${resumeIdRef.current || "new"}/save_draft`, {
    method: "POST",
    headers: {
     "Content-Type": "application/x-www-form-urlencoded",
     "X-CSRF-Token": document
      .querySelector('meta[name="csrf-token"]')
      ?.getAttribute("content"),
     Accept: "application/json",
    },
    body,
    // keepalive lets a save started as the tab is hidden finish (64 KB cap).
    keepalive: keepalive && body.toString().length < 60000,
    signal: controller.signal,
   });
   if (response.status === 409) {
    const conflict = await response.json().catch(() => ({}));
    if (conflict.error === "stale" && unansweredSavesRef.current.has(conflict.saved_at)) {
     baseUpdatedAtRef.current = conflict.updated_at;
     throw new Error("save_draft 409 own write");
    }
    if (conflict.error === "stale") {
     staleRef.current = true;
     setIsStale(true);
     clearTimeout(autoSaveTimerRef.current);
     clearTimeout(retryTimerRef.current);
     setAutoSaveStatus(null);
     return false;
    }
   }
   if (!response.ok) throw new Error(`save_draft ${response.status}`);
   const result = await response.json();
   if (result.updated_at) baseUpdatedAtRef.current = result.updated_at;
   unansweredSavesRef.current.clear();
   if (result.resume_id) {
    resumeIdRef.current = result.resume_id;
    setResumeId(result.resume_id);
   }
   markSaved(key);
   lastSaveFailedRef.current = false;
   retryCountRef.current = 0;
   clearTimeout(retryTimerRef.current);
   setLastSavedAt(new Date());
   setAutoSaveStatus("saved");
   return true;
  } catch (error) {
   console.error("Error saving draft:", error);
   // No response at all (timeout, network): the outcome is unknown.
   if (error.name === "AbortError" || error.name === "TypeError") unansweredSavesRef.current.add(savedAt);
   lastSaveFailedRef.current = true;
   setAutoSaveStatus("error");
   scheduleRetry();
   return false;
  } finally {
   clearTimeout(timeout);
   savesInFlightRef.current -= 1;
  }
 };

 const enqueueSave = (task) => {
  const result = saveQueueRef.current.then(task);
  saveQueueRef.current = result.catch(() => {});
  return result;
 };

 // Save now with the latest data (Next, Previous, preview, Manual save).
 const saveDraft = async (stepNumber = currentStepRef.current, silent = false) => {
  clearTimeout(autoSaveTimerRef.current);
  if (!silent) setIsSavingDraft(true);
  try {
   return await enqueueSave(() => runSave(stepNumber));
  } finally {
   if (!silent) setIsSavingDraft(false);
  }
 };

 const autoSave = (options = {}) => {
  clearTimeout(autoSaveTimerRef.current);
  if (autoSaveQueuedRef.current) return;
  autoSaveQueuedRef.current = true;
  enqueueSave(() => {
   autoSaveQueuedRef.current = false;
   if (!needsSave()) return true;
   return runSave(currentStepRef.current, options);
  });
 };
 const autoSaveRef = useRef(autoSave);
 autoSaveRef.current = autoSave;

 function scheduleRetry() {
  clearTimeout(retryTimerRef.current);
  const delay = RETRY_DELAYS_MS[Math.min(retryCountRef.current, RETRY_DELAYS_MS.length - 1)];
  retryCountRef.current += 1;
  retryTimerRef.current = setTimeout(() => autoSaveRef.current(), delay);
 }

 // Debounced autosave after the last change.
 useEffect(() => {
  if (!userEditedRef.current) {
   markSaved(draftKey);
   return;
  }
  if (draftKey === savedDraftKeyRef.current) return;
  clearTimeout(autoSaveTimerRef.current);
  autoSaveTimerRef.current = setTimeout(() => autoSaveRef.current(), AUTOSAVE_DELAY_MS);
 }, [draftKey]);

 // Save right away when the tab is hidden or the connection comes back, and
 // warn before leaving while changes are unsaved or a save is running.
 useEffect(() => {
  const flushIfDirty = (options) => {
   if (needsSave()) autoSaveRef.current(options);
  };
  const onVisibilityChange = () => {
   if (document.visibilityState === "hidden") flushIfDirty({ keepalive: true });
  };
  const onOnline = () => flushIfDirty();
  const onBeforeUnload = (event) => {
   if (staleRef.current) return;
   if (!isDirtyNow() && savesInFlightRef.current === 0) return;
   flushIfDirty({ keepalive: true });
   event.preventDefault();
   event.returnValue = "";
  };
  document.addEventListener("visibilitychange", onVisibilityChange);
  window.addEventListener("online", onOnline);
  window.addEventListener("beforeunload", onBeforeUnload);
  return () => {
   document.removeEventListener("visibilitychange", onVisibilityChange);
   window.removeEventListener("online", onOnline);
   window.removeEventListener("beforeunload", onBeforeUnload);
   clearTimeout(autoSaveTimerRef.current);
   clearTimeout(retryTimerRef.current);
  };
 }, []);

 // Any input, change or click inside the step counts as a user edit; leaving
 // a field saves at once instead of waiting for the debounce.
 const stepContentHandlers = {
  onInputCapture: () => { userEditedRef.current = true; },
  onChangeCapture: () => { userEditedRef.current = true; },
  onClickCapture: () => { userEditedRef.current = true; },
  onBlurCapture: () => {
   if (isDirtyNow()) autoSaveRef.current();
  },
 };

 // What the save indicator shows: only what is true right now.
 const saveIndicator =
  autoSaveStatus === "saving" ? "saving" :
  autoSaveStatus === "error" ? "error" :
  autoSaveStatus === "saved" && !hasUnsavedChanges ? "saved" :
  null;

 // Manual save button (the save status itself is shown in the header).
 const renderSaveDraftButton = (stepNumber) => (
  <div className="mt-4 sm:mt-6 pt-4 border-t border-white/10 flex items-center justify-end">
   <button
    type="button"
    onClick={() => saveDraft(stepNumber)}
    disabled={isSavingDraft}
    className="text-sm text-mist/60 hover:text-mist underline underline-offset-4 disabled:opacity-50 min-h-[44px] px-3 rounded-xl hover:bg-white/5 active:bg-white/10 transition-all touch-manipulation"
   >
    {isSavingDraft ? t('form.saving') : t('form.manual_save')}
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

      // Update remaining count from server (only counts completed)
      if (status.remaining_summary !== undefined) {
       setRemainingSummaryTranslations(status.remaining_summary);
      }

      setIsTranslating(false);
      return;
     } else if (status.status === "failed") {
      // Update remaining count from server (failed translations don't count)
      if (status.remaining_summary !== undefined) {
       setRemainingSummaryTranslations(status.remaining_summary);
      }
      setTranslationError(
       status.error_code
        ? `${translate("translation.failed")} (${status.error_code})`
        : translate("translation.failed")
      );
      setIsTranslating(false);
      return;
     }
    }

    attempts++;
    if (attempts < maxAttempts) {
     setTimeout(poll, 1000); // Poll every second
    } else {
     setTranslationError(translate("translation.timeout"));
     setIsTranslating(false);
    }
   } catch (error) {
    console.error("Polling error:", error);
    attempts++;
    if (attempts < maxAttempts) {
     setTimeout(poll, 1000);
    } else {
     setTranslationError(translate("translation.timeout"));
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

 const nextStep = async () => {
  if (currentStep < totalSteps) {
   // Validate current step before moving
   if (!validateCurrentStep()) {
    // Scroll to first error
    setTimeout(() => {
     const errorElement = document.querySelector('[data-error]');
     if (errorElement) {
      errorElement.scrollIntoView({ behavior: 'smooth', block: 'center' });
     }
    }, 100);
    return;
   }
   
   // Clear validation errors on successful validation
   setValidationErrors({});
   
   // Save in the background; a slow or hung save never holds the step
   // change, and later edits queue behind it.
   if (resumeId) {
    saveDraft(currentStep, true);
   }
   
   const newStep = currentStep + 1;
   setCurrentStep(newStep);

   // Track step progression
   trackEvent("form_step_completed", { step: currentStep, next_step: newStep });

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
   if (resumeId) {
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

 // Handle CV import completion - populate form with imported data
 const handleImportComplete = (parsedData) => {
  if (!parsedData) return;

  // Track import event
  trackEvent("cv_imported", { source: "pdf_upload" });
  userEditedRef.current = true;

  // Update form data with imported values
  setFormData(prev => ({
   ...prev,
   complete_name: parsedData.complete_name || prev.complete_name,
   email: parsedData.email || prev.email,
   phone_number: parsedData.phone_number || prev.phone_number,
   city: parsedData.city || prev.city,
   country: parsedData.country || prev.country,
   professional_summary: parsedData.professional_summary || prev.professional_summary,
   work_experience: parsedData.work_experiences?.length > 0
    ? parsedData.work_experiences.map(exp => ({
      job_title: exp.job_title || "",
      company: exp.company || "",
      start_date: exp.start_date || "",
      end_date: exp.end_date || "",
      is_current: exp.is_current || false,
      responsibilities: exp.responsibilities?.length > 0 ? exp.responsibilities : [""],
     }))
    : prev.work_experience,
   education: parsedData.educations?.length > 0
    ? parsedData.educations.map(edu => ({
      degree: edu.degree || "",
      institution: edu.institution || "",
      start_date: edu.start_date || "",
      end_date: edu.end_date || "",
      gpa: edu.gpa || "",
      is_current: edu.is_current || false,
     }))
    : prev.education,
   skills: parsedData.skills?.length > 0
    ? parsedData.skills.map(skill => ({
      category: skill.category || "",
      skill_names: skill.skill_names || [],
     }))
    : prev.skills,
   certifications: parsedData.certifications?.length > 0
    ? parsedData.certifications.map(cert => ({
      name: cert.name || "",
      organization: cert.organization || "",
      date: cert.date || "",
     }))
    : prev.certifications,
   languages: parsedData.languages?.length > 0
    ? parsedData.languages.map(lang => ({
      language: lang.language || "",
      proficiency: lang.proficiency || "",
     }))
    : prev.languages,
  }));

  // Clear validation errors since we have new data
  setValidationErrors({});
  setTouchedFields({});
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
   alert(translate("alerts.fill_required"));
   return;
  }

  // Validate education data
  const hasValidEducation = formData.education.some(
   (edu) => edu.degree && edu.institution && edu.start_date
  );

  if (!hasValidEducation) {
   alert(translate("alerts.education_required"));
   return;
  }

  // Validate work experience data
  const hasValidWorkExperience = formData.work_experience.some(
   (work) => work.job_title && work.company && work.start_date
  );

  if (!hasValidWorkExperience) {
   alert(translate("alerts.experience_required"));
   return;
  }

  // Validate skills data
  const hasValidSkills = formData.skills.some(
   (skill) =>
    skill.category && skill.skill_names.some((name) => name.trim() !== "")
  );

  if (!hasValidSkills) {
   alert(translate("alerts.skills_required"));
   return;
  }

  // Validate certifications data
  const hasValidCertifications = formData.certifications.some(
   (cert) => cert.name && cert.organization && cert.date
  );

  if (!hasValidCertifications) {
   alert(translate("alerts.certification_required"));
   return;
  }

  // Validate languages data
  const hasValidLanguages = formData.languages.some(
   (lang) => lang.language && lang.proficiency
  );

  if (!hasValidLanguages) {
   alert(translate("alerts.languages_required"));
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
    "resume[professional_summary_english]": englishSummary(formData),
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

   // Track form submission
   trackEvent("resume_form_submitted", {
    resume_id: resume?.id,
    has_professional_summary: !!formData.professional_summary_english,
    education_count: formData.education?.length || 0,
    work_experience_count: formData.work_experience?.length || 0,
    skills_count: formData.skills?.length || 0,
   });

   onSubmit(railsFormData);
  }
 };


 // Bumped by Retry after a step chunk failed to load: new lazy components
 // import the chunk again, and the new boundary key clears the error.
 const [stepLoadAttempt, setStepLoadAttempt] = useState(0);
 const lazySteps = useMemo(buildLazySteps, [stepLoadAttempt]);

 const retryStepLoad = async () => {
  try {
   await importFresh(STEP_LOADERS[currentStepRef.current]);
  } catch {
   // Online but still failing: a cached failed import. Save, then reload
   // (the URL keeps the step and the saved draft refills the form).
   if (navigator.onLine && (await saveDraft(currentStepRef.current, true))) {
    window.location.reload();
    return;
   }
  }
  setStepLoadAttempt((n) => n + 1);
 };

 useEffect(() => {
  const prefetch = () => Object.values(STEP_LOADERS).forEach((load) => load().catch(() => {}));
  const idle = window.requestIdleCallback || ((cb) => setTimeout(cb, 1500));
  const cancel = window.cancelIdleCallback || clearTimeout;
  const handle = idle(prefetch);
  return () => cancel(handle);
 }, []);

 const renderStepContent = () => {
  if (isLoading) return <StepLoadingSkeleton />;
  const stepProps = {
   formData,
   handleInputChange,
   translateProfessionalSummary,
   isTranslating,
   translationError,
   // Separate translation limits for each type
   remainingSummaryTranslations,
   maxSummaryTranslations,
   unlimitedUsage,
   remainingJobsTranslations,
   maxJobsTranslations,
   renderSaveDraftButton,
   validationErrors,
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
   // Step 2 translation props
   onTranslateJobDescriptions: translateJobDescriptions,
   isTranslatingJobs,
   jobTranslationError,
   jobTranslationSuccess,
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
   handleNewSkillKeyDown,
   handleNewSkillBlur,
   handleCertificationChange,
   addCertification,
   removeCertification,
   handleLanguageChange,
   addLanguage,
   removeLanguage,
   selectedTemplate: selectedAtsTemplate,
   onTemplateChange: setSelectedAtsTemplate,
   templateOptions,
   resumeId: resume?.id,
   pdfPreviewUrl,
   isPdfPreviewLoading,
   pdfPreviewError,
   onPdfPreviewLoaded: () => setIsPdfPreviewLoading(false),
   onPdfPreviewError: () => {
    setIsPdfPreviewLoading(false);
    setPdfPreviewError(t("preview.error"));
   },
  };

  const StepComponent = lazySteps[currentStep];
  return (
   <StepErrorBoundary key={`${stepLoadAttempt}-${currentStep}`} onRetry={retryStepLoad}>
    <Suspense fallback={<StepLoadingSkeleton />}>
     {StepComponent && <StepComponent {...stepProps} />}
    </Suspense>
   </StepErrorBoundary>
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
  <div data-turbo="false" className="py-2 sm:py-6 overflow-x-hidden w-full max-w-full">
   <div className="max-w-4xl mx-auto px-2 sm:px-4 w-full">
    <div data-form-card className="glass rounded-[32px] overflow-hidden w-full text-mist">
     {/* Header with step indicator */}
     <div className="px-4 sm:px-8 py-5 sm:py-6 border-b border-white/10">
      <div className="flex items-center justify-between flex-wrap gap-3">
       <div className="flex items-center gap-3 flex-wrap">
        <h1 className="m-0 flex items-center gap-2.5 text-lg sm:text-2xl font-semibold text-mist">
         <span className="sr-dot w-2 h-2 rounded-full bg-primary"></span>
         {t('resume.new_title')}
        </h1>
        {/* Import CV Button - Show on step 1 */}
        {currentStep === 1 && (
         <button
          type="button"
          onClick={() => setShowImportModal(true)}
          className="sr-btn glass-soft inline-flex items-center gap-2 min-h-[44px] px-4 rounded-2xl text-mist text-sm font-medium touch-manipulation"
         >
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
           <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" />
          </svg>
          <span className="hidden sm:inline">{t('import.from_file_long')}</span>
          <span className="sm:hidden">{t('import.from_file_short')}</span>
         </button>
        )}
       </div>
       <div className="flex items-center gap-3">
        {/* Auto-save indicator */}
        {saveIndicator && (
         <span role="status" data-save-status={saveIndicator} className={`text-xs flex items-center gap-1 whitespace-nowrap ${
          saveIndicator === "saving" ? "text-mist/70" :
          saveIndicator === "saved" ? "text-action" :
          "text-red-300"
         }`}>
          {saveIndicator === "saving" && (
           <>
            <svg className="animate-spin h-3 w-3" fill="none" viewBox="0 0 24 24">
             <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
             <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            {t('form.saving')}
           </>
          )}
          {saveIndicator === "saved" && (
           <>
            <svg className="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
             <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
            </svg>
            {t('form.auto_saved')}
           </>
          )}
          {saveIndicator === "error" && (
           <>
            <svg className="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
             <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            {t('form.save_retrying')}
           </>
          )}
         </span>
        )}
        <span className="sr-mono glass-soft text-xs sm:text-sm text-mist/80 px-3 py-1 rounded-full whitespace-nowrap">
         {t('steps.step_of', { current: currentStep, total: totalSteps })}
        </span>
       </div>
      </div>
      {/* Progress Bar */}
      <div className="mt-4" dir="rtl">
       <div className="w-full bg-white/10 rounded-full h-1.5 overflow-hidden">
        <div
         className="h-1.5 rounded-full bg-gradient-to-l from-gold to-primary-soft transition-[width] duration-700 ease-[cubic-bezier(.16,1,.3,1)] shadow-[0_0_12px_rgba(214,184,119,0.45)]"
         style={{ width: `${(currentStep / totalSteps) * 100}%` }}
        ></div>
       </div>
      </div>
     </div>

     {/* Portaled: the card's backdrop filter would trap a fixed element. */}
     {isStale && createPortal(
      <div role="alert" data-save-status="stale" className="fixed inset-x-4 z-50 mx-auto max-w-md flex items-center justify-between gap-3 rounded-2xl border border-red-400/40 px-4 py-2 text-sm text-red-200 shadow-lg" style={{ bottom: "max(1rem, env(safe-area-inset-bottom))", backgroundColor: "var(--color-darkCard)" }}>
       <span>{t('form.stale_tab')}</span>
       <button
        type="button"
        onClick={() => window.location.reload()}
        className="shrink-0 min-h-[44px] px-4 rounded-xl bg-white/10 hover:bg-white/15 active:bg-white/20 text-mist font-medium touch-manipulation"
       >
        {t('form.reload')}
       </button>
      </div>,
      document.body
     )}

     {/* Step Content */}
     <div className="px-4 sm:px-8 py-6 overflow-x-hidden" {...stepContentHandlers}>{renderStepContent()}</div>

     {/* Navigation Buttons - Mobile Optimized with Safe Area */}
     <div 
      className="px-4 sm:px-8 py-4 border-t border-white/10 bg-white/[0.03]" 
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
          className="sr-btn sr-primary flex-1 inline-flex items-center justify-center gap-2.5 min-h-[52px] rounded-2xl px-5 text-[15px] font-semibold shadow-glow touch-manipulation"
         >
          {t('steps.next')}
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
           <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
          </svg>
         </button>
        ) : (
         <button
          type="button"
          onClick={exportToPDF}
          disabled={isExporting}
          className="sr-btn flex-1 inline-flex items-center justify-center gap-2.5 min-h-[52px] rounded-2xl bg-action px-5 text-[15px] font-semibold text-darkBase hover:bg-actionHover disabled:opacity-50 shadow-glow-gold touch-manipulation"
         >
          {isExporting ? (
           <>
            <svg className="animate-spin h-4 w-4" fill="none" viewBox="0 0 24 24">
             <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
             <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            {t('form.exporting')}
           </>
          ) : (
           <>{t('form.create_download')}</>
          )}
         </button>
        )}
        <a href="/resumes" className="sr-btn glass-soft inline-flex items-center justify-center min-h-[52px] px-5 rounded-2xl text-[15px] font-medium text-mist touch-manipulation">
         {t('actions.cancel')}
        </a>
       </div>
       {currentStep > 1 && (
        <button
         type="button"
         onClick={prevStep}
         className="sr-btn glass-soft w-full min-h-[48px] rounded-2xl text-[15px] font-medium text-mist flex items-center justify-center gap-2 touch-manipulation"
        >
         <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
         </svg>
         {t('steps.previous')}
        </button>
       )}
      </div>
     </div>
    </div>
   </div>

   {/* CV Import Modal */}
   <CvImportModal
    isOpen={showImportModal}
    onClose={() => setShowImportModal(false)}
    onImportComplete={handleImportComplete}
   />
  </div>
 );
};

export default MultiStepResumeForm;
