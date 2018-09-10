#!/usr/bin/python

# =========================
# Author:          Jon Zeolla (JZeolla)
# Last update:     2017-01-27
# File Type:       Python Script
# Version:         1.0
# Repository:      https://github.com/JonZeolla/Development
# Description:     This is a python script to pull a list of planetlab node hostnames and then resolve them to IPs.
#
# Notes
# - Planetlab API documentation is currently available here:  https://www.planet-lab.org/doc/plc_api
#   - Unfortunately, the GetNodes function does not have an IP value, so I wrote this script to derive it ourselves.  https://www.planet-lab.org/doc/plc_api#GetNodes
#
# =========================

## Import modules
import sys, os, urllib, xmlrpclib, socket
from prettytable import PrettyTable

## Initialize variables
auth = {}
lookups = []
lookuptable = PrettyTable(['hostname', 'ip'])
sumtable = PrettyTable(['status', 'count'])

## Setup API requirements
# API location
api = 'https://www.planet-lab.org/PLCAPI/'
server = xmlrpclib.ServerProxy(api)
# API Auth
auth['Role'] = "user"
auth['AuthMethod'] = "anonymous"

## Query the API
nodelist = server.GetNodes(auth,{},['hostname'])

## Parse the response
for node in nodelist:
  try:
    lookup = socket.gethostbyname(node['hostname'])
    lookups.append(lookup)
    lookuptable.add_row([node['hostname'], lookup])
  except Exception, e:
#    print "ERROR:  ", node['hostname'], "lookup failed with error", e
    lookuptable.add_row([node['hostname'], "unknown"])
    continue

## Output
print "Line separated IPs\n"
for line in lookups:
  print line

print "\n\nComma separated IPs\n"
print ",".join(lookups)

print "\n\nHostnames and IPs in a pretty table\n"
print lookuptable

print "\n\nLookup summary information\n"
sumtable.add_row(['Successful', len(lookups)])
sumtable.add_row(['Failed', abs(len(nodelist)-len(lookups))])
print sumtable

