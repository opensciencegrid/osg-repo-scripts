#!/bin/bash
OSGTAGS=/etc/osg-koji-tags/osg-tags

usage () {
  echo "Usage: $(basename "$0") TAG"
  echo "Where:"
  echo "  TAG is osg-SERIES-DVER-REPO or devops-DVER-REPO"
  echo "  SERIES is: 3.X (3.5, 3.6, etc), or 2X (23, etc.)"
  echo "  DVER is: el7, el8, etc."
  echo "  REPO is: contrib, development, testing, or release for osg"
  echo "       or: itb or production for devops (formerly goc)"
  echo "  DESTDIR defaults to /etc/mash/"
  exit 1
}

[[ $# -eq 1 ]] || usage
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

arch="x86_64"
release_path="/usr/local/repo/osg/$SERIES/$DVER/$REPO"
working_path="/usr/local/repo.working/osg/$SERIES/$DVER/$REPO"
previous_path="/usr/local/repo.previous/osg/$SERIES/$DVER/$REPO"
reponame=$TAG
repo_working_path="$working_path/$reponame/$arch"
repo_working_srpm_path="$working_path/$reponame/source/SRPMS"

if test -d $release_path && grep -q $TAG $OSGTAGS.create-only ; then
  echo "Tag $TAG is create-only and already exists. Skipping"
  exit 0
fi

mkdir -p "$release_path" "$working_path" "$previous_path"
mash "$reponame" -o "$working_path" -p "$release_path"

# FIXME: temporarily let mash fail so that we can see all the warnings
# and fix things live
# if [ "$?" -ne "0" ]; then
#         echo "mash failed - please see error log" >&2
#         exit 1
# fi

# Copy relevant htcondor rpms to the working directory, if any
if pull_condor_rpms.sh $TAG $repo_working_path '' ; then
        # if htcondor rpms were copied, we need to regenerate the repo files
        createrepo --update $repo_working_path
        repoview $repo_working_path
fi

# Copy relevant htcondor srpms to the working directory, if any
if pull_condor_rpms.sh $TAG $repo_working_srpm_path 'SRPMS/' ; then
        # if htcondor srpms were copied, we need to regenerate the repo files
        createrepo --update $repo_working_srpm_path
        repoview $repo_working_srpm_path
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
