# pagerduty-tools #

Tools to work around limitations in the [PagerDuty](http://www.pagerduty.com)
[API](http://www.pagerduty.com/docs/api/api-documentation). As an example use,
here are two Campfire updates from these scripts that set the room topic to
the current on-call rotation, and then report on the incidents and alerts from
the previous rotation:

![campfire example](https://github.com/precipice/pagerduty_tools/raw/master/images/campfire-example.png)

## IMPORTANT: Status ##

Several changes to PagerDuty's site have broken parts of these tools. I'm 
currently working on repairing them and on making the tools into a gem. Status
as of this writing is that the `bin/pagerduty_oncall.rb` script is working and
the others are not.  The gem builds and installs.

## Installing ##

Ruby 1.8.7 or later is required.

First, clone the GitHub repo:

    $ git clone git://github.com/precipice/pagerduty-tools.git

If you don't already have [Bundler](http://gembundler.com/) installed, do that
now:

    $ gem install bundler

Then install required gems via Bundler:

    $ bundle install

The scripts log into the PagerDuty site when first run. Your email address
will be used to find associated PagerDuty accounts, and you can choose the
account you want to report on. After the first run, a login cookie is kept in
`~/.pagerduty-cookies` to allow future runs to be automatic (e.g., from cron).

## Campfire Support ##

If you would like to have PagerDuty reports sent to your
[Campfire](http://www.campfirenow.com) room, create a "PagerDuty" user in your
Campfire account, and then add a configuration file at
`~/.pagerduty-campfire.yaml` containing the following:

    site:  https://example.campfirenow.com
    room:  99999
    token: abababababababababababababababababababab

with the values changed to match your configuration. I'd recommend running:

    $ chmod 0600 ~/.pagerduty-campfire.yaml

after creating the file. See the documentation for each script for how to send
output to Campfire.

Tip: you can use [PagerDuty's Twitter icon](https://twitter.com/pagerduty) as
a profile icon for your Campfire PagerDuty account. This isn't necessary, but
it makes the PagerDuty message more recognizable and nicer.

## Limitations ##

* The rotation-report.rb script works well for weekly rotations with no
  exceptions set. It might work well for daily rotations (comparing to the
  same day one week ago), but hasn't been tested for that; and it fails
  completely if any of the weeks compared have an exception set. If you set
  an exception, you can work around this limitation using the `--start-time`
  and `--end-time` options to explicitly set the report date range.
* Login and other errors from PagerDuty's site are not parsed or reported.

# oncall.rb #

The `oncall.rb` script reports who is currently on call for your PagerDuty
account. Invoked with no arguments, it will list all on-call levels (1..n). If
one or more levels are given as arguments, it will only list those levels.

If the on call level has an associated on-call rotation, the name of that
rotation is used in the output. Otherwise, a generic `Level <#>` format is
used.

You can invoke oncall.rb with a `-t` or `--campfire-topic` option, and the
output of the script will be set as the topic for the configured room (see
__Campfire Support__, above). We do this out of cron right after the rotation
turns over to a new assignment.

oncall.rb defaults to showing the first escalation policy, but if you have
multiple ones and want to show a specific one, you can invoke it with `-p` or
`--policy` to specify which one to use.

Calling the script with `-h` or `--help` will display some help.

## Examples ##

    $ ./oncall.rb
    Hotseat: John Henry, Hotseat Backup: Lisa Limon, Level 3: Steven Sanders

    $ ./oncall.rb 1 2
    Hotseat: John Henry, Hotseat Backup: Lisa Limon

    $ ./oncall.rb --campfire-topic 1 2
    [No shell output, but the configured Campfire room's topic becomes:
    "Hotseat: John Henry, Hotseat Backup: Lisa Limon"]

# rotation-report.rb #

The `rotation-report.rb` script generates an automatic "end of shift" report
to show what happened over the course of a rotation. It measures how many
incidents occurred, shows who resolved them, and shows how many alerts people
got (including a breakout of after-midnight alerts, which we all must strive
to eradicate!). Also, it lists the top five causes for alerts during the
rotation, and compares the counts to the same period one week earlier.

Here's an example:

    Rotation report for February 23 - March 02:
      19 incidents (-9% vs. last week)

    Resolutions:
      John Henry: 8, George Harrison: 4, Scott Brinkley: 4, Jason Neeson: 2, [Automatic]: 1

    SMS/Phone Alerts (62 total, +77% vs. last week; 6 after midnight, -53% vs. last week):
      John Henry: 44, George Harrison: 10, Jason Neeson: 4, Scott Brinkley: 4

    Top triggers:
      6 'Pingdom: DOWN alert: example-health (www.example.com) is DOWN' (-14% vs. last week)
      5 'Pingdom: DOWN alert: sg-health (sg.example.com) is DOWN' (no occurrences last week)
      4 'Nagios: vip-api - check_api_lag' (+300% vs. last week)
      1 'Nagios: vip-redisapi - check_live_redis_lag' (-66% vs. last week)
      1 'Pingdom: DOWN alert: client-nike (www.nike.com) is DOWN' (no occurrences last week)

By default the script will report on the most recently-completed rotation.
However, you can use the `-a`|`--rotations-ago COUNT` option to specify how
far back in history you want to go. Or, you can use `-s`|`--start-time DATETIME`
and `-e`|`--end-time DATETIME` (giving the date in
[ISO 8601](http://en.wikipedia.org/wiki/ISO_8601#Combined_date_and_time_representations)
date and time format, e.g. "2011-03-02T14:00:00-05:00") to set a specific range
for the report.

Calling rotation-report.rb with a `-m`|`--campfire-message` argument will
cause the rotation report to be pasted into the configured Campfire room. (See
__Campfire Support__, above, for information about setting this up.)

Calling the script with `-h` or `--help` will display some help.

# alerts-by-day.rb #

This script is being revised and doesn't work with the rest of the package yet.

# Contributions #

Pull requests welcome. There are no tests or specs yet, so hey, contributing
couldn't be easier.

Thanks to the following people for contributions!

* [Jeffrey Wescott](https://github.com/binaryfeed)
* [André Arko](https://github.com/indirect)
* [Brian Donovan](https://github.com/eventualbuddha)
* [Brad Greenlee](https://github.com/bgreenlee)
* [Josh Nichols](https://github.com/technicalpickles)
* [James Casey](https://github.com/jamesc)

# License #

Copyright 2011 Marc Hedlund. Distributed under the Apache License, version 2.0.

