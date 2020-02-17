# iRODS rule
#
# Purpose: 
# - rule to intercept postPut, determine the file type and add the type information to the file metadata
#
# Installation:
# - copy the file to /etc/irods
# - add fileType to the re_rulebase_set in /etc/irods/server_config.json
#
acPostProcForPut 
{
    writeLine("serverLog", "INFO: data object [$objPath] has been PUT ; --> physical path: [$filePath]");
    msiExecCmd("filetype.sh", "\""++$filePath++"\"", "irods", "", "", *cmdRes);
    msiGetStdoutInExecCmdOut(*cmdRes,*fType);
    writeLine("serverLog", "DEBUG: file type="++str(*fType));

    *pair."Filetype" = *fType;
    msiAssociateKeyValuePairsToObj( *pair, "$objPath", "-d");
}
