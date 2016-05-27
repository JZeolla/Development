#!/bin/bash
# To enable and disable tracing use:  set -x (On) set +x (Off)

### BEGIN INIT INFO
# Provides:          tune-network-interface
# Required-Start:    $remote_fs $syslog $network
# Required-Stop:     
# Default-Start:     2 3 4 5
# Default-Stop:      
# Short-Description: Tune the NIC(s) to be properly configured sniffers
### END INIT INFO

# =========================
# Author:          Jon Zeolla (JZeolla)
# Last update:     2016-05-27
# File Type:       Bash Script
# Version:         1.3
# Repository:      https://github.com/JonZeolla/Development
# Description:     This is a basic script meant to be run during startup to ensure persistent NIC settings for systems that evaluate network traffic (such as IDSs).  It was designed to use @reboot via a cron, or rc.local to run during startup.  
#
# Notes
# - Reference the blog post at http://pevma.blogspot.com/2014/03/suricata-prepearing-10gbps-network.html
# - Anything that has a placeholder value is tagged with TODO.
#
# =========================

## Begin Logging stdout and stderr separately
exec 1> >(logger -t $(basename ${0}) -p local1.info)
exec 2> >(logger -s -t $(basename ${0}) -p local1.err)

## Global Instantiations
# Variables
EXIT_CODE=0 # Script exit code


## Functions
function errorecho() {
	>&2 echo "${1}"
}

function error_out() {
	ERROR=${1}
	# Known error codes to ignore because they occur when you attempt to configure a setting via ethtool that is already set
	if [[ ${ERROR} -ne 80 && ${ERROR} -ne 89 ]]; then
		EXIT_CODE=${1}
	        errorecho "ERROR on $(hostname) while running $(readlink -f ${0}) at $(date +%Y-%m-%d_%H:%M) with code ${EXIT_CODE}"
		exit ${1}
	fi
}

# trap and call error_out()
trap 'error_out 1' SIGINT SIGTERM SIGHUP SIGKILL

## Set the interfaces which are being used as sniffers and iterate through them
for interface in eth0
do
        # Disable NIC offloading for everything to ensure that the Suricata process sees everything as it was on the wire
        ethtool -K "${interface}" rx off || error_out "$?"
        ethtool -K "${interface}" tx off || error_out "$?"
        ethtool -K "${interface}" sg off || error_out "$?"
        ethtool -K "${interface}" tso off || error_out "$?"
        ethtool -K "${interface}" ufo off || error_out "$?"
        ethtool -K "${interface}" gso off || error_out "$?"
        ethtool -K "${interface}" gro off || error_out "$?"
        ethtool -K "${interface}" lro off || error_out "$?"
        ethtool -K "${interface}" rxvlan off || error_out "$?"
        ethtool -K "${interface}" txvlan off || error_out "$?"
        ethtool -K "${interface}" rxhash off || error_out "$?"

        # Set the rx ring parameter to the pre-set max
        ethtool -G "${interface}" rx 4096 || error_out "$?"

        # Load balance UDP flows using {IP Src, IP Dst, Src Port, Dst Port} for UDPv4 and UDPv6 instead of the default {IP Src, IP Dst}
        # TODO - Are there specific error codes which should be ignored for the below two commands if this is already set?
        ethtool -N "${interface}" rx-flow-hash udp4 sdfn || error_out "$?"
        ethtool -N "${interface}" rx-flow-hash udp6 sdfn || error_out "$?"

        # Generate an interrupt after each frame/millisecond, minimizing latency but increasing load
        ethtool -C "${interface}" rx-usecs 1 rx-frames 0 || error_out "$?"

        # Disable adaptive interrupt for rx because we are ok with up to one interrupt per received frame
        ethtool -C "${interface}" adaptive-rx off || error_out "$?"
done

## Stop Logging and exit appropriately
# The stdout output is so that, if this is run as a cron, it will not send an email with a successful run
echo "$(hostname):$(readlink -f ${0}) completed at [`date`] as PID $$ with $- flags and an exit code of ${EXIT_CODE}" >(logger -t $(basename ${0}) -p local1.info)
