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
as the topic of a Campfire room, add a configuration file at
`~/.pagerduty-campfire.yaml` containing the following:

    site:  https://example.campfirenow.com
    room:  99999
    token: abababababababababababababababababababab

(with the values changed to match your configuration). You can then invoke
oncall.rb with a `-t` or `--campfire-topic` option, and the output of the
script will be set as the topic for the configured room.  We do this out of
cron right after the rotation turns over to a new assignment.

## Examples ##

    $ ./oncall.rb
    Hotseat: John Henry, Hotseat Backup: Lisa Limon, Level 3: Steven Sanders

    $ ./oncall.rb 1 2
    Hotseat: John Henry, Hotseat Backup: Lisa Limon

    $ ./oncall.rb --campfire-topic 1 2
    [No shell output, but the configured Campfire room's topic becomes:
    "Hotseat: John Henry, Hotseat Backup: Lisa Limon"]

# alerts-by-day.rb #

This script is currently being revised and doesn't work with the rest of the
package yet.

# License #

Copyright 2011 Marc Hedlund. Distributed under the Apache License, version 2.0.

