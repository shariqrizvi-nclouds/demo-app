require 'net/http'
require 'resolv'
require 'uri'

class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  # This endpoint is used for health checks. It should return a 200 OK when the app is up and ready to serve requests.
  def health
    render plain: "OK"
  end

  # Resolve the SRV records for the hostname in the URL
  def expand_url(url)
    uri = URI(url)
    resolver = Resolv::DNS.new()

    # if host is relative, append the service discovery name
    host = uri.host.count('.') > 0 ? uri.host : "#{uri.host}.#{ENV["_SERVICE_DISCOVERY_NAME"]}"

    # lookup the SRV record and use if found
    begin
      srv = resolver.getresource(host, Resolv::DNS::Resource::IN::SRV)
      uri.host = srv.target.to_s
      uri.port = srv.port.to_s
      logger.info "uri port is #{uri.port}"
      if uri.port == 0
        uri.port = 80
        logger.info "uri port is now #{uri.port}"
      end
    rescue => e
      logger.error e.message
      logger.error e.backtrace.join("\n")
    end

    logger.info "expanded #{url} to #{uri}"
    uri
  end

  before_action :discover_availability_zone
  before_action :code_hash

  def discover_availability_zone
    @az = ENV["AZ"]
  end

  def code_hash
    @code_hash = ENV["CODE_HASH"]
  end

  def custom_header
    response.headers['Cache-Control'] = 'max-age=86400, public'
  end
end
