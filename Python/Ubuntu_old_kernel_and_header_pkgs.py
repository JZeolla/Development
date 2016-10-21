#!/usr/bin/env python2

# =========================
# Author:          Jon Zeolla (JZeolla) - Work derived from others
# Last update:     2016-10-21
# File Type:       Python Script
# Version:         1.0
# Repository:      https://github.com/JonZeolla/Development
# Description:     This is a python script to manage cleanups of old kernel headers on Ubuntu boxes.  See `apt-get autoremove --purge` as a potential alternative for newer machines.
#
# Notes
# - Thank you to Alan Franzoni <contactme@franzoni.eu> (https://www.franzoni.eu/purging-outdated-kernels-on-systems-with-unattended-upgrades/) for the script base.
# - Thank you to Ted Pham <telamon@gmail.com> for the OS selection code to turn on header package name changes for Ubuntu >= 13.04.
# - See `apt-get autoremove --purge` for a possible alternative.
# - Anything that has a placeholder value is tagged with TODO
#
# =========================

# print all installed kernel/headers/etc BUT the current and the latest;
# suitable to be used with apt-get remove.
# requires aptitude to be installed. Works on Ubuntu and probably Debian

import subprocess
import re
import os
import platform

# Workaround Python 2.6 (Ubuntu 10) not having check_output
if "check_output" not in dir( subprocess ):
    def f(*popenargs, **kwargs):
        if 'stdout' in kwargs:
            raise ValueError('stdout argument not allowed, it will be overridden.')
        process = subprocess.Popen(stdout=subprocess.PIPE, *popenargs, **kwargs)
        output, unused_err = process.communicate()
        retcode = process.poll()
        if retcode:
            cmd = kwargs.get("args")
            if cmd is None:
                cmd = popenargs[0]
            raise subprocess.CalledProcessError(retcode, cmd)
        return output
    subprocess.check_output = f


def runcmd(s):
    return subprocess.check_output(s.split())

# Should work for anything until kernel 3.100
kernel_version_pattern = re.compile("[23]\.\d{1,2}\.\d{1,2}-\d{1,3}")
def get_kernel_version(kernelstring):
    return kernel_version_pattern.search(kernelstring).group(0)

def get_providing_packages(pkg):
    return filter(lambda x: x != "",
        map(str.strip,
            runcmd('aptitude search ~i~P%s -F%%p' % pkg).split("\n")
            )
        )

def get_nonmatching_packages(package_list, excluding):
    return [k for k in package_list if not get_kernel_version(k) in
        excluding]

all_kernels = get_providing_packages("linux-image")
all_kernels.sort() # lexicographical

kernel_versions = map(get_kernel_version, all_kernels)
latest_version = kernel_versions[-1]
current_version = get_kernel_version(runcmd("uname -r"))

kernels_to_remove = get_nonmatching_packages(all_kernels, (current_version,
    latest_version))

impl_headers = get_providing_packages("linux-headers")

headers_to_remove = get_nonmatching_packages(impl_headers, (current_version,
    latest_version))

linux_distro = platform.linux_distribution()

if (linux_distro is not None) and (len(linux_distro) > 1) and (linux_distro[0] == 'Ubuntu') and (float(linux_distro[1]) >= 13.04):
    # This seems to be needed in Ubuntu >= 13.04
    base_headers_to_remove = [header.replace("-generic", "") for header in headers_to_remove]
    headers_to_remove += base_headers_to_remove

print " ".join(kernels_to_remove + headers_to_remove)
