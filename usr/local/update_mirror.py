#!/usr/bin/python

import urllib2
import time
import sys
import commands
from socket import gethostname

def log(log):
    print time.strftime("%a %m/%d/%y %H:%M:%S %Z: ", time.localtime()),log

tagfile = open("/usr/local/osg-tags", "r")
tags = [tag.rstrip("\n") for tag in tagfile]
tagfile.close()

archs = ["i386", "x86_64"]
mirrorhosts = [
    # list of mirror base urls, where osg/series/dver/repo/arch can be found
    "http://mirror.hep.wisc.edu/upstream",
    "http://mirror.batlab.org/repos",
    "http://t2.unl.edu"
]

threshold = 24 #hours

log("Using following parameters")
log("tags:"+str(tags))
log("hosts:"+str(mirrorhosts))
log("archs:"+str(archs))
log("threshold:"+str(threshold)+" (hours)")
print

#gethostname() returns actual instance name (like repo2.grid.iu.edu)
hostname="repo.grid.iu.edu"
if gethostname() == "repo-itb.grid.iu.edu":
    hostname="repo-itb.grid.iu.edu"

def mkarchurl(host,tag,arch):
    osg,series,dver,repo = tag.split('-')
    return '/'.join([host,osg,series,dver,repo,arch])

def test(hosts,tag,arch):
    # repo.grid should always exist
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

for tag in tags:
    log("evacuating live dir for osg")

    #creating new mirror_prev
    commands.getstatusoutput("rm -rf /usr/local/mirror/.osg.prev")
    commands.getstatusoutput("cp -a /usr/local/mirror/.osg.new /usr/local/mirror/.osg.prev")

    #pointing mirror to previous
    commands.getstatusoutput("ln -f -s -T .osg.prev /usr/local/mirror/osg")

    #empty new mirror
    commands.getstatusoutput("rm -rf /usr/local/mirror/.osg.new/*")

    log("checking for "+tag)
    osg,series,dver,repo = tag.split('-')
    for arch in archs:
        list = test(mirrorhosts,tag,arch)
        repopath = '/'.join(["/usr/local/mirror/.osg.new",series,dver,repo])
        commands.getstatusoutput("mkdir -p " + repopath)
        f = open(repopath + "/" + arch, "w")
        for m in list:
            f.write(m+"\n")
        f.close()       

    #pointing mirror to mirror_new
    commands.getstatusoutput("ln -f -s -T .osg.new /usr/local/mirror/osg")

log("all done")

