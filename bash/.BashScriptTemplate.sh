#!/bin/bash
# To enable and disable tracing use:  set -x (On) set +x (Off)

# =========================
# Author:         Jon Zeolla (JZeolla)
# Creation date:  *Creation Date*
# File Type:      *File Type*
# Version:        *Version*
# Description:    *Description*
#
# Notes
# - *Ideas for Improvement*
# - *Good reference information*
# - Anything that has a placeholder value is tagged with TODO.
#
# =========================


## Begin Logging



## Global Instantiations
# Constant Variables
declare -r logFile=/home/jzeolla/example.txt

# Integer Variables
declare -i var=10

# Variables
EXIT_CODE=0


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
echo -e "$0: $* completed at [`date`] as PID $$ with $- flags" >> $logFile
exit $EXIT_CODE
