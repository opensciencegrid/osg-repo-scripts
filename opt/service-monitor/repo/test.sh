#!/bin/bash

###################################################################################################
#
# Service test script
#
###################################################################################################

service=repo
logalert=/opt/service-monitor/$service/bin/logalert
logdir=/var/log/repo

#run logalert for each repo

for repo in $(< /etc/osg-koji-tags/osg-tags); do
  log=$logdir/update_repo.$repo.err

  grep ERR "$log" | tail -100 | $logalert "$service.$repo.error" "[$service] [ERROR] $log"
done

tail -100 $logdir/update_mirror.err | $logalert ${service}.update_mirror.err "[$service] [ERROR] $logdir/update_mirror.err"

#report status
time=`date +%s`
echo "<ServiceMonitorStatus><Status>OK</Status><LastRun>$time</LastRun></ServiceMonitorStatus>" > /opt/service-monitor/$service/www/status.xml

