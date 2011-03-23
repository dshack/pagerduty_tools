#!/usr/bin/env ruby

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

# oncall-email.rb -- Notify on-call people about shift start.
#
# Original script contributed by Jeffrey Wescott
# (https://github.com/binaryfeed). Thanks!

require 'rubygems'
require 'bundler/setup'
require 'net/smtp'

require 'optparse'

require "#{File.dirname(__FILE__)}/lib/pagerduty"

# Look for reporting options
options = {}

optparse = OptionParser.new do |opts|
  opts.banner = "Usage: oncall-email.rb\n" +
                "Send an email reminder to the on-call person (and any relevant CCs)."

  options[:smtp_server] = 'localhost'
  opts.on( '-m', '--smtp-server HOSTNAME', 'Use HOSTNAME as the SMTP server.') do |host|
    options[:smtp_server] = host
  end

  options[:subject] = '[PagerDuty] You are now on call'
  opts.on( '-s', '--subject SUBJECT', 'Use SUBJECT as the subject line of the email.') do |subject|
    options[:subject] = subject
  end

  options[:from_address] = 'nobody@example.com'
  opts.on( '-f', '--from ADDRESS', 'Use ADDERSS as the "From:" line of the email.') do |from|
    options[:from_address] = from
  end

  # REVIEW: Should this be an ARRAY option?
  options[:ccs] = []
  opts.on( '-c', '--cc EMAIL', 'Send a copy of the email to EMAIL.' ) do |cc|
    options[:ccs] << cc
  end

  options[:message_file] = nil
  opts.on( '-m', '--message-file FILENAME', 'Use contents of FILENAME as the email body.') do |filename|
    options[:message_file] = filename
  end

  opts.on( '-h', '--help', 'Display this message' ) do
    puts opts
    exit
  end
end

optparse.parse!

# Default to sending mail to the first-level assignee only, or use levels
# given as arguments.
mail_to_levels = ARGV.count > 0 ? ARGV : "1"

# Log into PagerDuty and get the Dashboard page.
pagerduty  = PagerDuty::Agent.new
escalation = PagerDuty::Escalation.new mail_to_levels

# REVIEW: don't we need one Person per level? What's this for?
person     = PagerDuty::Person.new
dashboard  = pagerduty.fetch "/dashboard"
levels     = escalation.parse dashboard.body

# Get the email address for each on-call level.
levels.each do |level|
  user = pagerduty.fetch level['person_path']
  person.parse user.body
  level['email'] = person.email
end

# REVIEW: Is the 'recips' line needed? Can Net::SMTP pull addresses from the header?
recips = options[:ccs] + (levels.map { |level| level['email'] })
to_line = levels.map{|level| "#{level['person']} <#{level['email']}>" }.join(", ")
cc_line = options[:ccs].join(", ")

header = <<HEADER_END
From: PagerDuty <#{options[:from_address]}>
To: #{to_line}
CC: #{cc_line}
Subject: #{options[:subject]}

HEADER_END

# REVIEW: Hmm...wonder if the email should be different for each person, telling
# them what level assignment they have now.

# REVIEW: Should show the full assignment list as a table.

body = <<BODY_END
Your PagerDuty on-call rotation has started. If you receive alerts about new
incidents, please acknowledge them as soon as possible if you can respond. If
not, please escalate them to the next level so they can be handled quickly.
For more information about an alert, please log into our PagerDuty account at:

    https://#{pagerduty.domain}

Thanks.
BODY_END

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

exit(0)
