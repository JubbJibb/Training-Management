# frozen_string_literal: true

# Fetches course list from https://training.odds.team/courses and upserts into Course.
# The ODT site may be server-rendered or SPA; we parse HTML for links to /courses/ and card-like blocks.
class OdtsCoursesFetcherService
  SOURCE_URL = "https://training.odds.team/courses"

  class FetchError < StandardError; end

  def self.call
    new.call
  end

  def call
    html = fetch_html
    doc = Nokogiri::HTML(html)
    items = extract_courses(doc)
    upsert_courses(items)
    { count: items.size, errors: [] }
  rescue StandardError => e
    raise FetchError, "Failed to fetch or parse courses: #{e.message}"
  end

  private

  def fetch_html
    uri = URI(SOURCE_URL)
    req = Net::HTTP::Get.new(uri)
    req["User-Agent"] = "TrainingManagement/1.0 (Admin)"
    req["Accept"] = "text/html"
    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 15) { |http| http.request(req) }
    raise FetchError, "HTTP #{res.code}" unless res.is_a?(Net::HTTPSuccess)

    res.body.force_encoding(Encoding::UTF_8)
  end

  def extract_courses(doc)
    items = []

    # Strategy 1: links to /courses/slug
    doc.css('a[href*="/courses/"]').each do |a|
      href = a["href"].to_s
      next if href.include?("?") || href == "/courses" || href.end_with?("/courses")

      slug = href.sub(%r{\A/courses/}, "").sub(%r{/.*\z}, "").strip
      next if slug.blank?

      # Title: use heading inside link only, or first line; never include description text
      title = a.at_css("h1, h2, h3, h4, h5")&.text&.strip
      title = title.presence && title.length < 500 ? title : nil
      if title.blank?
        first_line = a.text.to_s.strip.lines.first.to_s.strip
        if first_line.present?
          # If too long (likely title + description in one block), take first ~100 chars at word boundary
          max_len = 100
          title = first_line.length <= max_len ? first_line : first_line[0, max_len].strip.sub(/\s+\S*\z/, "")
        end
      end
      title = slug.humanize if title.blank?

      # Prefer card container for description/capacity/duration (card may be the link itself or an ancestor)
      card = a.ancestors("article, [class*='course'], [class*='card']").first
      card = a if card.nil? && a["class"].to_s =~ /course|card/
      desc = extract_description(a, card, title)
      capacity = nil
      duration_text = nil
      if card
        text = card.text
        capacity = text.scan(/\b(\d{1,3})\s*(?:seats?|people)?\b/i).dig(0, 0)&.to_i
        duration_text = text[/(\d+(?:\.\d+)?\s*(?:Day|Days|day|days))/]
      end

      items << {
        external_id: slug,
        title: title,
        description: desc,
        capacity: capacity,
        duration_text: duration_text,
        source_url: href.start_with?("http") ? href : "https://training.odds.team#{href}"
      }
    end

    # Strategy 2: if no links found, try elements with class containing "course"
    if items.empty?
      doc.css("[class*='course']").each do |el|
        next if el.css('a[href*="/courses/"]').any?
        next if el.text.to_s.strip.length < 5

        title_el = el.at_css("h1, h2, h3, h4, [class*='title']") || el
        title = title_el.text.to_s.strip.split("\n").first.to_s.strip
        next if title.blank? || title.length < 2

        external_id = title.parameterize.presence || "course-#{items.size}"
        items << {
          external_id: external_id,
          title: title,
          description: nil,
          capacity: nil,
          duration_text: nil,
          source_url: SOURCE_URL
        }
      end
    end

    # Deduplicate by external_id (keep first)
    seen = {}
    items = items.select { |h| seen.key?(h[:external_id]) ? false : (seen[h[:external_id]] = true) }
    items
  end

  def extract_description(link_el, card_el, title)
    # 1) First <p> inside the link (common: <a><h3>Title</h3><p>Desc</p></a>)
    link_el.css("p").each do |p|
      t = p.text.to_s.strip
      return t if t.length > 15 && t != title
    end
    # 2) First element after the heading inside the link (p, div, span)
    heading = link_el.at_css("h1, h2, h3, h4, h5")
    if heading
      n = heading.next_element
      if n
        t = n.text.to_s.strip
        return t if t.length > 15 && t != title
      end
    end
    # 3) From card container: first substantial <p> or <div> with enough text
    if card_el && card_el != link_el
      card_el.css("p").each do |p|
        t = p.text.to_s.strip
        return t if t.length > 15 && t != title
      end
      card_el.css("div, span").each do |el|
        next if el.at_css("h1, h2, h3, h4, h5")
        t = el.text.to_s.strip
        return t if t.length > 30 && t.length < 2000 && t != title
      end
    end
    # 4) Any element with class containing description/desc
    [link_el, card_el].compact.each do |el|
      el.css("[class*='description'], [class*='desc']").each do |d|
        t = d.text.to_s.strip
        return t if t.length > 15 && t != title
      end
    end
    # 5) First substantial text block in link (full text minus title)
    full = link_el.text.to_s.strip
    if full.length > title.length + 30
      rest = full.sub(/\A#{Regexp.escape(title)}\s*/i, "").strip
      rest = rest.lines.first.to_s.strip if rest.include?("\n")
      return rest[0, 500].strip if rest.length > 20
    end
    nil
  end

  def upsert_courses(items)
    items.each do |attrs|
      course = Course.find_or_initialize_by(external_id: attrs[:external_id])
      course.assign_attributes(
        title: attrs[:title],
        description: attrs[:description],
        capacity: attrs[:capacity],
        duration_text: attrs[:duration_text],
        source_url: attrs[:source_url],
        synced_at: Time.current
      )
      course.save!
    end
  end
end
