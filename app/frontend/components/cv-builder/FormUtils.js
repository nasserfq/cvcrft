// Shared form utilities and constants
export const inputClassName = "w-full rounded-xl border border-[#E6E8F0] dark:border-white/10 bg-white/70 dark:bg-[#27273A]/70 px-4 py-3 text-gray-900 dark:text-white placeholder:text-gray-400 dark:placeholder:text-gray-500 focus:outline-none focus:ring-2 focus:ring-[#7C6CF2]/40 focus:border-[#7C6CF2] ring-1 ring-black/5 dark:ring-white/5 transition-all";

export const buttonPrimaryClassName = "inline-flex items-center gap-2 rounded-xl bg-[#7C6CF2] text-white px-6 py-3 text-sm font-medium hover:bg-[#6A5AE0] hover:scale-105 active:scale-110 transition-all duration-150 touch-manipulation disabled:opacity-50 disabled:cursor-not-allowed shadow-[0_0_20px_-5px_rgba(124,108,242,0.4)]";

export const buttonSecondaryClassName = "inline-flex items-center gap-2 rounded-xl border border-[#E6E8F0] dark:border-white/10 text-gray-700 dark:text-gray-300 px-6 py-3 text-sm font-medium hover:bg-[#F8F7FF] dark:hover:bg-white/5 hover:scale-105 active:scale-110 transition-all duration-150 touch-manipulation";

export const buttonDangerClassName = "inline-flex items-center gap-2 rounded-xl bg-red-50 dark:bg-red-500/10 text-red-600 dark:text-red-400 px-3 py-2 text-sm font-medium hover:bg-red-100 dark:hover:bg-red-500/20 hover:scale-105 active:scale-110 transition-all duration-150 touch-manipulation";

export const sectionHeaderClassName = "inline-flex items-center justify-center w-16 h-16 rounded-full bg-[#7C6CF2]/10 text-[#7C6CF2] mb-4";

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
