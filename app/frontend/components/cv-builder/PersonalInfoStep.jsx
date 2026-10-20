import React, { memo } from "react";
import { inputClassName } from "./FormUtils";

// Icon component
const UserIcon = () => (
  <svg className="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
  </svg>
);

const PersonalInfoStep = ({ formData, handleInputChange, renderSaveDraftButton }) => {
  return (
    <div className="space-y-6">
      <div className="text-center mb-6">
        <div className="glass-soft inline-flex items-center justify-center w-16 h-16 rounded-[22px] text-gold mb-4">
          <UserIcon />
        </div>
        <h2 className="text-[22px] sm:text-2xl font-semibold text-mist">المعلومات الشخصية</h2>
        <p className="text-mist/70 mt-2 text-[15px] sm:text-base font-light">ابدأ بإدخال معلوماتك الشخصية الأساسية</p>
      </div>

      <div className="grid gap-6">
        <div>
          <label className="block text-sm font-medium text-mist/90 mb-2">
            الاسم الكامل
          </label>
          <input
            type="text"
            value={formData.complete_name}
            onChange={(e) => handleInputChange("complete_name", e.target.value)}
            className={inputClassName}
            placeholder="مثال: Ahmed Ali"
          />
          <p className="mt-2 text-xs text-mist/55">أدخل اسمك الكامل</p>
        </div>

        <div>
          <label className="block text-sm font-medium text-mist/90 mb-2">
            البريد الإلكتروني
          </label>
          <input
            type="email"
            value={formData.email}
            onChange={(e) => handleInputChange("email", e.target.value)}
            className={inputClassName}
            placeholder="مثال: ahmed@example.com"
          />
          <p className="mt-2 text-xs text-mist/55">
            البريد الإلكتروني المستخدم للتواصل المهني
          </p>
        </div>

        <div>
          <label className="block text-sm font-medium text-mist/90 mb-2">
            رقم الهاتف
          </label>
          <input
            type="tel"
            value={formData.phone_number}
            onChange={(e) => handleInputChange("phone_number", e.target.value)}
            className={inputClassName}
            placeholder="مثال: +966501234567"
          />
          <p className="mt-2 text-xs text-mist/55">رقم الهاتف مع رمز الدولة</p>
        </div>

        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-mist/90 mb-2">
              المدينة
            </label>
            <input
              type="text"
              value={formData.city}
              onChange={(e) => handleInputChange("city", e.target.value)}
              className={inputClassName}
              placeholder="مثال: Riyadh"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-mist/90 mb-2">
              الدولة
            </label>
            <input
              type="text"
              value={formData.country}
              onChange={(e) => handleInputChange("country", e.target.value)}
              className={inputClassName}
              placeholder="مثال: Saudi Arabia"
            />
          </div>
        </div>
      </div>

      {renderSaveDraftButton(1)}
    </div>
  );
};

export default memo(PersonalInfoStep);
