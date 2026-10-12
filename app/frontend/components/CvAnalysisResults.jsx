import React, { useEffect } from "react";
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
    poor: "ضعيف"
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
    poor: "Poor"
  }
};

const ScoreGauge = ({ score, size = "large" }) => {
  const getScoreColor = (score) => {
    if (score >= 80) return { main: "#10b981", light: "#d1fae5" }; // emerald
    if (score >= 60) return { main: "#3b82f6", light: "#dbeafe" }; // blue
    if (score >= 40) return { main: "#f59e0b", light: "#fef3c7" }; // amber
    return { main: "#ef4444", light: "#fee2e2" }; // red
  };

  const colors = getScoreColor(score);
  const circumference = 2 * Math.PI * 45;
  const progress = (score / 100) * circumference;
  const dimensions = size === "large" ? { w: 160, h: 160 } : { w: 80, h: 80 };
  const strokeWidth = size === "large" ? 8 : 4;
  const fontSize = size === "large" ? "text-4xl" : "text-lg";

  return (
    <div className="relative" style={{ width: dimensions.w, height: dimensions.h }}>
      <svg className="transform -rotate-90 w-full h-full" viewBox="0 0 100 100">
        <circle
          cx="50"
          cy="50"
          r="45"
          fill="none"
          stroke={colors.light}
          strokeWidth={strokeWidth}
        />
        <circle
          cx="50"
          cy="50"
          r="45"
          fill="none"
          stroke={colors.main}
          strokeWidth={strokeWidth}
          strokeDasharray={circumference}
          strokeDashoffset={circumference - progress}
          strokeLinecap="round"
          className="transition-all duration-1000 ease-out"
        />
      </svg>
      <div className="absolute inset-0 flex items-center justify-center">
        <span className={`${fontSize} font-bold`} style={{ color: colors.main }}>
          {score}
        </span>
      </div>
    </div>
  );
};

const SectionScoreCard = ({ title, score, feedback }) => {
  const getScoreColor = (score) => {
    if (score >= 80) return "text-emerald-600 bg-emerald-100";
    if (score >= 60) return "text-blue-600 bg-blue-100";
    if (score >= 40) return "text-amber-600 bg-amber-100";
    return "text-red-600 bg-red-100";
  };

  return (
    <div className="bg-white rounded-xl border border-slate-200 p-5">
      <div className="flex items-center justify-between mb-3">
        <h4 className="font-semibold text-slate-900">{title}</h4>
        <span className={`text-sm font-bold px-2.5 py-1 rounded-full ${getScoreColor(score)}`}>
          {score}%
        </span>
      </div>
      <p className="text-sm text-slate-600 leading-relaxed">{feedback}</p>
    </div>
  );
};

const PriorityBadge = ({ priority, t }) => {
  const colors = {
    high: "bg-red-100 text-red-700 ring-red-500/20",
    medium: "bg-amber-100 text-amber-700 ring-amber-500/20",
    low: "bg-blue-100 text-blue-700 ring-blue-500/20"
  };

  const labels = {
    high: t.high,
    medium: t.medium,
    low: t.low
  };

  return (
    <span className={`text-xs px-2 py-0.5 rounded-full ring-1 ${colors[priority] || colors.medium}`}>
      {labels[priority] || priority}
    </span>
  );
};

const CvAnalysisResults = ({ analysis, language, targetJob, targetIndustry }) => {
  const t = translations[language] || translations.ar;
  const isRtl = language === "ar";

  const {
    overall_score = 0,
    section_scores = {},
    strengths = [],
    improvements = [],
    ats_tips = [],
    detailed_feedback = {},
    keyword_analysis = {}
  } = analysis;

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

  return (
    <div className="space-y-8">
      {/* Target Context */}
      {(targetJob || targetIndustry) && (
        <div className="bg-primary/5 rounded-xl p-4 flex flex-wrap gap-4 text-sm">
          {targetJob && (
            <div>
              <span className="text-primary font-medium">{t.targetJob}: </span>
              <span className="text-slate-700">{targetJob}</span>
            </div>
          )}
          {targetIndustry && (
            <div>
              <span className="text-primary font-medium">{t.targetIndustry}: </span>
              <span className="text-slate-700">{targetIndustry}</span>
            </div>
          )}
        </div>
      )}

      {/* Overall Score */}
      <div className="bg-white rounded-2xl border border-slate-200 p-8">
        <h2 className="text-xl font-semibold text-slate-900 mb-6 text-center">{t.overallScore}</h2>
        <div className="flex flex-col items-center">
          <ScoreGauge score={overall_score} />
          <p className="mt-4 text-lg font-medium text-slate-700">{getScoreLabel(overall_score)}</p>
        </div>
      </div>

      {/* Section Scores */}
      {Object.keys(section_scores).length > 0 && (
        <div>
          <h2 className="text-xl font-semibold text-slate-900 mb-4">{t.sectionScores}</h2>
          <div className="grid md:grid-cols-2 gap-4">
            {Object.entries(section_scores).map(([key, data]) => (
              <SectionScoreCard
                key={key}
                title={sectionLabels[key] || key}
                score={data?.score || 0}
                feedback={data?.feedback || ""}
              />
            ))}
          </div>
        </div>
      )}

      {/* Strengths */}
      {strengths.length > 0 && (
        <div className="bg-emerald-50 rounded-2xl border border-emerald-200 p-6">
          <h2 className="text-xl font-semibold text-emerald-800 mb-4 flex items-center gap-2">
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            {t.strengths}
          </h2>
          <ul className="space-y-3">
            {strengths.map((strength, index) => (
              <li key={index} className="flex items-start gap-3">
                <div className="w-6 h-6 bg-emerald-200 rounded-full flex items-center justify-center flex-shrink-0 mt-0.5">
                  <svg className="w-3.5 h-3.5 text-emerald-700" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                  </svg>
                </div>
                <span className="text-slate-700">{strength}</span>
              </li>
            ))}
          </ul>
        </div>
      )}

      {/* Improvements */}
      {improvements.length > 0 && (
        <div className="bg-amber-50 rounded-2xl border border-amber-200 p-6">
          <h2 className="text-xl font-semibold text-amber-800 mb-4 flex items-center gap-2">
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            {t.improvements}
          </h2>
          <div className="space-y-4">
            {improvements.map((improvement, index) => (
              <div key={index} className="bg-white rounded-xl p-4 border border-amber-100">
                <div className="flex items-center justify-between mb-2">
                  <span className="font-medium text-slate-900">
                    {improvement.issue || improvement}
                  </span>
                  {improvement.priority && (
                    <PriorityBadge priority={improvement.priority} t={t} />
                  )}
                </div>
                {improvement.suggestion && (
                  <p className="text-sm text-slate-600">{improvement.suggestion}</p>
                )}
              </div>
            ))}
          </div>
        </div>
      )}

      {/* ATS Tips */}
      {ats_tips.length > 0 && (
        <div className="bg-blue-50 rounded-2xl border border-blue-200 p-6">
          <h2 className="text-xl font-semibold text-blue-800 mb-4 flex items-center gap-2">
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z" />
            </svg>
            {t.atsTips}
          </h2>
          <ul className="space-y-3">
            {ats_tips.map((tip, index) => (
              <li key={index} className="flex items-start gap-3">
                <div className="w-6 h-6 bg-blue-200 rounded-full flex items-center justify-center flex-shrink-0 mt-0.5">
                  <span className="text-blue-700 text-xs font-bold">{index + 1}</span>
                </div>
                <span className="text-slate-700">{tip}</span>
              </li>
            ))}
          </ul>
        </div>
      )}

      {/* Keyword Analysis */}
      {Object.keys(keyword_analysis).length > 0 && (
        <div className="bg-white rounded-2xl border border-slate-200 p-6">
          <h2 className="text-xl font-semibold text-slate-900 mb-4 flex items-center gap-2">
            <svg className="w-6 h-6 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z" />
            </svg>
            {t.keywordAnalysis}
          </h2>
          
          <div className="space-y-4">
            {keyword_analysis.found_keywords?.length > 0 && (
              <div>
                <h4 className="text-sm font-medium text-slate-700 mb-2">{t.foundKeywords}</h4>
                <div className="flex flex-wrap gap-2">
                  {keyword_analysis.found_keywords.map((keyword, index) => (
                    <span key={index} className="bg-emerald-100 text-emerald-700 px-3 py-1 rounded-full text-sm">
                      {keyword}
                    </span>
                  ))}
                </div>
              </div>
            )}
            
            {keyword_analysis.missing_keywords?.length > 0 && (
              <div>
                <h4 className="text-sm font-medium text-slate-700 mb-2">{t.missingKeywords}</h4>
                <div className="flex flex-wrap gap-2">
                  {keyword_analysis.missing_keywords.map((keyword, index) => (
                    <span key={index} className="bg-amber-100 text-amber-700 px-3 py-1 rounded-full text-sm">
                      {keyword}
                    </span>
                  ))}
                </div>
              </div>
            )}

            {keyword_analysis.industry_match && (
              <div className="mt-4 p-4 bg-slate-50 rounded-xl">
                <h4 className="text-sm font-medium text-slate-700 mb-1">{t.industryMatch}</h4>
                <p className="text-sm text-slate-600">{keyword_analysis.industry_match}</p>
              </div>
            )}
          </div>
        </div>
      )}

      {/* Detailed Feedback */}
      {Object.keys(detailed_feedback).length > 0 && (
        <div className="bg-white rounded-2xl border border-slate-200 p-6 mb-12">
          <h2 className="text-xl font-semibold text-slate-900 mb-4">{t.detailedFeedback}</h2>
          <div className="space-y-4">
            {Object.entries(detailed_feedback).map(([key, feedback]) => (
              <div key={key} className="border-b border-slate-100 pb-4 last:border-0 last:pb-0">
                <h4 className="font-medium text-slate-800 mb-2">
                  {feedbackLabels[key] || key}
                </h4>
                <p className="text-sm text-slate-600 leading-relaxed">{feedback}</p>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};

export default CvAnalysisResults;
