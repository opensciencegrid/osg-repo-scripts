#!/bin/bash

usage () {
  echo "Usage: $(basename "$0") TAG [DESTDIR]"
  echo "Where:"
  echo "  TAG is osg-SERIES-DVER-REPO"
  echo "  SERIES is: 3.1, 3.2, etc, or upcoming"
  echo "  DVER is: el5, el6, etc."
  echo "  REPO is: contrib, development, testing, or release"
  echo "  DESTDIR defaults to /etc/mash/"
  echo
  echo "Writes DESTDIR/osg-SERIES-DVER-REPO.mash"
  exit
}

case $# in
  1 ) DESTDIR=/etc/mash ;;
  2 ) DESTDIR=$2 ;;
  * ) usage ;;
esac


upper () { python -c 'import sys; print sys.argv[1].upper()' "$*" ; }
title () { python -c 'import sys; print sys.argv[1].title()' "$*" ; }

TAG=$1
if [[ $TAG != osg-*-*-* ]]; then
  usage
fi
IFS='-' read osg SERIES DVER REPO <<< "$TAG"

# repoviewtitle looks something like: OSG 3.1 RHEL5 Contrib
REPOVIEWTITLE="OSG $(title $SERIES) RH$(upper $DVER) $(title $REPO)"

case $REPO in
  release ) LATEST="latest=false" ;;
        * ) LATEST="" ;;
esac

TEMPLATEDIR=$(dirname "$0")

sed "
  s/{REPO}/$REPO/
  s/{DVER}/$DVER/
  s/{SERIES}/$SERIES/
  s/{REPOVIEWTITLE}/$REPOVIEWTITLE/
  s/{LATEST}/$LATEST/
" "$TEMPLATEDIR"/mash.template > "$DESTDIR/osg-$SERIES-$DVER-$REPO.mash"

