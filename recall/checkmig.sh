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
#
# Program Name: checkmig.sh
#
# Purpose: checks migration state of a file and if the file is migrated adds it to a file list on EENODE
#
# Authors: M. Tridici, CMCC (mauro.tridici@cmcc.it), N. Haustein, IBM (haustein@de.ibm.com)
#
# Invokation: checkmig.sh filename
#
# Prerequisite:
# Share the public key of the iRODS admin with the root user of the Spectrum Archive node. The public key of the iRODS admin user must be stored in the authorized_keys file of the root user on the Spectrum Archive node.
# - As irods admin on the iRODS server generate a key if it is not available yet in ~/.ssh: ssh-keygen
# - Copy the public key of the irods admin with the root of the Spectrum Archive node: ssh-copy-id root@eenode
#
# Input: 
# - filename from the iRODS server. It is composed of /$ZONE/path/name whereby path is the directory level past to the mount point
# - Some configuration variables need to be adjusted 
#
# Processing: 
# - map the file name from iRODS to the file name relative to the local mount point (NFS mount in iRODS) and the remote file system (GPFS)
# - determine the allocated blocks and size of the file using stat
# - if blocks=0 and size>0 then add the file to the recall list in the EENODE and return the string 0
# - otherwise return the string 1
# - exit 0 (always)
#
# Output: 
# - return code 
#   0: file is migrated
#   1: file is not migrated
#   2: some error occured checking the file
#
#
#---------------------------------------------------------------------------------------
# Change History
# 02/06/20 Mauro: first implementation
# 02/07/20 Nils: adjustments
#

############################
# These variables have to adjusted
############################

#irods zone name  for archiving purposes
ZONE="archive"

#local mount point name of HSM managed GPFS file system
LOCALMP="archive"

#remote path of the GPFS export
REMOTEMP="gpfs\/fs1\/irods"

#virtual ip of EENODE
EENODE="ibmces"

#remote path of HSM managed GPFS file system
FLISTPATH="/gpfs/fs1/.recall"
FLISTNAME="recall_input_list.$HOSTNAME"


#############################
# assigning variables
##############################
# $1 is the objPath we get from the rule. It is composed of /$ZONE/path/name whereby path is the directory level next to the 
#map the file name to the local path (from iRODS Server point of view)
FNAME=$(echo "$1" | sed -e "s/$ZONE/$LOCALMP/1")

#map the file name to the remote path (from EENODE point of view)
GPFSFNAME=$(echo "$1" | sed -e "s/$ZONE/$REMOTEMP/1")

# echo "DEBUG: FNAME=$FNAME, GPFSNAME=$GPFSFNAME"

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
  echo 2
  exit 0
fi

########################################
#if blocks=0 then result=0 (migrate file)
########################################
#>>> here we check blocks and size to make a decision
if (( "$blocks" == 0  &&  "$size" > 0 )); 
then

  ssh -l root $EENODE bash -c "'
  
     if [ ! -d "$FLISTPATH" ] 
      then
        mkdir -p $FLISTPATH 
     fi 

     echo "$GPFSFNAME" >> $FLISTPATH/$FLISTNAME
   
  '"

  echo "0" 
else
  echo "1"
fi

exit 0