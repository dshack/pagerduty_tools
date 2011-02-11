#!/usr/bin/env ruby

require 'rubygems'
require 'hpricot'

if (ARGV.length == 0)
  puts "Usage: pagerduty-report.rb [report-html-file]"
  exit(1)
end

doc = open(ARGV[0]) { |f| Hpricot(f) }

counts_by_day = []

(doc/"table#monthly_report_tbl/tbody/tr").each do |row|
  date = (row/"td.date").inner_html.split(' at ')[0]
  if (counts_by_day[-1] && counts_by_day[-1]['date'] == date)
    counts_by_day[-1]['count'] += 1
  else
    counts_by_day << { 'date' => date, 'count' => 1}
  end
end

counts_by_day.each do |day|
  puts "#{day['date']}\t#{day['count']}"
end
