
<#PSScriptInfo

.VERSION 2.10.2

.GUID 21bf030b-ee87-4619-899a-7c080fe5fbfe

.AUTHOR Mitch Richters (mrichters@themissinglink.com.au)

.COMPANYNAME The Missing Link Network Integration Pty Ltd

.COPYRIGHT Copyright (C) 2024 The Missing Link Network Integration Pty Ltd. All rights reserved.

#>

<#

.DESCRIPTION
This script detects whether a particular piece of software is installed or not.

#>

# Define variables for script.
$scrVer = (Test-ScriptFileInfo -LiteralPath "$([System.Environment]::SystemDirectory)\Invoke-DesiredStateManagementOperation.ps1" -ErrorAction Stop).Version
$minVer = (Test-ScriptFileInfo -LiteralPath $MyInvocation.MyCommand.Source -ErrorAction Stop).Version

# Check whether script is the minimum version.
if ($scrVer -lt $minVer)
{
	throw "Unable to detect product."
}
Write-Host "Product detected successfully."
