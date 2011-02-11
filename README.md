## pagerduty-report ##

This is a quick hack to spit out a report of notifications per day
from a PagerDuty HTML report page.  Use it to see how often your
team is getting paged in a month.

### Usage ###

First, log into PagerDuty, then go to the `Reports` tab. Click on 
`View report` for the month you want to report on. If you want, change
the select menu to choose the kind of alerts you want to report on.
Save the HTML of the page you're looking at - let's say you call
it `January2011.html`.

Then do this:

    ./pagerduty-report.html January2011.html

You'll get a report that looks like this:

    Jan 1  6
    Jan 2  2
    Jan 3  3
    Jan 4  3
    Jan 5  2
    Jan 6  7
    Jan 7  11
    ...

This is tab-separated output, so you could then import it into Excel 
or whatever else.

### Limitations ###

Dates with no alerts will be omitted from the list. (Would be nice to
zero-fill.)

No comments, error checking, HTTP support, etc.

