# frozen_string_literal: true

# Configure session store with proper cookie settings
Rails.application.config.session_store :cookie_store,
  key: '_cvcraft_session',
  same_site: :lax,
  secure: Rails.env.production?,
  expire_after: 30.days
