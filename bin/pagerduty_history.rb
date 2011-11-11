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

require 'psych'
require 'hpricot'

lib = File.expand_path(File.join(File.dirname(__FILE__), '../lib'))
$LOAD_PATH.unshift(lib) if File.directory?(lib) && !$LOAD_PATH.include?(lib)

require 'pagerduty_tools'

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
