
<#PSScriptInfo

.VERSION 1.14

.GUID dd1fb415-b54e-4773-938c-5c575c335bbd

.AUTHOR Michael Neihaus

.COMPANYNAME Out of Office Hours

.COPYRIGHT N/A

.TAGS

.LICENSEURI https://github.com/mtniehaus/AutopilotBranding/blob/master/LICENSE

.PROJECTURI https://github.com/mtniehaus/AutopilotBranding

.ICONURI

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES


.PRIVATEDATA

#>

<# 

.DESCRIPTION 
Script to customise Windows 10 devices via Windows Autopilot (although there's no reason it can't be used with other deployment processes, e.g. MDT or ConfigMgr).

#> 

[CmdletBinding()]
Param()

# Set required variables to ensure script functionality.
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
Set-PSDebug -Strict
Set-StrictMode -Version Latest


#---------------------------------------------------------------------------
#
# Returns a pretty multi-line error message derived from the provided ErrorRecord.
#
#---------------------------------------------------------------------------

filter Out-FriendlyErrorMessage
{
	# Get variables from 1st line in the stack trace, as well as called command if available.
	$function, $path, $script, $line = [System.Text.RegularExpressions.Regex]::Match($_.ScriptStackTrace, '^at\s(.+),\s(.+)\\(.+):\sline\s(\d+)').Groups.Value[1..4]
	$command = $_.InvocationInfo.MyCommand | Select-Object -ExpandProperty Name | Where-Object {!$function.Equals($_)}

	# Return constructed output to the pipeline.
	return "ERROR: Line #$line`: $function`: $(if ($command) {"$command`: "})$($_.Exception.Message)"
}


#---------------------------------------------------------------------------
#
# Writes a string to stderr. By default, Powershell writes everything to stdout, even errors.
#
#---------------------------------------------------------------------------

filter Write-StdErrMessage
{
	# Test if we're in a console host or ISE.
	if ($Host.Name -eq 'ConsoleHost')
	{
		# Colour the host 'Red' before writing, then reset.
		[System.Console]::ForegroundColor = [System.ConsoleColor]::Red
		[System.Console]::BackgroundColor = [System.ConsoleColor]::Black
		[System.Console]::Error.WriteLine($_)
		[System.Console]::ResetColor()
	}
	else
	{
		# Use the Host's UI while in ISE.
		$Host.UI.WriteErrorLine($_)
	}
}


#---------------------------------------------------------------------------
#
# Apply a customised start menu layout.
#
#---------------------------------------------------------------------------

function Import-CustomStartLayout
{
	$ci = Get-ComputerInfo
	if ($ci.OsBuildNumber -le 22000) {
		Write-Host "Importing layout: $PSScriptRoot\Layout.xml"
		Copy-Item "$PSScriptRoot\Layout.xml" "$env:SystemDrive\Users\Default\AppData\Local\Microsoft\Windows\Shell\LayoutModification.xml" -Force
	} else {
		Write-Host "Importing layout: $PSScriptRoot\Start2.bin"
		MkDir -Path "C:\Users\Default\AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState" -Force -ErrorAction SilentlyContinue
		Copy-Item "$PSScriptRoot\Start2.bin" "$env:SystemDrive\Users\Default\AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\Start2.bin" -Force
	}
}


#---------------------------------------------------------------------------
#
# Apply a customised desktop theme.
#
#---------------------------------------------------------------------------

function Import-CustomDesktopTheme
{
	Write-Host "Setting up Autopilot theme"
	Mkdir "$env:WinDir\Resources\OEM Themes" -Force | Out-Null
	Copy-Item "$PSScriptRoot\Autopilot.theme" "$env:WinDir\Resources\OEM Themes\Autopilot.theme" -Force
	Mkdir "$env:WinDir\web\wallpaper\Autopilot" -Force | Out-Null
	Copy-Item "$PSScriptRoot\Autopilot.jpg" "$env:WinDir\web\wallpaper\Autopilot\Autopilot.jpg" -Force
	Write-Host "Setting Autopilot theme as the new user default"
	reg.exe load HKLM\TempUser "$env:SystemDrive\Users\Default\NTUSER.DAT" | Out-Host
	reg.exe add "HKLM\TempUser\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes" /v InstallTheme /t REG_EXPAND_SZ /d "%SystemRoot%\resources\OEM Themes\Autopilot.theme" /f | Out-Host
	reg.exe unload HKLM\TempUser | Out-Host
}


#---------------------------------------------------------------------------
#
# Apply a customised time zone.
#
#---------------------------------------------------------------------------

function Set-CustomTimeZone
{
	Write-Host "Setting time zone: $($config.Config.TimeZone)"
	Set-Timezone -Id $config.Config.TimeZone
}


#---------------------------------------------------------------------------
#
# Enable location services for automatic time configuration.
#
#---------------------------------------------------------------------------

function Enable-LocationServices
{
	# Enable location services so the time zone will be set automatically (even when skipping the privacy page in OOBE) when an administrator signs in
	Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Name "Value" -Type "String" -Value "Allow" -Force
	Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}" -Name "SensorPermissionState" -Type "DWord" -Value 1 -Force
	Start-Service -Name "lfsvc" -ErrorAction SilentlyContinue
}


#---------------------------------------------------------------------------
#
# Remove provisioned applications from device.
#
#---------------------------------------------------------------------------

function Remove-ProvisionedApps
{
	Write-Host "Removing specified in-box provisioned apps"
	$apps = Get-AppxProvisionedPackage -online
	$config.Config.RemoveApps.App | % {
		$current = $_
		$apps | ? {$_.DisplayName -eq $current} | % {
			Write-Host "Removing provisioned app: $current"
			$_ | Remove-AppxProvisionedPackage -Online | Out-Null
		}
	}
}


#---------------------------------------------------------------------------
#
# Install OneDrive machine-wide.
#
#---------------------------------------------------------------------------

function Install-OneDriveMachineWide
{
	if ($config.Config.OneDriveSetup)
	{
		Write-Host "Downloading OneDriveSetup"
		$dest = "$($env:TEMP)\OneDriveSetup.exe"
		$client = new-object System.Net.WebClient
		$client.DownloadFile($config.Config.OneDriveSetup, $dest)
		Write-Host "Installing: $dest"
		$proc = Start-Process $dest -ArgumentList "/allusers" -WindowStyle Hidden -PassThru
		$proc.WaitForExit()
		Write-Host "OneDriveSetup exit code: $($proc.ExitCode)"
	}
}


#---------------------------------------------------------------------------
#
# Disable Microsoft Edge desktop shortcut creation.
#
#---------------------------------------------------------------------------

function Disable-EdgeDesktopShortcut
{
	Write-Host "Turning off (old) Edge desktop shortcut"
	reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v DisableEdgeDesktopShortcutCreation /t REG_DWORD /d 1 /f /reg:64 | Out-Host

	Write-Host "Turning off Edge desktop icon"
	reg.exe add "HKLM\SOFTWARE\Policies\Microsoft\EdgeUpdate" /v "CreateDesktopShortcutDefault" /t REG_DWORD /d 0 /f /reg:64 | Out-Host
}


#---------------------------------------------------------------------------
#
# Install any specified language packs.
#
#---------------------------------------------------------------------------

function Install-LanguagePacks
{
	Get-ChildItem "$PSScriptRoot\LPs" -Filter *.cab | % {
		Write-Host "Adding language pack: $($_.FullName)"
		Add-WindowsPackage -Online -NoRestart -PackagePath $_.FullName
	}
}


#---------------------------------------------------------------------------
#
# Import specified language settings via intl.cpl.
#
#---------------------------------------------------------------------------

function Import-LanguageSettings
{
	if ($config.Config.Language)
	{
		Write-Host "Configuring language using: $($config.Config.Language)"
		& $env:SystemRoot\System32\control.exe "intl.cpl,,/f:`"$PSScriptRoot\$($config.Config.Language)`""
	}
}


#---------------------------------------------------------------------------
#
# Add specified Windows features.
#
#---------------------------------------------------------------------------

function Add-WindowsFeatures
{
	$currentWU = (Get-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" -ErrorAction Ignore).UseWuServer
	if ($currentWU -eq 1)
	{
		Write-Host "Turning off WSUS"
		Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU"  -Name "UseWuServer" -Value 0
		Restart-Service wuauserv
	}
	$config.Config.AddFeatures.Feature | % {
		Write-Host "Adding Windows feature: $_"
		Add-WindowsCapability -Online -Name $_
	}
	if ($currentWU -eq 1)
	{
		Write-Host "Turning on WSUS"
		Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU"  -Name "UseWuServer" -Value 1
		Restart-Service wuauserv
	}
}


#---------------------------------------------------------------------------
#
# Import specified default app associations.
#
#---------------------------------------------------------------------------

function Import-DefaultAppAssociations
{
	if ($config.Config.DefaultApps)
	{
		Write-Host "Setting default apps: $($config.Config.DefaultApps)"
		& Dism.exe /Online /Import-DefaultAppAssociations:`"$PSScriptRoot\$($config.Config.DefaultApps)`"
	}
}


#---------------------------------------------------------------------------
#
# Set specified registration info.
#
#---------------------------------------------------------------------------

function Set-RegistrationInfo
{
	Write-Host "Configuring registered user information"
	reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v RegisteredOwner /t REG_SZ /d "$($config.Config.RegisteredOwner)" /f /reg:64 | Out-Host
	reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v RegisteredOrganization /t REG_SZ /d "$($config.Config.RegisteredOrganization)" /f /reg:64 | Out-Host
}


#---------------------------------------------------------------------------
#
# Set specified OEM info.
#
#---------------------------------------------------------------------------

function Set-OEMInformation
{
	if ($config.Config.OEMInfo)
	{
		Write-Host "Configuring OEM branding info"
		reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" /v Manufacturer /t REG_SZ /d "$($config.Config.OEMInfo.Manufacturer)" /f /reg:64 | Out-Host
		reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" /v Model /t REG_SZ /d "$($config.Config.OEMInfo.Model)" /f /reg:64 | Out-Host
		reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" /v SupportPhone /t REG_SZ /d "$($config.Config.OEMInfo.SupportPhone)" /f /reg:64 | Out-Host
		reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" /v SupportHours /t REG_SZ /d "$($config.Config.OEMInfo.SupportHours)" /f /reg:64 | Out-Host
		reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" /v SupportURL /t REG_SZ /d "$($config.Config.OEMInfo.SupportURL)" /f /reg:64 | Out-Host
		Copy-Item "$PSScriptRoot\$($config.Config.OEMInfo.Logo)" "$env:WinDir\$($config.Config.OEMInfo.Logo)" -Force
		reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" /v Logo /t REG_SZ /d "$env:WinDir\$($config.Config.OEMInfo.Logo)" /f /reg:64 | Out-Host
	}
}


#---------------------------------------------------------------------------
#
# Enable UE-V on system.
#
#---------------------------------------------------------------------------

function Enable-UserExperienceVirtualization
{
	Write-Host "Enabling UE-V"
	Enable-UEV
	Set-UevConfiguration -Computer -SettingsStoragePath "%OneDriveCommercial%\UEV" -SyncMethod External -DisableWaitForSyncOnLogon
	Get-ChildItem "$PSScriptRoot\UEV" -Filter *.xml | % {
		Write-Host "Registering template: $($_.FullName)"
		Register-UevTemplate -Path $_.FullName
	}
}


#---------------------------------------------------------------------------
#
# Disable network location flyout.
#
#---------------------------------------------------------------------------

function Disable-NetworkLocationFlyout
{
	Write-Host "Turning off network location fly-out"
	reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\Network\NewNetworkWindowOff" /f
}


#---------------------------------------------------------------------------
#
# Flag to system that Autopilot branding toolkit was installed.
#
#---------------------------------------------------------------------------

function Update-SuccessTag
{
	if (-not (Test-Path "$($env:ProgramData)\Microsoft\AutopilotBranding"))
	{
	    Mkdir "$($env:ProgramData)\Microsoft\AutopilotBranding"
	}
	Set-Content -Path "$($env:ProgramData)\Microsoft\AutopilotBranding\AutopilotBranding.ps1.tag" -Value "Installed"
}


#---------------------------------------------------------------------------
#
# Main execution code block for script.
#
#---------------------------------------------------------------------------

# If we are running as a 32-bit process on an x64 system, re-launch as a 64-bit process
if ("$env:PROCESSOR_ARCHITEW6432" -ne "ARM64")
{
    if (Test-Path "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe")
    {
        & "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy bypass -NoProfile -File "$PSCommandPath"
        Exit $lastexitcode
    }
}

# Start logging
Start-Transcript "$($env:ProgramData)\Microsoft\AutopilotBranding\AutopilotBranding.log"

# PREP: Load the Config.xml
Write-Host "Install folder: $PSScriptRoot"
Write-Host "Loading configuration: $PSScriptRoot\Config.xml"
[Xml]$config = Get-Content "$PSScriptRoot\Config.xml"

# Main execution process.
try
{
	Import-CustomStartLayout
	Import-CustomDesktopTheme
	if ($config.Config.TimeZone) { Set-TimeZone } else { Enable-LocationServices }
	Remove-ProvisionedApps
	Install-OneDriveMachineWide
	Disable-EdgeDesktopShortcut
	Install-LanguagePacks
	Import-LanguageSettings
	Add-WindowsFeatures
	Import-DefaultAppAssociations
	Set-RegistrationInfo
	Set-OEMInformation
	Enable-UserExperienceVirtualization
	Disable-NetworkLocationFlyout
	Update-SuccessTag
	$exitCode = 0
}
catch
{
	$_ | Out-FriendlyErrorMessage | Write-StdErrMessage
	$exitCode = 1618
}
finally
{
	Stop-Transcript
	exit $exitCode
}
