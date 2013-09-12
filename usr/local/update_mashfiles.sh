#!/bin/bash
set -e

usage () {
  echo "$(basename "$0") [DESTDIR]"
  echo "Generates .mash files based on osg tags from koji."
  echo "Writes files to DESTDIR, or /etc/mash by default."
  exit
}

cd /usr/local

# tag patterns to allow
series='([0-9]+\.[0-9]+|upcoming)'
dver='el[5-9]'
repo='(contrib|development|release|testing)'
tag_regex="osg-$series-$dver-$repo"

koji --config=/etc/mash_koji_config list-tags 'osg-*-*-*' \
| egrep -x "$tag_regex" > osg-tags.new

if [[ -s osg-tags.new ]]; then
  mv -bS.old osg-tags.new osg-tags
else
  echo "Could not retrieve any osg tags from koji, aborting." >&2
  exit 1
fi

while IFS='-' read osg series dver repo; do
  echo "Creating mash file for osg-$series-$dver-$repo"
  /usr/local/new_mashfile.sh "$repo" "$dver" "$series" < /dev/null
done < osg-tags

