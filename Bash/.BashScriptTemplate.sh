#!/bin/bash
# To enable and disable tracing use:  set -x (On) set +x (Off)

# =========================
# Author:          Jon Zeolla (JZeolla)
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


## Global Instantiations
# Constant Variables
declare -r logFile=/home/jzeolla/example.txt # Could also use /usr/bin/logger -t <tag> to send via syslog

# Integer Variables
declare -i var=10

# Variables
EXIT_CODE=0

## Begin Logging
exec 1> >(logger -s -t $(hostname)_$(readlink -f ${0})) 2>&1

## Functions
function test
{
  echo -e "test"
  exit 1
}


## Check syntax



## Sanatize variables, syntax, and input file(s)



## Beginning of main script
# Only call a function if it exists - declare -F Function &>/dev/null && Function


## Cleanup


## Stop Logging and exit appropriately
echo -e "$0: $* completed at [`date`] as PID $$ with $- flags" >> "${logFile}"

exit "${EXIT_CODE}"
