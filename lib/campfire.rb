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

require 'uri'
require 'net/http'

CONFIG_FILE = "~/.pagerduty-campfire.yaml"
CA_FILE     = "#{File.dirname(__FILE__)}/cacert.pem"

module Campfire
  class Bot
    def initialize
      # TODO: make sure that the file is there and that all the keys are, too.
      config = YAML::load(File.open(File.expand_path(CONFIG_FILE)))
      @uri   = URI.parse config["site"]
      @room  = config["room"]
      @token = config["token"]
      @pass  = 'x'
    end

    def topic topic
      x             = Net::HTTP.new(@uri.host, @uri.port)
      x.use_ssl     = true
      x.ca_file     = File.expand_path(CA_FILE)
      x.verify_mode = OpenSSL::SSL::VERIFY_PEER

      message = "<room><topic>#{topic}</topic></room>"

      x.start do |http|
        req = Net::HTTP::Put.new "/room/#{@room}.xml"
        req['Content-Type'] = 'application/xml'
        req.basic_auth @token, @pass
        http.request(req, message)
      end
    end

    def paste message
      x             = Net::HTTP.new(@uri.host, @uri.port)
      x.use_ssl     = true
      x.ca_file     = File.expand_path(CA_FILE)
      x.verify_mode = OpenSSL::SSL::VERIFY_PEER

      message = "<message><type>PasteMessage</type><body>#{message}</body></message>"

      x.start do |http|
        req = Net::HTTP::Post.new "/room/#{@room}/speak.xml"
        req['Content-Type'] = 'application/xml'
        req.basic_auth @token, @pass
        http.request(req, message)
      end
    end
  end
end
