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

ActiveRecord::Schema[8.0].define(version: 2025_09_13_132147) do
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
    t.string "status"
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
    t.index ["resume_id"], name: "index_cv_generations_on_resume_id"
    t.index ["user_id"], name: "index_cv_generations_on_user_id"
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

  create_table "otp_verifications", force: :cascade do |t|
    t.string "email", null: false
    t.string "otp_code", null: false
    t.datetime "expires_at", null: false
    t.boolean "verified", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.boolean "is_current"
    t.index ["resume_id"], name: "index_work_experiences_on_resume_id"
  end

  add_foreign_key "ai_translations", "resumes"
  add_foreign_key "ai_translations", "users"
  add_foreign_key "certifications", "resumes"
  add_foreign_key "cv_generations", "resumes"
  add_foreign_key "cv_generations", "users"
  add_foreign_key "educations", "resumes"
  add_foreign_key "languages", "resumes"
  add_foreign_key "resumes", "users"
  add_foreign_key "skills", "resumes"
  add_foreign_key "work_experiences", "resumes"
end
