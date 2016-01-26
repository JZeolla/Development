#!/bin/bash
# To enable and disable tracing use:  set -x (On) set +x (Off)

# =========================
# Author:          Jon Zeolla (JZeolla, JonZeolla)
# Last update:     2016-01-25
# File Type:       Bash Script
# Version:         1.0
# Repository:      https://github.com/JonZeolla/Development
# Description:     This is a bash script to create a branch, which is a subset of a repo, to allow people to only clone parts of repos quickly during labs where we may have limited bandwidth
#
# Notes
# - This script is exclusively created for my personal workflow and may not work well for others.
# - Anything that has a placeholder value is tagged with TODO.
#
# =========================

# Check for the correct amount of arguments
if [ $# -ne 3 ]; then
  echo -e "Please provide all 3 inputs in the following order:\nUser Repo Branch"
  exit 1
fi

# Get the username, repo, and new branch name
githubUser=$1
githubRepo=$2
githubBranch=$3

# Set a high level variable
exitstatus=0

# Clone the repo and move into it
git clone https://www.github.com/${githubUser}/${githubRepo}
cd ${githubRepo}

# Work whether or not the branch folder has already been made
if [ -d ${githubBranch} ]; then
  find . \( -path ./"${githubBranch}" -o -path ./.git \) -prune -o -name "*" -exec rm -rf {} + 2>/dev/null
  cd ${githubBranch}
  if [[ $(shopt dotglob | awk '{print $2}') == "off" && $(shopt nullglob | awk '{print $2}') == "off" ]]; then
    shopt -s dotglob nullglob
    mv * ../
    cd ..
    rmdir ${githubBranch}
    shopt -u dotglob nullglob
  elif [[ $(shopt dotglob | awk '{print $2}') == "on" ]]; then
    mv * ../
    cd ..
    rmdir ${githubBranch}
  fi
else
  find . -path ./.git -prune -o -name "*" -exec rm -rf {} + 2>/dev/null
  touch README.md
fi

# Create the new branch and push it back to GitHub
git checkout -b ${githubBranch}
exitstatus=$?
if [[ $exitstatus != 0 ]]; then echo -e "ERROR:\tIssue with the git checkout"; git checkout master; exit 1; fi
git add -A && git commit -m "Initial branch setup"
exitstatus=$?
if [[ $exitstatus != 0 ]]; then echo -e "ERROR:\tIssue with the git commit"; git checkout master; exit 1; fi
git push origin ${githubBranch}
exitstatus=$?
if [[ $exitstatus != 0 ]]; then echo -e "ERROR:\tIssue with the git push"; git checkout master; exit 1; fi
git checkout master

exit
