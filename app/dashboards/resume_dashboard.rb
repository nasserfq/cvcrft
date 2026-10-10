require "administrate/base_dashboard"

class ResumeDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    ai_translations: Field::HasMany,
    ats_keywords: Field::String.with_options(searchable: false),
    ats_score: Field::Number,
    certifications: Field::HasMany,
    city: Field::String,
    complete_name: Field::String,
    country: Field::String,
    cv_generations: Field::HasMany,
    educations: Field::HasMany,
    email: Field::String,
    languages: Field::HasMany,
    phone_number: Field::String,
    professional_summary: Field::Text,
    professional_summary_english: Field::Text,
    skills: Field::HasMany,
    summary: Field::Text,
    target_position: Field::String,
    title: Field::String,
    user: UserDetailField,
    work_experiences: Field::HasMany,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  # COLLECTION_ATTRIBUTES
  # an array of attributes that will be displayed on the model's index page.
  #
  # By default, it's limited to four items to reduce clutter on index pages.
  # Feel free to add, remove, or rearrange items.
  COLLECTION_ATTRIBUTES = %i[
    id
    user
    complete_name
    email
    title
    ats_score
    created_at
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
    ai_translations
    ats_keywords
    ats_score
    certifications
    city
    complete_name
    country
    cv_generations
    educations
    email
    languages
    phone_number
    professional_summary
    professional_summary_english
    skills
    summary
    target_position
    title
    user
    work_experiences
    created_at
    updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
    ai_translations
    ats_keywords
    ats_score
    certifications
    city
    complete_name
    country
    cv_generations
    educations
    email
    languages
    phone_number
    professional_summary
    professional_summary_english
    skills
    summary
    target_position
    title
    user
    work_experiences
  ].freeze

  # COLLECTION_FILTERS
  # a hash that defines filters that can be used while searching via the search
  # field of the dashboard.
  #
  # For example to add an option to search for open resources by typing "open:"
  # in the search field:
  #
  #   COLLECTION_FILTERS = {
  #     open: ->(resources) { resources.where(open: true) }
  #   }.freeze
  COLLECTION_FILTERS = {}.freeze

  # Overwrite this method to customize how resumes are displayed
  # across all pages of the admin dashboard.
  #
  # def display_resource(resume)
  #   "Resume ##{resume.id}"
  # end
end
