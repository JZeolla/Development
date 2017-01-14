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
# Last update:     2017-01-14
# File Type:       Bash Script
# Version:         1.4
# Repository:      https://github.com/JonZeolla/Development
# Description:     This is a basic script meant to be run during startup to ensure persistent NIC settings for systems that evaluate network traffic (such as IDSs).  It was designed to use @reboot via a cron, or rc.local to run during startup.  
#
# Notes
# - References:
#   - https://linux.die.net/man/8/ethtool
#   - http://pevma.blogspot.com/2014/03/suricata-prepearing-10gbps-network.html
#   - https://www.kernel.org/doc/Documentation/networking/scaling.txt
#   - http://www.cubrid.org/blog/dev-platform/understanding-tcp-ip-network-stack/
#   - https://www.coverfire.com/articles/queueing-in-the-linux-network-stack/
#   - http://www.alexonlinux.com/why-interrupt-affinity-with-multiple-cores-is-not-such-a-good-thing
#   - https://greenhost.nl/2013/04/10/multi-queue-network-interfaces-with-smp-on-linux/
#     - Interesting quote: "Hyperthreading creates an artificial layer of abstraction between physical CPU caches and and logical CPUs, which does not contribute to performance, and detracts from performance due to the maintenance of additional queues."
#   - https://blog.cloudflare.com/how-to-receive-a-million-packets/
#   - https://blog.cloudflare.com/how-to-achieve-low-latency/ especially #rfsonintel82599
# - Make sure you have the appropriate permissions to run this
# - Anything that has a placeholder value or requires thought before implementing is tagged with TODO.
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
        if [[ ${ERROR} -ne 78 && ${ERROR} -ne 80 && ${ERROR} -ne 89 ]]; then
                EXIT_CODE=${1}
                errorecho "ERROR on $(hostname) while running $(readlink -f ${0}) at $(date +%Y-%m-%d_%H:%M) with code ${EXIT_CODE}"
                exit ${1}
        fi
}

# trap and call error_out()
trap 'error_out 1' SIGINT SIGTERM SIGHUP SIGKILL

## TODO: Set the interfaces which are being used as sniffers and iterate through them
# TODO: Also consider disabling/configuring for IPv6
for interface in eth0
do
        # Disable NIC offloading and filtering for everything to ensure that the receiving process sees everything as it was on the wire
        for nicfunction in rx tx sg tso ufo gso gro lro rxvlan txvlan ntuple rxhash; do
                /sbin/ethtool -K "${interface}" "${nicfunction}" off || error_out "$?"
        done

        # Disable pause frames
        /sbin/ethtool -A "${interface}" autoneg off rx off tx off || error_out "$?"

        # Generate an interrupt after each frame/millisecond, minimizing latency but increasing load
        /sbin/ethtool -C "${interface}" rx-usecs 1 rx-frames 0 || error_out "$?"

        # Disable adaptive interrupt for rx because we are ok with up to one interrupt per received frame
        /sbin/ethtool -C "${interface}" adaptive-rx off || error_out "$?"

        # Set the rx ring parameter to the pre-set max
        # use `ethtool -g "${interface}" | grep "Pre-set maximums" -A1 | grep RX:` to verify the pre-set max
        # An alternative would be to reduce the rings in an attempt to keep packets in the CPU's L3 cache.  If that is of interest to you, also consider `/sbin/ethtool -L "${interface}" combined 1`.
        /sbin/ethtool -G "${interface}" rx 4096 || error_out "$?"

        # Load balance UDP flows using {IP Src, IP Dst, Src Port, Dst Port} for UDPv4 and UDPv6 instead of the default {IP Src, IP Dst}
        # TODO: Are there specific error codes which should be ignored for the below two commands if this is already set?
        /sbin/ethtool -N "${interface}" rx-flow-hash udp4 sdfn || error_out "$?"
        /sbin/ethtool -N "${interface}" rx-flow-hash udp6 sdfn || error_out "$?"

        # Pin IRQ to local CPU (-x is not really relevant for sniffers (as it configures XPS as opposed to RPS), hence it is left out)
        # TODO: Ensure set_irq_affinity is in your PATH/exists on the system, or change this to be fully qualified
        set_irq_affinity local "${interface}" || error_out "$?"
done

## Stop Logging and exit appropriately
# The stdout output is so that, if this is run as a cron, it will not send an email with a successful run
echo "$(hostname):$(readlink -f ${0}) completed at [`date`] as PID $$ with $- flags and an exit code of ${EXIT_CODE}" >(logger -t $(basename ${0}) -p local1.info)
