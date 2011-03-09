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
require 'optparse'

require "#{File.dirname(__FILE__)}/lib/campfire"
require "#{File.dirname(__FILE__)}/lib/pagerduty"
require "#{File.dirname(__FILE__)}/lib/report"

ONE_DAY  = 60 * 60 * 24
ONE_WEEK = ONE_DAY * 7

#
# Look for reporting options
#
options = {}

optparse = OptionParser.new do |opts|
  opts.banner = "Usage: rotation-report.rb [-a COUNT] [-c]"

  options[:rotations_ago] = 0
  opts.on('-a', '--rotations-ago COUNT', Integer,
          "Rotations back from current to report on (defaults to current)") do |rotations_ago|
    options[:rotations_ago] = rotations_ago
  end

  options[:campfire_message] = false
  opts.on('-c', '--campfire-message', "Paste the results as message in a Campfire room") do
    options[:campfire_message] = true
  end

  opts.on('-h', '--help', 'Display this message') do
    puts opts
    exit
  end
end

optparse.parse!

#
# Parse the on-call list.
#
pagerduty  = PagerDuty::Agent.new
escalation = PagerDuty::Escalation.new
dashboard  = pagerduty.fetch "/dashboard"

escalation.parse dashboard.body
target_level = escalation.label_for_level "1"

unless target_level
  puts "Couldn't find the top-level rotation on the Dashboard."
  exit(1)
end

#
# Derive the on-call schedule
#
current_start  = nil
current_end    = nil
previous_start = nil
previous_end   = nil

schedule_page = pagerduty.fetch "/schedule"
schedule_data = Nokogiri::HTML.parse schedule_page.body

schedule_data.css("table#schedule_index div.rotation_strip").each do |policy|
  title = policy.css("div.resource_labels > a").text

  if title == target_level
    rotation = policy.css("td.rotation_properties div table tr").each do |row|
      if row.css("td")[0].text =~ /On-call now/i
        period_offset = ONE_WEEK * options[:rotations_ago]
        current_start = Chronic.parse(row.css("td span")[0].text) - period_offset
        current_end   = Chronic.parse(row.css("td span")[1].text) - period_offset

        # Shifts are either one day or one week (currently, at least).
        # For a week-long shift, we want the previous full week. For a day
        # shift, we want the same day of the week, one week ago. Either
        # way, we want the start and end to be a full week before the current
        # start and end.
        previous_start = current_start - ONE_WEEK
        previous_end   = current_end   - ONE_WEEK
      end
    end
  end
end

unless current_start and current_end and previous_start and previous_end
  puts "Couldn't find the rotation schedule for level #{target_level}."
  exit(2)
end

#
# Parse the incident data.
#

incidents = Report::Summary.new current_start, current_end, previous_start, previous_end

# Use a method definition to let us return out of the while loop and block.
# REVIEW: this is a little heavy-handed; there's probably a better approach.
def collect_incidents pagerduty, incidents
  offset = 0

  while offset < 1000 # just a safety killswitch
    incidents_path = "/api/beta/incidents?offset=#{offset}&limit=100&sort_by=created_on%3Adesc&status="
    incidents_json = pagerduty.fetch incidents_path
    incidents_data = JSON.parse(incidents_json.body)

    incidents_data['incidents'].each do |incident_data|
      incident = PagerDuty::Incident.new(incident_data)
      if incident.between?(incidents.previous_start, incidents.current_end)
        incidents << incident
      elsif (incident.time <=> incidents.previous_start) == -1
        # This incident is before the time frame we care about, so stop
        # parsing from the incident list (which is sorted by date descending).
        return
      end
    end

    offset += 100
    sleep(1) # for API politeness
  end
end

collect_incidents(pagerduty, incidents)
unresolved = incidents.current_count {|incident| !incident.resolved? }
resolvers  = incidents.current_summary {|incident, summary| summary[incident.resolver] += 1 if incident.resolved? }
triggers   = incidents.current_summary {|incident, summary| summary[incident.trigger_name] += 1 }

#
# Parse the alert data.
#
alerts = Report::Summary.new current_start, current_end, previous_start, previous_end

def collect_alerts pagerduty, alerts, year, month
  alerts_path = "/reports/#{year}/#{month}?filter=all&time_display=local"
  alerts_html = pagerduty.fetch alerts_path
  alerts_data = Nokogiri::HTML(alerts_html.body)

  alerts_data.css("table#monthly_report_tbl > tbody > tr").each do |row|
    alert = PagerDuty::Alert.new(row.css("td.date").text, row.css("td.type").text, row.css("td.user").text)
    if alert.between?(alerts.previous_start, alerts.current_end)
      alerts << alert
    end
  end
end

collect_alerts(pagerduty, alerts, current_end.year, current_end.month)

# This assumes that the alerts span at most two consecutive months,
# between the previous period start and the current period end.
if current_end.year != previous_start.year or current_end.month != previous_start.month
  collect_alerts(pagerduty, alerts, previous_start.year, previous_start.month)
end

sms_or_phone = alerts.current_summary {|alert, summary| summary[alert.user] += 1 if alert.phone_or_sms? }
email        = alerts.current_summary {|alert, summary| summary[alert.user] += 1 if alert.email? }

#
# Build up the report format.
#

# Header
report =  "Rotation report for #{current_start.strftime("%B %d")} - "
report << "#{current_end.strftime("%B %d")}:\n"

# Incident volume
report << "  #{incidents.current_count} incidents"
report << ", #{unresolved} unresolved" if unresolved > 0
report << " (#{incidents.pct_change})\n\n"

# Resolutions
report << "Resolutions:\n  "
report << resolvers.map {|name, count| "#{name}: #{count}" }.join(", ") + "\n"
report << "\n"

# Alert volume
report << "SMS/Phone Alerts "
report << "(#{alerts.current_count {|alert| alert.phone_or_sms? }} total, "
report << "#{alerts.pct_change {|alert| alert.phone_or_sms? }}; "
report << "#{alerts.current_count {|alert| alert.phone_or_sms? and alert.graveyard? }} after midnight, "
report << "#{alerts.pct_change {|alert| alert.phone_or_sms? and alert.graveyard? }}):\n  "
report << sms_or_phone.map {|name, count| "#{name}: #{count}"}.join(", ") + "\n"
report << "\n"

# Top triggers
report << "Top triggers:\n"
trigger_report = triggers.map do |trigger, count| 
  trigger_change = Report.pct_change(incidents.previous_count {|incident| incident.trigger_name == trigger }, count)
  "  #{count} \'#{trigger}\' (#{trigger_change})"
end
report << trigger_report.take(5).join("\n")
report << "\n"

#
# Report output
#
if options[:campfire_message]
  campfire = Campfire::Bot.new
  campfire.paste report
else
  print report
end

