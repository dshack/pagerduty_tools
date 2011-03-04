# pagerduty.rb -- tools for grabbing data from the PagerDuty site.
#
# PagerDuty does provide an API, but it is fairly limited. This code
# knows how to find your PagerDuty domain, log into PagerDuty, store 
# cookies for future logins, and grab pages from the site for parsing.

require 'nokogiri'
require 'mechanize'
require 'highline/import'

EMAIL_PROMPT    = "PagerDuty account email address:"
PASSWORD_PROMPT = "PagerDuty password:"
ACCOUNT_PROMPT  = "Select your PagerDuty domain:"

module PagerDuty
  class Scraper
    def initialize cookie_file
      # Works around a bug in highline, producing "input stream exhausted" errors.
      # See http://groups.google.com/group/comp.lang.ruby/browse_thread/thread/939d9f86a18e6f9e/ec1c3f1921cd66ea
      HighLine.track_eof = false

      @cookie_file = cookie_file
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
      
      if (!@email)
        @email = ask("#{EMAIL_PROMPT} ")
      end
      
      login_form.email = @email
      login_form.password = ask("#{PASSWORD_PROMPT} ") {|q| q.echo = "*"}
      
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