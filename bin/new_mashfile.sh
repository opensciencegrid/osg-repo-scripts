#!/bin/bash

usage () {
  echo "Usage: $(basename "$0") TAG [DESTDIR]"
  echo "Where:"
  echo "  TAG is osg-SERIES-DVER-REPO or devops-DVER-REPO"
  echo "  SERIES is: 3.X (3.5, 3.6, etc), or 3.X-upcoming"
  echo "  DVER is: el7, el8, etc."
  echo "  REPO is: contrib, development, testing, or release for osg"
  echo "       or: itb or production for devops (formerly goc)"
  echo "  DESTDIR defaults to /etc/mash/"
  echo
  echo "Writes DESTDIR/TAG.mash"
  exit
}

case $# in
  1 ) DESTDIR=/etc/mash ;;
  2 ) DESTDIR=$2 ;;
  * ) usage ;;
esac


if command -v python3 &>/dev/null; then
    PYTHON=python3
else
    PYTHON=python
fi


upper () { $PYTHON -c 'import sys; print( sys.argv[1].upper() )' "$*" ; }
title () { $PYTHON -c 'import sys; print( sys.argv[1].title() )' "$*" ; }

TAG=$1
case $TAG in
  osg-*-*-*-* ) IFS='-' read osg SERIES branch DVER REPO <<< "$TAG"
                         SERIES+=-$branch ;;
  # matches osg-2X-elY-empty and contrib, but not the equivalent 3.X tags
  osg-[1-9][^.]*-*-empty|osg-[1-9][^.]*-*-contrib )
                IFS='-' read osg SERIES DVER REPO <<< "$TAG"
                SERIES+=-$REPO 
                REPO='' ;;
  osg-*-*-* ) IFS='-' read osg SERIES DVER REPO <<< "$TAG" ;;
  devops-*-*) IFS='-' read SERIES DVER REPO <<< "$TAG" ;;
          * ) usage ;;
esac

# repoviewtitle looks something like: OSG 3.1 RHEL5 Contrib
REPOVIEWTITLE="OSG $(title $SERIES) RH$(upper $DVER) $(title $REPO)"

case $REPO in
  release | rolling | itb | production ) LATEST="latest=false" ;;
        * ) LATEST="" ;;
esac

case $SERIES in
    23*) auto_key=4d4384d0       # OSG-23-auto
         developer_key=92897c00  # OSG-23-developer
         STRICT_KEYS=True
         ;;
    3.6) if [[ $DVER == el9 ]]; then
             auto_key=1887c61a   # OSG-4
         else
             auto_key=96d2b90f   # OSG-2
         fi
         developer_key=$auto_key
         STRICT_KEYS=False
         ;;
      *) auto_key=824b8603       # OSG
         developer_key=$auto_key
         STRICT_KEYS=False
         ;;
esac

# in OSG 23+, "contrib" and "empty" make it into the "$branch"; in previous, it's part of "$REPO"
if [[ $REPO == development || \
      $TAG  == *contrib* || \
      $TAG  == *empty* ]]; then
    KEYS="$auto_key $developer_key"
else
    KEYS=$developer_key
fi

case $DVER in
  el5|el6 ) ARCHES="i386 x86_64" ;;
        * ) ARCHES="x86_64" ;;
esac

TEMPLATEDIR=/usr/share/repo

KEYSDIR=$(tr -c '0-9A-Za-z' '_')

sed "
  s/{YUMREPO}/$TAG/
  s/{REPO}/$REPO/
  s/{DVER}/$DVER/
  s/{SERIES}/$SERIES/
  s/{REPOVIEWTITLE}/$REPOVIEWTITLE/
  s/{KOJI_TAG}/$TAG/
  s/{ARCHES}/$ARCHES/
  s/{LATEST}/$LATEST/
  s/{KEYS}/$KEYS/
  s/{KEYSDIR}/$KEYSDIR/
  s/{STRICT_KEYS}/$STRICT_KEYS/
" "$TEMPLATEDIR"/mash.template > "$DESTDIR/$TAG.mash"

