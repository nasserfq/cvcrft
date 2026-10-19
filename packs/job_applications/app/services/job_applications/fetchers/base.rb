require "net/http"

module JobApplications
  module Fetchers
    # Reads one employer's public job-board feed. Subclasses override #call and
    # use only #http_get / #http_post, so tests stub those.
    class Base
      Posting = Struct.new(:external_id, :title, :location, :country, :url, :apply_url, :description, :posted_at, keyword_init: true)

      MAX_PAGES = 10
      MAX_DESCRIPTION = 20_000

      attr_reader :employer

      def initialize(employer)
        @employer = employer
      end

      # Every page of the feed, Gulf postings only.
      def call
        raise NotImplementedError
      end

      private

      # Keeps a posting only when it is in the Gulf, and stamps its country.
      def gulf(postings)
        postings.filter_map do |posting|
          next if posting.external_id.blank? || posting.title.blank? || posting.url.blank?

          code = GulfLocation.for_posting(location: posting.location, country: posting.country, fallback: employer.country)
          next unless code

          posting.country = code
          posting.apply_url = posting.apply_url.presence || posting.url
          posting
        end
      end

      def http_get(url)
        request(Net::HTTP::Get.new(URI(url)))
      end

      def http_post(url, body)
        req = Net::HTTP::Post.new(URI(url))
        req["Content-Type"] = "application/json"
        req.body = body.to_json
        request(req)
      end

      def request(req)
        uri = req.uri
        req["Accept"] = "application/json"
        req["User-Agent"] = "SeeraJobs/1.0 (+https://cvcrft.com)"
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 20) do |http|
          http.request(req)
        end
        raise FetchError, "#{employer.ats}/#{employer.identifier}: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        JSON.parse(response.body)
      rescue JSON::ParserError => e
        raise FetchError, "#{employer.ats}/#{employer.identifier}: bad JSON (#{e.message.first(80)})"
      end

      def html_to_text(html)
        return nil if html.blank?

        Nokogiri::HTML.fragment(html.to_s).text.squish.first(MAX_DESCRIPTION)
      end

      def plain(text)
        text.to_s.squish.first(MAX_DESCRIPTION).presence
      end

      def time(value)
        case value
        when Integer then Time.zone.at(value / 1000.0)
        when String then Time.zone.parse(value)
        end
      rescue ArgumentError
        nil
      end
    end
  end
end
