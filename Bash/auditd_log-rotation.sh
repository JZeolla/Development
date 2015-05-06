#!/bin/bash
# To enable an disable tracing use:  set -x (On) set +x (Off)

# =========================
# Author:          Jon Zeolla (JZeolla)
# Last update:     2015-05-04
# File Type:       Bash Script
# Version:         1.0
# Repository:      https://github.com/JZeolla
# Description:     This is a bash script to rotate and compress audit logs, meant for use in a daily cron job at midnight
#
# Notes
# - If the name of this script changes, you should update any syslog monitoring programs, as this is tagged via the script name
# - This script assumes that the only thing rotating audit.log is this script (i.e. auditd.conf contains "max_log_file_action = IGNORE"), although I did add some logic to catch already rotated files (not perfect)
# - Reference http://unixadminschool.com/blog/2014/06/linux-admin-reference-configuring-auditd-in-redhat-enterprise-linux/ and https://www.redhat.com/archives/linux-audit/2011-June/msg00070.html
# - Anything that has a placeholder value is tagged with TODO.
#
# =========================

## Global Instantiations
# Variables
EXIT_CODE=0                                         # Script exit code
EXIT_VALUE=0                                        # Exit value for the rotation
NOTIFY_SRC="example@example.com"                    # TODO:  Notification source
NOTIFY_DST="example@example.com"                    # TODO:  Notification destination
AUDIT_LOG_DST="/var/log/audit"                      # Audit log destination

## Begin Logging stdout and stderr
exec 1> >(logger -s -t $(basename $0)) 2>&1

## Functions
function error_out() {
    echo "$(hostname):$(readlink -f ${0}) exited abnormally during ${1} with code ${EXIT_VALUE}" | tee /dev/stderr | mail -s "Alertd:  ERROR during ${1} while running $(hostname):$(readlink -f ${0}) at $(date +%Y-%m-%d_%H:%M)" -a "From: ${NOTIFY_SRC}" "${NOTIFY_DST}"
    if [[ (${2} -gt 1) || ($EXIT_CODE -gt 1) ]]; then
        shopt -u extglob
        exit ${2}
    fi
}

# trap and call error_out()
trap 'EXIT_CODE=2; error_out trap' SIGINT SIGTERM SIGHUP SIGKILL

## Check syntax
# This is meant to run as a cron and doesn't accept input

## Sanatize variables, syntax, and input file(s)
# This is meant to run as a cron and doesn't accept input

## Beginning of main script
# Cleanup gzip'd files with an mtime +7
find ${AUDIT_LOG_DST}/ -name "audit.log.*.gz" -mtime +7 -exec rm {} \;
EXIT_VALUE="$?"
if [ "${EXIT_VALUE}" != "0" ]; then
    error_out "cleanup" "2"
fi
# If there are gzip'd files which weren't already caught, they should be unaffected by the below logic and will be caught by the above commands in time

# Rename and compress files that were rotated normally and not compressed (if they exist)
shopt -s extglob
ls ${AUDIT_LOG_DST}/audit.log.+([0-9])
RESULT="$?"
if [[ $RESULT -eq "0" ]]; then
    for oldfile in $(ls ${AUDIT_LOG_DST}/audit.log.+([0-9]))
    do
        newfile="audit.log.$(date +%Y-%m-%d_%H:%M -r ${oldfile})"
        mv ${oldfile} ${AUDIT_LOG_DST}/${newfile}
        EXIT_VALUE="$?"
        if [ "${EXIT_VALUE}" != "0" ]; then
            error_out "initial renaming" "2"
        fi

        gzip -qf ${AUDIT_LOG_DST}/${newfile}
        EXIT_VALUE="$?"
        gzip -qf ${AUDIT_LOG_DST}/${newfile}
        EXIT_VALUE="$?"
        if [ "${EXIT_VALUE}" != "0" ]; then
            error_out "initial compression" "2"
        fi
    done
fi

# Rotate the auditd log
/usr/sbin/service auditd rotate
EXIT_VALUE="$?"
if [ "${EXIT_VALUE}" != "0" ]; then
    error_out "rotation" "2"
fi

# Need to put some time between the rotate and the ls.  This isn't the cleanest solution because if the audit.log.+([0-9]) matches more than one file it will throw an error but that's essentially what we're looking to do anyway (loop until match then break)...
timer=1
while [ ! -f ${AUDIT_LOG_DST}/audit.log.+([0-9]) ]; do
    sleep .10s
    ((timer++))
    if [[ $timer -gt 100 ]]; then
        error_out "the while loop" "2"
    fi
done

# Rename the rotated auditd file to yesterday's date (only if only the file from immediatly prior matches - otherwise error)
if [[ $(ls ${AUDIT_LOG_DST}/audit.log.+([0-9]) | wc -w) -eq 1 ]]; then
    for oldfile in $(ls ${AUDIT_LOG_DST}/audit.log.+([0-9])); do
        newfile="audit.log.$(date +%Y-%m-%d -d "yesterday")"
        mv ${oldfile} ${AUDIT_LOG_DST}/${newfile}
        EXIT_VALUE="$?"
        if [ "${EXIT_VALUE}" != "0" ]; then
            error_out "secondary renaming" "2"
        fi

        # Compress newly rotated files
        gzip -qf ${AUDIT_LOG_DST}/${newfile}
        EXIT_VALUE="$?"
        if [ "${EXIT_VALUE}" != "0" ]; then
            error_out "secondary compression" "2"
        fi
    done
else
    error_out "a check of the newly rotated log" "2"
fi
shopt -u extglob


## Stop Logging and exit appropriately
# This is meant to run as a cron and doesn't use temporary files, as all logging is done via syslog
echo "$(hostname):$(readlink -f ${0}) completed at [`date`] as PID $$ with $- flags and an exit code of ${EXIT_CODE}"

exit ${EXIT_CODE}
