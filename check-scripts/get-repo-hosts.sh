#!/bin/bash
# quick and dirty script to get which real hosts our various DNS aliases are pointing to.

command -v nslookup &>/dev/null || { echo >&2 "nslookup not found"; exit 127; }

for host in {repo,repo-rsync,repo-itb,repo-rsync-itb}.{opensciencegrid.org,osg-htc.org}; do
    realname=$(nslookup ${host} | awk '/^Name:/ { print $2; exit }')
    realname=${realname:-NOTFOUND}
    printf "%39s %39s\n" "$host" "$realname"
done

