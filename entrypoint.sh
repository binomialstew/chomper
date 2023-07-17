#!/bin/sh
echo "$SCHEDULE flock -n /reduce_directory /chomper.sh -d /reduce_directory/ /volume_usage_directory ${THRESHOLD} ${FILE_NUMBER}" > /etc/crontabs/root

echo "${FILE_NUMBER} oldest file will be deleted per loop in 'reduce_directory' until 'volume_usage_directory' reaches ${THRESHOLD}% usage according to the following cron expression: ${SCHEDULE}"
## Always run under tini, since we need to reap the leftovers
exec /sbin/tini -- "$@"
