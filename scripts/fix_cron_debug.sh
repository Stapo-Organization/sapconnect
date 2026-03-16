#!/bin/bash

# Find PHP path
PHP_PATH=$(which php)
if [ -z "$PHP_PATH" ]; then
    PHP_PATH="/usr/bin/php"
fi

echo "Detected PHP at: $PHP_PATH"

# Define the new debug cron job
CRON_JOB="* * * * * cd /home/sapapimuntajat/sapconnect_app && $PHP_PATH artisan schedule:run >> /home/sapapimuntajat/cron_debug.log 2>&1"

# Clear existing related crons and add new one
crontab -l 2>/dev/null | grep -v "schedule:run" | crontab -
(crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

echo "CRON updated with debug logging and absolute path."
echo "Waiting for next run... (Tail cron_debug.log to see output)"
