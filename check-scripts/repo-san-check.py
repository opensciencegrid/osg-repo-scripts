#!/usr/bin/env python3
# -*- coding: utf-8 -*-
from argparse import ArgumentParser
from html.parser import HTMLParser
from subprocess import run
from typing import NamedTuple
import functools
import requests
import shutil
import subprocess
import sys


REPO = "repo.opensciencegrid.org"
REPO_RSYNC = "repo-rsync.opensciencegrid.org"


HTTP = "http"
RSYNC = "rsync"
METHODS = [HTTP, RSYNC]


class TagAndDirectory(NamedTuple):
    tag: str
    directory: str
    should_have_condor: bool


class DirListParser:
    def __init__(self):
        self.dir_listing = []
        self.rpm_listing = []

    def read_data(self, data: str) -> None:
        raise NotImplementedError()


class HTMLDirListParser(HTMLParser, DirListParser):
    def __init__(self):
        HTMLParser.__init__(self)
        DirListParser.__init__(self)

    def handle_starttag(self, tag, attrs):
        #print(tag, attrs)
        attrs_d = dict(attrs)
        if tag == "a" and "href" in attrs_d:
            href = attrs_d["href"]
            if href.endswith(".rpm"):
                self.rpm_listing.append(href)
            elif not href.startswith((".", "/")) and href.endswith("/"):
                self.dir_listing.append(href[:-1])

    def read_data(self, data: str) -> None:
        self.feed(data)


class RsyncDirListParser(DirListParser):
    def handle_line(self, line: str) -> None:
        try:
            mode, size, date, time, name = line.split(None, 4)
        except ValueError:
            return
        if mode.startswith("d") and not name.startswith("."):
            self.dir_listing.append(name)
        elif name.endswith(".rpm"):
            self.rpm_listing.append(name)

    def read_data(self, data: str) -> None:
        for line in data.splitlines():
            self.handle_line(line)


@functools.lru_cache(maxsize=128)
def get_koji_listing(tag):
    latest = "release" not in tag
    ret = run(["osg-koji", "-q", "list-tagged", tag, "--latest" if latest else ""],
              stdout=subprocess.PIPE, encoding="latin-1")
    if ret.returncode == 0:
        return [it.split()[0] for it in ret.stdout.splitlines()]
    else:
        return []


def main(argv=None):
    if argv is None:
        argv = sys.argv

    parser = ArgumentParser()
    parser.add_argument("method",
                        help="The method to check with (http or rsync)",
                        choices=METHODS)
    parser.add_argument("repo",
                        help="The repo host to check",
                        nargs="?", default=None)
    parser.add_argument("--no-koji",
                        help="Do not compare repo against tags in koji",
                        dest="koji", action="store_false")
    args = parser.parse_args(argv[1:])
    method = args.method
    repo = args.repo if args.repo else (REPO if method == HTTP else REPO_RSYNC)
    koji = args.koji

    if koji and not shutil.which("osg-koji"):
        print("osg-koji not found; can't check tags", file=sys.stderr)
        koji = False

    tag_template = "osg-{repobase}-{el}-{level}"
    dir_template = "osg/{repobase}/{el}/{level}/{archdir}"
    repo_tags_and_directories = [
        TagAndDirectory(tag_template.format(**locals()), dir_template.format(**locals()), should_have_condor=True)
            for repobase in ["3.6", "3.6-upcoming", "23-main", "23-upcoming"]
            for el in ["el8", "el9"]
            for level in ["development", "testing", "release"]
            for archdir in ["x86_64", "source/SRPMS"]
    ] + [
        TagAndDirectory(tag_template.format(**locals()), dir_template.format(**locals()), should_have_condor=True)
            for repobase in ["3.6", "3.6-upcoming"]
            for el in ["el7"]
            for level in ["development", "testing", "release"]
            for archdir in ["x86_64", "source/SRPMS"]
    ]
    # TODO: Add contrib, empty, 3.5, etc.

    assert method in METHODS, f"bad method {method} should have been caught"

    if method == HTTP:
        try:
            resp = requests.get(f"https://{repo}/osg")
        except requests.ConnectionError as err:
            return f"Can't connect to repo {repo} via HTTP: {err}"
    elif method == RSYNC:
        ret = run(["rsync", f"rsync://{repo}/osg/"], stdout=subprocess.PIPE)
        if ret.returncode != 0:
            return f"Can't get listing from repo {repo} via RSYNC"

    for td in repo_tags_and_directories:
        tag = td.tag
        dir_ = td.directory
        should_have_condor = td.should_have_condor

        expected_num_srpms = None

        if koji:
            expected_num_srpms = len(get_koji_listing(tag))

        dlp = None
        if method == HTTP:
            resp = requests.get(f"https://{repo}/{dir_}")
            dlp = HTMLDirListParser()
            dlp.read_data(resp.text)
        elif method == RSYNC:
            ret = run(["rsync", f"rsync://{repo}/{dir_}/"], stdout=subprocess.PIPE, encoding="latin-1")
            if ret.returncode != 0:
                print(f"{dir_} could not be queried")
                continue
            dlp = RsyncDirListParser()
            dlp.read_data(ret.stdout)
        assert isinstance(dlp, DirListParser)

        if "repodata" not in dlp.dir_listing:
            print(f"{dir_} does not have a repodata dir")
        num_rpms = len(dlp.rpm_listing)
        if "SRPM" in dir_ and expected_num_srpms is not None:
            #print(f"{dir_:<60} {num_rpms:>4} {expected_num_srpms:>4}")
            if num_rpms < expected_num_srpms:
                # We can only check for "fewer" because we don't have a count of the condor SRPMs
                print(f"{dir_} has fewer RPMs than expected ({num_rpms} vs {expected_num_srpms})")
        elif num_rpms < 5:
            # We don't know how many RPMs there _should_ be so just make sure there's more than a handful
            print(f"{dir_} only has {num_rpms} RPMs")

        if should_have_condor:
            if not filter(lambda f: f.startswith("condor"), dlp.rpm_listing):
                print(f"{dir_} has no condor rpms")

    # TODO: Add tarball-install, cadist

    return 0


if __name__ == "__main__":
    sys.exit(main())
