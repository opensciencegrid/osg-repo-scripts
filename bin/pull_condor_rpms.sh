#!/bin/bash
# only need to fetch a subset of packages from condor repos
CONDOR_PKGS=(condor htcondor-ce minicondor python3-condor)

RSYNC_ROOT="rsync://rsync.cs.wisc.edu/htcondor"
TMP_PKG_LIST=/tmp/rsync_list.txt

TAG=$1
REPO_DIR=$2
SOURCE_SET=$3
usage () {
  echo "Usage: $(basename "$0") TAG REPO_DIR SOURCE_SET"
  echo "Where:"
  echo "  TAG is osg-SERIES-BRANCH-DVER-REPO"
  echo "  SERIES is: 23, 24, etc."
  echo "  DVER is: el8, el9, etc."
  echo "  BRANCH is: main or upcoming"
  echo "  REPO is: development, testing, or release"
  echo "  REPO_DIR is the directory to output condor RPMs into"
  echo "  SOURCE_SET is '' for rpms and 'SRPMS/' for srpms"
  exit 1
}

tag_not_supported() {
    echo "Tag $TAG does not have a corresponding condor version."
    exit 0
}

branch_not_supported() {
    echo "Branch $1 does not have a corresponding condor branch."
    exit 1
}

repo_not_supported() {
    echo "Repo $1 does not have a corresponding condor repo."
    exit 1
}

[[ $# -eq 2 ]] || usage

# read series, branch, dver, and repo from the osg tag
case $TAG in
  osg-2*-*-*-* ) IFS='-' read osg SERIES BRANCH DVER REPO <<< "$TAG" ;;
  osg-*-*-* ) tag_not_supported ;;
  devops-*-*) tag_not_supported ;;
  * ) usage ;;
esac

# branch "upcoming" corresponds to SERIES.x in htcondor, "main" corresponds to SERIES.0
# others do not have a corresponding series
case $BRANCH in
    main ) CONDOR_SERIES=$SERIES.0 ;;
    upcoming ) CONDOR_SERIES=$SERIES.x ;;
    * ) branch_not_supported $BRANCH ;;
esac

# OSG repos correspond to the condor repos in the following way:
# release -> release
# testing -> release, rc, update
# development -> daily
case $REPO in
    release ) CONDOR_REPOS=(release)
              LATEST_ONLY=0 ;;
    testing ) CONDOR_REPOS=(release rc update)
              LATEST_ONLY=1 ;;
    development ) CONDOR_REPOS=(daily)
              LATEST_ONLY=1 ;;
    * ) repo_not_supported $REPO ;;
esac

for condor_pkg in ${CONDOR_PKGS[@]}; do
    echo '' > $TMP_PKG_LIST
    # For each package and osg repo, get every build available for that package from every applicable condor repo
    for condor_repo in ${CONDOR_REPOS[@]}; do
        RSYNC_URL="$RSYNC_ROOT/$CONDOR_SERIES/$DVER/x86_64/$condor_repo/$SOURCE_SET$condor_pkg-[0-9]*.rpm"
        echo "rsyncing $RSYNC_URL to $REPO_DIR"
        if ! rsync --list-only $RSYNC_URL | awk '{print "'$condor_repo/$SOURCE_SET'"$5}' >> $TMP_PKG_LIST ; then
            echo "Warning: No packages found for $RSYNC_URL. Skipping"
        fi
    done

    # for development and testing, we only need to rsync the latest version of the package from across every repo
    if [ "$LATEST_ONLY" -eq "1" ]; then
        # overwrite the package list in-place
        (rm -f $TMP_PKG_LIST && sort -r | head -1 > $TMP_PKG_LIST) < $TMP_PKG_LIST
    fi

    rsync --files-from=$TMP_PKG_LIST --no-R "$RSYNC_ROOT/$CONDOR_SERIES/$DVER/x86_64/" $REPO_DIR
done
