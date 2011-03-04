#!/usr/bin/env ruby

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
require 'nokogiri'

require "lib/pagerduty.rb"

if (ARGV.include?("--help") or ARGV.include?("-h"))
  puts "Usage: oncall.rb [#]...[#] (where # is an oncall level you want reported, optional)"
  puts "If level is omitted, all levels will be shown."
  puts "Example: 'oncall.rb 1 2' will print the current person on-call for levels 1 and 2."
  exit(0)
end

dashboard_path = "/dashboard"
cookie_file    = File.expand_path("~/.pagerduty-cookies")
pagerduty      = PagerDuty::Scraper.new cookie_file
page           = pagerduty.fetch dashboard_path

# Now, we should have the Dashboard HTML.  Pull out the on-call people requested.
doc = Nokogiri::HTML(page.body)
oncall = doc.css("div.whois_oncall").first
results = []

oncall.css("div").each do |div|  
  level_text = div.css("span > strong").text
  level_text =~ /Level (\d+)\:/
  level = $1
  
  # PagerDuty sometimes adds a comment saying what the rotation is called
  # for this level. If it's there, use it, but otherwise use a generic 
  # label ("Level 2").
  label_text = div.xpath("span/comment()").text
  label_text =~ /\(<[^>]+>(.+) on-call<\/a>\)/
  label = $1 || "Level #{level}"
  
  person = div.css("span > a").text
  
  if (ARGV.length == 0 or ARGV.include?(level)):
    results << "#{label}: #{person}"
  end
end

puts results.join(", ")
