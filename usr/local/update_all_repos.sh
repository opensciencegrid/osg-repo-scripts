#!/bin/bash
set -e

usage () {
  echo "Usage: $(basename "$0") [-L LOGDIR] [-K LOCKDIR]"
  echo "Runs update_repo.sh on all tags in $PWD/osg-tags"
  echo "Logs are written to LOGDIR, /var/log/repo by default"
  exit
}

datemsg () {
  echo "$(date):" "$@"
}

# cd /usr/local
cd "$(dirname "$0")"
LOGDIR=/var/log/repo
LOCKDIR=/var/lock/repo

while [[ $1 = -* ]]; do
case $1 in
  -L ) LOGDIR=$2; shift 2 ;;
  -K ) LOCKDIR=$2; shift 2 ;;
  --help | -* ) usage ;;
esac
done

if [[ ! -e osg-tags ]]; then
  datemsg "$PWD/osg-tags is missing."
  datemsg "Please run $PWD/update_mashfiles.sh to generate"
  exit 1
fi >&2

[[ -d $LOGDIR  ]] || mkdir -p "$LOGDIR"
[[ -d $LOCKDIR ]] || mkdir -p "$LOCKDIR"

exec 299> "$LOCKDIR"/all-repos.lk
if ! flock -n 299; then
  datemsg "Can't acquire lock, is $(basename "$0") already running?" >&2
  exit 1
fi

datemsg "Updating all mash repos..."
for tag in $(< osg-tags); do
  datemsg "Running update_repo.sh for tag $tag ..."
  ./update_repo.sh "$tag" > "$LOGDIR/update_repo.$tag.log" \
                         2> "$LOGDIR/update_repo.$tag.err" \
  || datemsg "mash failed for $tag - please see error log" >&2
done
datemsg "Finished updating all mash repos."
echo

