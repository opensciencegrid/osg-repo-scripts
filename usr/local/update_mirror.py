#!/usr/bin/python

import urllib2
import time
import sys
import commands
from socket import gethostname

def log(log):
        print time.strftime("%a %m/%d/%y %H:%M:%S %Z: ", time.localtime()),log

repos = ["osg-development", "osg-release", "osg-testing", "osg-contrib", "osg-upcoming-development", "osg-upcoming-release", "osg-upcoming-testing"]
archs = ["i386", "x86_64"]
oshosts = {
    "el5": ["http://mirror.hep.wisc.edu/upstream", "http://mirror.batlab.org/repos/osg/3.0/el5", "http://t2.unl.edu/osg/3.0/el5"],
    "el6": ["http://mirror.batlab.org/repos/osg/3.0/el6", "http://t2.unl.edu/osg/3.0/el6"]
}
version = "3.0"

threshold = 24 #hours

log("Using following parameters")
log("repos:"+str(repos))
log("hosts:"+str(oshosts))
log("archs:"+str(archs))
log("threshold:"+str(threshold)+" (hours)")
print

#gethostname() returns actual instance name (like repo2.grid.iu.edu)
hostname="repo.grid.iu.edu"
if gethostname() == "repo-itb.grid.iu.edu":
	hostname="repo-itb.grid.iu.edu"

def test(os,hosts,repo,arch):
        list = ["http://"+hostname+"/"+version+"/"+os+"/"+repo+"/"+arch] #repo.grid should always exist
        for host in hosts:
                url=host+"/"+repo+"/"+arch
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

for os in oshosts.keys():
    log("evacuating live dir for "+os)

    #creating new mirror_prev
    commands.getstatusoutput("rm -rf /usr/local/mirror/"+version+"/."+os+".prev")
    commands.getstatusoutput("cp -r /usr/local/mirror/"+version+"/."+os+".new /usr/local/mirror/"+version+"/."+os+".prev")

    #pointing mirror to previous
    commands.getstatusoutput("ln -f -s -T /usr/local/mirror/"+version+"/."+os+".prev /usr/local/mirror/"+version+"/"+os)

    #empty new mirror
    commands.getstatusoutput("rm -rf /usr/local/mirror/"+version+"/."+os+".new/*")

    log("checking for "+os)
    hosts = oshosts[os]
    for repo in repos:
            for arch in archs:
                    list = test(os,hosts,repo,arch)
                    commands.getstatusoutput("mkdir -p /usr/local/mirror/"+version+"/."+os+".new/"+repo)
                    f = open("/usr/local/mirror/"+version+"/."+os+".new/"+repo+"/"+arch, "w")
                    for m in list:
                            f.write(m+"\n")
                    f.close()       

    #pointing mirror to mirror_new
    commands.getstatusoutput("ln -s -f -T /usr/local/mirror/"+version+"/."+os+".new /usr/local/mirror/"+version+"/"+os)

log("all done")

