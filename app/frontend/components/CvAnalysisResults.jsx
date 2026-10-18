import React, { useEffect, useRef, useState } from "react";
import { trackEvent } from "../lib/posthog";

const translations = {
  ar: {
    overallScore: "التقييم العام",
    sectionScores: "تقييم الأقسام",
    strengths: "نقاط القوة",
    improvements: "فرص التحسين",
    atsTips: "نصائح ATS",
    detailedFeedback: "تفاصيل التحليل",
    keywordAnalysis: "تحليل الكلمات المفتاحية",
    atsCompatibility: "التوافق مع ATS",
    contentQuality: "جودة المحتوى",
    formatting: "التنسيق",
    keywordOptimization: "تحسين الكلمات المفتاحية",
    impactStatements: "عبارات التأثير",
    professionalSummary: "الملخص المهني",
    workExperience: "الخبرات العملية",
    education: "التعليم",
    skills: "المهارات",
    overallStructure: "الهيكل العام",
    foundKeywords: "الكلمات الموجودة",
    missingKeywords: "الكلمات المقترحة",
    industryMatch: "توافق المجال",
    priority: "الأولوية",
    high: "عالية",
    medium: "متوسطة",
    low: "منخفضة",
    issue: "المشكلة",
    suggestion: "الاقتراح",
    targetJob: "الوظيفة المستهدفة",
    targetIndustry: "المجال المستهدف",
    excellent: "ممتاز",
    good: "جيد",
    needsWork: "يحتاج تحسين",
    poor: "ضعيف",
    outOf: "من 100",
    strengthsCount: "نقاط قوة",
    improvementsCount: "تحسينات",
    missingCount: "كلمات مقترحة"
  },
  en: {
    overallScore: "Overall Score",
    sectionScores: "Section Scores",
    strengths: "Strengths",
    improvements: "Areas for Improvement",
    atsTips: "ATS Tips",
    detailedFeedback: "Detailed Feedback",
    keywordAnalysis: "Keyword Analysis",
    atsCompatibility: "ATS Compatibility",
    contentQuality: "Content Quality",
    formatting: "Formatting",
    keywordOptimization: "Keyword Optimization",
    impactStatements: "Impact Statements",
    professionalSummary: "Professional Summary",
    workExperience: "Work Experience",
    education: "Education",
    skills: "Skills",
    overallStructure: "Overall Structure",
    foundKeywords: "Found Keywords",
    missingKeywords: "Suggested Keywords",
    industryMatch: "Industry Match",
    priority: "Priority",
    high: "High",
    medium: "Medium",
    low: "Low",
    issue: "Issue",
    suggestion: "Suggestion",
    targetJob: "Target Job",
    targetIndustry: "Target Industry",
    excellent: "Excellent",
    good: "Good",
    needsWork: "Needs Work",
    poor: "Poor",
    outOf: "out of 100",
    strengthsCount: "Strengths",
    improvementsCount: "Improvements",
    missingCount: "Suggested keywords"
  }
};

const MUTED = "rgba(238,243,238,0.7)";
const SOFT = "rgba(238,243,238,0.6)";
const RING_CIRCUMFERENCE = 2 * Math.PI * 50;

const prefersReducedMotion = () =>
  typeof window !== "undefined" &&
  window.matchMedia &&
  window.matchMedia("(prefers-reduced-motion: reduce)").matches;

const clampScore = (value) => {
  const n = Number(value);
  if (!Number.isFinite(n)) return 0;
  return Math.max(0, Math.min(100, Math.round(n)));
};

const scoreColor = (score) => {
  if (score >= 80) return "#2fa36b";
  if (score >= 60) return "#7fbf86";
  if (score >= 40) return "#d6b877";
  return "#e0715f";
};

// True once the element has scrolled into view (and stays true).
const useInView = (ref) => {
  const [inView, setInView] = useState(false);
  useEffect(() => {
    const node = ref.current;
    if (!node || inView) return undefined;
    if (typeof IntersectionObserver === "undefined") {
      setInView(true);
      return undefined;
    }
    const io = new IntersectionObserver(
      (entries) => {
        if (entries.some((e) => e.isIntersecting)) {
          setInView(true);
          io.disconnect();
        }
      },
      { rootMargin: "0px 0px -8% 0px" }
    );
    io.observe(node);
    return () => io.disconnect();
  }, [ref, inView]);
  return inView;
};

// Counts from 0 to `value` once `active` is true.
const useCountUp = (value, active, duration = 1600) => {
  const [shown, setShown] = useState(0);
  useEffect(() => {
    if (!active) return undefined;
    if (prefersReducedMotion()) {
      setShown(value);
      return undefined;
    }
    let raf;
    const t0 = performance.now();
    const step = (t) => {
      const p = Math.min(1, (t - t0) / duration);
      const eased = 1 - Math.pow(1 - p, 3);
      setShown(Math.round(value * eased));
      if (p < 1) raf = requestAnimationFrame(step);
    };
    raf = requestAnimationFrame(step);
    return () => cancelAnimationFrame(raf);
  }, [value, active, duration]);
  return shown;
};

// Scroll reveals for React-rendered blocks in browsers without CSS scroll
// timelines (site_scripts only observes what exists at page load).
const useRevealFallback = (rootRef) => {
  useEffect(() => {
    const root = rootRef.current;
    if (!root || !document.documentElement.classList.contains("sr-io")) return undefined;
    if (typeof IntersectionObserver === "undefined") {
      root.querySelectorAll(".sr-reveal, .sr-mask").forEach((el) => el.classList.add("is-in"));
      return undefined;
    }
    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((e) => {
          if (e.isIntersecting) {
            e.target.classList.add("is-in");
            io.unobserve(e.target);
          }
        });
      },
      { rootMargin: "0px 0px -10% 0px" }
    );
    root.querySelectorAll(".sr-reveal, .sr-mask").forEach((el) => io.observe(el));
    return () => io.disconnect();
  }, [rootRef]);
};

const Icon = ({ d, size = 22, strokeWidth = 1.7 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
    <path d={d} />
  </svg>
);

const ICONS = {
  chart: "M4 19V9M10 19V5M16 19v-7M22 19H2",
  check: "M5 13l4 4L19 7",
  shield: "M12 3l8 3v6c0 4.5-3.4 8.3-8 9-4.6-.7-8-4.5-8-9V6l8-3zM9 12l2 2 4-4",
  alert: "M12 8v4M12 16h.01M12 3a9 9 0 100 18 9 9 0 000-18z",
  bulb: "M9 18h6M10 21h4M12 3a6 6 0 00-3.5 10.9c.6.4 1 1.1 1 1.8V16h5v-.3c0-.7.4-1.4 1-1.8A6 6 0 0012 3z",
  tag: "M3 12V5a2 2 0 012-2h7l9 9-9 9-9-9zM8 8h.01",
  doc: "M14 3H7a2 2 0 00-2 2v14a2 2 0 002 2h10a2 2 0 002-2V8zM14 3v5h5M9 13h6M9 17h4",
  target: "M12 3a9 9 0 100 18 9 9 0 000-18zM12 7a5 5 0 100 10 5 5 0 000-10zM12 11a1 1 0 100 2 1 1 0 000-2z",
  sparkle: "M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8z"
};

const SectionHeading = ({ icon, color = "#2fa36b", children, count }) => (
  <div className="flex items-center gap-3.5">
    <span className="glass-soft sr-ico flex-none w-12 h-12 rounded-2xl flex items-center justify-center" style={{ color }}>
      <Icon d={ICONS[icon]} />
    </span>
    <h2 className="m-0 font-semibold flex-1" style={{ fontSize: "clamp(22px, 2.6vw, 28px)", letterSpacing: "-0.02em", lineHeight: 1.2 }}>
      {children}
    </h2>
    {typeof count === "number" && (
      <span className="glass-soft sr-mono px-3 py-1 rounded-full text-sm" style={{ color: SOFT }} dir="ltr">
        {count}
      </span>
    )}
  </div>
);

const ScoreRing = ({ score, label, outOf }) => {
  const ref = useRef(null);
  const inView = useInView(ref);
  const shown = useCountUp(score, inView, 2200);
  const [drawn, setDrawn] = useState(false);
  const color = scoreColor(score);

  useEffect(() => {
    if (!inView) return undefined;
    // Two frames so the empty ring paints before the transition starts.
    let r2;
    const r1 = requestAnimationFrame(() => {
      r2 = requestAnimationFrame(() => setDrawn(true));
    });
    return () => {
      cancelAnimationFrame(r1);
      if (r2) cancelAnimationFrame(r2);
    };
  }, [inView]);

  const offset = drawn ? RING_CIRCUMFERENCE * (1 - score / 100) : RING_CIRCUMFERENCE;

  return (
    <div ref={ref} className="relative w-[200px] h-[200px] sm:w-[240px] sm:h-[240px]">
      <div
        aria-hidden="true"
        className="absolute inset-4 rounded-full"
        style={{ background: `radial-gradient(circle, ${color}40, transparent 70%)`, filter: "blur(18px)" }}
      />
      <svg width="100%" height="100%" viewBox="0 0 120 120" style={{ transform: "rotate(-90deg)" }} aria-hidden="true">
        <circle cx="60" cy="60" r="50" fill="none" stroke="rgba(255,255,255,0.1)" strokeWidth="9" />
        <circle
          cx="60"
          cy="60"
          r="50"
          fill="none"
          stroke={color}
          strokeWidth="9"
          strokeLinecap="round"
          strokeDasharray={RING_CIRCUMFERENCE}
          strokeDashoffset={offset}
          style={{ transition: "stroke-dashoffset 2.2s cubic-bezier(.65,0,.35,1)" }}
        />
      </svg>
      <div
        className="absolute inset-0 flex flex-col items-center justify-center"
        role="img"
        aria-label={`${label}: ${score}/100`}
      >
        <span dir="ltr" className="sr-mono font-semibold" style={{ fontSize: "clamp(48px, 7vw, 64px)", lineHeight: 1, fontVariantNumeric: "tabular-nums" }}>
          {shown}
        </span>
        <span className="text-[13px] mt-1" style={{ color: SOFT }}>{outOf}</span>
      </div>
    </div>
  );
};

const ScoreBar = ({ score, active, delay = 0, rtl }) => {
  const color = scoreColor(score);
  return (
    <div className="h-2.5 rounded-full overflow-hidden" style={{ background: "rgba(255,255,255,0.08)" }}>
      <div
        className="h-full rounded-full"
        style={{
          width: active ? `${score}%` : "0%",
          background: `linear-gradient(${rtl ? "to left" : "to right"}, ${color}99, ${color})`,
          boxShadow: `0 0 14px ${color}66`,
          transition: `width 1.3s cubic-bezier(.65,0,.35,1) ${delay}s`
        }}
      />
    </div>
  );
};

const SectionScoreCard = ({ title, score, feedback, index, rtl }) => {
  const ref = useRef(null);
  const inView = useInView(ref);
  const shown = useCountUp(score, inView, 1300);
  const color = scoreColor(score);

  return (
    <article ref={ref} className="glass-soft sr-lift sr-reveal rounded-[24px] p-5 sm:p-6 flex flex-col gap-3.5">
      <div className="flex items-center justify-between gap-3">
        <h3 className="m-0 text-[17px] font-semibold">{title}</h3>
        <span dir="ltr" className="sr-mono text-lg font-semibold" style={{ color, fontVariantNumeric: "tabular-nums" }}>
          {shown}%
        </span>
      </div>
      <ScoreBar score={score} active={inView} delay={0.08 * (index % 2)} rtl={rtl} />
      {feedback && (
        <p className="m-0 text-[15px] font-light leading-relaxed" style={{ color: MUTED }}>
          {feedback}
        </p>
      )}
    </article>
  );
};

const PRIORITY_STYLES = {
  high: { background: "rgba(224,113,95,0.16)", border: "1px solid rgba(224,113,95,0.45)", color: "#f0a493" },
  medium: { background: "rgba(214,184,119,0.16)", border: "1px solid rgba(214,184,119,0.45)", color: "#d6b877" },
  low: { background: "rgba(47,163,107,0.16)", border: "1px solid rgba(47,163,107,0.45)", color: "#7fbf86" }
};

const PriorityBadge = ({ priority, t }) => {
  const key = String(priority || "").toLowerCase();
  const labels = { high: t.high, medium: t.medium, low: t.low };
  return (
    <span
      className="flex-none inline-flex items-center gap-1.5 text-xs font-medium px-2.5 py-1 rounded-full"
      style={PRIORITY_STYLES[key] || PRIORITY_STYLES.medium}
    >
      <span className="w-1.5 h-1.5 rounded-full" style={{ background: "currentColor" }} />
      {labels[key] || priority}
    </span>
  );
};

const KeywordChips = ({ words, kind }) => {
  const found = kind === "found";
  return (
    <div className="flex flex-wrap gap-2">
      {words.map((word, index) => (
        <span
          key={`${word}-${index}`}
          className="sr-up inline-flex items-center gap-1.5 px-3.5 py-1.5 rounded-full text-sm"
          style={{
            animationDelay: `${Math.min(index, 12) * 0.04}s`,
            background: found ? "rgba(47,163,107,0.14)" : "rgba(214,184,119,0.1)",
            border: found ? "1px solid rgba(47,163,107,0.4)" : "1px dashed rgba(214,184,119,0.55)",
            color: found ? "#a9dcb9" : "#e6cf9c"
          }}
        >
          {found ? <Icon d={ICONS.check} size={13} strokeWidth={2.2} /> : <span aria-hidden="true">+</span>}
          {word}
        </span>
      ))}
    </div>
  );
};

const StatChip = ({ value, label, color }) => (
  <div className="glass-soft rounded-2xl px-4 py-3 flex flex-col gap-0.5 min-w-[120px]">
    <span dir="ltr" className="sr-mono text-2xl font-semibold self-start" style={{ color }}>
      {value}
    </span>
    <span className="text-[13px]" style={{ color: SOFT }}>{label}</span>
  </div>
);

const CvAnalysisResults = ({ analysis, language, targetJob, targetIndustry }) => {
  const t = translations[language] || translations.ar;
  const isRtl = language !== "en";
  const rootRef = useRef(null);
  useRevealFallback(rootRef);

  const {
    overall_score = 0,
    section_scores = {},
    detailed_feedback = {},
    keyword_analysis = {}
  } = analysis || {};
  const asList = (value) => (Array.isArray(value) ? value.filter(Boolean) : []);
  const strengths = asList(analysis?.strengths);
  const improvements = asList(analysis?.improvements);
  const ats_tips = asList(analysis?.ats_tips);

  // Track when CV analysis results are viewed
  useEffect(() => {
    trackEvent("cv_analysis_viewed", {
      overall_score,
      target_job: targetJob,
      target_industry: targetIndustry,
      strengths_count: strengths.length,
      improvements_count: improvements.length
    });
  }, []);

  const sectionLabels = {
    ats_compatibility: t.atsCompatibility,
    content_quality: t.contentQuality,
    formatting: t.formatting,
    keyword_optimization: t.keywordOptimization,
    impact_statements: t.impactStatements
  };

  const feedbackLabels = {
    professional_summary: t.professionalSummary,
    work_experience: t.workExperience,
    education: t.education,
    skills: t.skills,
    overall_structure: t.overallStructure
  };

  const getScoreLabel = (score) => {
    if (score >= 80) return t.excellent;
    if (score >= 60) return t.good;
    if (score >= 40) return t.needsWork;
    return t.poor;
  };

  const overall = clampScore(overall_score);
  const foundKeywords = Array.isArray(keyword_analysis?.found_keywords) ? keyword_analysis.found_keywords : [];
  const missingKeywords = Array.isArray(keyword_analysis?.missing_keywords) ? keyword_analysis.missing_keywords : [];
  const sectionEntries = Object.entries(section_scores || {});
  const feedbackEntries = Object.entries(detailed_feedback || {}).filter(([, text]) => text);
  const hasKeywords = foundKeywords.length > 0 || missingKeywords.length > 0 || Boolean(keyword_analysis?.industry_match);

  return (
    <div ref={rootRef} dir={isRtl ? "rtl" : "ltr"} className="flex flex-col gap-8" style={{ color: "#eef3ee" }}>
      {/* Overall score */}
      <section
        className="glass sr-up relative overflow-hidden rounded-[32px] grid gap-8 sm:gap-12 items-center"
        style={{
          animationDelay: ".3s",
          padding: "clamp(28px, 5vw, 56px)",
          gridTemplateColumns: "repeat(auto-fit, minmax(min(100%, 260px), 1fr))"
        }}
      >
        <div
          aria-hidden="true"
          className="absolute rounded-full pointer-events-none"
          style={{
            top: -160,
            [isRtl ? "right" : "left"]: -120,
            width: 440,
            height: 440,
            background: "radial-gradient(circle, rgba(0,150,85,0.32), rgba(0,150,85,0) 65%)",
            filter: "blur(30px)"
          }}
        />
        <div className="relative flex justify-center">
          <ScoreRing score={overall} label={t.overallScore} outOf={t.outOf} />
        </div>
        <div className="relative flex flex-col gap-5">
          <div className="flex flex-col gap-2">
            <span className="text-sm" style={{ color: SOFT }}>{t.overallScore}</span>
            <span className="font-semibold" style={{ fontSize: "clamp(30px, 4vw, 44px)", lineHeight: 1.15, letterSpacing: "-0.02em", color: scoreColor(overall) }}>
              {getScoreLabel(overall)}
            </span>
          </div>

          {(targetJob || targetIndustry) && (
            <div className="flex flex-wrap gap-2">
              {targetJob && (
                <span className="glass-soft inline-flex items-center gap-2 px-3.5 py-2 rounded-xl text-sm">
                  <span style={{ color: "#d6b877" }}><Icon d={ICONS.target} size={15} /></span>
                  <span style={{ color: SOFT }}>{t.targetJob}:</span>
                  <span>{targetJob}</span>
                </span>
              )}
              {targetIndustry && (
                <span className="glass-soft inline-flex items-center gap-2 px-3.5 py-2 rounded-xl text-sm">
                  <span style={{ color: "#d6b877" }}><Icon d={ICONS.sparkle} size={15} /></span>
                  <span style={{ color: SOFT }}>{t.targetIndustry}:</span>
                  <span>{targetIndustry}</span>
                </span>
              )}
            </div>
          )}

          <div className="flex flex-wrap gap-2.5">
            <StatChip value={strengths.length} label={t.strengthsCount} color="#2fa36b" />
            <StatChip value={improvements.length} label={t.improvementsCount} color="#d6b877" />
            {missingKeywords.length > 0 && (
              <StatChip value={missingKeywords.length} label={t.missingCount} color="#e6cf9c" />
            )}
          </div>
        </div>
      </section>

      {/* Section scores */}
      {sectionEntries.length > 0 && (
        <section className="flex flex-col gap-5">
          <SectionHeading icon="chart">{t.sectionScores}</SectionHeading>
          <div className="grid gap-4" style={{ gridTemplateColumns: "repeat(auto-fit, minmax(min(100%, 320px), 1fr))" }}>
            {sectionEntries.map(([key, data], index) => (
              <SectionScoreCard
                key={key}
                index={index}
                rtl={isRtl}
                title={sectionLabels[key] || key}
                score={clampScore(data?.score)}
                feedback={data?.feedback || ""}
              />
            ))}
          </div>
        </section>
      )}

      {/* Strengths and ATS tips */}
      {(strengths.length > 0 || ats_tips.length > 0) && (
        <div className="grid gap-5" style={{ gridTemplateColumns: "repeat(auto-fit, minmax(min(100%, 380px), 1fr))" }}>
          {strengths.length > 0 && (
            <section className="glass sr-lift sr-reveal rounded-[32px] p-6 sm:p-8 flex flex-col gap-5">
              <SectionHeading icon="shield" count={strengths.length}>{t.strengths}</SectionHeading>
              <ul className="list-none m-0 p-0 flex flex-col gap-2.5">
                {strengths.map((strength, index) => (
                  <li key={index} className="glass-soft rounded-2xl px-4 py-3.5 flex items-start gap-3">
                    <span className="flex-none w-7 h-7 rounded-full flex items-center justify-center mt-0.5" style={{ background: "rgba(47,163,107,0.18)", color: "#2fa36b" }}>
                      <Icon d={ICONS.check} size={15} strokeWidth={2.2} />
                    </span>
                    <span className="text-[15px] leading-relaxed" style={{ color: "rgba(238,243,238,0.88)" }}>{strength}</span>
                  </li>
                ))}
              </ul>
            </section>
          )}

          {ats_tips.length > 0 && (
            <section className="glass sr-lift sr-reveal rounded-[32px] p-6 sm:p-8 flex flex-col gap-5">
              <SectionHeading icon="bulb" color="#d6b877" count={ats_tips.length}>{t.atsTips}</SectionHeading>
              <ol className="list-none m-0 p-0 flex flex-col gap-2.5">
                {ats_tips.map((tip, index) => (
                  <li key={index} className="glass-soft rounded-2xl px-4 py-3.5 flex items-start gap-3">
                    <span dir="ltr" className="sr-mono flex-none w-7 h-7 rounded-full flex items-center justify-center text-xs font-semibold mt-0.5" style={{ background: "rgba(214,184,119,0.16)", border: "1px solid rgba(214,184,119,0.4)", color: "#d6b877" }}>
                      {index + 1}
                    </span>
                    <span className="text-[15px] leading-relaxed" style={{ color: "rgba(238,243,238,0.88)" }}>{tip}</span>
                  </li>
                ))}
              </ol>
            </section>
          )}
        </div>
      )}

      {/* Improvements */}
      {improvements.length > 0 && (
        <section className="glass sr-reveal rounded-[32px] p-6 sm:p-8 flex flex-col gap-5">
          <SectionHeading icon="alert" color="#d6b877" count={improvements.length}>{t.improvements}</SectionHeading>
          <div className="grid gap-3" style={{ gridTemplateColumns: "repeat(auto-fit, minmax(min(100%, 340px), 1fr))" }}>
            {improvements.map((improvement, index) => {
              const isObject = improvement && typeof improvement === "object";
              const issue = isObject ? improvement.issue : improvement;
              return (
                <article key={index} className="glass-soft sr-lift rounded-[22px] p-5 flex flex-col gap-2.5">
                  <div className="flex items-start justify-between gap-3">
                    <h3 className="m-0 text-[16px] font-semibold leading-snug">{issue}</h3>
                    {isObject && improvement.priority && <PriorityBadge priority={improvement.priority} t={t} />}
                  </div>
                  {isObject && improvement.suggestion && (
                    <p className="m-0 text-[15px] font-light leading-relaxed" style={{ color: MUTED }}>
                      <span className="font-medium" style={{ color: "#d6b877" }}>{t.suggestion}: </span>
                      {improvement.suggestion}
                    </p>
                  )}
                </article>
              );
            })}
          </div>
        </section>
      )}

      {/* Keyword analysis */}
      {hasKeywords && (
        <section className="glass sr-reveal rounded-[32px] p-6 sm:p-8 flex flex-col gap-6">
          <SectionHeading icon="tag">{t.keywordAnalysis}</SectionHeading>
          <div className="grid gap-5" style={{ gridTemplateColumns: "repeat(auto-fit, minmax(min(100%, 320px), 1fr))" }}>
            {foundKeywords.length > 0 && (
              <div className="flex flex-col gap-3">
                <h3 className="m-0 text-[15px] font-medium flex items-center gap-2" style={{ color: "#a9dcb9" }}>
                  {t.foundKeywords}
                  <span className="sr-mono text-xs" style={{ color: SOFT }} dir="ltr">{foundKeywords.length}</span>
                </h3>
                <KeywordChips words={foundKeywords} kind="found" />
              </div>
            )}
            {missingKeywords.length > 0 && (
              <div className="flex flex-col gap-3">
                <h3 className="m-0 text-[15px] font-medium flex items-center gap-2" style={{ color: "#e6cf9c" }}>
                  {t.missingKeywords}
                  <span className="sr-mono text-xs" style={{ color: SOFT }} dir="ltr">{missingKeywords.length}</span>
                </h3>
                <KeywordChips words={missingKeywords} kind="missing" />
              </div>
            )}
          </div>
          {keyword_analysis?.industry_match && (
            <div className="glass-soft rounded-[20px] p-5 flex flex-col gap-1.5">
              <h3 className="m-0 text-[15px] font-semibold">{t.industryMatch}</h3>
              <p className="m-0 text-[15px] font-light leading-relaxed" style={{ color: MUTED }}>{keyword_analysis.industry_match}</p>
            </div>
          )}
        </section>
      )}

      {/* Detailed feedback */}
      {feedbackEntries.length > 0 && (
        <section className="glass sr-reveal rounded-[32px] p-6 sm:p-8 flex flex-col gap-5">
          <SectionHeading icon="doc">{t.detailedFeedback}</SectionHeading>
          <div className="grid gap-3" style={{ gridTemplateColumns: "repeat(auto-fit, minmax(min(100%, 340px), 1fr))" }}>
            {feedbackEntries.map(([key, feedback]) => (
              <article key={key} className="glass-soft sr-lift rounded-[22px] p-5 flex flex-col gap-2">
                <h3 className="m-0 text-[16px] font-semibold flex items-center gap-2">
                  <span className="w-1.5 h-1.5 rounded-full flex-none" style={{ background: "#d6b877" }} />
                  {feedbackLabels[key] || key}
                </h3>
                <p className="m-0 text-[15px] font-light leading-relaxed" style={{ color: MUTED }}>
                  {typeof feedback === "string" ? feedback : JSON.stringify(feedback)}
                </p>
              </article>
            ))}
          </div>
        </section>
      )}
    </div>
  );
};

export default CvAnalysisResults;
