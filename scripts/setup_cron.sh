#!/bin/bash

# Define the cron job
CRON_JOB="* * * * * cd /home/sapapimuntajat/sapconnect_app && php artisan schedule:run >> /dev/null 2>&1"

# Check if it exists
crontab -l 2>/dev/null | grep -F "schedule:run" > /dev/null

if [ $? -ne 0 ]; then
    echo "Adding CRON job..."
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    echo "CRON job added successfully."
else
    echo "CRON job already exists."
fi

echo "Current Date on Server:"
date

echo "Testing php artisan schedule:run..."
cd /home/sapapimuntajat/sapconnect_app
php artisan schedule:run
