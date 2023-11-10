
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
This script publishes SAPUILandscapeGlobal.xml to the user's %AppData% folder. 

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
<Landscape>
	<Messageservers>
		<Messageserver uuid="993cb0b8-b240-490d-b06f-e30989c28634" name="E01" description="E01" port="3911" />
		<Messageserver uuid="f83e4d53-b127-48ce-808e-c6cfc73f2fc7" name="SEE" description="SEE" port="3901" />
		<Messageserver uuid="e7b1349d-ff4e-487f-a276-4451d903735f" name="SEP" description="SEP" port="3901" />
		<Messageserver uuid="255c6757-2e42-4991-8dbb-43221302120b" name="SKP" host="DEHAM-P-SAP03.schenckprocess.com" port="3601" />
		<Messageserver uuid="d934c7d0-59c7-4573-97b2-4982a7f870b1" name="SKQ" host="DENOT-D-SAP03.schenckprocess.com" port="3602" />
		<Messageserver uuid="8fcdbe6e-566f-485c-8428-2c4abd5b1fc4" name="SKT" host="DEHAM-T-SAP04.schenckprocess.com" port="3603" />
		<Messageserver uuid="76903be4-e877-403f-a2e9-96893d791743" name="SP8" host="DEHAM-P-SAP08.schenckprocess.com" port="3600" />
		<Messageserver uuid="0fea3bf7-3205-4b56-a123-977b9af0059a" name="ST8" host="DEHAM-T-SAP09.schenckprocess.com" port="3600" />
	</Messageservers>
</Landscape>
'@ | Out-File -FilePath "$([System.IO.Directory]::CreateDirectory("$Env:APPDATA\SAP\Common").FullName)\SAPUILandscapeGlobal.xml" -Encoding utf8 -Force
