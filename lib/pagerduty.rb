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

# pagerduty.rb -- tools for grabbing data from the PagerDuty site.
#
# PagerDuty does provide an API, but it is fairly limited. This code
# knows how to find your PagerDuty domain, log into PagerDuty, store 
# cookies for future logins, and grab pages from the site for parsing.

require 'nokogiri'
require 'mechanize'
require 'highline/import'

COOKIE_FILE     = "~/.pagerduty-cookies"
EMAIL_PROMPT    = "PagerDuty account email address:"
PASSWORD_PROMPT = "PagerDuty password:"
ACCOUNT_PROMPT  = "Select your PagerDuty domain:"

module PagerDuty
  class Agent
    def initialize
      # Works around a bug in highline, producing "input stream exhausted" errors.
      # See http://groups.google.com/group/comp.lang.ruby/browse_thread/thread/939d9f86a18e6f9e/ec1c3f1921cd66ea
      HighLine.track_eof = false

      @cookie_file = File.expand_path(COOKIE_FILE)
      @agent       = Mechanize.new
      
      load_cookies
      find_domain      
    end

    def load_cookies
      if (File.exist?(@cookie_file))
        @agent.cookie_jar.load(@cookie_file)
        
        # Try to find the user's PagerDuty domain from their auth_token cookie.
        token = @agent.cookie_jar.to_a.select { |cookie| cookie.name == "auth_token" }.first
        
        if (token)
          @domain = token.domain
        end
      end
    end
    
    def find_domain
      if (!@domain)
        @email = ask("#{EMAIL_PROMPT} ")
        
        accounts_search_page = @agent.get URI.parse "http://app.pagerduty.com/accounts/search"
        account_form = accounts_search_page.form_with(:action => "/accounts/search_results")
        account_form.email = @email
        
        search_results_page = account_form.submit
        search_results = Nokogiri::HTML(search_results_page.body)
        account_list = search_results.css("ul.accounts_list")
        domains = account_list.css("a").map { |account| URI.parse(account["href"]).host }
        
        if (domains.count == 0)
          puts "No PagerDuty accounts found for that address."
          exit(1)
        elsif (domains.count == 1)
          @domain = domains.first
        else
          say(ACCOUNT_PROMPT)
          @domain = choose(*domains)
        end
      end
    end
    
    def login page
      login_form = page.form_with(:action => "/session")
      
      @email ||= ask("#{EMAIL_PROMPT} ")
      login_form.email = @email
      login_form.password = ask("#{PASSWORD_PROMPT} ") {|q| q.echo = "*" }
      
      return login_form.submit
    end
    
    def fetch path
      uri  = URI.parse "https://#{@domain}#{path}"
      page = @agent.get uri
      
      # If we asked for a page and didn't get it, we probably have to log in.
      # TODO: check for non-login pages, like server error pages.
      while (page.uri != uri)
        page = login page
      end

      if @cookie_file
        @agent.cookie_jar.save_as(@cookie_file)
        File.chmod(0600, @cookie_file)
      end      
      
      return page
    end
  end
end