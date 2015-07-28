#!/bin/bash
# To enable and disable tracing use:  set -x (On) set +x (Off)

# =========================
# Author:          Jon Zeolla (JZeolla)
# Last update:     2015-07-28
# File Type:       Bash Script
# Version:         1.1
# Repository:      https://github.com/JonZeolla
# Description:     This is a basic script meant to be run via a cron at @reboot to ensure persistent NIC settings for systems that evaluate network traffic (such as IDSs).
#
# Notes
# - Reference the blog post at http://pevma.blogspot.com/2014/03/suricata-prepearing-10gbps-network.html
# - Anything that has a placeholder value is tagged with TODO.
#
# =========================

# Set the interfaces which are being used as sniffers and iterate through them
for interface in eth0
do
        # Disable NIC offloading for everything to ensure that the Suricata process sees everything as it was on the wire
        ethtool -K "${interface}" rx off
        ethtool -K "${interface}" tx off
        ethtool -K "${interface}" sg off
        ethtool -K "${interface}" tso off
        ethtool -K "${interface}" ufo off
        ethtool -K "${interface}" gso off
        ethtool -K "${interface}" gro off
        ethtool -K "${interface}" lro off
        ethtool -K "${interface}" rxvlan off
        ethtool -K "${interface}" txvlan off
        ethtool -K "${interface}" rxhash off

        # Set the rx ring parameter to the pre-set max
        ethtool -G "${interface}" rx 4096

        # Load balance UDP flows using {IP Src, IP Dst, Src Port, Dst Port} for UDPv4 and UDPv6 instead of the default {IP Src, IP Dst}
        ethtool -N "${interface}" rx-flow-hash udp4 sdfn
        ethtool -N "${interface}" rx-flow-hash udp6 sdfn

        # Generate an interrupt after each frame/millisecond, minimizing latency but increasing load
        ethtool -C "${interface}" rx-usecs 1 rx-frames 0

        # Disable adaptive interrupt for rx because we are ok with up to one interrupt per received frame
        ethtool -C "${interface}" adaptive-rx off
done
