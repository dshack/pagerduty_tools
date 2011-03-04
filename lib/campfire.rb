# campfire.rb -- Totally stupid Campfire API client
#
# This is the simplest possible Campfire client, intended just
# to set the topic in a Campfire room, and nothing else.
#
# Adapted from https://gist.github.com/7cefe083682cdd3e4e10

require 'uri'
require 'net/http'

module Campfire
  class Topic
    attr_reader :uri, :token, :pass

    def initialize uri, room, token, pass = 'x'
      @uri   = URI.parse uri
      @room  = room
      @token = token
      @pass  = pass
    end

    def topic topic
      x             = Net::HTTP.new(uri.host, uri.port)
      x.use_ssl     = true
      x.verify_mode = OpenSSL::SSL::VERIFY_NONE

      message = "<room><topic>#{topic}</topic></room>"

      x.start do |http|
        req = Net::HTTP::Put.new "/room/#{@room}.xml"
        req['Content-Type'] = 'application/xml'
        req.basic_auth token, pass
        http.request(req, message)
      end
    end
  end
end
