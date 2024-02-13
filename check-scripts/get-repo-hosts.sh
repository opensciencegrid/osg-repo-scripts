#!/bin/bash
# quick and dirty script to get which real hosts our various DNS aliases are pointing to.

command -v nslookup &>/dev/null || { echo >&2 "nslookup not found"; exit 127; }

for host in repo repo-rsync repo-itb; do
    realname=$(nslookup ${host}.opensciencegrid.org | awk '/^Name:/ { print $2 }')
    realname=${realname:-NOTFOUND}
    printf "%15s %s\n" "$host" "$realname"
done

