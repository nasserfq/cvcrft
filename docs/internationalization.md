# Internationalization (i18n) Implementation Guide

This document explains how the i18n system works in CVCraft and how to complete the translation of remaining components.

## Architecture Overview

### Backend (Rails)
- **Translation files**: `config/locales/ar.yml` and `config/locales/en.yml`
- **Locale detection**: `ApplicationController#set_locale` checks: 1) logged-in user preference, 2) cookie, 3) default (Arabic)
- **Language switch**: `LocalesController#update` handles language switching and persists to cookie + user profile
- **Helper methods**: `current_locale` and `text_direction` available in all views

### Frontend (React)
- **i18n library**: `react-i18next` with `i18next`
- **Translation files**: `app/frontend/lib/locales/ar.json` and `app/frontend/lib/locales/en.json`
- **Configuration**: `app/frontend/lib/i18n.js`
- **Locale detection**: Reads `lang` attribute from `<html>` or `<meta name="locale">` tag

## How to Use Translations

### In Rails Views (.html.erb)
```erb
<%# Use t() helper %>
<h1><%= t('home.hero_title') %></h1>
<p><%= t('home.hero_description') %></p>

<%# With interpolation %>
<p><%= t('welcome', name: current_user.name) %></p>
```

### In Rails Controllers
```ruby
redirect_to root_path, notice: t('success.saved')
```

### In React Components
```jsx
import { useTranslation } from 'react-i18next';

const MyComponent = () => {
  const { t } = useTranslation();
  
  return (
    <div>
      <h1>{t('personal.title')}</h1>
      <input placeholder={t('personal.full_name_placeholder')} />
    </div>
  );
};
```

## Directory/Layout Switching (RTL/LTR)

The layout direction is automatically set based on locale:
- Arabic (ar) → `dir="rtl"`
- English (en) → `dir="ltr"`

This is handled in `app/views/layouts/application.html.erb`:
```erb
<html lang="<%= current_locale %>" dir="<%= text_direction %>">
```

## Remaining Translation Work

### High Priority
1. **Home page** (`app/views/home/index.html.erb`) - Contains its own full HTML structure with hardcoded Arabic
2. **React CV Builder components** - Large files with Arabic text:
   - `app/frontend/components/cv-builder/CombinedStep1.jsx`
   - `app/frontend/components/cv-builder/CombinedStep2.jsx`
   - `app/frontend/components/cv-builder/CombinedStep3.jsx`
   - `app/frontend/components/cv-builder/ReviewStep.jsx`
   - `app/frontend/components/cv-builder/CvImportModal.jsx`

### Medium Priority
3. **Profile views** (`app/views/profiles/`)
4. **Auth views** (`app/views/auth/`)
5. **Resume views** (`app/views/resumes/`)

### Lower Priority
6. **Error pages** (`public/404.html`, etc.)
7. **Email templates** (`app/views/*_mailer/`)

## Adding New Translations

1. Add Arabic strings to `config/locales/ar.yml`
2. Add English strings to `config/locales/en.yml`
3. For React components, also update:
   - `app/frontend/lib/locales/ar.json`
   - `app/frontend/lib/locales/en.json`

## Testing

To test the language toggle:
1. Start the Rails server: `bin/rails server`
2. Click the language toggle button in the header (globe icon with "EN" or "ع")
3. The page should reload with:
   - Changed direction (RTL ↔ LTR)
   - Translated navigation items
   - Updated content in translated views

## Translation Keys Naming Convention

- Use nested keys: `section.subsection.key`
- Keep keys descriptive but concise
- Use snake_case for keys
- Group related translations together

Example:
```yaml
en:
  resume:
    personal_info: "Personal Information"
    work_experience: "Work Experience"
    education:
      title: "Education"
      add: "Add Education"
```
