#!/bin/bash

usage () {
  echo "Usage: $(basename "$0") REPO DVER SERIES [DESTDIR]"
  echo "Where:"
  echo "  REPO is: contrib, release, etc."
  echo "  DVER is: el5, el6, etc."
  echo "  SERIES is: 3.1, 3.2, etc, or upcoming"
  echo "  DESTDIR defaults to /etc/mash/"
  echo
  echo "Writes DESTDIR/osg-SERIES-DVER-REPO.mash"
  exit
}

case $# in
  3 ) DESTDIR=/etc/mash ;;
  4 ) DESTDIR=$4 ;;
  * ) usage ;;
esac

upper () { python -c 'import sys; print sys.argv[1].upper()' "$*" ; }
title () { python -c 'import sys; print sys.argv[1].title()' "$*" ; }

REPO=$1
DVER=$2
SERIES=$3
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

