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

# oncall.rb -- find and list the people currently on call for PagerDuty.
#
# This scrapes a list of on-call assignments out of the PagerDuty Dashboard.
# You can specify which rotation levels you want to find, by giving one or
# more level numbers as arguments. If no arguments are given, all levels are
# reported.
#
# PagerDuty login cookies will be stored at ~/.pagerduty-cookies, so you
# should only need to enter login credentials on the first run.

require 'rubygems'
require 'bundler/setup'

require 'nokogiri'
require 'optparse'

require "#{File.dirname(__FILE__)}/lib/pagerduty"
require "#{File.dirname(__FILE__)}/lib/campfire"

# Look for reporting options
options = {}

optparse = OptionParser.new do |opts|
  opts.banner = "Usage: oncall.rb [#]...[#] (where # is an oncall level you want shown)\n" +
                "If no level is given, all levels will be shown by default."

  options[:campfire_topic] = false
  opts.on( '-t', '--campfire-topic', 'Set the result as a topic for a Campfire room' ) do
    options[:campfire_topic] = true
  end

  opts.on( '-h', '--help', 'Display this message' ) do
    puts opts
    exit
  end
end

optparse.parse!

# Log into PagerDuty and get the Dashboard page.
pagerduty  = PagerDuty::Agent.new
escalation = PagerDuty::Escalation.new ARGV
page       = pagerduty.fetch "/dashboard"
results    = escalation.parse page.body

# Show the current on-call list.
report = results.map{|result| "#{result['label']}: #{result['person']}" }.join(", ")

if (options[:campfire_topic])
  campfire = Campfire::Bot.new
  campfire.topic report
else
  puts report
end

exit(0)
