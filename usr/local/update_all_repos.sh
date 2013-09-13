#!/bin/bash
set -e

usage () {
  echo "Usage: $(basename "$0") [-L LOGDIR]"
  echo "Runs update_repo.sh on all tags in $PWD/osg-tags"
  echo "Logs are written to LOGDIR, /var/log/repo by default"
  exit
}

# cd /usr/local
cd "$(dirname "$0")"
LOGDIR=/var/log/repo

case $1 in
  -L ) LOGDIR=$2 ;;
  --help | * ) usage ;;
esac

if [[ ! -e osg-tags ]]; then
  echo "$PWD/osg-tags is missing."
  echo "Please run $PWD/update_mashfiles.sh to generate"
  exit 1
fi >&2

if [[ ! -d $LOGDIR ]]; then
  mkdir -p "$LOGDIR"
fi

for tag in $(< osg-tags); do
  echo "Running update_repo.sh for tag $tag ..."
  ./update_repo.sh "$tag" > "$LOGDIR/update_repo.$tag.log" \
                         2> "$LOGDIR/update_repo.$tag.err"
done

