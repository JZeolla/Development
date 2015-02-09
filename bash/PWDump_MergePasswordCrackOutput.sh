#!/bin/bash
#To enable and disable tracing use:  set -x (On) set +x (Off)

# =========================
# Author:         Jon Zeolla (JZeolla)
# Creation date:  2012-10-22
# File Type:      Bash Script
# Version:        1.0
# Description:    This is a bash script to merge the output of a password cracking tool with the original dump into a csv, putting all information for one account on one row.
#
# Notes
# - If you consider this script useful, you should invest in a better password cracking tool.
# - Anything that has a placeholder value is tagged with TODO.
#
# =========================

## Set high level variables
CurrentDate=$(date +"%F_%H-%M")

## Set file variables
DumpFile="/home/user/Dump.csv"                    # TODO: Replace this with the appropriate directory
CrackedFile="/home/user/Cracked.csv"              # TODO: Replace this with the appropriate directory
SanatizedDump="/home/user/SanatizedDump"          # TODO: Replace this with the appropriate directory
SanatizedCracked="/home/user/SanatizedCracked"    # TODO: Replace this with the appropriate directory
OutputFile="/home/user/${CurrentDate}.csv"        # TODO: Replace this with the appropriate directory

## Cleanup
rm -f ${SanatizedDump} ${SanatizedCracked} ${OutputFile}

## Sanitize files
sed -e 's/ /+/g' -e 's/(/%28/g' -e 's/)/%29/g' -e 's/\n//g' "${DumpFile}" >> "${SanatizedDump}"
sed -e 's/ /+/g' -e 's/(/%28/g' -e 's/)/%29/g' -e 's/\n//g' "${CrackedFile}" >> "${SanatizedCracked}"

## Set primary keys
PrimaryKey_Dump=$(awk -F\" {'print $6'} "${SanatizedDump}")
PrimaryKey_Cracked=$(awk -F, {'print $2'} "${SanatizedCracked}")

## Set header for file
echo -e "Match,DistinguishedName,PwdLastSet,SAMAccountName,DisplayName,PasswordNeverExpires,Enabled,ManagedAccount,Device,Account,SID,LM1 Method,LM2 Method,NTLM Method" >> "${OutputFile}"

## Grab the account from the DumpFile
for DumpIteration in ${PrimaryKey_Dump}
do
  # Set DumpInfo to the whole line entry(s)
  DumpInfo=$(grep -w "${DumpIteration}" "${SanatizedDump}" | sort -u) || errorDump=$?

  # Error handling for DumpInfo
  if [[ ${errorDump} != '' ]]; then
    echo -e "${DumpIteration} failed sanity check" >> "${OutputFile}"
    continue
  fi

  # Make sure there was only one line that matched DumpInfo's grep
  # If there were multiple matches, reset DumpInfo to the correct one
  if [[ $(wc -l <<< "${DumpInfo}") > 1 ]]; then
    CorrectLine=$(awk -F\" {'print $6'} ${DumpInfo} | grep -nw "^${DumpIteration}$" | cut -f1 -d:)p
    DumpInfo=$(sed 's/ /\n/g' ${DumpInfo} | sed -n $CorrectLine)
  fi

  # Grab the account from the CrackedFile
  for CrackedIteration in ${PrimaryKey_Cracked}
  do
    # Set CrackedInfo to the whole line entry(s)
    CrackedInfo=$(grep -w "${CrackedIteration}" "${SanatizedCracked}" | sort -u) || errorCracked=$?

    # Error handling for CrackedInfo
    if [[ ${errorCracked} != '' ]]; then
      echo -e "${CrackedIteration} failed sanity check" >> "${OutputFile}"
      continue
    fi

    # Make sure there was only one line that matched CrackedInfo's grep
    # If there were multiple matches, reset CrackedInfo to the correct one
    if [[ $(wc -l <<< "${CrackedInfo}") > 1 ]]; then
      CorrectLine=$(echo ${CrackedInfo} | awk -F, {'print $2'} | grep -nw "^${CrackedIteration}$" | cut -f1 -d:)p
      CrackedInfo=$(echo ${CrackedInfo} | sed -e 's/ /\n/g' -e 's/\r//g' | sed -n $CorrectLine)
    fi

    # Truncate both of the accounts to 20 characters, due to limitations with the password cracking output
    fPrimaryKey_Dump=${DumpIteration:0:19}
    fPrimaryKey_Cracked=${CrackedIteration:0:19}

    # Compare the Dumped account to the Cracked account
    if [[ "${fPrimaryKey_Dump}" == "${fPrimaryKey_Cracked}" ]]; then
    # Make sure that neither the Dumped account or Cracked account is already in the OutputFile
      if [[ $(grep "${CrackedInfo}" "${OutputFile}") == '' ]] && [[ $(grep "${DumpInfo}" "${OutputFile}") == '' ]]; then
        # Add the entry to the output and go to the next Dumped account
        echo -e "Yes,${DumpInfo},${CrackedInfo}" >> "${OutputFile}"
        break
      else
        # Don't add if it already exists and go to the next Dumped account
        break
      fi
    fi
  done
done

## Make sure that all accounts in the cracked file exists in the log file
# If any are missing in the log file, add them without any Dump information
for CrackedIteration in ${PrimaryKey_Cracked}
do
  # Set CrackedInfo to the whole line entry(s)
  CrackedInfo=$(grep -w "${CrackedIteration}" "${SanatizedCracked}" | sed -e 's/ /\n/g' -e 's/\r//g') || errorCracked=$?

  # Error handling for CrackedInfo
  if [[ ${errorCracked} != '' ]]; then
    echo -e "${CrackedIteration} failed sanity check" >> "${OutputFile}"
    continue
  fi

  # In case of a single account on multiple servers
  for EachLine in ${CrackedInfo}
  do
    if [[ $(grep "${EachLine}" "${OutputFile}") == '' ]]; then
      echo -e "No,,,,,,,,${EachLine}" >> "${OutputFile}"
    fi
  done
done
