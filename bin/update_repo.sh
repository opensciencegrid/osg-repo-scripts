#!/bin/bash


usage () {
  echo "Usage: $(basename "$0") TAG"
  echo "Where:"
  echo "  TAG is osg-SERIES-DVER-REPO or devops-DVER-REPO"
  echo "  SERIES is: 3.X (3.5, 3.6, etc), or 3.X-upcoming"
  echo "  DVER is: el7, el8, etc."
  echo "  REPO is: contrib, development, testing, or release for osg"
  echo "       or: itb or production for devops (formerly goc)"
  echo "  DESTDIR defaults to /etc/mash/"
  exit 1
}

[[ $# -eq 1 ]] || usage
TAG=$1

case $TAG in
  osg-3.*-upcoming-*-* ) IFS='-' read osg SERIES upcoming DVER REPO <<< "$TAG"
                         SERIES+=-$upcoming ;;
  osg-*-*-*-* ) IFS='-' read osg SERIES branch DVER REPO <<< "$TAG"
                         SERIES+=-$branch ;;
  osg-*-*-* ) IFS='-' read osg SERIES DVER REPO <<< "$TAG" ;;
  devops-*-*) IFS='-' read SERIES DVER REPO <<< "$TAG" ;;
          * ) usage ;;
esac

# Prevent simultaneous mash runs from colliding
# Causes errors when another instance opens an incompletely downloaded RPM
# Wait up to 5 minutes for the other task to complete
mkdir -p /var/lock/repo
lockfile=/var/lock/repo/lock.update_repo-$SERIES.$DVER
exec 99>$lockfile
if ! flock --wait 300 99  ; then
         echo "another instance is running" >&2
         exit 1
fi

release_path="/usr/local/repo/osg/$SERIES/$DVER/$REPO"
working_path="/usr/local/repo.working/osg/$SERIES/$DVER/$REPO"
previous_path="/usr/local/repo.previous/osg/$SERIES/$DVER/$REPO"
reponame=$TAG

mkdir -p "$release_path" "$working_path" "$previous_path"
mash "$reponame" -o "$working_path" -p "$release_path"
if [ "$?" -ne "0" ]; then
        echo "mash failed - please see error log" >&2
        exit 1
fi

rm -rf "$previous_path"
mv "$release_path" "$previous_path"
mv "$working_path/$reponame" "$release_path"

if [[ $REPO = release && $SERIES != *-upcoming ]]; then
        echo "creating osg-$SERIES-$DVER-release-latest symlink"
        cd /usr/local/repo/osg/"$SERIES"
        # use ls version-sort so that 3.2-11 > 3.2-2
        target=$(ls -v "$DVER/$REPO"/x86_64/osg-release-[1-9]*.rpm | tail -1)
        echo "target: $target"
        if [[ $target ]]; then
                ln -fs "$target" "osg-$SERIES-$DVER-release-latest.rpm"
        else
                echo "didn't find the osg-release rpm under $SERIES/$DVER/$REPO"
        fi
fi
