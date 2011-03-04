# pagerduty-tools #

Tools to work around the limitations in the PagerDuty API.

## Installing ##

First, clone the GitHub repo:

    $ git clone git://github.com/precipice/pagerduty-tools.git

If you don't already have Bundler installed, do that now:

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

## Examples ##

    $ ./oncall.rb
    Hotseat: John Henry, Hotseat Backup: Lisa Limon, Level 3: Steven Sanders

    $ ./oncall.rb 1 2
    Hotseat: John Henry, Hotseat Backup: Lisa Limon
