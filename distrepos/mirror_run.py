"""
This module contains the functions for populating mirrors for a single tag.
The main entry point is update_mirrors_for_tag(); other functions are helpers.
"""

import logging
from distrepos.params import Options, Tag
from distrepos.tag_run import update_release_repos
import typing as t
import socket
import string
import os
import requests
from datetime import datetime, timedelta
from pathlib import Path

_log = logging.getLogger(__name__)

def _get_baseline_urls() -> t.List[str]:
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

def get_mirror_base_for_arch(hostname: str, tag: Tag, arch: str) -> str:
    path_arch = string.Template(tag.arch_rpm_mirror_base).safe_substitute({"ARCH": arch})
    # TODO this might be a misuse of os.path.join. The more appropriate function,
    # urllib.parse.urljoin, is very sensitive to leading/trailing slashes in the path parts though
    return os.path.join(hostname, path_arch)

def get_repomd_for_mirror_base(mirror_base: str) -> str:
    return os.path.join(mirror_base, 'repodata', 'repomd.xml')

def test_single_mirror(repodata_url: str) -> bool:
    _log.info(f"Checking for existence and up-to-dateness of {repodata_url}")
    response = requests.get(repodata_url, timeout=10)
    if response.status_code != 200:
        _log.warning(f"bad(non 200) response.code for mirror {repodata_url}: {response.status_code}")
        return False
    else:
        #make sure the repository is up-to-date
        lastmod_str = response.headers["Last-Modified"]
        lastmodtime = datetime.strptime(lastmod_str, "%a, %d %b %Y %H:%M:%S %Z") #Sun, 15 Sep 2024 13:34:06 GMT
        age = datetime.now() - lastmodtime
        if datetime.now() - lastmodtime > timedelta(hours=24):
            _log.warning(f"Mirror {repodata_url} too old ({age} seconds old) Last-Modified: {lastmod_str} ... ignoring")
            return False
        else:
            _log.debug(f"Mirror {repodata_url} all good")
            return True

def update_mirrors_for_tag(options: Options, tag: Tag):
    mirror_hostnames = _get_baseline_urls() + options.mirror_hosts

    for arch in tag.arches:
        good_mirrors = []
        for hostname in mirror_hostnames:
            _log.info(f"Checking mirror {hostname}")
            mirror_base = get_mirror_base_for_arch(hostname, tag, arch)
            repodata_url = get_mirror_base_for_arch(hostname, tag, arch)
            if test_single_mirror(repodata_url):
                good_mirrors.append(mirror_base)

        working_path = Path(options.mirror_working_root) / tag.dest / arch
        prev_path = Path(options.mirror_prev_root) / tag.dest / arch
        dest_path = Path(options.mirror_root) / tag.dest / arch

        _log.info(f"Writing working mirror file {working_path}")
        # ensure the output path exists
        working_path.parent.mkdir(parents=True, exist_ok=True)

        with open(working_path, 'w') as mirrorf:
            mirrorf.write('\n'.join(good_mirrors))

        update_release_repos(dest_path, working_path, prev_path)
    

