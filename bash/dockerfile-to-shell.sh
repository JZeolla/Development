#!/usr/bin/env bash

# Please find a better way than this.
# Seriously.
# Go back now.
# Here be dragons

shopt -s nocasematch
set -u # nounset
set -e # errexit
set -E # errtrap
set -o pipefail

if [[ "$(tr -dc '0-9.' < /etc/debian_version | cut -f1 -d\.)" != "10" ]]; then
  echo "Only supported for Debian buster (10)"
  exit
fi

# Make the script
SCRIPT="${1:-Dockerfile}.sh"
cp -f "${1:-Dockerfile}" "${SCRIPT}"
chmod 0755 "${SCRIPT}"

# Ignore these instructions
for instruction in CMD EXPOSE FROM MAINTAINER VOLUME; do
  sed -r "s_^(${instruction}\s+)_# \1_gI" -i "${SCRIPT}"
done

# Simple instruction modifications
sed -r "s_^ADD\s_cp -R _gI" -i "${SCRIPT}"
sed -r "s_^COPY\s_cp -R _gI" -i "${SCRIPT}"
sed -r 's_^RUN\s\\__gI' -i "${SCRIPT}"
sed -r "s_^RUN\s__gI" -i "${SCRIPT}"
sed -r "s_^WORKDIR\s_cd _gI" -i "${SCRIPT}"

# More nuanced instruction modifications

# Simulate docker USER instructions
#
# Exit if the user who logged into the controlling terminal is not the current
# user, then `su` while keeping the current directory unchanged
sed -r 's_^USER\s(\w+)_if [[ "${USER}" != "$(logname)" ]]; then exit; fi; sudo su -w PWD \1_gI' -i "${SCRIPT}"

# Setup environment variables
#
# Ensure these work with the examples at
# https://docs.docker.com/engine/reference/builder/#env
#
# Comment out "ENV \" lines
sed -r -e 's_^(ENV\s*\\)$_# \1_gI' -i "${SCRIPT}"

# Change standard "ENV KEY=VALUE" and "ENV KEY VALUE" lines into "export
# KEY=VALUE" lines. If it ends with a \, exclude it
#
# This is multiple, specifically ordered lines because of the lack of a
# negative lookahead like (?!.+\s\\$)
sed -r 's_^ENV\s(\w+)[\s=](.+)\\$_export \1=\2_gI' -i "${SCRIPT}"
sed -r 's_^ENV\s(\w+)[\s=](.+)$_export \1=\2_gI' -i "${SCRIPT}"

# This is the most dangerous section
#
# Change "KEY=VALUE \" or "KEY=VALUE", 'KEY="VALUE" \' or 'KEY="VALUE"', and
# "KEY='VALUE' \" or "KEY='VALUE'" (i.e.  assumed multiline ENV statements)
# lines into 'export KEY="VALUE"' lines, in that order.
#
# Some valid combinations are not yet supported, like "KEY=VAL/UE" (An unquoted
# VALUE containing special characters), or specifying key value pairs without
# an "=" between them (except for those caught by prior transformations like
# "ENV KEY VALUE")
#
# If modifying this, keep in mind that `sed` (at of this writing) has a lack of
# negative lookaheads like (?!.+\s?\\$)
#
# `/^export /b;` is a workaround for this, which searches for "export " at the
# beginning and, if there's a match, branch unconditionally to the end of the
# sed expression (due to the lack of a label)
sed -r '/^export /b; s_^\s*(\w+)=(\w+)[\\]?$_export \1=\2_gI' -i "${SCRIPT}"
# ['"'"'"] means ' or "
sed -r '/^export /b; s_^\s*(\w+)=['"'"'"](.*)['"'"'"]\s?\\?_export \1="\2"_gI' -i "${SCRIPT}"

# Persist
while read -r line; do
  grep -q "$line" "${HOME}/.bashrc" || echo "$line" >> "${HOME}/.bashrc"
done < <(grep '^export ' "${SCRIPT}")
