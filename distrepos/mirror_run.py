"""
This module contains the functions for populating mirrors for a single tag.
The main entry point is get_mirrors_for_tag(); other functions are helpers.
"""

from distrepos.params import Options, Tag
import typing as t
import socket
import string
import os
import requests
from datetime import datetime, timedelta


def _get_baseline_urls() -> t.List[str]:
    #gethostname() returns actual instance name (like repo2.opensciencegrid.org)
    timeout = 5
    socket.setdefaulttimeout(timeout)
    if 'repo-itb' in socket.gethostname():
        return [
            "http://repo-itb.opensciencegrid.org", 
            "http://repo-itb.osg-htc.org"
        ]
    else:
        return [
            "http://repo.opensciencegrid.org", 
            "http://repo.osg-htc.org"
        ]

def _get_repodata_for_arch(hostname: str, tag: Tag, arch: str):
    path_arch = string.Template(tag.arch_rpms_repodata).safe_substitute({"ARCH": arch})
    return os.path.join(hostname, path_arch)


def _test_single_mirror(repodata_url)-> bool:
    print(f"Checking for existence and up-to-dateness of {repodata_url}...")
    response = requests.get(repodata_url, timeout=10)
    if response.status_code != 200:
        print("\tbad(non 200) response.code:"+response.status_code)
        return False
    else:
        #make sure the repository is up-to-date
        lastmod_str = response.headers["Last-Modified"]
        lastmodtime = datetime.strptime(lastmod_str, "%a, %d %b %Y %H:%M:%S %Z") #Sun, 15 Sep 2024 13:34:06 GMT
        age = datetime.now() - lastmodtime
        if datetime.now() - lastmodtime > timedelta(hours=24):
            print("\ttoo old ("+str(age)+" seconds old) Last-Modified: "+lastmod_str+" .. ignoring")
            return False
        else:
            print("\tall good")
            return True

def update_mirrors_for_tag(options: Options, tag: Tag):
    mirror_hostnames = _get_baseline_urls() + options.mirror_hosts

    for hostname in mirror_hostnames:
        print(f"Checking mirror {hostname}...")

        for arch in tag.arches:
            repodata_url = _get_repodata_for_arch(hostname, tag, arch)
            _test_single_mirror(repodata_url)