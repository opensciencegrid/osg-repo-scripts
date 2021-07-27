#!/bin/bash

REPO_BASEDIR="${REPO_BASEDIR:-/data}"
REPO_MAXAGE="${REPO_MAXAGE:-480}" # default of 8 hours (8*60 min)
REPO_TIMESTAMP="$REPO_BASEDIR/repo/osg/timestamp.txt"

# Show errors, but allow a sleep for container debugging
err_exit() {
    echo "Error on line $(caller)" >&2
    sleep 5m
    if [ -f /.ignore-errors ] ; then
        exit 0
    else
        exit 1
    fi
}
trap 'err_exit' ERR

# Was timestamp file modified less than $REPO_MAXAGE minutes ago?
if test "$(find $REPO_TIMESTAMP -mmin -$REPO_MAXAGE)" ; then
    echo "Repo is current. Skipping sync."
    exit 0
fi

# Generate output directories
mkdir -p "$REPO_BASEDIR/mash" \
         "$REPO_BASEDIR/mirror" \
         "$REPO_BASEDIR/repo" \
         "$REPO_BASEDIR/repo.previous" \
         "$REPO_BASEDIR/repo.working"

# Generate mash config files
update_mashfiles.sh

# Reorder mash tags for less lock contention
rev /etc/osg-koji-tags/osg-tags | sort | rev > /tmp/osg-tags

# Download repo data in parallel
parallel --max-procs 12 --results /tmp/init --arg-file /tmp/osg-tags --retries 10 update_repo.sh {}

# Add symlink for mirrorlist
ln --no-target-directory --force --symbolic "$REPO_BASEDIR/mirror" "$REPO_BASEDIR/repo/mirror"

# Generate mirrorlist
update_mirror.py

# Note: we can't run repo-update-cadist here, since it downloads *from* repo

# Update tarballs
update_tarball-install.sh

# Create timestamp marker file
echo $(date) > $REPO_TIMESTAMP
