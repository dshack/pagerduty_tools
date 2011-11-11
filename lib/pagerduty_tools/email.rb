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

# email.rb -- Basic email agent
#
# Original script contributed by Jeffrey Wescott
# (https://github.com/binaryfeed). Thanks!

require 'net/smtp'

CONFIG_FILE = "~/.pagerduty-email.yaml"

module PagerDuty
  class Email
    def initialize
      # REVIEW: Is the 'recips' line needed? Can Net::SMTP pull addresses from the header?
      recips = options[:ccs] + (levels.map { |level| level['email'] })
      to_line = levels.map{|level| "#{level['person']} <#{level['email']}>" }.join(", ")
      cc_line = options[:ccs].join(", ")

      if options[:message_file] != nil
        body = ""
        File.open(options[:message_file], "r") do |file|
          file.each_line do |line|
            body += line
          end
        end
      end

      Net::SMTP.start(options[:smtp_server]) do |smtp|
        smtp.send_message header + body, options[:from_address], recips
      end
    end
  end
end
