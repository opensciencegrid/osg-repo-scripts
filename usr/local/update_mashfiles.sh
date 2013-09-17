#!/bin/bash
set -e

usage () {
  echo "Usage: $(basename "$0") [--skip-koji] [--remove-old] [DESTDIR]"
  echo "Generates .mash files based on osg tags from koji."
  echo "If --remove-old is specified, delete out-of-date osg .mash files too."
  echo "If --skip-koji is specified, do not pull new tags from koji, but"
  echo "instead use the osg-tags file saved from a previous run."
  echo "Write to DESTDIR, defaulting to /etc/mash"
  exit
}

DESTDIR=/etc/mash
SCRIPTDIR=$(cd "$(dirname "$0")"; pwd)

while [[ $1 = -* ]]; do
case $1 in
  --skip-koji ) SKIP_KOJI=Y; shift ;;
  --remove-old ) REMOVE_OLD=Y; shift ;;
  --help | * ) usage ;;
esac
done

if [[ $1 ]]; then
  if [[ -d $1 ]]; then
    DESTDIR=$(cd "$1" && pwd)
  else
    echo "DESTDIR '$1' does not exist" >&2
    exit 1
  fi
fi

cd "$SCRIPTDIR"

if [[ $SKIP_KOJI ]]; then
  if [[ ! -s osg-tags ]]; then
    echo "--skip-koji was specified but no existing osg-tags were found" >&2
    exit 1
  else
    echo "Using existing osg-tags..."
  fi
else
  # list new-style osg tags from koji

  # tag patterns to allow
  series='([0-9]+\.[0-9]+|upcoming)'
  dver='el[5-9]'
  repo='(contrib|development|release|testing)'
  tag_regex="osg-$series-$dver-$repo"

  echo "Pulling osg tags from koji..."

  koji --config=/etc/mash_koji_config list-tags 'osg-*-*-*' \
  | egrep -x "$tag_regex" > osg-tags.new || :

  if [[ -s osg-tags.new ]]; then
    # don't replace osg-tags if it hasn't changed
    if [[ -e osg-tags ]] && diff -q osg-tags osg-tags.new >/dev/null; then
      echo "osg-tags from koji have not changed, using existing."
      rm -f osg-tags.new
    else
      echo "Using updated osg-tags"
      mv -bS.prev osg-tags.new osg-tags
    fi
  else
    echo "Could not retrieve any osg tags from koji, aborting." >&2
    rm -f osg-tags.new
    exit 1
  fi
fi

echo "Backing up existing .mash files to $DESTDIR/mash.bak/"
rm -rf "$DESTDIR/mash.bak/"
mkdir "$DESTDIR/mash.bak/"
cp "$DESTDIR"/*.mash "$DESTDIR/mash.bak/" 2>/dev/null || :

for tag in $(< osg-tags); do
  echo "Creating mash file for $tag"
  ./new_mashfile.sh "$tag" "$DESTDIR"
done

if [[ $REMOVE_OLD ]]; then
  cd "$DESTDIR"
  ls el[56]-osg-*.mash osg-*.mash 2>/dev/null | # list all osg .mash files
     sed 's/\.mash$//'                        | # strip .mash extension
     fgrep -xvf "$SCRIPTDIR"/osg-tags         | # omit valid tags
     sed 's/$/.mash/'                         | # add back .mash extension
     xargs -rd '\n' rm -v                       # remove unused osg .mash files
fi

