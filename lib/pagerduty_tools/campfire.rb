# Copyright 2011 Marc Hedlund <marc@precipice.org>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# campfire.rb -- Totally stupid Campfire API client
#
# This is the simplest possible Campfire client, intended just
# to set the topic in a Campfire room, and nothing else.
#
# Adapted from https://gist.github.com/7cefe083682cdd3e4e10
#
# To make this work, add a configuration file at ~/.pagerduty-campfire.yaml
# containing the following:
#
#     site:  https://example.campfirenow.com
#     room:  99999
#     token: abababababababababababababababababababab
#
# (with the values changed to match your configuration).

require 'net/http'
require 'nokogiri'
require 'uri'
require 'yaml'

CONFIG_FILE = "~/.pagerduty-campfire.yaml"
CA_FILE     = "#{File.dirname(__FILE__)}/cacert.pem"

module Campfire
  class Bot
    def initialize
      # TODO: make sure that the file is there and that all the keys are, too.
      config = YAML.load_file(File.expand_path(CONFIG_FILE))
      @uri   = URI.parse config["site"]
      @room  = config["room"]
      @token = config["token"]
      @pass  = 'x'

      @http             = Net::HTTP.new(@uri.host, @uri.port)
      @http.use_ssl     = true
      @http.ca_file     = File.expand_path(CA_FILE)
      @http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    end

    def topic(topic)
      request = Net::HTTP::Put.new "/room/#{@room}.xml"
      message = Nokogiri::XML::Builder.new do |xml|
        xml.room {
          xml.topic topic
        }
      end
      return do_request(request, message.to_xml)
    end

    def paste(body)
      request = Net::HTTP::Post.new("/room/#{@room}/speak.xml")
      message = Nokogiri::XML::Builder.new do |xml|
        xml.message {
          xml.type_ "PasteMessage"
          xml.body body
        }
      end
      return do_request(request, message.to_xml)
    end

    private

    def do_request(request, message)
      @http.start do |connection|
        request['Content-Type'] = 'application/xml'
        request.basic_auth @token, @pass
        return connection.request(request, message)
      end
    end
  end
end
