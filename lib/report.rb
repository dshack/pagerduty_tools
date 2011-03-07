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

# report.rb - basic tool for building up reports.

require 'chronic'

module Report
  def self.pct_change old_value, new_value
    if (old_value == 0)
      return "no occurrences last week"
    else
      change = (((new_value.to_f - old_value.to_f) / old_value.to_f) * 100).to_i

      if (change == 0)
        return "no change vs. last week"

      elsif (change < 0)
        return "#{change}% vs. last week"

      else
        return "+#{change}% vs. last week"
      end
    end
  end

  class Incident
    def self.trigger_name incident
      event = incident['trigger_details']['event']

      if (incident['service']['name'] == "Nagios")
        return "Nagios: #{event['host']} - #{event['service']}"
    
      elsif (incident['service']['name'] == "Pingdom")
        return "Pingdom: #{event['description']}"
    
      else
        return "Unknown event"
      end  
    end
  end

  class Alert
    attr_accessor(:time, :type, :user)

    def initialize time, type, user
      @time = Chronic.parse(time)
      @type = type
      @user = user
    end

    def late_night?
      # We don't like waking people up. Assume a risk of that between 
      # 10p and 8a localtime.
      (time.hour < 8 or time.hour >= 22)
    end
    
    def phone_or_sms?
      type == "Phone" or type == "SMS"
    end
    
    def email?
      type == "Email"
    end
  end
end
