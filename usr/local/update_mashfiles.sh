#!/bin/bash
set -e

usage () {
  echo "Usage: $(basename "$0") [--remove-old] [DESTDIR]"
  echo "Generates .mash files based on osg tags from koji."
  echo "Write to DESTDIR, defaulting to /etc/mash"
  echo "If --remove-old is specified, delete out-of-date osg .mash files too."
  exit
}

DESTDIR=/etc/mash
SCRIPTDIR=$(cd "$(dirname "$0")"; pwd)

while [[ $1 = -* ]]; do
case $1 in
  --remove-old ) REMOVE_OLD=Y; shift ;;
  --help | * ) usage ;;
esac
done

if [[ $1 ]]; then
  if [[ ! -d $1 ]]; then
    echo "DESTDIR '$DESTDIR' does not exist" >&2
    exit 1
  fi
fi

cd "$SCRIPTDIR"

# tag patterns to allow
series='([0-9]+\.[0-9]+|upcoming)'
dver='el[5-9]'
repo='(contrib|development|release|testing)'
tag_regex="osg-$series-$dver-$repo"

# list new-style osg tags from koji
koji --config=/etc/mash_koji_config list-tags 'osg-*-*-*' \
| egrep -x "$tag_regex" > osg-tags.new

if [[ -s osg-tags.new ]]; then
  mv -bS.old osg-tags.new osg-tags
else
  echo "Could not retrieve any osg tags from koji, aborting." >&2
  exit 1
fi

for tag in $(< osg-tags); do
  echo "Creating mash file for osg-$series-$dver-$repo"
  ./new_mashfile.sh "$tag" "$DESTDIR" < /dev/null
done < osg-tags

if [[ $REMOVE_OLD ]]; then
  cd "$DESTDIR"
  ls | grep -e '^osg-' -e 'el[56]-osg-' | # list all osg .mash files
       sed 's/\.mash$//'                | # strip .mash extension
       fgrep -xvf "$SCRIPTDIR"/osg-tags | # omit valid tags
       sed 's/$/.mash/'                 | # add back .mash extension
       xargs -rd '\n' rm -v               # remove obsolete osg .mash files
fi

