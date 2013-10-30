###################################################################################################
#
# Service test script
#
###################################################################################################

service=repo
logalert=/opt/service-monitor/$service/bin/logalert

#run logalert
tail -100 /var/log/repo/update_repo.30.el5.development.err | grep "ERR" | $logalert ${service}.30.el5.development.error "[$service] [ERROR] /var/log/update_repo.30.el5.development.err"
tail -100 /var/log/repo/update_repo.30.el5.testing.err | grep "ERR" | $logalert ${service}.30.el5.testing.error "[$service] [ERROR] /var/log/update_repo.30.el5.testing.err"
tail -100 /var/log/repo/update_repo.30.el5.release.err | grep "ERR" | $logalert ${service}.30.el5.release.error "[$service] [ERROR] /var/log/update_repo.30.el5.release.err"
tail -100 /var/log/repo/update_repo.30.el5.contrib.err | grep "ERR" | $logalert ${service}.30.el5.contrib.error "[$service] [ERROR] /var/log/update_repo.30.el5.contrib.err"

tail -100 /var/log/repo/update_repo.30.el6.development.err | grep "ERR" | $logalert ${service}.30.el6.development.error "[$service] [ERROR] /var/log/update_repo.30.el6.development.err"
tail -100 /var/log/repo/update_repo.30.el6.testing.err | grep "ERR" | $logalert ${service}.30.el6.testing.error "[$service] [ERROR] /var/log/update_repo.30.el6.testing.err"
tail -100 /var/log/repo/update_repo.30.el6.release.err | grep "ERR" | $logalert ${service}.30.el6.release.error "[$service] [ERROR] /var/log/update_repo.30.el6.release.err"
tail -100 /var/log/repo/update_repo.30.el6.contrib.err | grep "ERR" | $logalert ${service}.30.el6.contrib.error "[$service] [ERROR] /var/log/update_repo.30.el6.contrib.err"

tail -100 /var/log/repo/update_mirror.err | $logalert ${service}.update_mirror.err "[$service] [ERROR] /var/log/repo/update_mirror.err"

#report status
time=`date +%s`
echo "<ServiceMonitorStatus><Status>OK</Status><LastRun>$time</LastRun></ServiceMonitorStatus>" > /opt/service-monitor/$service/www/status.xml

