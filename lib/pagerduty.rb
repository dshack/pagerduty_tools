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

# pagerduty.rb -- tools for working with data from the PagerDuty site.
#
# PagerDuty does provide an API, but it is fairly limited. This code is
# intended to make it look like the API was more extensive and could
# provide some better reporting options.

require 'nokogiri'
require 'mechanize'
require 'highline/import'

require "#{File.dirname(__FILE__)}/report"

COOKIE_FILE     = "~/.pagerduty-cookies"
EMAIL_PROMPT    = "PagerDuty account email address: "
PASSWORD_PROMPT = "PagerDuty password: "
ACCOUNT_PROMPT  = "Select your PagerDuty domain: "

module PagerDuty
  class Agent
    attr_accessor :domain

    def initialize
      # Works around a bug in highline, producing "input stream exhausted" errors. See:
      # http://groups.google.com/group/comp.lang.ruby/browse_thread/thread/939d9f86a18e6f9e/ec1c3f1921cd66ea
      HighLine.track_eof = false

      @cookie_file = File.expand_path(COOKIE_FILE)
      @agent       = Mechanize.new

      load_cookies
      find_domain
    end

    def fetch(path)
      uri  = URI.parse "https://#{@domain}#{path}"
      page = @agent.get uri

      # If we asked for a page and didn't get it, we probably have to log in.
      # TODO: check for non-login pages, like server error pages.
      while page.uri.path != uri.path
        page = login page
      end

      if @cookie_file
        @agent.cookie_jar.save_as(@cookie_file)
        File.chmod(0600, @cookie_file)
      end

      return page
    end

    private

    def load_cookies
      if File.exist?(@cookie_file)
        @agent.cookie_jar.load(@cookie_file)

        # Try to find the user's PagerDuty domain from their auth_token cookie.
        token = @agent.cookie_jar.to_a.select { |cookie| cookie.name == "auth_token" }.first

        if token
          @domain = token.domain
        end
      end
    end

    def find_domain
      return if @domain

      @email = ask(EMAIL_PROMPT)

      accounts_search_page = @agent.get URI.parse "http://app.pagerduty.com/accounts/search"
      accounts_search_form = accounts_search_page.form_with(:action => "/accounts/search_results")
      accounts_search_form.email = @email

      search_results_page = accounts_search_form.submit
      search_results = Nokogiri::HTML(search_results_page.body)
      account_list = search_results.css("ul.accounts_list")
      domains = account_list.css("a").map { |account| URI.parse(account["href"]).host }

      if domains.count == 0
        puts "No PagerDuty accounts found for that address."
      elsif domains.count == 1
        @domain = domains.first
      else
        say(ACCOUNT_PROMPT)
        @domain = choose(*domains)
      end
    end

    def login(page)
      login_form = page.form_with(:action => "/session")
      @email   ||= ask(EMAIL_PROMPT)

      login_form.email    = @email
      login_form.password = ask(PASSWORD_PROMPT) {|q| q.echo = "*" }

      return login_form.submit
    end
  end

  class Escalation
    def initialize(levels=nil, policy = nil)
      @levels = levels
      @policy = policy
    end

    def parse(dashboard_body)
      # Scrape out the on-call list from the Dashboard HTML.
      policies = Nokogiri::HTML(dashboard_body).css("div.whois_oncall")

      oncall = if @policy
                 policies.detect do |policy|
                   policy.css('h4 a').text == @policy
                 end
               else
                 policies.first
               end

      @results = []

      oncall.css("div").each do |div|
        level_text = div.css("span > strong").text
        level_text =~ /Level (\d+)\:/
        level = $1

        # PagerDuty sometimes adds a comment saying what the rotation is called
        # for this level. If it's there, use it, or fall back to a generic label.
        label_text = div.xpath("span/comment()").text
        label = label_text[/\(<[^>]+>(.+) on-call<\/a>\)/, 1] || "Level #{level}"

        person = div.css("span > a")

        start_time, end_time = div.css("span.time").text.split(" - ").map {|text| text.strip }

        if @levels == nil or @levels.length == 0 or @levels.include?(level)
          @results << {
                        'level' => level,
                        'label' => label,
                        'person' => person.text,
                        'person_path' => person.first['href'],
                        'start_time' => start_time,
                        'end_time' => end_time
                      }
        end
      end

      return @results
    end

    def label_for_level(level)
      @results.find {|result| result['level'] == level }['label']
    end

    def label_for_person(person)
      @results.find {|result| result['person'] == person }['label']
    end

    def level_for_person(person)
      @results.find {|result| result['person'] == person }['level']
    end
  end

  class Alert < Report::Item
    attr_accessor :type, :user

    def initialize(time, type, user)
      # This charming little chunk works around an apparent bug in Chronic:
      # if the parsed month is the same as the current month, :context =>
      # :past will fail to set the month correctly.  (Looks like
      # 'if @now.month > target_month' on line 28 of
      # chronic-0.3.0/lib/chronic/repeaters/repeater_month_name.rb
      # should be 'if @now.month >= target_month'.) Anyway, there, I
      # fixed it.
      if time.start_with?(Time.now.strftime("%b"))
        super(Chronic.parse(time))
      else
        super(Chronic.parse(time, :context => :past))
      end
      @type = type
      @user = user
    end

    def phone_or_sms?
      type == "Phone" or type == "SMS"
    end

    def email?
      type == "Email"
    end
  end

  class Incident < Report::Item
    attr_accessor :status, :resolver, :service, :trigger, :event

    def initialize(incident)
      super(Time.xmlschema(incident['created_on']))
      @status  = incident['status']
      @service = incident['service']['name']
      @trigger = incident['trigger_details']
      @event   = incident['trigger_details']['event']

      if status == 'resolved'
        if incident['resolved_by'].nil? # nil resolvers are automatic, e.g. Nagios
          @resolver = "[Automatic]"
        else
          @resolver = incident['resolved_by']['name']
        end
      end
    end

    def resolved?
      status == 'resolved'
    end

    def trigger_name
      if trigger['type'] == 'nagios_trigger'
        return "#{service}: #{event['host']} - #{event['service']}"
      else
        return "#{service}: #{event['description']}"
      end
    end
  end

  class Person
    attr_accessor :email
    
    def parse page_body
      user = Nokogiri::HTML(page_body).css("div#user_profile").first
      div = user.css("div").first
      @email = div.css("td > a").text
    end
  end
end
