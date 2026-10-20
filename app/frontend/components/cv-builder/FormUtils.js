// Shared form utilities and constants
// Seera glass: dark-only fields, buttons and tiles shared by the builder steps.
// Fields stay at 16px so iOS does not zoom on focus, and every control is at
// least 44px tall. The site-wide gold :focus-visible outline is the focus ring.
export const fieldClassName = "min-h-[48px] rounded-xl border border-white/10 bg-white/[0.06] px-4 py-3 text-base text-mist placeholder:text-mist/40 transition-colors duration-300 hover:bg-white/[0.08]";

export const inputClassName = `w-full ${fieldClassName}`;

// Appended to a field with a validation error. The global field rules pin the
// border colour, so the error shows as a red ring.
export const fieldErrorClassName = "ring-2 ring-red-400/60";

export const buttonPrimaryClassName = "sr-btn sr-primary inline-flex items-center justify-center gap-2 min-h-[48px] rounded-2xl px-6 text-[15px] font-semibold shadow-glow touch-manipulation disabled:opacity-50 disabled:cursor-not-allowed";

export const buttonSecondaryClassName = "sr-btn glass-soft inline-flex items-center justify-center gap-2 min-h-[48px] rounded-2xl px-6 text-[15px] font-medium text-mist touch-manipulation disabled:opacity-50 disabled:cursor-not-allowed";

export const buttonDangerClassName = "sr-btn inline-flex items-center justify-center gap-2 min-h-[44px] rounded-2xl border border-red-400/30 bg-red-500/10 px-4 text-sm font-medium text-red-300 hover:bg-red-500/20 touch-manipulation";

export const sectionHeaderClassName = "glass-soft inline-flex items-center justify-center w-16 h-16 rounded-[22px] text-gold mb-4";

// A section panel inside the form card.
export const panelClassName = "glass-soft rounded-[24px] p-4 sm:p-6";

// Muted body copy, as on the landing.
export const mutedTextStyle = { color: "rgba(238,243,238,0.7)" };

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
