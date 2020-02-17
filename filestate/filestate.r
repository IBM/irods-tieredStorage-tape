# iRODS rule
#
# Purpose: 
# - rule determines the migration state of the file given with input
#
# Installation:
# - copy the file to /etc/irods
#
# Invokation: irule  -s -F /etc/irods/filestate.r  *f=<iRODS-zone-path> *lf=<physical-path>
#
filestate {
   writeLine("serverLog", "DEBUG: Rule filestate for file: "++*f++".");
   msiExecCmd("filestate.sh", "\""++*f++"\"", "irods", "", "", *cmdRes);
   msiGetStdoutInExecCmdOut(*cmdRes,*fstat);
   writeLine("serverLog", "DEBUG: fstat="++str(*fstat));

   # if the file is migrated (fstat=0) then return file is migrated, else file is not migrated
   if ( int(*fstat) == 0 ) then {
     msiExit("0", "file "++*lf++" is MIGRATED");
   }
   else { if ( int(*fstat) == 1 ) then { 
     msiExit("1", "file "++*lf++" is NOT migrated.");
   } else { 
       msiExit("2", "file "++*lf++" NOT FOUND.");
	 }
   }
}

# assign input parameters obtained from the ifilestate command
INPUT *f=$"1", *lf=$"2"
OUTPUT ruleExecOut
