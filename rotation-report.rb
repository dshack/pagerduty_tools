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

# rotation-report.rb -- automatically generate an end-of-shift report.
#
# Gathers information about incidents during a PagerDuty rotation, and
# reports on them.

require 'rubygems'
require 'bundler/setup'

require 'date'
require 'json'
require 'nokogiri'

require "#{File.dirname(__FILE__)}/lib/campfire"
require "#{File.dirname(__FILE__)}/lib/pagerduty"
require "#{File.dirname(__FILE__)}/lib/report"

INCIDENTS_PATH = '/api/beta/incidents?echo=1&offset=0&limit=100&sort_by=created_on%3Adesc&status='
ALERTS_PATH    = '/reports/2011/3?filter=all&time_display=local' 

# Static dates for now.
# TODO: need to set these dynamically. From a rotation, maybe?
current_shift_end    = Time.xmlschema("2011-03-09T14:00:00-05:00")
current_shift_start  = Time.xmlschema("2011-03-02T14:00:00-05:00")
previous_shift_start = Time.xmlschema("2011-02-23T14:00:00-05:00")

pagerduty = PagerDuty::Agent.new

#
# Parse the incident data.
#

# TODO: need to get more incident data if there are more than 100 incidents
# in the report period.  Make offset = limit for second page.
incidents_json = pagerduty.fetch INCIDENTS_PATH
incidents_data = JSON.parse(incidents_json.body)

resolved_count    = 0
resolvers         = Hash.new(0)
current_triggers  = Hash.new(0)
previous_triggers = Hash.new(0)

# TODO: needs some extraction and cleanup.
current_incidents = incidents_data['incidents'].select do |incident|
  created = Time.xmlschema(incident['created_on'])
  (current_shift_start <=> created) <= 0 and (created <=> current_shift_end) == -1  
end

current_incidents.each do |incident|
  if incident['status'] == 'resolved'
    resolved_count += 1
    resolvers[incident['resolved_by']['name']] += 1
  end
  
  current_triggers[Report::Incident.trigger_name(incident)] += 1
end

previous_incidents = incidents_data['incidents'].select do |incident|
  created = Time.xmlschema(incident['created_on'])
  (previous_shift_start <=> created) <= 0 and (created <=> current_shift_start) == -1  
end

previous_incidents.each do |incident|
  previous_triggers[Report::Incident.trigger_name(incident)] += 1
end

#
# Parse the alert data.
#
alerts_html = pagerduty.fetch ALERTS_PATH
alerts_data = Nokogiri::HTML(alerts_html.body)

current_alerts     = []
previous_alerts    = []
sms_phone_alertees = Hash.new(0)

alerts_data.css("table#monthly_report_tbl > tbody > tr").each do |row|
  alert = Report::Alert.new(row.css("td.date").text, row.css("td.type").text, row.css("td.user").text)
  
  if (current_shift_start <=> alert.time) <= 0 and (alert.time <=> current_shift_end) == -1
    current_alerts << alert
    
    if alert.phone_or_sms?
      sms_phone_alertees[alert.user] += 1
    end
  elsif (previous_shift_start <=> alert.time) <= 0 and (alert.time <=> current_shift_start) == -1
    previous_alerts << alert
  end
end

#
# Print out the report.
#
report = ""
report << "Rotation report for #{current_shift_start.strftime("%B %d")} - "
report << "#{current_shift_end.strftime("%B %d")}:\n"

incidents_change = Report.pct_change(previous_incidents.count, current_incidents.count)
report << "  #{current_incidents.count} incidents"

if resolved_count != current_incidents.count
  report << ", #{current_incidents.count - resolved_count} unresolved"
end

report << " (#{incidents_change})\n\n"

# TODO: enough with the mega block calls, perldork.
report << "Resolutions:\n  "
report << resolvers.sort{|a, b| b[1] <=> a[1]}.map{|name, count| "#{name}: #{count}"}.join(", ") + "\n"
report << "\n"

current_sms_count  = current_alerts.count{|alert| alert.phone_or_sms? }
previous_sms_count = previous_alerts.count{|alert| alert.phone_or_sms? }
current_late_sms_count  = current_alerts.count{|alert| alert.phone_or_sms? and alert.late_night? }
previous_late_sms_count = previous_alerts.count{|alert| alert.phone_or_sms? and alert.late_night? }

report << "SMS/Phone Alerts "
report << "(#{current_sms_count} total, "
report << "#{Report.pct_change(previous_sms_count, current_sms_count)}; "
report << "#{current_late_sms_count} late night, "
report << "#{Report.pct_change(previous_late_sms_count, current_late_sms_count)}):\n  "
report << sms_phone_alertees.sort{|a, b| b[1] <=> a[1]}.map{|name, count| "#{name}: #{count}"}.join(", ") + "\n"
report << "\n"

report << "Top triggers:\n"
top_triggers = current_triggers.sort{|a, b| b[1] <=> a[1]}.map do |trigger, count| 
  trigger_change = Report.pct_change(previous_triggers[trigger], count)
  "  #{count} \'#{trigger}\' (#{trigger_change})"
end
report << top_triggers[0..4].join("\n")
report << "\n"

# TODO: add options.
#campfire = Campfire::Bot.new
#campfire.paste report

print report


