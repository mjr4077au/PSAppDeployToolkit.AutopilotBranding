
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
This script publishes SAPUILandscape.xml to the user's %AppData% folder. 

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
<Landscape updated="2018-08-08T00:10:02Z" version="1" generator="SAP GUI for Windows v7500.2.6.134">
	<Workspaces>
		<Workspace uuid="b88a1ec9-af18-4805-8150-f9edda4b0416" name="Local">
			<Item uuid="09cf0437-d278-48f2-a7ad-30b4c884d1af" serviceid="03405bc2-e06b-4ae0-96f7-5dcf01f4e811" />
			<Item uuid="d892592c-8417-4cde-b15d-37de798bfe77" serviceid="3b60f948-741e-4153-b378-f2d6d290b25a" />
			<Item uuid="201e7dad-41ea-490c-81da-0a26be85bd73" serviceid="7451efa1-f6ed-4b18-910b-5b196f7d62ad" />
			<Item uuid="dadcf8e5-bd01-4d08-8485-d0baf5ab404e" serviceid="4509d8ff-433c-48e1-ada3-3a179320d9a7" />
			<Item uuid="7d03ca0e-7e2f-42d9-927a-6cc97498db0d" serviceid="a62dd646-ec52-44a8-9085-c219abb39d45" />
		</Workspace>
	</Workspaces>
	<Messageservers>
		<Messageserver uuid="0fea3bf7-3205-4b56-a123-977b9af0059a" name="ST8" host="DEHAM-T-SAP09.schenckprocess.com" port="3600" />
		<Messageserver uuid="d934c7d0-59c7-4573-97b2-4982a7f870b1" name="SKQ" host="DENOT-D-SAP03.schenckprocess.com" port="3602" />
		<Messageserver uuid="255c6757-2e42-4991-8dbb-43221302120b" name="SKP" host="DEHAM-P-SAP03.schenckprocess.com" port="3601" />
		<Messageserver uuid="76903be4-e877-403f-a2e9-96893d791743" name="SP8" host="DEHAM-P-SAP08.schenckprocess.com" port="3600" />
		<Messageserver uuid="8fcdbe6e-566f-485c-8428-2c4abd5b1fc4" name="SKT" host="DEHAM-T-SAP04.schenckprocess.com" port="3603" />
	</Messageservers>
	<Services>
		<Service type="SAPGUI" uuid="03405bc2-e06b-4ae0-96f7-5dcf01f4e811" name="50 Solution Manager  ST8" systemid="ST8" mode="1" server="DEHAM-T-SAP09.schenckprocess.com:3200" sncop="-1" sapcpg="1100" dcpg="2" />
		<Service type="SAPGUI" uuid="3b60f948-741e-4153-b378-f2d6d290b25a" name="20 Quality System  SKQ Hamburg" systemid="SKQ" mode="1" server="DENOT-D-SAP03.schenckprocess.com:3200" sncop="-1" sapcpg="1100" dcpg="2" />
		<Service type="SAPGUI" uuid="7451efa1-f6ed-4b18-910b-5b196f7d62ad" name="10 Productive System SKP Hamburg" systemid="SKP" msid="255c6757-2e42-4991-8dbb-43221302120b" server="SKP" sncop="-1" sapcpg="1100" dcpg="2" />
		<Service type="SAPGUI" uuid="4509d8ff-433c-48e1-ada3-3a179320d9a7" name="40 Solution Manager  SP8" systemid="SP8" mode="1" server="DEHAM-P-SAP08.schenckprocess.com:3200" sncop="-1" sapcpg="1100" dcpg="2" />
		<Service type="SAPGUI" uuid="a62dd646-ec52-44a8-9085-c219abb39d45" name="30 Test System  SKT Hamburg" systemid="SKT" mode="1" server="DEHAM-T-SAP04.schenckprocess.com:3200" sncop="-1" sapcpg="1100" dcpg="2" />
	</Services>
	<Includes>
		<Include url="file:///{0}/SAP/Common/SAPUILandscapeGlobal.xml" index="0" />
	</Includes>
</Landscape>
'@ -f ($Env:APPDATA -replace '\\','/') | Out-File -FilePath "$([System.IO.Directory]::CreateDirectory("$Env:APPDATA\SAP\Common").FullName)\SAPUILandscape.xml" -Encoding utf8 -Force
