#!/bin/bash
# To enable and disable tracing use:  set -x (On) set +x (Off)

# =========================
# Author:          Jon Zeolla (JZeolla, JonZeolla)
# Last update:     *Creation Date*
# File Type:       Bash Script
# Version:         *Version*
# Repository:      *Repository location*
# Description:     *Description*
#
# Notes
# - *Ideas for Improvement*
# - *Good reference information*
# - Anything that has a placeholder value is tagged with TODO.
#
# =========================


## Begin Logging stdout and stderr
exec 1> >(logger -s -t $(basename ${0}) -p local1.info)
exec 2> >(logger -s -t $(basename ${0}) -p local1.err)


## Global Instantiations
# Constant Variables
#declare -r var
# Array Variables
#declare -a var
# Associative Arrays
#declre -A var
# Integer Variables
declare -i EXIT_CODE=0
# Generic Global Variables
#


## Functions
function errorecho() {
        >&2 echo "${1}"
}

function cleanup() {
        # Cleanup temporary files, etc.
}

function error_out() {
        EXIT_CODE=${1:-2}
        errorecho "ERROR on $(hostname) while running $(readlink -f ${0}) $* at $(date +%Y-%m-%d_%H:%M) with code ${EXIT_CODE}"
        cleanup
        exit "${EXIT_CODE}"
}

function quit() {
        EXIT_CODE=${1:-0}
        cleanup
        exit "${EXIT_CODE}"
}


## Handle signals
# trap common kill signals and call error_out()
trap 'error_out' SIGINT SIGTERM SIGHUP 


## Check syntax



## Sanatize variables, syntax, and input file(s)



## Beginning of main script
# Only call a function if it exists - declare -F Function &>/dev/null && Function


## Cleanup



## Stop Logging and exit appropriately
echo "$(hostname):$(readlink -f ${0}) $* completed at [`date`] as PID $$ with $- flags and an exit code of ${EXIT_CODE}"
quit
