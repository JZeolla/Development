#!/bin/bash
# To enable and disable tracing use:  set -x (On) set +x (Off)

# =========================
# Author:          Jon Zeolla (JZeolla)
# Last update:     2015-02-12
# File Type:       Bash Script
# Version:         1.1
# Repository:      https://github.com/JZeolla
# Description:     This is a bash script to download and update MaxMind GeoIP
#
# Notes
# - MaxMind's geoipupdate script is an alternative - https://github.com/maxmind/geoipupdate
# - Anything that has a follow-up or placeholder value is tagged with TODO.
#
# =========================

## Set static variable(s)
declare -r GEOIP_URL="http://geolite.maxmind.com/download/geoip/database"   # Base GeoIP URL
declare -r GEOLITE_COUNTRY_FILE="GeoLiteCountry/GeoIP.dat.gz"               # GeoIP.dat relative URI
declare -r GEOLITE_COUNTRY_IPV6_FILE="GeoIPv6.dat.gz"                       # GeoIPv6.dat relative URI
declare -r GEOLITE_CITY_FILE="GeoLiteCity.dat.gz"                           # GeoLiteCity.dat relative URI
declare -r GEOLITE_ASNUM_FILE="asnum/GeoIPASNum.dat.gz"                     # GeoIPASNum.dat relative URI
declare -r GEOLITE_ASNUM_IPV6_FILE="asnum/GeoIPASNumv6.dat.gz"              # GeoIPASNumv6.dat relative URI
declare -r DEFAULT_PLAYGROUND="/tmp"                                        # Default playground, in case the real playground is inaccessable
declare -r PLAYGROUND="/usr/share/GeoIP/tmp"                                # Playground area for manipulating files.  
declare -r PRODUCTION="/usr/share/GeoIP"                                    # Production area
declare -r EMAIL_FILE="GEOIP_$(date +"%F_%H-%M").txt"                       # Persistent file for managing the email notifications
declare -r NOTIFY_SRC="example@example.com"                                 # TODO:  Update the notification source
declare -r NOTIFY_DST="example@example.com"                                 # TODO:  Update the notification destination

## Set integer variable(s)
declare -i EXIT_CODE=0

## Set regular global variables
NETCONN="0"
BKPDONE="0"

## Load up the array of file(s) to download/validate
declare -a arrayURLList=("${GEOIP_URL}/${GEOLITE_COUNTRY_FILE}" "${GEOIP_URL}/${GEOLITE_COUNTRY_IPV6_FILE}" "${GEOIP_URL}/${GEOLITE_CITY_FILE}" "${GEOIP_URL}/${GEOLITE_ASNUM_FILE}" "${GEOIP_URL}/${GEOLITE_ASNUM_IPV6_FILE}")


## Fallback function in case of an issue modifying files in production
function fallback() {
if [ -s "${PLAYGROUND}/${1}.bkp" ] && [ -s "${PRODUCTION}/${1}" ] && [ "$(/usr/bin/md5sum ${PLAYGROUND}/${1}.bkp | awk '{print $1}')" != "$(/usr/bin/md5sum ${PRODUCTION}/${1} | awk '{print $1}')" ] && [ "${BKPDONE}" == "1" ]; then
    if [ -w "${PRODUCTION}/${1}" ]; then
        echo -e "INFO:     Validated that there is a non-empty backup and a non-empty, writable production file that does not match the backup.  Restoring ${PLAYGROUND}/${1}.bkp to production." | tee -a "${PLAYGROUND}/${EMAIL_FILE}"
        mv "${PLAYGROUND}/${1}.bkp" "${PRODUCTION}/${1}"

        if [ "$?" != "0" ]; then
            if [ "${EXIT_CODE}" -lt "2" ]; then EXIT_CODE=2; fi
            echo -e "ERROR:    Error when attempting to restore the backup for ${PRODUCTION}/${FILE%.*}" | tee -a "${PLAYGROUND}/${EMAIL_FILE}"
        else
            echo -e "INFO:     Successfully restored the backup for ${PRODUCTION}/${FILE%.*}." | tee -a "${PLAYGROUND}/${EMAIL_FILE}"
        fi
    else
        if [ "${EXIT_CODE}" -lt "2" ]; then EXIT_CODE=2; fi
        echo -e "ERROR:    ${PRODUCTION}/${1} is not writable, unable to fallback this file.  Archiving the backup for manual review." | tee -a "${PLAYGROUND}/${EMAIL_FILE}"
        mv "${PLAYGROUND}/${1}.bkp" "${PLAYGROUND}/${1}.bkp.$(date +"%F_%H-%M")"

        if [ "$?" != "0" ]; then
            if [ "${EXIT_CODE}" -lt "1" ]; then EXIT_CODE=1; fi
            echo -e "ERROR:    Unable to archive ${PLAYGROUND}/${1}.bkp as ${PLAYGROUND}/${1}.bkp.$(date +"%F_%H-%M")" | tee -a "${PLAYGROUND}/${EMAIL_FILE}"
        else
            echo -e "INFO:     ${PLAYGROUND}/${1}.bkp was successfully archived as ${PLAYGROUND}/${1}.bkp.$(date +"%F_%H-%M")" | tee -a "${PLAYGROUND}/${EMAIL_FILE}"
        fi
    fi
elif [ "$(/usr/bin/md5sum ${PLAYGROUND}/${FILE%.*}.bkp | awk '{print $1}')" == "$(/usr/bin/md5sum ${PRODUCTION}/${FILE%.*} | awk '{print $1}')" ]; then
    echo -e "INFO:     The backup is identical to the production file.  Removing the backup without restoring it." | tee -a "${PLAYGROUND}/${EMAIL_FILE}"
    rm "${PLAYGROUND}/${1}.bkp"

    if [ "$?" != "0" ]; then
        if [ "${EXIT_CODE}" -lt "1" ]; then EXIT_CODE=1; fi
        echo -e "WARNING:  ${PLAYGROUND}/${1}.bkp was unable to be removed." | tee -a "${PLAYGROUND}/${EMAIL_FILE}"
    else
        echo -e "INFO:     ${PLAYGROUND}/${1}.bkp was successfully removed" | tee -a "${PLAYGROUND}/${EMAIL_FILE}"
    fi
else
    if [ -r "${PRODUCTION}/${1}" ]; then
        if [ "${EXIT_CODE}" -lt "2" ]; then EXIT_CODE=2; fi
        echo -e "ERROR:    ${PLAYGROUND}/${1}.bkp did not exist, was blank, the backup process did not complete properly, or we refused to create a blank file in production.  Removing the backup file ${PLAYGROUND}/${1}.bkp." | tee -a "${PLAYGROUND}/${EMAIL_FILE}" 
        rm "${PLAYGROUND}/${1}.bkp"

        if [ "$?" != "0" ]; then
            if [ "${EXIT_CODE}" -lt "1" ]; then EXIT_CODE=1; fi
            echo -e "WARNING:  ${PLAYGROUND}/${1}.bkp was unable to be removed." | tee -a "${PLAYGROUND}/${EMAIL_FILE}"
        else
            echo -e "INFO:     ${PLAYGROUND}/${1}.bkp was successfully removed" | tee -a "${PLAYGROUND}/${EMAIL_FILE}"
        fi
    else
        if [ "${EXIT_CODE}" -lt "2" ]; then EXIT_CODE=2; fi
        echo -e "ERROR:    There were numerous issues that occurred.  Whatever happened, this instance of the script should be scrutinized.  Removing the backup file ${PLAYGROUND}/${1}.bkp if it exists." | tee -a "${PLAYGROUND}/${EMAIL_FILE}"
        rm "${PLAYGROUND}/${1}.bkp"

        if [ "$?" != "0" ]; then
            if [ "${EXIT_CODE}" -lt "1" ]; then EXIT_CODE=1; fi
            echo -e "WARNING:  ${PLAYGROUND}/${1}.bkp was unable to be removed.  It may not have existed." | tee -a "${PLAYGROUND}/${EMAIL_FILE}"
        else
            echo -e "INFO:     ${PLAYGROUND}/${1}.bkp was successfully removed" | tee -a "${PLAYGROUND}/${EMAIL_FILE}"
        fi
    fi
fi
}


## Function to cleanup and exit properly
function cleanup() {
if [ "${1}" == "trap" ]; then
    if [ "${EXIT_CODE}" -lt "2" ]; then EXIT_CODE=2; fi
    echo -e "\nERROR:    The script was unexpectedly stopped" | tee -a "${PLAYGROUND}/${EMAIL_FILE}"
fi

# This tests if the playground directory is writable and removes any downloaded or uncompressed files that may be lingering
if [ -w "${PLAYGROUND}" ]; then
    rm -f "${PLAYGROUND}"/*.dat.gz* "${PLAYGROUND}"/*.dat
elif [ -f "${PLAYGROUND}" ]; then
    if [ "${EXIT_CODE}" -lt "1" ]; then EXIT_CODE=1; fi
    echo "WARNING:  ${PLAYGROUND} is not writable, unable to clean up the playground" | tee -a "${PLAYGROUND}/${EMAIL_FILE}"
else
    if [ "${EXIT_CODE}" -lt "1" ]; then EXIT_CODE=1; fi
    echo "WARNING:  ${PLAYGROUND} does not exist, unable to clean up the playground" | tee -a "${PLAYGROUND}/${EMAIL_FILE}"
fi

if [ "${1}" == "trap" ]; then
    for url in "${arrayURLList[@]}"
    do
        FILE=$(basename "${url}")

        fallback "${FILE%.*}"
    done
fi

if [ "${EXIT_CODE}" == "2" ]; then
    [ -r "${PLAYGROUND}/${EMAIL_FILE}" ] && cat "${PLAYGROUND}/${EMAIL_FILE}" | mail -s "GeoIP Update:  ERROR running $(hostname):$(readlink -f "${0}") at $(date +%Y-%m-%d_%H:%M)" -a "From: ${NOTIFY_SRC}" "${NOTIFY_DST}"
elif [ "${EXIT_CODE}" == "1" ]; then
    [ -r "${PLAYGROUND}/${EMAIL_FILE}" ] && cat "${PLAYGROUND}/${EMAIL_FILE}" | mail -s "GeoIP Update:  WARNING running $(hostname):$(readlink -f "${0}") at $(date +%Y-%m-%d_%H:%M)" -a "From: ${NOTIFY_SRC}" "${NOTIFY_DST}"
#elif [ "${EXIT_CODE}" == "0" ]; then
#    [ -r "${PLAYGROUND}/${EMAIL_FILE}" ] && cat "${PLAYGROUND}/${EMAIL_FILE}" | mail -s "GeoIP Update:  No issues running $(hostname):$(readlink -f "${0}") at $(date +%Y-%m-%d_%H:%M)" -a "From: ${NOTIFY_SRC}" "${NOTIFY_DST}"
fi

[ -w "${PLAYGROUND}/${EMAIL_FILE}" ] && rm -f "${PLAYGROUND}/${EMAIL_FILE}" || echo -e "ERROR:    Unable to clean up ${PLAYGROUND}/${EMAIL_FILE}\n\nWARNING:  It is possible that this script was unable to send a GeoIP Update email, which could result in unnoticed issues.  Please investigate." | mail -s "GeoIP Update:  ERROR running $(hostname):$(readlink -f "${0}") at $(date +%Y-%m-%d_%H:%M)" -a "From: ${NOTIFY_SRC}" "${NOTIFY_DST}"

exit "${EXIT_CODE}"
}


## Verify write access to playground and prod
if [ ! -w "${PLAYGROUND}" ]; then
    if [ "${EXIT_CODE}" -lt "2" ]; then EXIT_CODE=2; fi
    echo -e "\nERROR:    Unable to write to ${PLAYGROUND}" | tee -a "${DEFAULT_PLAYGROUND}/${EMAIL_FILE}"
    cleanup sanitizefailure
elif [ ! -w "${PRODUCTION}" ]; then
    if [ "${EXIT_CODE}" -lt "2" ]; then EXIT_CODE=2; fi
    echo -e "\nERROR:    Unable to write to ${PRODUCTION}" | tee -a "${PLAYGROUND}/${EMAIL_FILE}"
    cleanup sanitizefailure
fi


## Make sure variables are set correctly
if [ "${PLAYGROUND}" == "${PRODUCTION}" ]; then
    if [ "${EXIT_CODE}" -lt "2" ]; then EXIT_CODE=2; fi
    echo -e "\nERROR:    '${PLAYGROUND}' and '${PRODUCTION}' must be set to different folders" | tee -a "${PLAYGROUND}/${EMAIL_FILE}"
    cleanup sanitizefailure
fi


# trap and call cleanup()
trap 'EXIT_CODE=2; cleanup trap' SIGINT SIGTERM SIGHUP SIGKILL



## Begin main

## Ensure network connectivity
for url in "${arrayURLList[@]}"
do
    /usr/bin/wget -q --spider "${url}"
    if [ "$?" != "0" ]; then
        if [ "${EXIT_CODE}" -lt "2" ]; then EXIT_CODE=2; fi
        echo -e "ERROR:    ${url} is NOT accessible from this machine" | tee -a "${PLAYGROUND}/${EMAIL_FILE}"
    else
        NETCONN="1"
        echo -e "INFO:     ${url} is accessible from this machine" | tee -a "${PLAYGROUND}/${EMAIL_FILE}"
    fi
done


if [ "${NETCONN}" == "0" ]; then
    if [ "${EXIT_CODE}" -lt "2" ]; then EXIT_CODE=2; fi
    echo -e "\n\nERROR:    Unable to proceed due to insufficient network connectivity" | tee -a "${PLAYGROUND}/${EMAIL_FILE}"
    cleanup networkfailure
else
    echo -e "\nINFO:     At least one file was able to be accessed properly, continuing...\n" | tee -a "${PLAYGROUND}/${EMAIL_FILE}"
fi


## Work with data in the playground
# Make a backup of all files
for url in "${arrayURLList[@]}"
do
    FILE=$(basename "${url}")

    # Make a backup of production.  Create a blank backup if the file did not already exist for use tracking state
    if [ -r "${PRODUCTION}/${FILE%.*}" ]; then
        cp -p "${PRODUCTION}/${FILE%.*}" "${PLAYGROUND}/${FILE%.*}.bkp"

        if [ "$?" != "0" ]; then
            if [ "${EXIT_CODE}" -lt "2" ]; then EXIT_CODE=2; fi
            echo -e "ERROR:    Issue copying ${PRODUCTION}/${FILE%.*} to ${PLAYGROUND}/${FILE%.*}.bkp" | tee -a "${PLAYGROUND}/${EMAIL_FILE}"
        fi
    elif [ -f "${PLAYGROUND}" ]; then
        if [ "${EXIT_CODE}" -lt "2" ]; then EXIT_CODE=2; fi
        echo -e "ERROR:    ${PLAYGROUND} is not readable, unable to take a backup of ${PRODUCTION}/${FILE%.*}" | tee -a "${PLAYGROUND}/${EMAIL_FILE}"
    else
        # TODO:  May not want to call this .bkp as it is not intuitive that it is only used for tracking and is not a true backup
        touch "${PLAYGROUND}/${FILE%.*}.bkp"

        if [ "$?" != "0" ]; then
            if [ "${EXIT_CODE}" -lt "2" ]; then EXIT_CODE=2; fi
            echo -e "ERROR:    Unable to touch ${PLAYGROUND}/${FILE%.*}.bkp" | tee -a "${PLAYGROUND}/${EMAIL_FILE}"
        else
            if [ "${EXIT_CODE}" -lt "1" ]; then EXIT_CODE=1; fi
            echo -e "WARNING:  ${PRODUCTION}/${FILE%.*} did not originally exist" | tee -a "${PLAYGROUND}/${EMAIL_FILE}"
        fi
    fi
done

BKPDONE="1"

# Download and decompress the files
for url in "${arrayURLList[@]}"
do
    FILE=$(basename "${url}")

    if [ ! -f "${PLAYGROUND}/${FILE%.*}.bkp" ]; then
        continue
    fi

    echo -e "\nINFO:     Attempting to download ${url}" | tee -a "${PLAYGROUND}/${EMAIL_FILE}"

    # Get the new file and unzip it
    /usr/bin/wget -t3 -T15 -O "${PLAYGROUND}/${FILE}" "${url}" --quiet && /bin/gunzip -f "${PLAYGROUND}/${FILE}"

    # Check for issues with the wget and/or gunzip
    if [ "$?" != "0" ]; then
        if [ "${EXIT_CODE}" -lt "2" ]; then EXIT_CODE=2; fi
        echo -e "ERROR:    Failed to download and decompress ${FILE}" | tee -a "${PLAYGROUND}/${EMAIL_FILE}"

        if [ -w "${PLAYGROUND}/${FILE%.*}" ]; then
            if [ "${EXIT_CODE}" -lt "2" ]; then EXIT_CODE=2; fi && echo -e "ERROR:    ${PLAYGROUND}/${FILE%.*} exists and is writable but we encountered an error while retrieving and decompressing the file.  Attempting to fall back." | tee -a "${PLAYGROUND}/${EMAIL_FILE}"
            fallback "${FILE%.*}"
        elif [ -f "${PLAYGROUND}/${FILE%.*}" ]; then
            if [ "${EXIT_CODE}" -lt "2" ]; then EXIT_CODE=2; fi && echo -e "ERROR:    ${PLAYGROUND}/${FILE%.*} exists but is not writable.  Attempting to fall back." | tee -a "${PLAYGROUND}/${EMAIL_FILE}"
            fallback "${FILE%.*}"
        else
            if [ "${EXIT_CODE}" -lt "2" ]; then EXIT_CODE=2; fi && echo -e "ERROR:    ${PLAYGROUND}/${FILE%.*} does not exist.  Attempting to fall back." | tee -a "${PLAYGROUND}/${EMAIL_FILE}"
            fallback "${FILE%.*}"
        fi
    else
        echo -e "INFO:     Download and decompression of ${FILE} was successful" | tee -a "${PLAYGROUND}/${EMAIL_FILE}"
    fi
done


## Move the final playground files to production
echo -e "" | tee -a "${PLAYGROUND}/${EMAIL_FILE}"

for url in "${arrayURLList[@]}"
do
    FILE=$(basename "${url}")

    if [ ! -f "${PLAYGROUND}/${FILE%.*}.bkp" ]; then
        if [ "${EXIT_CODE}" -lt "1" ]; then EXIT_CODE=1; fi
        echo -e "WARNING:  Unable to create or update ${PRODUCTION}/${FILE%.*}" | tee -a "${PLAYGROUND}/${EMAIL_FILE}"
        continue
    fi

    if [ -f "${PLAYGROUND}/${FILE%.*}" ] && [ -w "${PRODUCTION}" ]; then
        cp -p "${PLAYGROUND}/${FILE%.*}" "${PRODUCTION}/${FILE%.*}"
        if [ "$?" == "0" ]; then
            echo -e "INFO:     Successfully updated ${PRODUCTION}/${FILE%.*}" | tee -a "${PLAYGROUND}/${EMAIL_FILE}"
        fi
    fi

    # Check for issues with the cp
    if [ "$?" != "0" ]; then
        if [ "${EXIT_CODE}" -lt "2" ]; then EXIT_CODE=2; fi
        echo -e "ERROR:    Error when attempting to update ${PRODUCTION}/${FILE%.*}" | tee -a "${PLAYGROUND}/${EMAIL_FILE}"
        fallback "${FILE%.*}"
    else
        if [ -w "${PLAYGROUND}/${FILE%.*}.bkp" ]; then
            rm -f "${PLAYGROUND}/${FILE%.*}.bkp" "${PLAYGROUND}/${FILE%.*}" "${PLAYGROUND}/${FILE%.*}.gz*"
        else
            if [ "${EXIT_CODE}" -lt "2" ]; then EXIT_CODE=2; fi
            echo -e "ERROR:    ${PLAYGROUND}/${FILE%.*}.bkp is not writable, unable to clean up the playground" | tee -a "${PLAYGROUND}/${EMAIL_FILE}"
        fi
    fi
done


## Exit with a message relating to the error code
if [ "${EXIT_CODE}" == "2" ]; then
    echo -e "\nERROR:    There was an issue with at least one of the file updates" | tee -a "${PLAYGROUND}/${EMAIL_FILE}"
elif [ "${EXIT_CODE}" == "1" ]; then
    echo -e "\nWARNING:  There was a possible issue with at least one of the file updates" | tee -a "${PLAYGROUND}/${EMAIL_FILE}"
elif [ "${EXIT_CODE}" == "0" ]; then
    echo -e "\nINFO:     All files were updated successfully" | tee -a "${PLAYGROUND}/${EMAIL_FILE}"
fi

cleanup end
