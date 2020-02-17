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
# Program Name: fileType.sh
#
# Purpose: checks type of the file and returns the type
#
# Authors: M. Tridici, CMCC (mauro.tridici@cmcc.it), N. Haustein, IBM (haustein@de.ibm.com)
#
# Invokation: filetype.sh filename
#
# Input: 
# - filename from the iRODS server. It is composed of /$ZONE/path/name whereby path is the directory level past to the mount point
# - Some configuration variables need to be adjusted 
#
# Processing: 
# - map the file name from iRODS to the file name relative to the local mount point (NFS mount in iRODS) and the remote file system (GPFS)
# - determine the type of the file using file
# - return file type
# - exit 0 (always)
#
# Output: 
# - file type
# - return code is 0
#
#
#---------------------------------------------------------------------------------------
# Change History
# 02/14/20 Nils: first implementation
#

############################
# These variables have to adjusted
############################

#irods zone name  for archiving purposes
#ZONE="archive"

#local mount point name of HSM managed GPFS file system
#LOCALMP="archive"

#############################
# assigning variables
##############################
# $1 is the $filepath we get from the rule. 
#OBJPATH=$1
#FNAME=$(echo "$OBJPATH" | sed -e "s/$ZONE/$LOCALMP/1")
FNAME=$1


#############################
#check file type
#############################
if [[ -a $FNAME ]]; then
  fType=$(file "$FNAME" | cut -d':' -f 2 | cut -d',' -f1)
else
  fType="UNKNOWN"
fi

# have to print the file type without EOL
echo -e "$fType\c"

exit 0


