
<#PSScriptInfo

.VERSION 1.0

.GUID a1f3188d-39e6-417a-b7f2-4c100f96dc0e

.AUTHOR Mitch Richters (mitch.richters@crosspoint.com.au)

.COMPANYNAME CrossPoint Technology Solutions Pty Ltd

.COPYRIGHT Copyright (C) 2021 CrossPoint Technology Solutions Pty Ltd. All rights reserved.

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
Performs print addition, removal and validation for SMB printers for Intune. 

#>

# Set required variables to ensure script functionality.
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
Set-PSDebug -Strict
Set-StrictMode -Version Latest
$regData = [ordered]@{
	'HKCU:\SOFTWARE\SalesLogix\ADOLogin\Connection1' = @(
		@{
			Name         = 'Alias'
			Value        = 'SALESLOGIX_LIVE'
			PropertyType = [Microsoft.Win32.RegistryValueKind]::String
		}
		@{
			Name         = 'Provider'
			Value        = 'SLXOLEDB.1'
			PropertyType = [Microsoft.Win32.RegistryValueKind]::String
		}
		@{
			Name         = 'Initial Catalog'
			Value        = 'SALESLOGIX_LIVE'
			PropertyType = [Microsoft.Win32.RegistryValueKind]::String
		}
		@{
			Name         = 'Data Source'
			Value        = 'colslx01'
			PropertyType = [Microsoft.Win32.RegistryValueKind]::String
		}
		@{
			Name         = 'DBUser'
			Value        = $null
			PropertyType = [Microsoft.Win32.RegistryValueKind]::String
		}
		@{
			Name         = 'DBPassword'
			Value        = $null
			PropertyType = [Microsoft.Win32.RegistryValueKind]::String
		}
		@{
			Name         = 'Extended Properties'
			Value        = 'PORT=1706;LOG=ON;CASEINSENSITIVEFIND=ON;AUTOINCBATCHSIZE=1;SVRCERT=;'
			PropertyType = [Microsoft.Win32.RegistryValueKind]::String
		}
	)
}

# Don't apply if we have a log file from `Set-UserDefaults.ps1`.
if ([System.IO.Directory]::Exists("$env:LOCALAPPDATA\Schenck\ScriptLogs\Set-UserDefaults.ps1")) {exit}

# Create registry items.
foreach ($regKey in $regData.GetEnumerator()) {
	$keyPath = New-Item -Path $regKey.Key -Force
	$regKey.Value | ForEach-Object {$keyPath | New-ItemProperty @psitem -Force} | Out-Null
}
