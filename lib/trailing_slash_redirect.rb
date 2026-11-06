# /jobs/ and /jobs serve the same page. One 301 to the slashless URL keeps a
# single copy in search results.
# The PostHog proxy paths pass through untouched: its API uses trailing slashes.
class TrailingSlashRedirect
  PASS_THROUGH = %r{\A/(ingest|decide|ph-static)(/|\z)}

  def initialize(app)
    @app = app
  end

  def call(env)
    path = env["PATH_INFO"].to_s
    if %w[GET HEAD].include?(env["REQUEST_METHOD"]) && path.length > 1 && path.end_with?("/") && !path.match?(PASS_THROUGH)
      location = path.sub(%r{/+\z}, "")
      location = "/" if location.empty?
      query = env["QUERY_STRING"].to_s
      location += "?#{query}" unless query.empty?
      return [ 301, { "location" => location, "content-type" => "text/html" }, [] ]
    end

    @app.call(env)
  end
end
