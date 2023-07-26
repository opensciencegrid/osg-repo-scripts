#!/bin/bash

# Tail all of the logs from cron jobs to the init process's stdout so they show up in Kubernetes logs

# Pre-populate log directories and files so there's something to tail
mkdir -p /var/log/repo
touch /var/log/repo/update_mirror.log
touch /var/log/repo/update_all_repos.log
touch /var/log/repo/update_mashfiles.log

# Tail the logs in the background 
# Note: This is very fragile, requires append-only operations to every log file
tail -f /var/log/repo/*.log &
