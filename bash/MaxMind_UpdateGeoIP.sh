#!/bin/bash
# To enable and disable tracing use:  set -x (On) set +x (Off)

# =========================
# Author:         Jon Zeolla (JZeolla)
# Creation date:  2015-01-26
# File Type:      Bash Script
# Version:        1.0
# Description:    This is a bash script to download and update MaxMind GeoIP
#
# Notes
# - MaxMind's geoipupdate script is an alternative - https://github.com/maxmind/geoipupdate
# - Anything that has a placeholder value is tagged with TODO.
#
# =========================

## Set static variable(s)
declare -r GEOIP_URL="http://geolite.maxmind.com/download/geoip/database"
declare -r GEOLITE_COUNTRY_PATH="GeoLiteCountry"
declare -r GEOLITE_COUNTRY_FILE="GeoIP.dat.gz"
declare -r GEOLITE_COUNTRY_IPV6_PATH=""
declare -r GEOLITE_COUNTRY_IPV6_FILE="GeoIPv6.dat.gz"
declare -r GEOLITE_CITY_PATH=""
declare -r GEOLITE_CITY_FILE="GeoLiteCity.dat.gz"
declare -r GEOLITE_ASNUM_PATH="asnum"
declare -r GEOLITE_ASNUM_FILE="GeoIPASNum.dat.gz"
declare -r GEOLITE_ASNUM_IPV6_PATH="asnum"
declare -r GEOLITE_ASNUM_IPV6_FILE="GeoIPASNumv6.dat.gz"
declare -r PLAYGROUND="/tmp"
declare -r PRODUCTION="/usr/share/GeoIP"
declare -r EMAIL_FILE="GEOIP_$(date +"%F_%H-%M").txt"
declare -r NOTIFY_SRC="example@example.com" # TODO:  Update the notification source
declare -r NOTIFY_DST="example@example.com" # TODO:  Update the notification destination

## Set integer variable(s)
declare -i EXIT_CODE=0

## Set regular global variables
NETCONN="0"

## Load up the array of file(s) to download/validate
declare -a arrayURLList=("${GEOIP_URL}/${GEOLITE_COUNTRY_PATH}/${GEOLITE_COUNTRY_FILE}" "${GEOIP_URL}/${GEOLITE_COUNTRY_IPV6_PATH}/${GEOLITE_COUNTRY_IPV6_FILE}" "${GEOIP_URL}/${GEOLITE_CITY_PATH}/${GEOLITE_CITY_FILE}" "${GEOIP_URL}/${GEOLITE_ASNUM_PATH}/${GEOLITE_ASNUM_FILE}" "${GEOIP_URL}/${GEOLITE_ASNUM_IPV6_PATH}/${GEOLITE_ASNUM_IPV6_FILE}")

## Function to close out the script properly
function closeout() {
if [ "${EXIT_CODE}" == "2" ]; then
    cat ${PLAYGROUND}/${EMAIL_FILE} | mail -s "GeoIP Update:  ERROR running $(hostname):${0} at $(date +%Y-%m-%d_%H:%M)" -a "From: ${NOTIFY_SRC}" ${NOTIFY_DST}
elif [ "${EXIT_CODE}" == "1" ]; then
    cat ${PLAYGROUND}/${EMAIL_FILE} | mail -s "GeoIP Update:  WARNING running $(hostname):${0} at $(date +%Y-%m-%d_%H:%M)" -a "From: ${NOTIFY_SRC}" ${NOTIFY_DST}
elif [ "${EXIT_CODE}" == "0" ]; then
#   Intentionally don't alert on an exit code of 0
#    cat ${PLAYGROUND}/${EMAIL_FILE} | mail -s "GeoIP Update:  No issues running $(hostname):${0} at $(date +%Y-%m-%d_%H:%M)" -a "From: ${NOTIFY_SRC}" ${NOTIFY_DST}
fi

rm ${PLAYGROUND}/${EMAIL_FILE}

exit ${EXIT_CODE}
}


## Validate that certain variables are set correctly
if [ ${PLAYGROUND} == ${PRODUCTION} ]; then
    if [ "${EXIT_CODE}" -lt "2" ]; then EXIT_CODE=2; fi
    echo -e "\nERROR:    '${PLAYGROUND}' and '${PRODUCTION}' must be set to different folders" >> ${PLAYGROUND}/${EMAIL_FILE}
    closeout
fi


## Verify write access to playground and prod
if [ ! -w ${PLAYGROUND} ]; then
    if [ "${EXIT_CODE}" -lt "2" ]; then EXIT_CODE=2; fi
    echo -e "\nERROR:    Unable to write to ${PLAYGROUND}" >> ${PLAYGROUND}/${EMAIL_FILE}
    closeout
elif [ ! -w ${PRODUCTION} ]; then
    if [ "${EXIT_CODE}" -lt "2" ]; then EXIT_CODE=2; fi
    echo -e "\nERROR:    Unable to write to ${PRODUCTION}" >> ${PLAYGROUND}/${EMAIL_FILE}
    closeout
fi


## Cleanup function in case of an unexpected signal
function cleanup() {
# This tests if the directory is writable
[ -w ${PLAYGROUND} ] && rm -f ${PLAYGROUND}/*.dat.gz ${PLAYGROUND}/*.dat || echo "WARNING:  ${PLAYGROUND} is not writable, unable to clean up the playground due to an unexpected signal" >> ${PLAYGROUND}/${EMAIL_FILE}

for url in "${arrayURLList[@]}"
do
    FILE=$(basename ${url})

    if [ -f ${PLAYGROUND}/${FILE%.*}.bkp ]; then
        # Tests if the destination file is writable
        [ -w ${PRODUCTION}/${FILE%.*} ] && mv ${PLAYGROUND}/${FILE%.*}.bkp ${PRODUCTION}/${FILE%.*} || echo -e "ERROR:    ${PRODUCTION}/${FILE%.*} is not writable, unable to reinstate the backups due to an unexpected signal" >> ${PLAYGROUND}/${EMAIL_FILE}
    else
        if [ "${EXIT_CODE}" -lt "1" ]; then EXIT_CODE=1; fi
        echo -e "WARNING:  The script was suddenly stopped and and we were unable to restore ${FILE%.*} to its backup.  It is possible that there is an issue with this file now." >> ${PLAYGROUND}/${EMAIL_FILE}
    fi
done


closeout
}

## Fallback function in case of an issue modifying files in production
function fallback() {
if [ -f ${PLAYGROUND}/${1}.bkp ]; then
    [ -w ${PRODUCTION}/${1} ] && mv ${PLAYGROUND}/${1}.bkp ${PRODUCTION}/${1} || echo -e "ERROR:    ${PRODUCTION}/${1} is not writable, unable to fallback this file" >> ${PLAYGROUND}/${EMAIL_FILE}
else
    if [ "${EXIT_CODE}" -lt "2" ]; then EXIT_CODE=2; fi
    echo -e "ERROR:    ${PRODUCTION}/${1}.bkp did not exist and we were unable to fallback" >> ${PLAYGROUND}/${EMAIL_FILE}
fi
}


## Trap to call cleanup()
trap 'EXIT_CODE=2; cleanup' SIGINT SIGTERM SIGHUP SIGKILL


## Ensure network connectivity
for url in "${arrayURLList[@]}"
do
    /usr/bin/wget -q --spider "${url}"
    if [ "$?" != "0" ]; then
        if [ "${EXIT_CODE}" -lt "2" ]; then EXIT_CODE=2; fi
        echo -e "ERROR:    ${url} is NOT accessible from this machine" >> ${PLAYGROUND}/${EMAIL_FILE}
    else
        NETCONN="1"
        echo -e "INFO:     ${url} is accessible from this machine" >> ${PLAYGROUND}/${EMAIL_FILE}
    fi
done


if [ $NETCONN == "0" ]; then
    echo -e "\n\nERROR:    Unable to proceed due to insufficient network connectivity" >> ${PLAYGROUND}/${EMAIL_FILE}
    closeout
else
    echo -e "\n" >> ${PLAYGROUND}/${EMAIL_FILE}
fi


## Work with data in the playground
for url in "${arrayURLList[@]}"
do
    FILE=$(basename ${url})

    # Make a backup of production
    if [ -f ${PRODUCTION}/${FILE%.*} ]; then
        [ -w ${PLAYGROUND} ] && cp -p ${PRODUCTION}/${FILE%.*} ${PLAYGROUND}/${FILE%.*}.bkp || echo -e "ERROR:    ${PLAYGROUND} is not writable, unable to take a backup of ${PRODUCTION}/${FILE%.*}" >> ${PLAYGROUND}/${EMAIL_FILE}
    else
        if [ "${EXIT_CODE}" -lt "1" ]; then EXIT_CODE=1; fi
        echo -e "WARNING:  ${PRODUCTION}/${FILE%.*} was unable to be backed up because it does not exist" >> ${PLAYGROUND}/${EMAIL_FILE}
    fi

    echo -e "INFO:     Downloading ${url}" >> ${PLAYGROUND}/${EMAIL_FILE}

    # Get the new file and unzip it
    /usr/bin/wget -t3 -T15 -P ${PLAYGROUND}/ "${url}" --quiet && /bin/gunzip -f ${PLAYGROUND}/$FILE

    # Check for issues with the wget and/or gunzip
    if [ "$?" != "0" ]; then
        if [ "${EXIT_CODE}" -lt "2" ]; then EXIT_CODE=2; fi
        [ -w ${PLAYGROUND}/${FILE%.*} ] && rm -f ${PLAYGROUND}/${FILE%.*} ${PLAYGROUND}/$FILE || echo -e "ERROR:    ${PLAYGROUND}/${FILE%.*} is not writable or does not exist, unable to clean up the playground" >> ${PLAYGROUND}/${EMAIL_FILE}
        echo -e "ERROR:    Failed to download and decompress $FILE\n" >> ${PLAYGROUND}/${EMAIL_FILE}
    else
        echo -e "INFO:     Download of $FILE was successful\n" >> ${PLAYGROUND}/${EMAIL_FILE}
    fi
done


## Move the final playground files to production
for url in "${arrayURLList[@]}"
do
    FILE=$(basename ${url})

    if [ -f ${PLAYGROUND}/${FILE%.*} ]; then
        [ -w ${PRODUCTION} ] && cp -p ${PLAYGROUND}/${FILE%.*} ${PRODUCTION}/${FILE%.*} || echo -e "ERROR:    ${PRODUCTION} is not writable, unable to put the updated ${FILE%.*} into production" >> ${PLAYGROUND}/${EMAIL_FILE}

        # Check for issues with the cp
        if [ "$?" != "0" ]; then
            fallback ${FILE%.*}
        else
            [ -w ${PLAYGROUND}/${FILE%.*} ] && rm -f ${PLAYGROUND}/${FILE%.*}.bkp ${PLAYGROUND}/${FILE%.*} || echo -e "ERROR:    ${PLAYGROUND}/${FILE%.*} is not writable, unable to cleanup the playground" >> ${PLAYGROUND}/${EMAIL_FILE}
        fi
    fi
done


## Exit with a message relating to the error code
if [ "${EXIT_CODE}" == "2" ]; then
    echo -e "\nERROR:    There was an issue with at least one of the file updates" >> ${PLAYGROUND}/${EMAIL_FILE}
elif [ "${EXIT_CODE}" == "1" ]; then
    echo -e "\nWARNING:  There was a possible issue with at least one of the file updates, likely the fact that there was no production file to backup" >> ${PLAYGROUND}/${EMAIL_FILE}
elif [ "${EXIT_CODE}" == "0" ]; then
    echo -e "\nINFO:     All files were updated successfully" >> ${PLAYGROUND}/${EMAIL_FILE}
fi

closeout
