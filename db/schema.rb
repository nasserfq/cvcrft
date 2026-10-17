# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_17_000100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "ai_translations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "resume_id"
    t.text "arabic_text"
    t.text "english_text"
    t.string "translation_quality"
    t.string "ai_model"
    t.integer "tokens_used"
    t.string "status", default: "pending"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "metadata", default: {}
    t.index ["metadata"], name: "index_ai_translations_on_metadata", using: :gin
    t.index ["resume_id"], name: "index_ai_translations_on_resume_id"
    t.index ["user_id"], name: "index_ai_translations_on_user_id"
  end

  create_table "certifications", force: :cascade do |t|
    t.bigint "resume_id", null: false
    t.string "name"
    t.string "organization"
    t.text "date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["resume_id"], name: "index_certifications_on_resume_id"
  end

  create_table "coach_chats", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "path", null: false
    t.jsonb "draft", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "proposals", default: [], null: false
    t.index ["user_id"], name: "index_coach_chats_on_user_id"
  end

  create_table "coach_messages", force: :cascade do |t|
    t.bigint "coach_chat_id", null: false
    t.string "role", null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "fields", default: [], null: false
    t.index ["coach_chat_id", "created_at"], name: "index_coach_messages_on_coach_chat_id_and_created_at"
    t.index ["coach_chat_id"], name: "index_coach_messages_on_coach_chat_id"
  end

  create_table "coupon_redemptions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "coupon_id", null: false
    t.datetime "redeemed_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["coupon_id"], name: "index_coupon_redemptions_on_coupon_id"
    t.index ["user_id", "coupon_id"], name: "index_coupon_redemptions_on_user_id_and_coupon_id", unique: true
    t.index ["user_id"], name: "index_coupon_redemptions_on_user_id"
  end

  create_table "coupons", force: :cascade do |t|
    t.string "code", null: false
    t.text "description"
    t.integer "bonus_summary_translations", default: 0, null: false
    t.integer "bonus_jobs_translations", default: 0, null: false
    t.integer "bonus_cv_builder_generations", default: 0, null: false
    t.integer "bonus_job_based_generations", default: 0, null: false
    t.datetime "expires_at"
    t.integer "max_redemptions"
    t.integer "redemptions_count", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "unlimited", default: false, null: false
    t.index "lower((code)::text)", name: "index_coupons_on_lower_code", unique: true
  end

  create_table "credit_ledger_entries", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "amount", null: false
    t.integer "balance_after", null: false
    t.string "reason", null: false
    t.string "idempotency_key", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["idempotency_key"], name: "index_credit_ledger_entries_on_idempotency_key", unique: true
    t.index ["user_id", "created_at"], name: "index_credit_ledger_entries_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_credit_ledger_entries_on_user_id"
  end

  create_table "credit_purchases", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "pack", null: false
    t.integer "credits", null: false
    t.integer "amount_halalas", null: false
    t.string "currency", default: "SAR", null: false
    t.string "status", default: "pending", null: false
    t.string "moyasar_invoice_id"
    t.string "checkout_url"
    t.datetime "paid_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["moyasar_invoice_id"], name: "index_credit_purchases_on_moyasar_invoice_id", unique: true
    t.index ["user_id"], name: "index_credit_purchases_on_user_id"
  end

  create_table "cv_analyses", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "status", default: "pending", null: false
    t.string "original_filename"
    t.text "extracted_text"
    t.jsonb "analysis_results", default: {}
    t.text "error_message"
    t.string "target_job"
    t.string "target_industry"
    t.string "language", default: "ar"
    t.string "ai_model"
    t.integer "tokens_used"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_cv_analyses_on_created_at"
    t.index ["status"], name: "index_cv_analyses_on_status"
    t.index ["user_id"], name: "index_cv_analyses_on_user_id"
  end

  create_table "cv_generations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "resume_id"
    t.text "job_description"
    t.text "generated_content"
    t.string "ai_model"
    t.string "status"
    t.integer "tokens_used"
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_draft", default: false, null: false
    t.json "draft_data", default: {}
    t.index ["is_draft"], name: "index_cv_generations_on_is_draft"
    t.index ["resume_id"], name: "index_cv_generations_on_resume_id"
    t.index ["user_id", "is_draft"], name: "index_cv_generations_on_user_id_and_is_draft"
    t.index ["user_id"], name: "index_cv_generations_on_user_id"
  end

  create_table "cv_imports", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "status", default: "pending", null: false
    t.string "original_filename"
    t.text "extracted_text"
    t.jsonb "parsed_data", default: {}
    t.text "error_message"
    t.string "detected_language"
    t.bigint "resume_id"
    t.string "job_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["detected_language"], name: "index_cv_imports_on_detected_language"
    t.index ["job_id"], name: "index_cv_imports_on_job_id"
    t.index ["resume_id"], name: "index_cv_imports_on_resume_id"
    t.index ["status"], name: "index_cv_imports_on_status"
    t.index ["user_id"], name: "index_cv_imports_on_user_id"
  end

  create_table "educations", force: :cascade do |t|
    t.bigint "resume_id", null: false
    t.string "degree"
    t.string "institution"
    t.text "start_date"
    t.text "end_date"
    t.string "gpa"
    t.boolean "is_current"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["resume_id"], name: "index_educations_on_resume_id"
  end

  create_table "languages", force: :cascade do |t|
    t.bigint "resume_id", null: false
    t.string "language"
    t.string "proficiency"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["resume_id"], name: "index_languages_on_resume_id"
  end

  create_table "linkedin_imports", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "status", default: "pending", null: false
    t.string "original_filename"
    t.text "extracted_text"
    t.jsonb "parsed_data", default: {}
    t.text "error_message"
    t.bigint "resume_id"
    t.string "job_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["job_id"], name: "index_linkedin_imports_on_job_id"
    t.index ["resume_id"], name: "index_linkedin_imports_on_resume_id"
    t.index ["status"], name: "index_linkedin_imports_on_status"
    t.index ["user_id"], name: "index_linkedin_imports_on_user_id"
  end

  create_table "otp_verifications", force: :cascade do |t|
    t.string "email", null: false
    t.string "otp_code", null: false
    t.datetime "expires_at", null: false
    t.boolean "verified", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.index ["email"], name: "index_otp_verifications_on_email"
    t.index ["expires_at"], name: "index_otp_verifications_on_expires_at"
    t.index ["otp_code"], name: "index_otp_verifications_on_otp_code"
  end

  create_table "resumes", force: :cascade do |t|
    t.bigint "user_id"
    t.string "title"
    t.string "target_position"
    t.text "summary"
    t.integer "ats_score"
    t.json "ats_keywords"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "professional_summary"
    t.string "complete_name"
    t.string "email"
    t.string "phone_number"
    t.string "city"
    t.string "country"
    t.text "professional_summary_english"
    t.boolean "is_draft", default: false, null: false
    t.json "draft_data", default: {}
    t.string "source", default: "manual", null: false
    t.index ["is_draft"], name: "index_resumes_on_is_draft"
    t.index ["source"], name: "index_resumes_on_source"
    t.index ["user_id", "is_draft"], name: "index_resumes_on_user_id_and_is_draft"
    t.index ["user_id"], name: "index_resumes_on_user_id"
  end

  create_table "skills", force: :cascade do |t|
    t.bigint "resume_id", null: false
    t.string "name"
    t.string "level"
    t.string "category"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "skill_names"
    t.index ["resume_id"], name: "index_skills_on_resume_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "locale", default: "ar", null: false
    t.integer "summary_translations_count", default: 0, null: false
    t.integer "jobs_translations_count", default: 0, null: false
    t.integer "job_based_generations_count", default: 0, null: false
    t.integer "document_ai_count", default: 0, null: false
    t.integer "credit_balance", default: 0, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "work_experiences", force: :cascade do |t|
    t.bigint "resume_id", null: false
    t.string "company"
    t.string "position"
    t.text "start_date"
    t.text "end_date"
    t.text "arabic_description"
    t.text "english_description"
    t.json "ats_keywords"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "job_title"
    t.text "responsibilities"
    t.boolean "is_current", default: false
    t.index ["resume_id"], name: "index_work_experiences_on_resume_id"
  end

  add_foreign_key "ai_translations", "resumes"
  add_foreign_key "ai_translations", "users"
  add_foreign_key "certifications", "resumes"
  add_foreign_key "coach_chats", "users", on_delete: :cascade
  add_foreign_key "coach_messages", "coach_chats", on_delete: :cascade
  add_foreign_key "coupon_redemptions", "coupons"
  add_foreign_key "coupon_redemptions", "users"
  add_foreign_key "credit_ledger_entries", "users"
  add_foreign_key "credit_purchases", "users"
  add_foreign_key "cv_analyses", "users"
  add_foreign_key "cv_generations", "resumes"
  add_foreign_key "cv_generations", "users"
  add_foreign_key "cv_imports", "resumes"
  add_foreign_key "cv_imports", "users"
  add_foreign_key "educations", "resumes"
  add_foreign_key "languages", "resumes"
  add_foreign_key "linkedin_imports", "resumes"
  add_foreign_key "linkedin_imports", "users"
  add_foreign_key "resumes", "users"
  add_foreign_key "skills", "resumes"
  add_foreign_key "work_experiences", "resumes"
end
