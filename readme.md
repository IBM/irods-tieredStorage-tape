# Introduction


This project includes examples for integrating iRODS software with IBM Spectrum Scale™ and Spectrum Archive™ Enterprise Edition.

The [iRODS](https://irods.org/about/) consortium brings together businesses, research organizations, universities, and government agencies to ensure the sustainability of iRODS software by:
- Guiding further development of the software;
- Growing the user and developer communities; and
- Facilitating iRODS support, education, and collaboration opportunities.

The [iRODS software](https://irods.org/download/) is a data management layer that sits above the storage that contain data, and below domain-specific applications [1]. Because iRODS has a plugin framework and is technology-agnostic, it provides insulation from vendor lock-in. The data virtualization capabilities of iRODS make it a one-stop shop for all data regardless of the heterogeneity of storage devices. Whether data is stored on a local hard drive, on remote file systems or object storage, iRODS' virtualization layer presents data resources in the classic files and folders format, within a single namespace.

[IBM Spectrum Scale™](https://www.ibm.com/us-en/marketplace/scale-out-file-and-object-storage) is licensed software providing a UNIX filesystem that supports tiered storage. [IBM Spectrum Archive™ Enterprise Edition](https://www.ibm.com/us-en/marketplace/data-archive) is a licensed software that represents the tape storage tier within IBM Spectrum Scale. As such it controls all tape operation including the migration and recall of files from the disk tier to the tape tier. 

In a solution integrating iRODS with IBM Spectrum Scale and IBM Spectrum Archive, the tiered storage file system is provided by IBM Spectrum Scale whereby the tape tier is managed by IBM Spectrum Archive. This tiered storage file system is exported to the iRODS server managing the iRODS zone via NFS. The iRODS zone of the user contains the NFS exported tiered storage file system as storage resource of type `unixfilesystem`. 

The integration of iRODS with IBM Spectrum Archive EE as presented in this project provides the following sub-projects:
- [prevent transparent recalls](recall/) of files that are on tape and instead collect files that are requested by the iRODS user and recall them in a tape optimized manner
- [determine migration state](filestate/) from an iRODS user perspective
- [setting storage quota](quota/) for users that apply to all files regardless if stored on disk or on tape in the underlying 
- [determine and add the file type](filetype/) to the iRODS metadata catalog (iCAT) 


## Disclaimer and license
This project is released under the terms of the [MIT license](LICENSE).

The integration of iRODS with IBM Spectrum Archive is an open source project and NOT an IBM product. As such it is not supported by any official IBM product support. 

The code provided in this git repository is a prototype and has not been tested in production and in multi-user environments. The author does not assume any liability for damages or other trouble when deploying this API. Changes in the products it integrates with - for example IBM Spectrum Archive Enterprise Edition - may cause the API to stop working. 

Even though we do not redistribute iRODS, this project uses iRODS function, here is the iRODS license 
Copyright (c) 2005-2018, Regents of the University of California and the University of North Carolina at Chapel Hill. All rights reserved. 

**iRODS disclaimer**
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 


-----------------------------------------------------------------

# Prevent transparent recalls

With this sub-project transparent recalls of files that are stored on tape in the underlying tiered storage file system are prevented. When the user accesses a file in iRODS that is stored in the tiered storage file system - for example by using the `iget` command - the file migration status is checked and if the file is migrated to tape then the access request is failed and the path and file name is added to queue (file list) in the IBM Spectrum Archive server. If the file is not on tape then the access request is granted. There are three components required:

[checkmig.re](recall/checkmig.re) is an iRODS rule that intercepts an open request for a file and invokes a `checkmig.sh` microservice along with the path and file name of the file to be opened. It uses the iRODS system defined rule `acPreprocForDataObjOpen` to intercept the file open processing and invokes `checkmig.sh`. Depending on the output returned by by `checkmig.sh`, the rule permits or fails the open requires using the iRODS microservice `msiExit`. 
Add this rule to the iRODS rule repository by placing the rule-file in directory /etc/irods and adding the name of the rule-file to the configuration file /etc/irods/server_config.json in the iRODS server. 

[checkmig.sh](recall/checkmig.sh) is an iRODS microservice that is invoked by the iRODS rule `checkmig.re` along with a path and file name relative to the iRODS zone encoded in $1. The check-program transforms the iRODS path and filename into name of the local mount point and determines if the file is migrated using the Unix command ls -ls. If the file is **not** migrated, then the check-program returns “1” to the rule-program. Otherwise, if the file is migrated, then the program returns “0”. It also transforms the iRODS path and filename into the name of the IBM Spectrum Scale file system export and adds this name to a file list located in the IBM Spectrum Archive server. For this the check-program uses an ssh-communication that requires to share the public key of the iRODS administrator with appropriate user in the IBM Spectrum Archive server. 
The `checkmig.sh` microservice has to be place in the microservices directory (/var/lib/irods/msiExecCmd_bin) on the iRODS server. Furthermore the iRODS administrative user has to generate and share it public key with appropriate user of the IBM Spectrum Archive server. 

[bulkrecall.sh](recall/bulkrecall.sh) runs on the IBM Spectrum Archive server and periodically checks the file list containing migrated files to be recalled. The file list is created and updated by the `checkmig.sh` microservice and contains the path and file names to be recalled. If there are files to be recalled, then this program recalls these files using the tape optimized recall function. 
The `bulkrecall.sh` program is placed on the IBM Spectrum Archive server and scheduled to run periodically. The [IBM Spectrum Scale storage services automation framework](https://github.com/nhaustein/SpectrumScaleAutomation) can be used to run the bulkrecall-program periodically. Depending on the workload the bulkrecall-program can run periodically multiple times a day. The scheduled time period is the time the iRODS user has wait at maximum before he can access a migrated file. 


If these components are installed the request to open a migrated file will fail as shown in the example below:

	$ iget -f file1
	Level 0: file /archive/home/mia/col1/file1 is still on tape, but queued to be staged.


-----------------------------------------------------------------

# Show file status

Another user requirement in an environment with tape as a storage tier is to determine if a file is on tape or not. The user can use this information to be prepared that an access to a migrated file takes a longer time because files are collected and recalled in a bulk in an asynchronous manner. To accommodate this, three components are required:

[ifilestate](filestate/ifilestate) is a new command script for the iRODS user to determine the state of a file. This script wraps the call to iRODS rule that checks the file state. Install the `ifilestate` script in /usr/local/bin of the iRODS client. 

[filestate.r](filestate/filestate.r) is an iRODS rule that is invoked by the `ifilestate` command. This rule gets two parameters as input from the ifilestate script: the path and file name relative to the iRODS zone and the path and file name relative to the mount point of the IBM Spectrum Scale file system (physical path). This rule invokes a new microservice named `filestate.sh` with the physical path, that checks the file state and returns the appropriate result. Depending on the result string returned by the microservice the filestate.r rule prints the appropriate message to the user utilizing the msiExit microservice. 
his new rule needs to be installed on the iRODS client in /etc/irods. If this directory does not exist, then it must be created. It can also be installed on the iRODS server. Find an example of the new rule (filestate.r) rule below:

[filestate.sh](filestate/filestate.sh) is a new iRODS microservice that checks if the file is migrated by performing a stat-command and comparing the block size and the file size. If the block size is 0 and the file size is greater than 0 then the file is migrated. The `filestate.sh` microservice return a string “0” if the file is migrated and “1” if the file is not migrated. This string is evaluated by the `filestate.r` rule. The filestate.sh script must be installed in the iRODS server directory for the microservices (/var/lib/irods/msiExecCmd_bin).

If these componentes are installed the iRODS user can use the new `ifilestate` command to determine the migration state of a file. The file name to check the state for is given as argument with the `ifilestate` command. The file name can be the file name relative to the current collection or it can be the full iRODS path and file name. 

In the first example the state of file name file1 is inquired:

	$ ifilestate file1
	Level 0: file /archive/home/mia/col1/file1 is MIGRATED

In the second example the state of all files in the current collection are inquired:

	$ ifilestate -a
	Level 0: file /archive/home/mia/col1/file0 is NOT migrated
	Level 0: file /archive/home/mia/col1/file1 is MIGRATED



-----------------------------------------------------------------

# Setting Quota

One typical requirement for archiving systems in multi-user environments is the capability to set quota for users, groups or entire storage spaces. While IBM Spectrum Scale allows setting quota for the files stored on disk, there is no quota for files stored on tape. This means that a user with 10 TB quota can easily store 100 TB if the data is migrated to tape. Fortunately, iRODS allows setting quota which applies for all data the user has stored in the iRODS storage resource, regardless if the data is on disk or on tape. To accomodate this some iRODS configuration and a new iRODS rule is required:

[quota.r](quota/quota.r) is a iRODS delayed rule that periodically checks quota by uisng the build-in `msiQuota` microservice every 60s. Store the rule in /etc/irods/ on the iRODS server. 


Enable quota by editing the file /etc/core.re and adding the following line:

	acRescQuotaPolicy {msiSetRescQuotaPolicy("on"); }


Set quota limit for the user on the iRODS storage resources that represents the tiered storage file system. In this example the user is `username` and the storage resource is `archivefs`. 

	$ iadmin suq username archivefs 2147483648
	$ iadmin suq username total 2147483648


To check the quota limit of the user use the following command in iRODS:

	$ iquota -u username


Load the delayed quota rule `quota.r` that runs every 60 seconds:

	$ irule -F /etc/irods/quota.r -r irods_rule_engine_plugin-irods_rule_language-instance


The delayed rule can be checked using the command:

	$ iqstat



-----------------------------------------------------------------

# Harvesting file information

In this sub-project we present a solution to automatically determine the type of a file ingested into an iRODS zone and add the file type to the file meta information in the iRODS catalog (iCAT). This meta-information can be searched on, for example to find files of a certain type. Two components are required:

[filetype.re](filetype/filetype.re) is an iRODS rule that is invoked after a file has been stored in the iRODS zone, for example by using the `iput` command. This rule implements the iRODS policy enforcement point `acPostProcForPut` and invokes the microservice `filetype.sh` that returns the string including the type of the file. The `filetype.re` rule then adds the file type to the file metadata as attribute `Filetype`. 
This rule must be installed in directory `/etc/irods` on the iRODS server. 

[filetype.sh](filetype/filetype.sh) is a new iRODS microservice that is invoked by the `filetype.re` rule along with the path and file name and determines the filetype by using the UNIX command `file`. It returns the extracted filetype as string to the `filetype.re` rule.
This microservice must be installed in the iRODS microservices directory (/var/lib/irods/msiExecCmd_bin) of the iRODS server. 

To activate this new rule it must be added to the server_config.json under elements `rule_engines` - `re_rulebase_set` as "filetype" as shown below:

	"rule_engines": [
		{
			"instance_name": "irods_rule_engine_plugin-irods_rule_language-instance", 
			"plugin_name": "irods_rule_engine_plugin-irods_rule_language", 
			"plugin_specific_configuration": {
				"re_data_variable_mapping_set": [
					"core"
				], 
				"re_function_name_mapping_set": [
					"core"
				], 
				"re_rulebase_set": [
					"checkmig",
					"fileType",
					"core"
				], 
				...

After ingesting files to iRODS using the `ìput` command, the file will automatically obtain the file type as metadata:

	$ iput document.pdf file1

	$ imeta ls -d file1
	AVUs defined for dataObj file1:
	attribute: Filetype
	value:  PDF document
	units:

It is also possible to search for all files that are of type PDF document using the iRODS `imeta` command:

	$ imeta qu -d Filetype like %PDF%
	collection: /archive/home/mia/col1
	dataObj: file1

	collection: /archive/home/mia/col1
	dataObj: file2

