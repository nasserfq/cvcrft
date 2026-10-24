# Every email Seera sends: Arabic first, then English, in one message, with
# both subjects in the subject line ("عربي | English"). Each kind has its body
# in packs/accounts/app/views/emails/_<kind>.{html,text}.erb, rendered once per
# language inside emails/message, and its copy under emails.<kind> in
# config/locales/emails.{ar,en}.yml.
#
#   SeeraEmail.otp("123456").deliver_to("someone@example.com")
class SeeraEmail
  LOCALES = %w[ar en].freeze
  SITE_URL = "https://cvcrft.com".freeze
  # Its own file, not /icon.png: public files are cached for a year, so mail
  # clients and image proxies kept showing the old icon.png. Give a new logo a
  # new file name rather than overwriting this one.
  LOGO_URL = "#{SITE_URL}/email-logo.png".freeze

  # Inline styles shared by the bodies (email clients drop most <style> rules).
  FONT = "'Bricolage Grotesque', 'Readex Pro', 'Segoe UI', Tahoma, Arial, sans-serif".freeze
  STYLES = {
    h1: "margin:0 0 12px;font-family:#{FONT};font-size:24px;line-height:1.35;font-weight:600;color:#eef3ee;",
    p: "margin:0 0 16px;font-family:#{FONT};font-size:16px;line-height:1.75;color:rgba(238,243,238,0.82);",
    muted: "margin:0 0 16px;font-family:#{FONT};font-size:14px;line-height:1.7;color:rgba(238,243,238,0.55);",
    code: "margin:8px 0 20px;padding:18px 12px;font-family:'JetBrains Mono', Menlo, Consolas, monospace;font-size:34px;line-height:1;font-weight:700;letter-spacing:10px;text-align:center;color:#d6b877;background:#0b1a12;border:1px solid rgba(214,184,119,0.45);border-radius:16px;",
    button: "display:inline-block;padding:14px 28px;font-family:#{FONT};font-size:16px;font-weight:600;color:#ffffff;text-decoration:none;background:#0b7f48;border-radius:14px;"
  }.freeze

  attr_reader :subject, :html, :text

  def self.otp(code)
    new(:otp, code: code)
  end

  def self.welcome(name)
    new(:welcome, name: name, cta_url: "#{SITE_URL}/resumes/new")
  end

  def self.notification
    new(:notification, cta_url: SITE_URL)
  end

  def initialize(kind, **locals)
    @subject = both_languages("emails.#{kind}.subject", " | ")
    preheader = both_languages("emails.#{kind}.preheader", " · ")
    locals = locals.merge(kind: kind, subject: @subject, preheader: preheader)
    @html = render(:html, locals)
    @text = render(:text, locals)
  end

  def deliver_to(email)
    AmazonSesService.new.send_email(to: email, subject: subject, body: html, text: text)
  end

  private

  def both_languages(key, separator)
    LOCALES.map { |locale| I18n.t(key, locale: locale) }.join(separator)
  end

  def render(format, locals)
    ApplicationController.render(template: "emails/message", layout: false, formats: [ format ], locals: locals)
  end
end
