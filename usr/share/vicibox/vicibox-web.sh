#!/bin/bash

# Web server fix-up script
# $1 = 0 for no redirect, 1 for redirect
# $2 = 0 for no phpMyAdmin, 1 for phpMyAdmin
# $3 = database IP for phpMyAdmin, ignored if php isn't flagged

# If enabled, copy our URL redirector
if [ "$1" == "1" ]; then
	/bin/cp /usr/share/vicibox/index.html /srv/www/htdocs/index.html
fi

# Get the correct timezone string
TIMEZONERAW="$(cut -d':' -f2 <<<`timedatectl | grep 'Time zone'` | tr -d '[:space:]')"
#echo "Time Zone Raw: $TIMEZONERAW"
TIMEZONE="$(cut -d'(' -f1 <<<$TIMEZONERAW)"

# And make changes to php and /etc/sysconfig/clock
sed -i "/date.timezone = /c\date.timezone = '$TIMEZONE'" /etc/php7/cli/php.ini
sed -i "/date.timezone = /c\date.timezone = '$TIMEZONE'" /etc/php7/apache2/php.ini
echo "DEFAULT_TIMEZONE=\"$TIMEZONE\"" > /etc/sysconfig/clock
