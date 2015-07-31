#!/bin/bash

usage () {
  echo "Usage: $(basename "$0") TAG[:OLD_TAG] [DESTDIR]"
  echo "Where:"
  echo "  TAG is osg-SERIES-DVER-REPO or goc-DVER-REPO"
  echo "  SERIES is: 3.1, 3.2, etc, or upcoming"
  echo "  DVER is: el5, el6, etc."
  echo "  REPO is: contrib, development, testing, or release"
  echo "  DESTDIR defaults to /etc/mash/"
  echo "  OLD_TAG, if specified, is the old-style koji tag to pull from"
  echo "           (otherwise pull from TAG)"
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
case $TAG in
  osg-*-*-*:el[56]-osg-* ) NEW_TAG=${TAG%%:*}
                           KOJI_TAG=${TAG##*:}  # mapped old style tag
                           IFS='-' read osg SERIES DVER REPO <<< "$NEW_TAG" ;;

  osg-*-*-* ) NEW_TAG=$TAG
              KOJI_TAG=$TAG  # new style tag
              IFS='-' read osg SERIES DVER REPO <<< "$NEW_TAG" ;;

  goc-*-*   ) NEW_TAG=$TAG
              KOJI_TAG=$TAG
              IFS='-' read SERIES DVER REPO <<< "$NEW_TAG" ;;

  * ) usage ;;
esac

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
  s/{KOJI_TAG}/$KOJI_TAG/
  s/{LATEST}/$LATEST/
" "$TEMPLATEDIR"/mash.template > "$DESTDIR/$NEW_TAG.mash"

