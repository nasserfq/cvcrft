# ATS template previews

## 1. Goal
In both ATS template pickers, each of the 11 styles shows a page-1 thumbnail of a sample CV above its name.
A "Preview" control on each card opens the full-size image in a glass lightbox. Tapping the card still
selects it. The look is the dark Seera glass style, and Arabic and English both work, including RTL.
- Picker A: `packs/ai_tools/app/views/cv_generations/new.html.erb` (inline React, cards at ~:696-725)
- Picker B: `app/frontend/components/cv-builder/ReviewStep.jsx` (Vite, buttons at :38-61)
- `resumes/show.html.erb` keeps its plain `<select>` (out of scope).

## 2. Approach
The thumbnails are static WebP (thumb, @2x, full)s committed to `public/ats_previews/<key>.png`. A rake task makes them from an
in-memory English sample CV. It calls the real `AtsTemplatePdfService.generate_pdf`, so each preview is exactly
what that template exports. `pdftoppm` turns page 1 into a WebP (thumb, @2x, full) about 600px wide, and ImageMagick/`optipng`
shrinks it to under 80 KB. Files in `public/` are served at a fixed URL (`/ats_previews/<key>.png`), so the
ERB/Babel picker and the Vite picker use the same URL with no asset-digest lookup.

The obvious alternative is to render a live preview from the user's own data on every request. We reject it
because it costs a Prawn render per card (11 per page view), and Prawn Helvetica cannot render Arabic, so an
Arabic CV would show broken glyphs. A static sample is instant, cacheable, and the same for every locale.
The trade-off is that someone must re-run the rake task when a preset changes. The test in section 5 catches a
missing file, but not a stale one.

## 3. Work units (parallel; no shared files)

### Unit A: generator, assets, helper (owner: `resume_builder` + `ai_tools` helper)
Files it owns:
- NEW `packs/resume_builder/app/services/ats_style_presets/ats_preview_sample.rb`
  - `AtsStylePresets::AtsPreviewSample.resume` returns a duck-typed Struct with `complete_name`, `email`,
    `phone_number`, `city`, `country`, `professional_summary_english`, `professional_summary`, and
    `work_experiences`: 2-3 Structs with `job_title`, `company`, `start_date`, `end_date`, `is_current`,
    `responsibilities`.
  - `.data` returns a symbol-keyed hash with `professional_summary`, `educations`, `skills`,
    `certifications`, `languages`.
  - All values are fictional and generic, for example "Sara Al-Ahmad", "sara@example.com". No DB access.
  - Check the legacy `AtsPdfGenerator` path (`original_classic`) for any extra methods it calls on the
    resume, and add them to the Struct.
- NEW `lib/tasks/ats_previews.rake` defines `ats_previews:generate` (`=> :environment`):
  - Loop over `AtsTemplatePdfService.template_catalog`.
  - Call `generate_pdf(sample.resume, sample.data, template: key)`.
  - Run `pdftoppm -png -f 1 -l 1 -scale-to-x 600 -scale-to-y -1 <pdf> <tmp>`.
  - Run `convert ... -strip` (and `optipng -o5` if present), then write `public/ats_previews/<key>.png`.
  - Delete the temp PDF. Use `Open3` with argument arrays (no shell interpolation; Brakeman).
- NEW `public/ats_previews/*.png` (11 files, committed). The engineer runs the task locally
  (`bundle install` first if needed; no DB needed).
- EDIT `packs/ai_tools/app/helpers/cv_generation_helper.rb`: add
  `preview_url: "/ats_previews/#{key}.png"` to each option hash.

### Unit B: picker UI + strings (owner: the two views + locale files)
Files it owns: `packs/ai_tools/app/views/cv_generations/new.html.erb`,
`app/frontend/components/cv-builder/ReviewStep.jsx`, `config/locales/en.yml`, `config/locales/ar.yml`,
`app/frontend/lib/locales/en.json`, `app/frontend/lib/locales/ar.json`.
It does not depend on Unit A's code: it builds the URL from `template.key`, and Unit A's `preview_url`
is an optional override.
- **Card layout (both pickers):**
  - Grid: `grid-cols-2 sm:grid-cols-3 lg:grid-cols-4`.
  - Thumbnail: `<img loading="lazy" decoding="async" alt={name}>` in an `aspect-[1/1.414]` box with
    `rounded-lg overflow-hidden border border-white/10 bg-white`.
  - Name, then description (`line-clamp-2`).
  - Selected state: keep the existing `ring-primary` style.
  - Because the cards get taller, remove `max-h-[min(50vh,28rem)]` on mobile, or raise it to `70vh`.
  - Use `onError` to hide a broken image, which falls back to the current text-only card.
- **Preview control:** a small glass button with a magnifier icon at the thumbnail corner, placed with
  `end-2 top-2` (logical, so it is RTL-safe).
  - Make it a sibling of the select button inside a `relative` wrapper. Do not nest it inside the button,
    because a `<button>` inside a `<button>` is invalid HTML.
  - Give it `aria-label={t.preview_template}` and a hit area of at least 44px.
- **Lightbox:** `fixed inset-0 z-50 bg-black/70 backdrop-blur-sm` with a centered `.glass rounded-2xl p-3`
  panel.
  - Image: `max-h-[85vh] w-auto`. Title: the template name.
  - Buttons: Close, and "Use this template", which selects the template and closes the lightbox.
  - Escape and a backdrop click close it. Focus moves to Close on open and returns to the trigger on close.
  - `role="dialog" aria-modal="true"`, and lock body scroll while open.
  - In `new.html.erb`: lightbox state lives in the inline component (`useState(previewTemplate)`).
  - In `ReviewStep.jsx`: local `useState` (keep `memo`).
- **Strings (en + ar):**
  - Add `cv_generation.preview_template` ("Preview template" / "معاينة القالب"), `cv_generation.close`
    ("Close" / "إغلاق") and `cv_generation.use_template` ("Use this template" / "استخدم هذا القالب")
    to the yml files.
  - Expose them in `window.CV_TRANSLATIONS` (new.html.erb ~:185-193).
  - Add the same three keys under `templates` in `en.json` and `ar.json` (next to `ats_picker_label`, ~:198).

## 4. Data
No migrations and no schema change. The only new data is static files in `public/`.
The helper hash gains one key, which existing consumers can ignore.

## 5. Tests
- Unit A:
  - NEW `test/services/ats_preview_assets_test.rb`: for every `AtsStylePresets::AtsStyleCatalog` key, assert
    `Rails.root.join("public/ats_previews/#{key}.png")` exists and is under 200 KB.
  - NEW `test/services/resume_builder/ats_preview_sample_test.rb`: `generate_pdf` succeeds for every key with
    the sample (no DB records).
  - NEW `test/helpers/cv_generation_helper_test.rb` (ActionView::TestCase): each option has
    `preview_url == "/ats_previews/<key>.png"`.
- Unit B:
  - Extend the existing system test for the CV generation page, or add `test/system/ats_template_preview_test.rb`.
  - It checks: thumbnails render (11 imgs); clicking Preview opens the dialog; Escape closes it;
    "Use this template" selects the card. Run it under `locale=ar` too.
  - If a Vitest/Jest suite exists for `app/frontend`, add a ReviewStep render test. If not, verify by hand.

## 6. Risks
- **Stale previews** after a preset changes. Mitigation: a comment in `ats_style_catalog.rb` saying to run
  `bin/rails ats_previews:generate`, plus the asset test.
- **Legacy `original_classic` renderer** may need more resume methods than the Struct has. Check that the rake
  task renders all 11 without errors.
- **Page weight:** 11 images. Mitigation: lazy-loading, an 80 KB target, and `public/` caching headers.
- **Mobile picker height and scrolling** in new.html.erb (the overflow container). Check at 375px in both
  languages.
- **Invalid nested interactive elements** would break a11y and keyboard selection. Keep the Preview button
  outside the select button.
- **CI:** `bin/rubocop` (rake + service), `bin/brakeman` (Open3 arrays only), and
  `bin/rails test test:system`. The rake task is never run in CI or production, and it touches no production
  data or secrets.
