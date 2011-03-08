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
  class Item
    attr_accessor(:time)

    def initialize time
      @time = time
    end

    def between?(start_time, end_time)
      # `time` equals or is after `start_time`, and is before `end_time`
      (start_time <=> time) <= 0 and (time <=> end_time) == -1
    end

    def off_hours?
      # Outside normal work hours - 6p to 8a (localtime)
      time.hour >= 18 or graveyard?
    end

    def graveyard?
      # Worst of the worst - midnight to 8am (localtime)
      time.hour < 8
    end
  end

  class Summary
    def initialize current_start, current_end, previous_start, previous_end
      @current_start  = current_start
      @current_end    = current_end
      @previous_start = previous_start
      @previous_end   = previous_end
      @items          = []
    end

    def <<(item)
      @items << item
    end

    def current_items
      _select_between?(@current_start, @current_end)
    end

    def previous_items
      _select_between?(@previous_start, @previous_end)
    end

    def _select_between? a, b
      @items.select {|item| item.between?(a, b) }
    end

    def current_count(&selector)
      _count_from(current_items, &selector)
    end

    def previous_count(&selector)
      _count_from(previous_items, &selector)
    end

    def _count_from collection
      if block_given?
        return collection.count {|item| yield item }
      else
        return collection.count
      end
    end

    def current_summary(&selector)
      _summarize(current_items, &selector)
    end

    def previous_summary(&selector)
      _summarize(previous_items, &selector)
    end

    def _summarize collection
      summary = Hash.new(0)

      collection.each do |item|
        yield item, summary
      end

      return summary.sort{|a, b| b[1] <=> a[1] }
    end

    def pct_change(&selector)
      old_value = previous_count(&selector)
      new_value = current_count(&selector)
      Report.pct_change old_value, new_value
    end
  end

  def self.pct_change old_value, new_value
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
end
