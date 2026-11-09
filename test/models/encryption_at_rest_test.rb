require "test_helper"

# Large free-text CV columns are encrypted at rest
# (config/initializers/active_record_encryption.rb). Rows written before that
# stay plaintext and must still read.
class EncryptionAtRestTest < ActiveSupport::TestCase
  CV_TEXT = "محمد أحمد\nSenior Engineer, Riyadh"

  setup do
    @user = users(:test_user)
  end

  test "keys are configured without credentials" do
    config = ActiveRecord::Encryption.config

    assert config.primary_key.present?
    assert config.deterministic_key.present?
    assert config.key_derivation_salt.present?
    assert config.support_unencrypted_data
    assert_not config.extend_queries
  end

  test "the chosen columns are encrypted" do
    assert_equal [ :extracted_text ], CvImport.encrypted_attributes.to_a
    assert_equal [ :extracted_text ], LinkedinImport.encrypted_attributes.to_a
    assert_equal [ :extracted_text ], CvAnalysis.encrypted_attributes.to_a
    assert_equal [ :content ], Coach::Message.encrypted_attributes.to_a
  end

  test "stores extracted CV text encrypted and reads it back" do
    records.each do |record|
      raw = raw_value(record, :extracted_text)

      assert_not_includes raw, "Senior Engineer", "#{record.class} stored plaintext"
      assert ActiveRecord::Encryption.encryptor.encrypted?(raw), "#{record.class} value is not an encrypted payload"
      assert_equal CV_TEXT, record.class.find(record.id).extracted_text
    end
  end

  test "stores coach messages encrypted and reads them back" do
    chat = Coach::Chat.create!(user: @user, path: "scratch")
    message = chat.messages.create!(role: "user", content: CV_TEXT)

    assert_not_includes raw_value(message, :content), "Senior Engineer"
    assert_equal CV_TEXT, Coach::Message.find(message.id).content
  end

  test "reads legacy plaintext rows and encrypts them on the next save" do
    records.each do |record|
      write_raw(record, :extracted_text, "Legacy plaintext CV")
      reloaded = record.class.find(record.id)

      assert_equal "Legacy plaintext CV", reloaded.extracted_text

      reloaded.update!(extracted_text: "Legacy plaintext CV, edited")
      assert_not_includes raw_value(record, :extracted_text), "Legacy plaintext"
      assert_equal "Legacy plaintext CV, edited", record.class.find(record.id).extracted_text
    end
  end

  test "nil checks and clearing still work in SQL" do
    analysis = records.last
    CvAnalysis.where(id: analysis.id).update_all(extracted_text: nil)

    assert_nil raw_value(analysis, :extracted_text)
    assert CvAnalysis.where(id: analysis.id, extracted_text: nil).exists?
    assert_not CvAnalysis.where(id: analysis.id).where.not(extracted_text: nil).exists?
  end

  private

  def records
    [
      CvImport.create!(user: @user, original_filename: "cv.pdf", extracted_text: CV_TEXT),
      LinkedinImport.create!(user: @user, original_filename: "in.pdf", extracted_text: CV_TEXT),
      CvAnalysis.create!(user: @user, original_filename: "cv.pdf", extracted_text: CV_TEXT)
    ]
  end

  def raw_value(record, column)
    table = record.class.quoted_table_name
    record.class.connection.select_value(
      "SELECT #{record.class.connection.quote_column_name(column)} FROM #{table} WHERE id = #{record.id.to_i}"
    )
  end

  def write_raw(record, column, value)
    connection = record.class.connection
    connection.execute(
      "UPDATE #{record.class.quoted_table_name} SET #{connection.quote_column_name(column)} = " \
      "#{connection.quote(value)} WHERE id = #{record.id.to_i}"
    )
  end
end
