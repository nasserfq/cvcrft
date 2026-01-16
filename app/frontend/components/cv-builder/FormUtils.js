// Shared form utilities and constants
export const inputClassName = "w-full rounded-lg border border-slate-300/70 bg-white/70 px-4 py-3 text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/40 focus:border-emerald-400 ring-1 ring-black/5 transition-all";

export const buttonPrimaryClassName = "inline-flex items-center gap-2 rounded-lg bg-emerald-600 text-white px-6 py-3 text-sm font-medium hover:bg-emerald-700 hover:scale-105 active:bg-emerald-800 active:scale-110 transition-all duration-150 touch-manipulation disabled:opacity-50 disabled:cursor-not-allowed";

export const buttonSecondaryClassName = "inline-flex items-center gap-2 rounded-lg border border-slate-300 text-slate-700 px-6 py-3 text-sm font-medium hover:bg-slate-50 hover:scale-105 active:bg-slate-100 active:scale-110 transition-all duration-150 touch-manipulation";

export const buttonDangerClassName = "inline-flex items-center gap-2 rounded-lg bg-red-50 text-red-600 px-3 py-2 text-sm font-medium hover:bg-red-100 hover:scale-105 active:bg-red-200 active:scale-110 transition-all duration-150 touch-manipulation";

export const sectionHeaderClassName = "inline-flex items-center justify-center w-16 h-16 rounded-full bg-emerald-100 text-emerald-600 mb-4";

// Form validation helpers
export const isFieldEmpty = (value) => !value || value.trim() === '';

export const validateEmail = (email) => {
  const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return re.test(email);
};

export const validatePhone = (phone) => {
  const re = /^\+?[\d\s-()]+$/;
  return phone ? re.test(phone) : true;
};

// Form data helpers
export const cleanSkillsData = (skills) => {
  if (!skills || !Array.isArray(skills)) {
    return [{ category: "", skill_names: [] }];
  }

  return skills.map((skill) => {
    let skillNames = skill.skill_names;

    if (typeof skillNames === "string") {
      try {
        skillNames = JSON.parse(skillNames);
      } catch (e) {
        skillNames = [];
      }
    }

    if (!Array.isArray(skillNames)) {
      skillNames = [];
    }

    const cleanedNames = skillNames.filter((name) => 
      name != null &&
      typeof name === "string" &&
      name.trim() !== "" &&
      name.trim() !== '""' &&
      name.trim() !== "''"
    );

    return {
      ...skill,
      skill_names: cleanedNames,
    };
  });
};

// Default form data
export const getDefaultFormData = (resume) => ({
  complete_name: resume?.complete_name || "",
  email: resume?.email || "",
  phone_number: resume?.phone_number || "",
  city: resume?.city || "",
  country: resume?.country || "",
  professional_summary: resume?.professional_summary || "",
  professional_summary_english: resume?.professional_summary_english || "",
  skills_extracted: resume?.skills_extracted || [],
  translation_notes: resume?.translation_notes || "",
  education: resume?.education || [{
    degree: "",
    institution: "",
    start_date: "",
    end_date: "",
    gpa: "",
    is_current: false,
  }],
  work_experience: resume?.work_experience || [{
    job_title: "",
    company: "",
    start_date: "",
    end_date: "",
    is_current: false,
    responsibilities: [""],
  }],
  skills: cleanSkillsData(resume?.skills) || [{
    category: "",
    skill_names: [],
  }],
  certifications: resume?.certifications || [{
    name: "",
    organization: "",
    date: "",
  }],
  languages: resume?.languages || [{
    language: "",
    proficiency: "",
  }],
});
