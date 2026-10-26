class LinkedinImportsController < ApplicationController
  include CreditsUpsell
  before_action :authenticate_user!

  include UserRateLimit
  rate_limit_per_user to: 5, within: 1.minute, only: :create, name: "linkedin-import"
  before_action :set_linkedin_import, only: [ :status, :show, :update, :destroy, :download_pdf, :save_to_cv ]

  # GET /linkedin-import
  def new
    @linkedin_import = LinkedinImport.new
  end

  # POST /linkedin-import
  def create
    # Check if file was uploaded
    unless params[:pdf_file].present?
      respond_to do |format|
        format.html do
          flash[:alert] = "Please upload a LinkedIn PDF file"
          redirect_to linkedin_import_path
        end
        format.json { render json: { success: false, error: "Please upload a LinkedIn PDF file" }, status: :unprocessable_entity }
      end
      return
    end

    if params[:pdf_file].size > 10.megabytes
      return reject_upload("حجم الملف كبير جداً. الحد الأقصى 10 ميجابايت", :unprocessable_entity)
    end

    # Free allowance first, then credits (Billing::UsageGate::COSTS) while billing is on
    charge_key = SecureRandom.uuid
    charge = Billing::UsageGate.allow!(current_user, :document_ai, key: charge_key)
    if charge == :blocked
      return reject_upload("لقد وصلت إلى الحد الأقصى لتحليل واستيراد الملفات.", :too_many_requests,
                           limit_reached: true, **credits_upsell)
    end

    begin
      # Parse PDF to extract text
      pdf_file = params[:pdf_file]
      parser = LinkedinPdfParserService.new(pdf_file.path)
      extracted_text = parser.parse

      # Create the import record
      @linkedin_import = LinkedinImport.new(
        user: current_user,
        extracted_text: extracted_text,
        original_filename: pdf_file.original_filename
      )

      if @linkedin_import.save
        # Queue the background job for AI processing
        LinkedinImportJob.perform_async(@linkedin_import.id, *(charge_key if charge == :credit))

        respond_to do |format|
          format.html { redirect_to linkedin_import_status_path(@linkedin_import) }
          format.json { render json: { success: true, id: @linkedin_import.id, status_url: linkedin_import_status_path(@linkedin_import, format: :json) } }
        end
      else
        refund_import(charge, charge_key)
        respond_to do |format|
          format.html do
            flash[:alert] = "Failed to create import: #{@linkedin_import.errors.full_messages.join(', ')}"
            redirect_to linkedin_import_path
          end
          format.json { render json: { success: false, error: @linkedin_import.errors.full_messages.join(", ") }, status: :unprocessable_entity }
        end
      end
    rescue LinkedinPdfParserService::LinkedinPdfParseError => e
      refund_import(charge, charge_key)
      respond_to do |format|
        format.html do
          flash[:alert] = "Failed to parse PDF: #{e.message}"
          redirect_to linkedin_import_path
        end
        format.json { render json: { success: false, error: "Failed to parse PDF: #{e.message}" }, status: :unprocessable_entity }
      end
    end
  end

  # GET /linkedin-import/:id/status
  def status
    respond_to do |format|
      format.html
      format.json do
        render json: {
          status: @linkedin_import.status,
          error_message: @linkedin_import.error_message,
          completed: @linkedin_import.completed?,
          failed: @linkedin_import.failed?,
          processing: @linkedin_import.processing?,
          parsed_data: @linkedin_import.completed? ? @linkedin_import.parsed_data : nil
        }
      end
    end
  end

  # GET /linkedin-import/:id/edit
  def show
    unless @linkedin_import.completed?
      redirect_to linkedin_import_status_path(@linkedin_import) and return
    end

    @parsed_data = @linkedin_import.parsed_data
  end

  # PATCH /linkedin-import/:id
  def update
    if @linkedin_import.update(parsed_data: parsed_data_params.to_h)
      render json: { success: true, message: "CV updated successfully" }
    else
      render json: { success: false, errors: @linkedin_import.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # POST /linkedin-import/:id/save-to-cv
  def save_to_cv
    unless @linkedin_import.completed?
      render json: { success: false, error: "Import not completed" }, status: :unprocessable_entity
      return
    end

    begin
      resume = create_resume_from_import(@linkedin_import)
      @linkedin_import.update!(resume: resume)

      render json: {
        success: true,
        resume_id: resume.id,
        redirect_url: resume_path(resume)
      }
    rescue => e
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    end
  end

  # GET /linkedin-import/:id/download-pdf
  def download_pdf
    unless @linkedin_import.completed? && @linkedin_import.resume.present?
      redirect_to linkedin_import_edit_path(@linkedin_import), alert: "Please save your CV first"
      return
    end

    redirect_to download_resume_path(@linkedin_import.resume, format: :pdf)
  end

  # DELETE /linkedin-import/:id
  def destroy
    @linkedin_import.destroy
    redirect_to linkedin_import_path, notice: "Import deleted"
  end

  private

  # Gives the credit back when the import it paid for didn't start.
  def refund_import(charge, key)
    Billing::UsageGate.refund!(current_user, :document_ai, key: key) if charge == :credit
  end

  def reject_upload(message, status, **extra)
    respond_to do |format|
      format.html do
        flash[:alert] = message
        redirect_to linkedin_import_path
      end
      format.json { render json: { success: false, error: message, **extra }, status: status }
    end
  end

  def set_linkedin_import
    @linkedin_import = current_user.linkedin_imports.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to linkedin_import_path, alert: "Import not found"
  end

  def parsed_data_params
    params.require(:parsed_data).permit(
      :complete_name, :email, :phone_number, :city, :country, :professional_summary,
      work_experiences: [ :job_title, :company, :start_date, :end_date, :is_current, responsibilities: [] ],
      educations: [ :degree, :institution, :start_date, :end_date, :gpa, :is_current ],
      skills: [ :category, skill_names: [] ],
      certifications: [ :name, :organization, :date ],
      languages: [ :language, :proficiency ]
    )
  end

  def create_resume_from_import(linkedin_import)
    data = linkedin_import.parsed_data

    ActiveRecord::Base.transaction do
      resume = Resume.create!(
        user: current_user,
        complete_name: data["complete_name"],
        email: data["email"],
        phone_number: data["phone_number"],
        city: data["city"],
        country: data["country"],
        professional_summary: data["professional_summary"],
        source: "linkedin"
      )

      # Create work experiences
      (data["work_experiences"] || []).each do |exp|
        resume.work_experiences.create!(
          job_title: exp["job_title"],
          company: exp["company"],
          start_date: exp["start_date"],
          end_date: exp["is_current"] ? nil : exp["end_date"],
          responsibilities: Array(exp["responsibilities"]).join("\n"),
          is_current: exp["is_current"]
        )
      end

      # Create educations
      (data["educations"] || []).each do |edu|
        resume.educations.create!(
          degree: edu["degree"],
          institution: edu["institution"],
          start_date: edu["start_date"],
          end_date: edu["is_current"] ? nil : edu["end_date"],
          gpa: edu["gpa"],
          is_current: edu["is_current"]
        )
      end

      # Create skills with categories
      (data["skills"] || []).each do |skill_group|
        category = skill_group["category"]
        skill_names = skill_group["skill_names"] || []
        next if skill_names.empty?

        resume.skills.create!(
          category: category,
          skill_names: skill_names,
          name: skill_names.first # For backward compatibility
        )
      end

      # Create certifications
      (data["certifications"] || []).each do |cert|
        resume.certifications.create!(
          name: cert["name"],
          organization: cert["organization"],
          date: cert["date"]
        )
      end

      # Create languages
      (data["languages"] || []).each do |lang|
        resume.languages.create!(
          language: lang["language"],
          proficiency: lang["proficiency"]
        )
      end

      resume
    end
  end
end
