#!/bin/bash


usage () {
  echo "Usage: $(basename "$0") TAG"
  echo "Where:"
  echo "  TAG is osg-SERIES-DVER-REPO"
  echo "  SERIES is: 3.1, 3.2, etc, or upcoming"
  echo "  DVER is: el5, el6, etc."
  echo "  REPO is: contrib, development, testing, or release"
  echo "  DESTDIR defaults to /etc/mash/"
  exit 1
}

TAG=$1
if [[ $# -ne 1 || $TAG != osg-*-*-* ]]; then
  usage
fi
IFS='-' read osg SERIES DVER REPO <<< "$TAG"

release_path="/usr/local/repo/osg/$SERIES/$DVER/$REPO"
working_path="/usr/local/repo.working/osg/$SERIES/$DVER/$REPO"
previous_path="/usr/local/repo.previous/osg/$SERIES/$DVER/$REPO"
reponame=osg-$SERIES-$DVER-$REPO

mkdir -p "$release_path" "$working_path" "$previous_path"
mash "$reponame" -o "$working_path" -p "$release_path"
if [ "$?" -ne "0" ]; then
        echo "mash failed - please see error log" >&2
        exit 1
fi

rm -rf "$previous_path"
mv "$release_path" "$previous_path"
mv "$working_path/$reponame" "$release_path"

if [[ $REPO = release && $SERIES != upcoming ]]; then
        echo "creating osg-$SERIES-$DVER-release-latest symlink"
        cd /usr/local/repo/osg/"$SERIES"
        # use ls version-sort so that 3.2-11 > 3.2-2
        target=$(ls -v "$DVER/$REPO"/x86_64/osg-release-[1-9]*.rpm | tail -1)
        echo "target: $target"
        if [[ $target ]]; then
                ln -fs "$target" "osg-$SERIES-$DVER-release-latest.rpm"
                if [[ $target -nt RPM-GPG-KEY-OSG ]]; then
                    rpm2cpio "$target" | cpio -i --quiet --to-stdout \
                      ./etc/pki/rpm-gpg/RPM-GPG-KEY-OSG > RPM-GPG-KEY-OSG
                fi
        else
                echo "didn't find the osg-release rpm under $SERIES/$DVER/$REPO"
        fi
fi

# temporarily create el7 release-latest symlinks for development,
# until we create the osg-3.x-el7-release repos
if [[ $DVER = el7 && $REPO = development && $SERIES != upcoming ]]; then
        echo "creating osg-$SERIES-$DVER-release-latest symlink"
        cd /usr/local/repo/osg/"$SERIES/$DVER/$REPO"/x86_64
        # use ls version-sort so that 3.2-11 > 3.2-2
        target=$(ls -v osg-release-[1-9]*.rpm | tail -1)
        echo "target: $target"
        if [[ $target ]]; then
                ln -fs "$target" "osg-$SERIES-$DVER-release-latest.rpm"
        else
                echo "didn't find the osg-release rpm under $SERIES/$DVER/$REPO"
        fi
fi

