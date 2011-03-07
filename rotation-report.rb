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
require 'json'
require 'date'
require "#{File.dirname(__FILE__)}/lib/pagerduty"
require "#{File.dirname(__FILE__)}/lib/campfire"

# make offset = limit for second page
INCIDENT_PATH = '/api/beta/incidents?echo=1&offset=0&limit=100&sort_by=created_on%3Adesc&status='

# Static dates for now.
# TODO: need to set these dynamically. From a rotation, maybe?
current_shift_end    = Time.xmlschema("2011-03-09T14:00:00-05:00")
current_shift_start  = Time.xmlschema("2011-03-02T14:00:00-05:00")
previous_shift_start = Time.xmlschema("2011-02-23T14:00:00-05:00")

# TODO: need to get more incident data if there are more than 100 incidents
# in the report period.
pagerduty        = PagerDuty::Scraper.new
incidents_json   = pagerduty.fetch INCIDENT_PATH
incidents_report = JSON.parse(incidents_json.body)

resolvers         = Hash.new(0)
current_triggers  = Hash.new(0)
previous_triggers = Hash.new(0)

# TODO: make these into a report object so the formatting is changable.
def pct_change old_value, new_value
  if (old_value == 0)
    return "(no occurrences last week)"
  else
    change = (((new_value.to_f - old_value.to_f) / old_value.to_f) * 100).to_i

    if (change == 0)
      return "(no change vs. last week)"

    elsif (change < 0)
      return "(#{change}% vs. last week)"

    else
      return "(+#{change}% vs. last week)"
    end
  end
end

def trigger_name incident
  event = incident['trigger_details']['event']

  if (incident['service']['name'] == "Nagios")
    return "Nagios: #{event['host']} - #{event['service']}"
    
  elsif (incident['service']['name'] == "Pingdom")
    return "Pingdom: #{event['description']}"
    
  else
    return "Unknown event"
  end  
end

# TODO: needs some extraction.
current_incidents = incidents_report['incidents'].select do |incident|
  created = Time.xmlschema(incident['created_on'])
  (current_shift_start <=> created) <= 0 and (created <=> current_shift_end) == -1  
end

current_incidents.each do |incident|
  if (incident['status'] == 'resolved')
    resolvers[incident['resolved_by']['name']] += 1
  end
  
  current_triggers[trigger_name(incident)] += 1
end

previous_incidents = incidents_report['incidents'].select do |incident|
  created = Time.xmlschema(incident['created_on'])
  (previous_shift_start <=> created) <= 0 and (created <=> current_shift_start) == -1  
end

previous_incidents.each do |incident|
  previous_triggers[trigger_name(incident)] += 1
end


report = ""
report << "Rotation report for #{current_shift_start.strftime("%B %d")} - "
report << "#{current_shift_end.strftime("%B %d")}:\n\n"

incidents_change = pct_change(previous_incidents.count, current_incidents.count)
report << "#{current_incidents.count} incidents #{incidents_change}\n\n"

# TODO: enough with the mega block calls.
report << "Resolutions:\n  "
report << resolvers.sort{|a, b| b[1] <=> a[1]}.map{|name, count| "#{name}: #{count}"}.join(", ") + "\n"
report << "\n"

report << "Top triggers:\n"
top_triggers = current_triggers.sort{|a, b| b[1] <=> a[1]}.map do |trigger, count| 
  trigger_change = pct_change(previous_triggers[trigger], count)
  "  #{count} \'#{trigger}\' #{trigger_change}"
end
report << top_triggers[0..4].join("\n")
report << "\n"

# TODO: add options.
#campfire = Campfire::Bot.new
#campfire.paste report

print report
