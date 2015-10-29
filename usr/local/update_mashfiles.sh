#!/bin/bash
set -e

usage () {
  echo "Usage: $(basename "$0") [options] [DESTDIR]"
  echo "Generates .mash files based on osg tags from koji."
  echo "Write to DESTDIR, defaulting to /etc/mash"
  echo
  echo "Options:"
  echo "  --remove-old   delete out-of-date osg .mash files too."
  echo "  --skip-koji    do not pull new tags from koji, but instead use"
  echo "                 the osg-tags file saved from a previous run."
  echo "  --tags-only    only update osg-tags, don't update mashfiles."
  exit
}

DESTDIR=/etc/mash
SCRIPTDIR=$(cd "$(dirname "$0")"; pwd)

while [[ $1 = -* ]]; do
case $1 in
  --skip-koji ) SKIP_KOJI=Y; shift ;;
  --remove-old ) REMOVE_OLD=Y; shift ;;
  --tags-only ) TAGS_ONLY=Y; shift ;;
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
  echo "Pulling osg tags from koji..."

  [[ -e osg-tags.exclude ]] || touch osg-tags.exclude

  osg_seriespat='[0-9]+\.[0-9]+|upcoming'
  osg_repopat='contrib|development|release|testing|empty'
  osg_tagpat="osg-($osg_seriespat)-el[5-9]-($osg_repopat)"
  goc_tagpat='goc-el[5-9]-(itb|production)'

  koji --config=/etc/mash_koji_config list-tags 'osg-*-*-*' 'goc-*-*' \
  | egrep -xe "$osg_tagpat" -e "$goc_tagpat"                          \
  | fgrep -vxf osg-tags.exclude > osg-tags.new || :

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

if [[ $TAGS_ONLY ]]; then
  echo "Skipping mashfile update."
  exit
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
  ls osg-*.mash 2>/dev/null                   | # list all osg .mash files
     sed 's/\.mash$//'                        | # strip .mash extension
     fgrep -xvf "$SCRIPTDIR"/osg-tags         | # omit valid tags
     sed 's/$/.mash/'                         | # add back .mash extension
     xargs -rd '\n' rm -v                       # remove unused osg .mash files
fi

