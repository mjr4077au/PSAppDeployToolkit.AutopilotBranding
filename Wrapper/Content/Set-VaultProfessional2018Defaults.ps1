
<#PSScriptInfo

.VERSION 1.0

.GUID c2f10730-e9d4-45e3-b6fa-3f0ddfc40f78

.AUTHOR Mitch Richters (mitch.richters@crosspoint.com.au).

.COMPANYNAME CrossPoint Technology Solutions

.COPYRIGHT Copyright (C) 2021 CrossPoint Technology Solutions. All rights reserved.

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
This script installs Autodesk Vault Professional 2018 defaults.

#>

# Set required variables to ensure script functionality.
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
Set-PSDebug -Strict
Set-StrictMode -Version Latest

# Don't apply if we have a log file from `Set-UserDefaults.ps1`.
if ([System.IO.Directory]::Exists("$env:LOCALAPPDATA\Schenck\ScriptLogs\Set-UserDefaults.ps1")) {exit}

# Create directory.
$outputdir = [System.IO.Directory]::CreateDirectory("$env:APPDATA\Autodesk\Autodesk Vault Professional 2018").FullName

# Generate ApplicationPreferences.xml.
@'
<?xml version="1.0"?>
<Categories xmlns="http://schemas.autodesk.com/msd/plm/Preferences/2006-04-11">
	<Category ID="Login">
	<!--Created by Autodesk Inventor Version 22.3 Production Candidate-->
		<Property Name="AutoLogin" Value="True" />
		<Property Name="ServerName" Value="sydvault02" />
		<Property Name="UserName" Value="{0}" />
		<Property Name="SelectedAuthenticationType" Value="1" />
		<Property Name="DatabaseName" Value="Vault" />
		<Property Name="Expanded" Value="True" />
	</Category>
</Categories>
'@ -f (whoami.exe 2>&1) | Out-File -FilePath "$outputdir\ApplicationPreferences.xml" -Encoding utf8 -Force

# Generate ApplicationInfo.xml.
@'
<?xml version="1.0"?>
<ApplicationInfo xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://schemas.autodesk.com/msd/plm/ApplicationInfo/2005-04-01">
	<Product Version="23.3.21.0" />
</ApplicationInfo>
'@ | Out-File -FilePath "$outputdir\ApplicationInfo.xml" -Encoding utf8 -Force
