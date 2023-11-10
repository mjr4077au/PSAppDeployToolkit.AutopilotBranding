
<#PSScriptInfo

.VERSION 1.0

.GUID 89cd3aad-a56a-41bf-852f-bd5f54cb265e

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
This script sets the DPI level to 96 DPI / 100%.

#>

# Set required variables to ensure script functionality.
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
Set-PSDebug -Strict
Set-StrictMode -Version Latest

# Don't apply if we have a log file from `Set-UserDefaults.ps1`.
if ([System.IO.Directory]::Exists("$env:LOCALAPPDATA\Schenck\ScriptLogs\Set-UserDefaults.ps1")) {exit}

# Store managed code to call.
$managedcode = @'
[DllImport("user32.dll", ExactSpelling = true, SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "SystemParametersInfoW")]
private static extern int SystemParametersInfo(uint uiAction, uint uiParam, IntPtr pvParam, uint fWinIni);

private const uint SPI_SETLOGICALDPIOVERRIDE = 0x009F;
private const uint LowestDpiScalePermitted = uint.MaxValue - 10;

public static int ResetDpiScaling()
{
	return SystemParametersInfo(SPI_SETLOGICALDPIOVERRIDE, LowestDpiScalePermitted, IntPtr.Zero, 1);
}
'@

# Set DPI to 96 if we're not running on a Surface.
if (!(Get-CimInstance -ClassName Win32_ComputerSystem).Model.Contains('Surface'))
{
	# Change DPI and throw if not successful.
	if (!(Add-Type -Namespace Win32 -Name WinUser -MemberDefinition $managedcode -PassThru)::ResetDpiScaling())
	{
		throw "Call to SystemParametersInfo() failed."
	}
}
