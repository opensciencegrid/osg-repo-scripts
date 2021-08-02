FROM opensciencegrid/software-base:3.6-el7-release

# Install dependencies
# Note that OSG builds of mash and createrepo are necessary
RUN \
    yum update -y \
    && yum install -y --enablerepo=devops-itb \
      mash \
    && yum install -y --enablerepo=devops \
      repo-update-cadist \
    && yum install -y \
      lftp \
      parallel \
      httpd \
      repoview \
      rsync \
      which \
    && yum clean all && rm -rf /var/cache/yum/*

# supervisord and cron configs
COPY docker/supervisor-*.conf /etc/supervisord.d/
COPY docker/*.cron /etc/cron.d/

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
