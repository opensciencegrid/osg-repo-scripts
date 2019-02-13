#!/usr/bin/python

import urllib2
import time
import sys
import os
import shutil
import socket
import fcntl
import errno

def log(log):
    print time.strftime("%a %m/%d/%y %H:%M:%S %Z: ", time.localtime()),log

def lock(path):
    dir = os.path.dirname(path)
    if dir and not os.path.exists(dir):
        os.makedirs(dir)
    lock_fd = os.open(path, os.O_WRONLY | os.O_CREAT)
    try:
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except IOError, e:
        if e.errno == errno.EWOULDBLOCK:
            log("Script appears to already be running.")
            sys.exit(1)

lock("/var/lock/repo/update-mirror.lk")

tagfile = open("/etc/osg-koji-tags/osg-tags", "r")
tags = [tag.rstrip("\n").split(":")[0] for tag in tagfile]
tags = sorted(set(tags))
tagfile.close()

archs = ["i386", "x86_64"]
mirrorhosts = [
    # list of mirror base urls, where osg/series/dver/repo/arch can be found
    "http://mirror.hep.wisc.edu/upstream",
    "http://t2.unl.edu",
    "http://mirror.grid.uchicago.edu/pub"
]

threshold = 24 #hours
timeout = 10 #seconds
socket.setdefaulttimeout(timeout)

log("Using following parameters")
log("tags:"+str(tags))
log("hosts:"+str(mirrorhosts))
log("archs:"+str(archs))
log("threshold:"+str(threshold)+" (hours)")
log("timeout:"+str(timeout)+" (seconds)")
print

def host2ip(name):
    return socket.getaddrinfo(name, 80, socket.AF_INET)[0][4][0]

#gethostname() returns actual instance name (like repo2.opensciencegrid.org)
hostname="repo.opensciencegrid.org"
if host2ip(socket.gethostname()) == host2ip("repo-itb.opensciencegrid.org"):
    hostname="repo-itb.opensciencegrid.org"

def mkarchurl(host,tag,arch):
    series,dver,repo = tag.split('-')[-3:]
    return '/'.join([host,'osg',series,dver,repo,arch])

def test(hosts,tag,arch):
    # always include repo.opensciencegrid.org in list
    list = [mkarchurl('http://'+hostname,tag,arch)]
    for host in hosts:
        url = mkarchurl(host,tag,arch)
        mdurl=url+"/repodata/repomd.xml"
        log("checking: "+mdurl)
        try:
            response = urllib2.urlopen(mdurl)
            if response.code != 200:
                log("\tbad(non 200) response.code:"+response.code)
            else:
                #make sure the repository is up-to-date
                lastmod_str = response.headers["Last-Modified"]
                lastmodtime = time.strptime(lastmod_str, "%a, %d %b %Y %H:%M:%S %Z") #Thu, 15 Sep 2011 13:34:06 GMT
                age = (time.mktime(time.gmtime()) - time.mktime(lastmodtime))
                if age > 3600 * threshold:
                    log("\ttoo old ("+str(age)+" seconds old) Last-Modified: "+lastmod_str+" .. ignoring")
                else:
                    list.append(url)
                    log("\tall good")
        except urllib2.HTTPError,e:
            #no such repo on this host..
            log("\tURL caught while processing url:"+url+" "+str(e))
        except Exception, e:
            log("\tException caught while processing url:"+url+" "+str(e))

    return list

log("evacuating live dir for osg")

#replace previous mirror
if os.path.exists("/usr/local/mirror/.osg.prev"):
    shutil.rmtree("/usr/local/mirror/.osg.prev")

if os.path.exists("/usr/local/mirror/.osg.new"):
    os.rename("/usr/local/mirror/.osg.new", "/usr/local/mirror/.osg.prev")

#point mirror to previous
if os.path.lexists("/usr/local/mirror/osg"):
    os.unlink("/usr/local/mirror/osg")

os.symlink(".osg.prev", "/usr/local/mirror/osg")

#create new mirror
for tag in tags:
    log("checking for "+tag)
    series,dver,repo = tag.split('-')[-3:]
    repopath = '/'.join(["/usr/local/mirror/.osg.new",series,dver,repo])
    os.makedirs(repopath)
    for arch in archs:
        list = test(mirrorhosts,tag,arch)
        f = open(repopath + "/" + arch, "w")
        for m in list:
            f.write(m+"\n")
        f.close()

#point mirror to new
os.unlink("/usr/local/mirror/osg")
os.symlink(".osg.new", "/usr/local/mirror/osg")

log("all done")

