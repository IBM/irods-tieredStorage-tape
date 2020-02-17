# iRODS rule
#
# Purpose: 
# - rule that periodically checks the quota limits
#
# Installation:
# - copy the file to /etc/irods
#
# Invokation: 
# - to schedule this delayed rule: irule -F /etc/irods/quota.r -r irods_rule_engine_plugin-irods_rule_language-instance
# - to check if it is running: iqstat
#
quotacheck {
  delay("<PLUSET>1s</PLUSET><EF>60s</EF>") {
    msiQuota;
    writeLine("serverLog","INFO: Quota updated");
  }
}

INPUT null
OUTPUT ruleExecOut