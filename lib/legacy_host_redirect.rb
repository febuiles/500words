# Permanently redirects requests for a retired domain (and its subdomains) to
# the canonical host, keeping the path and query string so old links survive
# a domain move.
class LegacyHostRedirect
  def initialize(app, legacy_hosts:, canonical_host:)
    @app = app
    @legacy_hosts = legacy_hosts
    @canonical_host = canonical_host
  end

  def call(env)
    request = Rack::Request.new(env)

    if legacy_host?(request.host)
      [ 301, { "location" => "https://#{@canonical_host}#{request.fullpath}", "content-type" => "text/html" }, [] ]
    else
      @app.call(env)
    end
  end

  private
    def legacy_host?(host)
      @legacy_hosts.any? { |legacy| host == legacy || host.end_with?(".#{legacy}") }
    end
end
