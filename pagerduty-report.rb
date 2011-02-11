#!/usr/bin/env ruby

require 'rubygems'
require 'hpricot'

if (ARGV.length == 0)
  puts "Usage: pagerduty-report.rb [report-html-file]"
  exit(1)
end

doc = open(ARGV[0]) { |f| Hpricot(f) }

dates = []
counts = {}
last_date = ""
count = 0

(doc/"table#monthly_report_tbl/tbody/tr").each do |row|
  date = (row/"td.date").inner_html.split(' at ')[0]
  if (date == last_date)
    count = count + 1
  else
    if (last_date != "")
      dates << last_date
      counts[last_date] = count
    end
    last_date = date
    count = 1
  end
end

dates.each do |date|
  puts "#{date}\t#{counts[date]}"
end
