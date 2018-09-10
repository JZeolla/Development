#!/usr/bin/env python3

# =========================
# Author:          Jon Zeolla (JZeolla)
# Last update:     2018-09-11
# File Type:       Python Script
# Version:         0.1
# Repository:      https://github.com/JonZeolla/Development
# Description:     This is a python script that accepts the output of `aws sts get-session-token` as stdin to create the appropriate environment variables make it transiently effective.
#
# Notes
# - This plays much more nicely in a zsh environment than it does in bash.
#
# =========================

import sys, json;

try:
    data=json.load(sys.stdin)
except:
    print('Not valid JSON, exiting...')
    exit(1)

print('export AWS_ACCESS_KEY_ID="%s"' % data['Credentials']['AccessKeyId'])
print('export AWS_SECRET_ACCESS_KEY="%s"' % data['Credentials']['SecretAccessKey'])
print('export AWS_SESSION_TOKEN="%s"' % data['Credentials']['SessionToken'])

