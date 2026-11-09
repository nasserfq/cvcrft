# Active Record encryption at rest for large free-text CV columns (PDPL, see
# docs/pdpl.md). Models opt in with `encrypts :column`.
#
# Keys come from credentials (active_record_encryption.*) when they are set
# there. Otherwise they are derived from secret_key_base with fixed salts, so
# no new secret is needed. Rotating secret_key_base therefore makes encrypted
# columns unreadable: move the keys into credentials first (the values printed
# by `bin/rails runner 'p ActiveRecord::Encryption.config.primary_key'`).
#
# Rows written before a column was encrypted stay plaintext until they are
# saved again; support_unencrypted_data lets them still be read. Encrypted
# columns are not queryable (extend_queries stays off), so only encrypt
# columns no code filters, orders, searches or indexes on.
encryption = Rails.application.config.active_record.encryption
encryption.support_unencrypted_data = true

if Rails.application.credentials.dig(:active_record_encryption, :primary_key).blank?
  key_generator = Rails.application.key_generator
  derive = ->(salt) { key_generator.generate_key("active_record_encryption.#{salt}", 32).unpack1("H*") }

  encryption.primary_key = derive.call("primary_key")
  encryption.deterministic_key = derive.call("deterministic_key")
  encryption.key_derivation_salt = derive.call("key_derivation_salt")
end
