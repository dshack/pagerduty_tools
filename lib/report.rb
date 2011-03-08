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
  def self.pct_change(old_value, new_value)
    if old_value == 0
      return "no occurrences last week"
    else
      change = (((new_value.to_f - old_value.to_f) / old_value.to_f) * 100).to_i

      if change == 0
        return "no change vs. last week"

      elsif change < 0
        return "#{change}% vs. last week"

      else
        return "+#{change}% vs. last week"
      end
    end
  end
  
  def self.sort_by_values_desc(hash)
    
  end
end
