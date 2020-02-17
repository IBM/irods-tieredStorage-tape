# iRODS rule
#
# Purpose: 
# - this rule intercepts pre_open, checks if the file is migrated using checkmig.sh and if this is the case it returns an error along with a message
#
# Installation:
# - copy the file to /etc/irods
# - add checkmig to the re_rulebase_set in /etc/irods/server_config.json
#
acPreprocForDataObjOpen {
  ON($writeFlag == "0") {
    *fname=str($objPath);
    *resc=str($rescName);
    writeLine("serverLog", "DEBUG: Entered PreprocForDataObjOpen for file: "++*fname++" on resource: "++*resc++".");

    if ( *resc == "buffer" ) then {
      # calling checkmig, 0=migrated, 1=not migrated, 2=stat error
	  # if the file is migrated then checkmig will send the file name to Spectrum Archive
      msiExecCmd("checkmig.sh", "\""++*fname++"\"", "irods", "", "", *cmdRes);
      msiGetStdoutInExecCmdOut(*cmdRes,*fstat);
      writeLine("serverLog", "DEBUG: fstat="++str(*fstat));

      # if the file is migrated (fstat=0) then fail the open processing
      if ( int(*fstat) == 0 ) then {
        msiExit("-1", "file "++*fname++" is still on tape, but queued to be staged."); 
      }
      else {
        msiExit("1", "file "++*fname++" is NOT migrated."); 
      }
    }
  }
}
