# pagerduty-tools #

Tools to work around the current limitations in the
[PagerDuty](http://www.pagerduty.com)
[API](http://www.pagerduty.com/docs/api/api-documentation).

## Installing ##

First, clone the GitHub repo:

    $ git clone git://github.com/precipice/pagerduty-tools.git

If you don't already have [Bundler](http://gembundler.com/) installed, do that
now:

    $ gem install bundler

Then install required gems via Bundler:

    $ bundle install

# oncall.rb #

The `oncall.rb` script reports who is currently on call for your PagerDuty
account. Invoked with no arguments, it will list all on-call levels (1..n). If
one or more levels are given as arguments, it will only list those levels.

The script logs into the PagerDuty site when first run. Your email address
will be used to find associated PagerDuty accounts, and you can choose the
account you want to report on. After the first run, a login cookie is kept in
your home directory to allow future runs to be automatic (e.g., from cron).

The output of the script is meant to be suitable for use as a Campfire room
topic, which is how we're currently using it. (Pull requests welcome if you
want another output format.)

If the on call level has an associated on-call rotation, the name of that
rotation is used in the output. Otherwise, a generic `Level <#>` format is
used.

Calling the script with `-h` or `--help` will display some help.

## Campfire Support ##

If you would like to have your current PagerDuty rotation assignments listed
as the topic of a [Campfire](http://www.campfirenow.com) room, add a
configuration file at `~/.pagerduty-campfire.yaml` containing the following:

    site:  https://example.campfirenow.com
    room:  99999
    token: abababababababababababababababababababab

with the values changed to match your configuration. I'd recommend running:

    $ chmod 0600 ~/.pagerduty-campfire.yaml

after creating it. You can then invoke oncall.rb with a `-t` or
`--campfire-topic` option, and the output of the script will be set as the
topic for the configured room. We do this out of cron right after the rotation
turns over to a new assignment.

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
rotation.

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

By default the script will report on the currently in-progress rotation.
However, you can use the `-a`|`--rotations-ago COUNT` option to specify how
far back in history you want to go. (Currently, only weekly rotations are
supported for history.)

## Campfire Support ##

See __Campfire Support__ under *oncall.rb* for information about setting up
Campfire support. Calling rotation-report.rb with a `-m`|`--campfire-message`
argument will cause the rotation report to be pasted into the configured Campfire
room.

# alerts-by-day.rb #

This script is being revised and doesn't work with the rest of the package yet.

# Contributions #

Pull requests welcome. There are no tests or specs yet, so hey, contributing
couldn't be easier.

Thanks to the following people for contributions!

* [Jeffrey Wescott](https://github.com/binaryfeed)
* [André Arko](https://github.com/indirect)

# License #

Copyright 2011 Marc Hedlund. Distributed under the Apache License, version 2.0.

