class AtsOptimizationService
  def initialize(resume)
    @resume = resume
  end

  def optimize
    begin
      # Analyze current resume for ATS compatibility
      current_score = calculate_current_ats_score

      # Generate optimization suggestions
      suggestions = generate_optimization_suggestions

      # Update resume with new score and keywords
      @resume.update(
        ats_score: current_score,
        ats_keywords: extract_current_keywords
      )

      {
        success: true,
        current_score: current_score,
        suggestions: suggestions,
        keywords: extract_current_keywords
      }
    rescue => e
      {
        success: false,
        error: e.message
      }
    end
  end

  private

  def calculate_current_ats_score
    score = 0

    # Base score for having required sections
    score += 20 if @resume.summary.present?
    score += 20 if @resume.work_experiences.any?
    score += 20 if @resume.skills.any?

    # Score for content quality
    score += calculate_content_score

    # Score for keyword optimization
    score += calculate_keyword_score

    # Cap at 100
    [ score, 100 ].min
  end

  def calculate_content_score
    score = 0

    # Work experience quality
    @resume.work_experiences.each do |exp|
      score += 5 if exp.english_description.present?
      score += 5 if exp.english_description&.length.to_i > 100
      score += 5 if exp.english_description&.include?("developed") || exp.english_description&.include?("managed")
    end

    # Skills variety
    score += 10 if @resume.skills.count >= 5
    score += 5 if @resume.skills.technical.any?
    score += 5 if @resume.skills.soft.any?

    score
  end

  def calculate_keyword_score
    score = 0
    target_keywords = extract_target_keywords

    # Check if resume contains target keywords
    resume_text = extract_resume_text.downcase

    target_keywords.each do |keyword|
      score += 3 if resume_text.include?(keyword.downcase)
    end

    score
  end

  def extract_target_keywords
    # In production, this would analyze the target position and industry
    # For now, return common professional keywords
    [
      "project management", "leadership", "communication", "problem solving",
      "teamwork", "analytical", "strategic planning", "customer service",
      "development", "implementation", "coordination", "optimization",
      "research", "analysis", "planning", "organization"
    ]
  end

  def extract_current_keywords
    keywords = []

    # Extract keywords from work experience
    @resume.work_experiences.each do |exp|
      if exp.english_description.present?
        keywords.concat(extract_keywords_from_text(exp.english_description))
      end
    end

    # Extract keywords from skills
    @resume.skills.each do |skill|
      keywords << skill.name.downcase
    end

    # Extract keywords from summary
    keywords.concat(extract_keywords_from_text(@resume.summary))

    # Remove duplicates and common words
    keywords.uniq.reject { |k| k.length < 3 || common_words.include?(k) }
  end

  def extract_keywords_from_text(text)
    # Simple keyword extraction - in production, use NLP libraries
    text.downcase
        .gsub(/[^\w\s]/, " ")
        .split(/\s+/)
        .select { |word| word.length > 3 }
        .reject { |word| common_words.include?(word) }
  end

  def common_words
    %w[the and or but in on at to for of with by from up down out off over under]
  end

  def extract_resume_text
    [
      @resume.summary,
      @resume.work_experiences.map(&:english_description).compact.join(" "),
      @resume.skills.map(&:name).join(" ")
    ].compact.join(" ")
  end

  def generate_optimization_suggestions
    suggestions = []

    # Check for missing sections
    suggestions << "Add a professional summary" if @resume.summary.blank?
    suggestions << "Include work experience" if @resume.work_experiences.empty?
    suggestions << "List relevant skills" if @resume.skills.empty?

    # Check content quality
    @resume.work_experiences.each do |exp|
      if exp.english_description.blank?
        suggestions << "Translate work experience for #{exp.company} to English"
      elsif exp.english_description.length < 100
        suggestions << "Expand description for #{exp.company} position"
      end
    end

    # Check for action verbs
    resume_text = extract_resume_text.downcase
    action_verbs = %w[developed managed implemented coordinated analyzed planned]

    if action_verbs.none? { |verb| resume_text.include?(verb) }
      suggestions << "Use more action verbs (developed, managed, implemented, etc.)"
    end

    # Check for metrics
    if resume_text.scan(/\d+/).empty?
      suggestions << "Include specific metrics and numbers to quantify achievements"
    end

    suggestions
  end
end
