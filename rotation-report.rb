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

INCIDENTS_PATH = '/api/beta/incidents?offset=0&limit=100&sort_by=created_on%3Adesc&status='
ALERTS_PATH    = '/reports/2011/3?filter=all&time_display=local' 
ONE_WEEK       = 60 * 60 * 24 * 7

pagerduty = PagerDuty::Agent.new

#
# Parse the on-call list.
#
escalation   = PagerDuty::Escalation.new ARGV
page         = pagerduty.fetch "/dashboard"
oncall_html  = escalation.parse page.body
target_level = oncall_html.find {|result| result['level'] == "1" }['label']

#
# Derive the on-call schedule
#
current_shift_end    = nil
current_shift_start  = nil
previous_shift_start = nil

schedule_page = pagerduty.fetch "/schedule"
schedule_data = Nokogiri::HTML.parse(schedule_page.body)

schedule_data.css("table#schedule_index div.rotation_strip").each do |policy|
  title = policy.css("div.resource_labels > a").text

  if title == target_level
    rotation = policy.css("td.rotation_properties div table tr").each do |row|
      if row.css("td")[0].text =~ /On-call now/i
        current_shift_start  = Chronic.parse(row.css("td span")[0].text)
        current_shift_end    = Chronic.parse(row.css("td span")[1].text)
        previous_shift_start = current_shift_start - ONE_WEEK
      end
    end
  end
end

#
# Parse the incident data.
#

# TODO: need to get more incident data if there are more than 100 incidents
# in the report period.  Make offset = limit for second page.
incidents_json = pagerduty.fetch INCIDENTS_PATH
incidents_data = JSON.parse(incidents_json.body)

incidents         = []
resolved_count    = 0
resolvers         = Hash.new(0)
current_triggers  = Hash.new(0)
previous_triggers = Hash.new(0)

incidents_data['incidents'].each do |incident|
  incidents << PagerDuty::Incident.new(incident)
end

incidents.each do |incident| 
  if incident.between?(current_shift_start, current_shift_end)
    current_triggers[incident.trigger_name] += 1

    if incident.resolved?
      resolved_count += 1
      resolvers[incident.resolver] += 1
    end  
  elsif incident.between?(previous_shift_start, current_shift_start)
    previous_triggers[incident.trigger_name] += 1
  end
end

#
# Parse the alert data.
#
alerts_html = pagerduty.fetch ALERTS_PATH
alerts_data = Nokogiri::HTML(alerts_html.body)

alerts             = []
current_alerts     = []
previous_alerts    = []
sms_phone_alertees = Hash.new(0)

alerts_data.css("table#monthly_report_tbl > tbody > tr").each do |row|
  alerts << PagerDuty::Alert.new(row.css("td.date").text, row.css("td.type").text, row.css("td.user").text)
end

current_alerts  = alerts.select{|alert| alert.between?(current_shift_start, current_shift_end) }
previous_alerts = alerts.select{|alert| alert.between?(previous_shift_start, current_shift_start) }

current_alerts.each do |alert|
  if alert.phone_or_sms? 
    sms_phone_alertees[alert.user] += 1
  end
end

#
# Build up the report format.
#
report = ""

# Header
report << "Rotation report for #{current_shift_start.strftime("%B %d")} - "
report << "#{current_shift_end.strftime("%B %d")}:\n"

# Incident volume
current_incidents  = current_triggers.each_value.inject {|sum, n| sum + n } 
previous_incidents = previous_triggers.each_value.inject {|sum, n| sum + n } 
incidents_change   = Report.pct_change(previous_incidents, current_incidents)

report << "  #{current_incidents} incidents"
if resolved_count != current_incidents
  report << ", #{current_incidents - resolved_count} unresolved"
end
report << " (#{incidents_change})\n\n"

# Resolutions
report << "Resolutions:\n  "
report << resolvers.sort{|a, b| b[1] <=> a[1]}.map{|name, count| "#{name}: #{count}"}.join(", ") + "\n"
report << "\n"

# Alert volume
current_sms_count       = current_alerts.count{|alert| alert.phone_or_sms? }
previous_sms_count      = previous_alerts.count{|alert| alert.phone_or_sms? }
current_late_sms_count  = current_alerts.count{|alert| alert.phone_or_sms? and alert.late_night? }
previous_late_sms_count = previous_alerts.count{|alert| alert.phone_or_sms? and alert.late_night? }

report << "SMS/Phone Alerts "
report << "(#{current_sms_count} total, "
report << "#{Report.pct_change(previous_sms_count, current_sms_count)}; "
report << "#{current_late_sms_count} late night, "
report << "#{Report.pct_change(previous_late_sms_count, current_late_sms_count)}):\n  "
report << sms_phone_alertees.sort{|a, b| b[1] <=> a[1]}.map{|name, count| "#{name}: #{count}"}.join(", ") + "\n"
report << "\n"

# Top triggers
report << "Top triggers:\n"
top_triggers = current_triggers.sort{|a, b| b[1] <=> a[1]}.map do |trigger, count| 
  trigger_change = Report.pct_change(previous_triggers[trigger], count)
  "  #{count} \'#{trigger}\' (#{trigger_change})"
end
report << top_triggers[0..4].join("\n")
report << "\n"

#
# Report output
#

# TODO: add options.
#campfire = Campfire::Bot.new
#campfire.paste report

print report


