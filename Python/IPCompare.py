#!/usr/bin/env python2

# =========================
# Author:          Jon Zeolla (JZeolla)
# Last update:     2014-10-16
# File Type:       Python Script
# Version:         1.0
# Repository:      https://github.com/JonZeolla/Development
# Description:     This is a python script to quickly check whether IPs are in preset groups using stdin.  It will print the IP(s) you provided to stdout if it is in the IPSet which you are comparing against.  
#
# Notes
# - Could be improved to create IPSets using imports from a company's IPAM solution
# - Anything that has a placeholder value is tagged with TODO
# - By default, print will convert the input to a string, add a space between args, add a newline at the end, and call the write function of sys.stdout
# - An example of how to use this would be:
#   - alias notlist1='python -c '\''import IPCompare; IPCompare.not_list1()'\'''
#   - echo 192.0.2.2 | notlist1
#
# =========================

import netaddr
import sys

## Various IP Address Subnets (Can handle individual IPs)
list1 = netaddr.IPSet(['192.0.2.0/24', '198.51.100.0/24', '203.0.113.0/24']) # TODO:  Update IPs

# as9_list as of 2014-10-15
company1 = netaddr.IPSet(['192.0.2.0/24', '198.51.100.0/24', '203.0.113.0/24']) # TODO:  Update IPs

def is_ip():
	for request_ip in sys.stdin:
		try:
			ip = netaddr.IPAddress(request_ip)
			print request_ip
		except:
			pass

def in_list1():
	for request_ip in sys.stdin:
		try:
			if request_ip in sii_list:
				print request_ip
		except:
			pass

def not_list1():
  for request_ip in sys.stdin:
    try:
      if request_ip not in sii_list:
        print request_ip
    except:
      pass

def in_company1():
	for request_ip in sys.stdin:
		try:
			if request_ip in as9_list:
				print request_ip
		except:
			pass

def not_company1():
  for request_ip in sys.stdin:
		try:
      if request_ip not in as9_list:
        print request_ip
		except:
			pass

def is_private():
	for request_ip in sys.stdin:
		try:
			if netaddr.IPAddress(request_ip).is_private():
				print request_ip
		except:
			pass

def not_private():
  for request_ip in sys.stdin:
    try:
      if not netaddr.IPAddress(request_ip).is_private():
        print request_ip
    except:
      pass

def is_company():
  for request_ip in sys.stdin:
    try:
      if netaddr.IPAddress(request_ip).is_private() or request_ip in company1:
        print request_ip
    except:
      pass

def not_company():
  for request_ip in sys.stdin:
    try:
      if not netaddr.IPAddress(request_ip).is_private() or request_ip not in company1:
        print request_ip
    except:
      pass
