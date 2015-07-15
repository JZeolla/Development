#!/bin/bash
# To enable and disable tracing use:  set -x (On) set +x (Off)

# =========================
# Author:          Jon Zeolla (JZeolla)
# Last update:     2015-07-15
# File Type:       Bash Script
# Version:         1.0
# Repository:      https://github.com/JonZeolla
# Description:     This is a basic script meant to be run via a cron at @reboot to ensure persistent NIC settings for systems that evaluate network traffic (such as IDSs).
#
# Notes
# - Reference the blog post at http://pevma.blogspot.com/2014/03/suricata-prepearing-10gbps-network.html
# - Anything that has a placeholder value is tagged with TODO.
#
# =========================

# Disable network offloading for everything
ethtool -K eth0 rx off
ethtool -K eth0 tx off
ethtool -K eth0 sg off
ethtool -K eth0 tso off
ethtool -K eth0 ufo off
ethtool -K eth0 gso off
ethtool -K eth0 gro off
ethtool -K eth0 lro off
ethtool -K eth0 rxvlan off
ethtool -K eth0 txvlan off
ethtool -K eth0 rxhash off

# Set the rx ring parameter to the pre-set max
ethtool -G eth0 rx 4096

# Set UDPv4 and UDPv6 to use the (IP Src, IP Dst, Src Port, Dst Port) tuple instead of (IP Src, IP Dst)
ethtool -N eth0 rx-flow-hash udp4 sdfn
ethtool -N eth0 rx-flow-hash udp6 sdfn

# Generate an interrupt after each frame/millisecond, minimizing latency but increasing load
ethtool -C eth0 rx-usecs 1 rx-frames 0

# Disable adaptive interrupt for rx because we are ok with up to one interrupt per received frame
ethtool -C eth0 adaptive-rx off

