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
require 'optparse'
require 'nokogiri'
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
pagerduty = PagerDuty::Scraper.new
page      = pagerduty.fetch "/dashboard"

# Scrape out the on-call list from the Dashboard HTML.
dashboard = Nokogiri::HTML(page.body)
oncall    = dashboard.css("div.whois_oncall").first
results   = []

oncall.css("div").each do |div|  
  level_text = div.css("span > strong").text
  level_text =~ /Level (\d+)\:/
  level = $1
  
  # PagerDuty sometimes adds a comment saying what the rotation is called
  # for this level. If it's there, use it, or fall back to a generic label.
  label_text = div.xpath("span/comment()").text
  label_text =~ /\(<[^>]+>(.+) on-call<\/a>\)/
  label = $1 || "Level #{level}"
  
  person = div.css("span > a").text
  
  if (ARGV.length == 0 or ARGV.include?(level))
    results << "#{label}: #{person}"
  end
end

# Show the current on-call list.
report = results.join(", ")

if (options[:campfire_topic])
  campfire = Campfire::Topic.new
  campfire.topic report
else
  puts report
end

exit(0)
