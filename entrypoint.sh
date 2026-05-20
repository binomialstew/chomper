#!/bin/sh
echo "$SCHEDULE flock -n /reduce_directory /chomper.sh -d /reduce_directory/ /volume_usage_directory ${THRESHOLD} ${FILE_NUMBER}" > /etc/crontabs/root

echo -e "The oldest ${FILE_NUMBER} file(s) will be deleted per loop in 'reduce_directory' until 'volume_usage_directory' \nreaches ${THRESHOLD}% usage according to the following cron expression: ${SCHEDULE}\n"
## Always run under tini, since we need to reap the leftovers
exec /sbin/tini -- "$@"
