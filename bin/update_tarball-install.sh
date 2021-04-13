#!/bin/bash

DEST=/usr/local/repo/tarball-install

#############################
### Mirror tarball-client ###
#############################

/usr/bin/lftp -c mirror                                              \
  --delete                                                           \
  --exclude-glob=osg-afs-client-*         `# Skip osg-afs-client`    \
  --exclude-glob=*tarballs.rescue         `# Ignore rescue tarballs` \
  --exclude-glob=osg-wn-client-latest.*   `# Ignore latest symlinks` \
  --exclude=3.2                           `# Exclude old releases`   \
  https://vdt.cs.wisc.edu/tarball-client/                            \
  $DEST

##############################
### Create latest symlinks ###
##############################

# For each OSG release series directory
for REL_DIR in $DEST/* ; do

  # For each "release/architecture"
  #   E.g. /usr/local/repo/tarball-install/3.3/i386/
  for REL_ARCH_DIR in "$REL_DIR"/* ; do

    # For tarballs inside...
    #   E.g. /usr/local/repo/tarball-install/3.3/i386/osg-wn-client-3.3.5-1.el6.i386.tar.gz
    # Cut the last 4 fields and make unique os.arch list
    OS_ARCHES=$(find "$REL_ARCH_DIR" -type f | rev | cut -d. -f1-4 | rev | sort | uniq)

    # For each os.arch suffix
    #   E.g. el7.x86_64.tar.gz
    for OS_ARCH in $OS_ARCHES ; do

      # Find the latest tarfile
      LATEST=$(find "$REL_ARCH_DIR" -name "*.$OS_ARCH" | sort --version-sort | tail -1)

      # And create latest symlink
      ln -s --relative --force "$LATEST" "$REL_DIR/osg-wn-client-latest.$OS_ARCH"

    done
  done
done
