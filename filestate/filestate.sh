#!/bin/bash
# set -xv
################################################################################
# The MIT License (MIT)                                                        #
#                                                                              #
# Copyright (c) 2020 Nils Haustein, Mauro Tridic               				   #
#                                                                              #
# Permission is hereby granted, free of charge, to any person obtaining a copy #
# of this software and associated documentation files (the "Software"), to deal#
# in the Software without restriction, including without limitation the rights #
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell    #
# copies of the Software, and to permit persons to whom the Software is        #
# furnished to do so, subject to the following conditions:                     #
#                                                                              #
# The above copyright notice and this permission notice shall be included in   #
# all copies or substantial portions of the Software.                          #
#                                                                              #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR   #
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,     #
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE  #
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER       #
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,#
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE#
# SOFTWARE.                                                                    #
################################################################################
#-------------------------------------------------------------------------------
# Program Name: filestate.sh
#
# Purpose: checks migration state of a file and returns the state
#
# Authors: M. Tridici, CMCC (mauro.tridici@cmcc.it), N. Haustein, IBM (haustein@de.ibm.com)
#
# Invokation: filestate.sh filename
#
# Input: 
# - physical path name of the file to be checked
#
# Processing: 
# - determine the allocated blocks and size of the file using stat
# - if blocks=0 and size>0 then return exit string 0 (file migrated)
# - otherwise return the string 1 (file not migrated)
# - exit 0 (always)
#
# Output: 
# - return code 
#   0: file is migrated
#   1: file is not migrated
#   2: some error occured checking the file
#
# Installation
# - install this in /var/lib/irods/msiExecCmd_bin/ on the server
#---------------------------------------------------------------------------------------
# Change History
# 02/10/20 Nils: first implementation
# 02/22/20 Nils: some streamlining
#


#############################
# assigning variables
##############################
# $1 is the physical path relativ to the mount point on the iRODS server

FNAME=$1

#############################
#check if stat command exists
#############################
if ! [ -x "$(command -v stat)" ]; then
  #Error: stat is not installed
  echo "2"
  exit 0
fi

#######################################
#stat of file passed as input argument
#######################################
# do one stat call to get blocks, size and extract it
out=""
out=$(/usr/bin/stat --format=%b,%s "$FNAME" 2>/dev/null)
if [[ ! -z $out ]]; then
  blocks=$(echo $out | cut -d',' -f1)
  size=$(echo $out | cut -d',' -f2)
else
  # error on stat
  echo "2"
  exit 0
fi

########################################
#if blocks=0 then result=0 (migrate file)
########################################
#>>> here we check blocks and size to make a decision
if (( "$blocks" == 0  &&  "$size" > 0 )); 
then
  echo "0" 
else
  echo "1"
fi

exit 0