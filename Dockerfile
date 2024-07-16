FROM opensciencegrid/software-base:3.6-el7-release

# EL7
RUN \
    yum-config-manager --disable base,updates,extras,centosplus >/dev/null \
    && yum-config-manager --enable C7.9.2009-* >/dev/null

# Install dependencies
# Note that OSG builds of mash and createrepo are necessary
RUN \
    yum update -y \
    && yum install -y \
                  --disablerepo='osg-upcoming*' \
                  --enablerepo=devops-itb \
                  mash \
    && yum install -y \
                  --disablerepo='osg-upcoming*' \
                  --enablerepo=devops \
                  repo-update-cadist \
    && yum install -y \
                  --disablerepo='osg-upcoming*' \
                  lftp \
                  parallel \
                  httpd \
                  repoview \
                  rsync \
    && yum clean all && rm -rf /var/cache/yum/*

# supervisord and cron configs
COPY docker/supervisor-*.conf /etc/supervisord.d/
COPY docker/*.cron /etc/cron.d/
COPY 99-tail-cron-logs.sh /etc/osg/image-init.d/

# OSG scripts for repo maintenance
COPY bin/* /usr/bin/

# Data required for update_mashfiles.sh and rsyncd config
COPY etc/ /etc/
COPY share/repo/mash.template /usr/share/repo/mash.template

# Add symlinks for OSG script output, pointing to /data directory
# Create repo script log directory
# Create symlink to mirrorlist
# Disable Apache welcome page
# Set Apache docroot to /usr/local/repo
RUN for i in mash mirror repo repo.previous repo.working ; do mkdir -p /data/$i ; ln -s /data/$i /usr/local/$i ; done && \
    mkdir /var/log/repo && \
    ln -s /data/mirror /usr/local/repo/mirror && \
    truncate --size 0 /etc/httpd/conf.d/welcome.conf && \
    perl -pi -e 's#/var/www/html#/usr/local/repo#g' /etc/httpd/conf/httpd.conf

EXPOSE 80/tcp
EXPOSE 873/tcp
