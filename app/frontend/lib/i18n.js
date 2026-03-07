import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';

import en from './locales/en.json';
import ar from './locales/ar.json';

// Get locale from Rails (passed via data attribute or meta tag)
const getInitialLocale = () => {
  // Check data attribute on html element
  const htmlLang = document.documentElement.lang;
  if (htmlLang && ['ar', 'en'].includes(htmlLang)) {
    return htmlLang;
  }
  
  // Check meta tag
  const metaLocale = document.querySelector('meta[name="locale"]')?.content;
  if (metaLocale && ['ar', 'en'].includes(metaLocale)) {
    return metaLocale;
  }
  
  // Default to Arabic
  return 'ar';
};

i18n
  .use(initReactI18next)
  .init({
    resources: {
      en: { translation: en },
      ar: { translation: ar }
    },
    lng: getInitialLocale(),
    fallbackLng: 'ar',
    interpolation: {
      escapeValue: false // React already escapes by default
    },
    react: {
      useSuspense: false
    }
  });

// Export function to change language (for external use)
export const changeLanguage = (lng) => {
  i18n.changeLanguage(lng);
  document.documentElement.lang = lng;
  document.documentElement.dir = lng === 'ar' ? 'rtl' : 'ltr';
};

// Listen for locale changes from Rails
window.addEventListener('locale-changed', (event) => {
  if (event.detail?.locale) {
    i18n.changeLanguage(event.detail.locale);
  }
});

export default i18n;
