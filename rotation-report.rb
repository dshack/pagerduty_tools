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
#
# Currently gets the data and does nothing with it yet.

require 'rubygems'
require 'bundler/setup'
require 'json'
require "#{File.dirname(__FILE__)}/lib/pagerduty"

# make offset = limit for second page
INCIDENT_PATH = '/api/beta/incidents?echo=3&offset=0&limit=10&sort_by=created_on%3Adesc&status='

pagerduty = PagerDuty::Scraper.new
incidents_json = pagerduty.fetch INCIDENT_PATH

incidents_report = JSON.parse(incidents_json.body)

resolvers = {}
events    = {}

pp incidents_report['incidents']
