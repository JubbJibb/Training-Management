# frozen_string_literal: true

module TrainingClassPublicSlug
  extend ActiveSupport::Concern

  included do
    validates :public_slug, uniqueness: { case_sensitive: true }, allow_blank: true
  end

  def public_url
    return nil unless public_enabled? && public_slug.present?
    opts = url_options
    Rails.application.routes.url_helpers.public_class_url(public_slug, **opts)
  rescue ArgumentError
    # Fallback if default_url_options not set
    host = Rails.application.config.action_mailer.default_url_options&.dig(:host) || "localhost"
    port = Rails.application.config.action_mailer.default_url_options&.dig(:port)
    protocol = Rails.application.config.action_mailer.default_url_options&.dig(:protocol) || "http"
    base = port.to_i.in?([80, 443]) ? "#{protocol}://#{host}" : "#{protocol}://#{host}:#{port}"
    "#{base}/classes/#{public_slug}"
  end

  def public_url_with_fallback
    public_url.presence || "#"
  end

  # Generates a unique slug from title + date. Call when enabling public page or on create.
  def generate_public_slug!
    base = [title, date.strftime("%Y-%m-%d")].join(" ").parameterize.presence || "class"
    slug = base
    n = 0
    while slug_taken?(slug)
      n += 1
      slug = "#{base}-#{n}"
    end
    update_column(:public_slug, slug)
    slug
  end

  def ensure_public_slug!
    return public_slug if public_slug.present?
    generate_public_slug!
  end

  private

  def slug_taken?(slug)
    self.class.where(public_slug: slug).where.not(id: id).exists?
  end

  def url_options
    opts = Rails.application.config.action_mailer.default_url_options || {}
    h = { host: opts[:host] || "localhost", protocol: opts[:protocol] || "http" }
    p = opts[:port].to_i
    h[:port] = p if p.positive? && p != 80 && p != 443
    h.compact
  end
end
