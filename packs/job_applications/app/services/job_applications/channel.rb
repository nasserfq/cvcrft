module JobApplications
  # How an application reaches the employer: their ATS form in a browser, an
  # email to the address in the posting, or nothing we can do (manual).
  module Channel
    module_function

    def for(posting)
      if SUBMITTERS.include?(posting.employer.ats) then "browser"
      elsif posting.apply_email.present? then "email"
      else "manual"
      end
    end
  end
end
