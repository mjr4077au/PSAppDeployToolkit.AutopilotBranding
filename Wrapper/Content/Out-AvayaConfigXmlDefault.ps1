
<#PSScriptInfo

.VERSION 1.0

.GUID accc1d63-f280-47a6-9f99-0ac270fd053b

.AUTHOR Mitch Richters (mitch.richters@crosspoint.com.au)

.COMPANYNAME CrossPoint Technology Solutions

.COPYRIGHT Copyright (c) 2021 CrossPoint Technology Solutions. All rights reserved.

.TAGS 

.LICENSEURI 

.PROJECTURI 

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES


#>

<# 

.DESCRIPTION 
This script publishes config.xml to the user's %AppData% folder. 

#>

# Set required variables to ensure script functionality.
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
Set-PSDebug -Strict
Set-StrictMode -Version Latest

# Don't apply if we have a log file from `Set-UserDefaults.ps1`.
if ([System.IO.Directory]::Exists("$env:LOCALAPPDATA\Schenck\ScriptLogs\Set-UserDefaults.ps1")) {exit}

# Output payload to disk.
@'
<?xml version="1.0" encoding="UTF-8"?>
<ConfigData xmlns="http://xml.avaya.com/endpointAPI">
	<version>1</version>
	<parameter>
		<name>SipControllerList</name>
		<value>avaya.schenckprocess.com.au:5061;transport=tls</value>
	</parameter>
	<parameter>
		<name>SipDomain</name>
		<value>schenckprocess.com.au</value>
	</parameter>
	<parameter>
		<name>DialPlanCountryCode</name>
		<value>001161</value>
	</parameter>
	<parameter>
		<name>DialPlanInternationalAccessCode</name>
		<value>0011</value>
	</parameter>
	<parameter>
		<name>DialPlanOutsideLineAccessCode</name>
		<value>0</value>
	</parameter>
	<parameter>
		<name>UserEnableDialingRules</name>
		<value>0</value>
	</parameter>
	<parameter>
		<name>SipSignalTransportType</name>
		<value>2</value>
	</parameter>
	<parameter>
		<name>LocalLogLevel</name>
		<value>3</value>
	</parameter>
	<parameter>
		<name>AudioLogLevel</name>
		<value>3</value>
	</parameter>
	<parameter>
		<name>DialPlanAreaCode</name>
		<value>0</value>
	</parameter>
	<parameter>
		<name>DialPlanExtensionLengthList</name>
		<value>3</value>
	</parameter>
	<parameter>
		<name>VideoRtpPortLow</name>
		<value>5024</value>
	</parameter>
	<parameter>
		<name>VideoRtpPortRange</name>
		<value>20</value>
	</parameter>
	<parameter>
		<name>MicrosoftOutlookContacts</name>
		<value>0</value>
	</parameter>
	<parameter>
		<name>VideoAdaptorLogLevel</name>
		<value>3</value>
	</parameter>
</ConfigData>
'@ | Out-File -FilePath "$([System.IO.Directory]::CreateDirectory("$Env:APPDATA\Avaya\Avaya Communicator").FullName)\config.xml" -Encoding utf8 -Force
