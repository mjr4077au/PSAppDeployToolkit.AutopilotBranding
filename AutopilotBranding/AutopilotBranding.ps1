
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
$scrname = 'AutopilotBranding'
$divider = [System.Text.RegularExpressions.Regex]::Unescape('\u2014') * 75


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
	if ([System.IO.File]::Exists(($layout = "$PSScriptRoot\Layout.xml")) -and (Get-ComputerInfo).OsBuildNumber -le 22000)
	{
		Write-Host "Importing layout: $layout"
		Copy-Item $layout "$env:SystemDrive\Users\Default\AppData\Local\Microsoft\Windows\Shell\LayoutModification.xml" -Force
	}
	else if ([System.IO.File]::Exists(($layout = "$PSScriptRoot\Start2.bin")))
	{
		Write-Host "Importing layout: $layout"
		MkDir -Path "C:\Users\Default\AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState" -Force -ErrorAction SilentlyContinue
		Copy-Item $layout "$env:SystemDrive\Users\Default\AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\Start2.bin" -Force
	}
}


#---------------------------------------------------------------------------
#
# Apply a customised desktop theme.
#
#---------------------------------------------------------------------------

function Import-CustomDesktopTheme
{
	if ([System.IO.File]::Exists(($theme = "$PSScriptRoot\Autopilot.theme")) -and [System.IO.File]::Exists(($wallpaper = "$PSScriptRoot\Autopilot.jpg")))
	{
		# Set up Autopilot theme.
		Copy-Item -Path $theme -Destination "$([System.IO.Directory]::CreateDirectory("$env:WinDir\Resources\OEM Themes").FullName)\Autopilot.theme" -Force
		Copy-Item -Path $wallpaper -Destination "$([System.IO.Directory]::CreateDirectory("$env:WinDir\Web\Wallpaper\Autopilot").FullName)\Autopilot.jpg" -Force

		# Configure it to be default in registry.
		[System.Void](reg.exe LOAD HKLM\TempUser "$env:SystemDrive\Users\Default\NTUSER.DAT" 2>&1)
		[System.Void](reg.exe ADD "HKLM\TempUser\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes" /v InstallTheme /t REG_EXPAND_SZ /d "%SystemRoot%\Resources\OEM Themes\Autopilot.theme" /f 2>&1)
		[System.Void](reg.exe UNLOAD HKLM\TempUser 2>&1)
		Write-Host "Sucessfully deployed Autopilot theme."
		Write-Host $divider
	}
}


#---------------------------------------------------------------------------
#
# Apply a customised time zone.
#
#---------------------------------------------------------------------------

function Set-CustomTimeZone
{
	if ($config.Config.TimeZone)
	{
		Set-TimeZone -Id $config.Config.TimeZone
		Write-Host "Successfully set timezone to '$($config.Config.TimeZone)'."
		Write-Host $divider
	}
}


#---------------------------------------------------------------------------
#
# Enable location services for automatic time configuration.
#
#---------------------------------------------------------------------------

function Enable-LocationServices
{
	# Enable location services so the time zone will be set automatically (even when skipping the privacy page in OOBE) when an administrator signs in
	[System.Void](reg.exe ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /v Value /t REG_SZ /d Allow /f 2>&1)
	[System.Void](reg.exe ADD "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}" /v SensorPermissionState /t REG_DWORD /d 1 /f 2>&1)
	[System.Void](reg.exe ADD "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsAccessLocation /t REG_DWORD /d 1 /f 2>&1)
	
	# Try to start location services.
	try
	{
		Start-Service -Name lfsvc
		Write-Host "Successfully enabled location services and started the Geolocation service."
	}
	catch
	{
		Write-Host "Successfully enabled location services but failed to start the Geolocation service, time may not be set as expected."
	}
	Write-Host $divider
}


#---------------------------------------------------------------------------
#
# Remove provisioned applications from device.
#
#---------------------------------------------------------------------------

function Remove-ProvisionedApps
{
	if ($config.Config.RemoveApps -and $config.Config.RemoveApps.App)
	{
		# Get all provisioned apps we need to remove where they exist.
		$apps = Get-AppxProvisionedPackage -Online | Where-Object {$config.Config.RemoveApps.App -contains $_.DisplayName}
		Write-Host "Removing $($apps.Count)/$($config.Config.RemoveApps.App.Count) specified in-box provisioned apps, please wait..."

		# Do removals and advise of success.
		$apps | ForEach-Object {
			[System.Void]($_ | Remove-AppxProvisionedPackage -Online)
			Write-Host "Removed provisioned app '$($_.DisplayName)'."
		}
		Write-Host "Successfully removed specified in-box provisioned apps."
		Write-Host $divider
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
		# Commence download.
		Write-Host "Downloading OneDriveSetup.exe, please wait..."
		Invoke-WebRequest -UseBasicParsing -Uri $config.Config.OneDriveSetup -OutFile ($dest = "$($env:TEMP)\OneDriveSetup.exe")

		# Commence install.
		Write-Host "Installing OneDriveSetup.exe, please wait..."
		cmd.exe /c $dest 2>&1
		Write-Host "Successfully installed OneDriveSetup.exe with exit code '$LASTEXITCODE'."
		Write-Host $divider
	}
}


#---------------------------------------------------------------------------
#
# Disable Microsoft Edge desktop shortcut creation.
#
#---------------------------------------------------------------------------

function Disable-EdgeDesktopShortcut
{
	[System.Void](reg.exe ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v DisableEdgeDesktopShortcutCreation /t REG_DWORD /d 1 /f /reg:64 2>&1)
	[System.Void](reg.exe ADD "HKLM\SOFTWARE\Policies\Microsoft\EdgeUpdate" /v "CreateDesktopShortcutDefault" /t REG_DWORD /d 0 /f /reg:64 2>&1)
	Write-Host "Successfully disabled creation of Microsoft Edge desktop shortcuts."
	Write-Host $divider
}


#---------------------------------------------------------------------------
#
# Install any specified language packs.
#
#---------------------------------------------------------------------------

function Install-LanguagePacks
{
	# Get language packs and store.
	if ($lps = Get-ChildItem -Path "$PSScriptRoot\LPs\*.cab")
	{
		Write-Host "Adding $($lps.Count) language pack$(if ($lps.Count -ne 1) {'s'}), please wait..."
		$lps.FullName | ForEach-Object {
			Add-WindowsPackage -Online -NoRestart -PackagePath $_
			Write-Host "Added language pack '$_'."
		}
		Write-Host "Successfully added language pack$(if ($lps.Count -ne 1) {'s'})."
		Write-Host $divider
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
		control.exe "intl.cpl,,/f:`"$PSScriptRoot\$($config.Config.Language)`"" 2>&1
		Write-Host "Successfully configured language using '$($config.Config.Language)'."
		Write-Host $divider
	}
}


#---------------------------------------------------------------------------
#
# Add specified Windows features.
#
#---------------------------------------------------------------------------

function Add-WindowsFeatures
{
	if ($config.Config.AddFeatures -and $config.Config.AddFeatures.Feature)
	{
		Write-Host "Adding $($config.Config.AddFeatures.Feature.Count) Windows Feature$(if ($config.Config.AddFeatures.Feature.Count -ne 1) {'s'}), please wait..."

		# Disable WSUS if it's been enforced via GPOs.
		if (($currentWU = Get-ItemProperty -Path ($path = "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU") -ErrorAction Ignore | Select-Object -ExpandProperty UseWuServer) -eq 1)
		{
			Set-ItemProperty -Path $path -Name UseWuServer -Value 0
			Restart-Service wuauserv
			Write-Host "Temporarily disabled WSUS as required to complete Windows Feature deployments."
		}

		# Install features as required.
		foreach ($feature in $config.Config.AddFeatures.Feature)
		{
			Add-WindowsCapability -Online -Name $feature
			Write-Host "Added Windows Feature '$_'."
		}

		# Re-enable WSUS if it was previously enabled.
		if ($currentWU -eq 1)
		{
			Set-ItemProperty -Path $path -Name UseWuServer -Value 1
			Restart-Service wuauserv
			Write-Host "Re-enabled temporarily disabled WSUS setup."
		}
		Write-Host "Successfully added Windows Feature$(if ($config.Config.AddFeatures.Feature.Count -ne 1) {'s'})."
		Write-Host $divider
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
		dism.exe /Online /Import-DefaultAppAssociations:`"$PSScriptRoot\$($config.Config.DefaultApps)`" 2>&1
		Write-Host "Successfully set default app associations."
		Write-Host $divider
	}
}


#---------------------------------------------------------------------------
#
# Set specified registration info.
#
#---------------------------------------------------------------------------

function Set-RegistrationInfo
{
	if ($config.Config.RegisteredOwner -and $config.Config.RegisteredOrganization)
	{
		@('RegisteredOwner', 'RegisteredOrganization') | ForEach-Object {
			[System.Void](reg.exe ADD "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v $_ /t REG_SZ /d "$($config.Config.($_))" /f /reg:64 2>&1)
		}
		Write-Host "Successfully configured registered user information."
		Write-Host $divider
	}
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
		Copy-Item -Source "$PSScriptRoot\$($config.Config.OEMInfo.Logo)" -Destination "$env:WinDir\$($config.Config.OEMInfo.Logo)" -Force
		@('Manufacturer', 'Model', 'SupportPhone', 'SupportHours', 'SupportURL', 'Logo') | ForEach-Object {
			[System.Void](reg.exe ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" /v $_ /t REG_SZ /d "$($config.Config.OEMInfo.($_))" /f /reg:64 2>&1)
		}
		Write-Host "Successfully configured OEM branding info."
		Write-Host $divider
	}
}


#---------------------------------------------------------------------------
#
# Enable UE-V on system.
#
#---------------------------------------------------------------------------

function Enable-UserExperienceVirtualization
{
	# Do initial setup prior to enablement.
	Write-Host "Enabling UE-V, please wait..."
	Set-UevConfiguration -Computer -SettingsStoragePath "%OneDriveCommercial%\UEV" -SyncMethod External -DisableWaitForSyncOnLogon

	# Apply templates if there's any.
	if ($templates = Get-ChildItem -Path "$PSScriptRoot\UEV\*.xml")
	{
		Write-Host "Registering $($templates.Count) template$(if ($templates.Count -ne 1) {'s'}), please wait..."
		$templates.FullName | ForEach-Object {
			Register-UevTemplate -Path $_
			Write-Host "Registered template '$_'."
		}
		Write-Host "Successfully registered $($templates.Count) template$(if ($templates.Count -ne 1) {'s'})"
	}

	# Finally enable the service after setup is complete.
	Enable-UEV
	Write-Host "Successfully enabled UE-V."
	Write-Host $divider
}


#---------------------------------------------------------------------------
#
# Disable network location flyout.
#
#---------------------------------------------------------------------------

function Disable-NetworkLocationFlyout
{
	[System.Void](reg.exe ADD "HKLM\SYSTEM\CurrentControlSet\Control\Network\NewNetworkWindowOff" /f 2>&1)
	Write-Host "Successfully disabled network location fly-out."
	Write-Host $divider
}


#---------------------------------------------------------------------------
#
# Main execution code block for script.
#
#---------------------------------------------------------------------------

# If we are running as a 32-bit process on an x64 system, re-launch as a 64-bit process
if (($env:PROCESSOR_ARCHITEW6432 -ne "ARM64") -and [System.IO.File]::Exists(($nativePwsh = "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe")))
{
	& $nativePwsh -ExecutionPolicy Bypass -NoProfile -File $PSCommandPath 2>&1
	exit $LASTEXITCODE
}

# Main execution process.
try
{
	# Start logging
	[System.Console]::WriteLine((Start-Transcript -Path ($logPath = [System.IO.Directory]::CreateDirectory("$($env:ProgramData)\Microsoft\$scrname\$scrname.log").FullName)))

	# PREP: Load the Config.xml
	Write-Host "$scrname.ps1 1.14"
	Write-Host "Install folder: $PSScriptRoot"
	Write-Host "Loading configuration: $($confFile = "$PSScriptRoot\Config.xml")"
	($config = [System.Xml.XmlDocument]::new()).Load($confFile)
	Write-Host "Commencing execution, please wait..."
	Write-Host $divider

	# Perform functions.
	Import-CustomStartLayout
	Import-CustomDesktopTheme
	if ($config.Config.TimeZone) { Set-CustomTimeZone } else { Enable-LocationServices }
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

	# Advise of success.
	[System.IO.File]::WriteAllText("$($env:ProgramData)\Microsoft\$scrname\$scrname.ps1.tag", 'Installed')
	$exitCode = 0
	Write-Host "Successfully deployed $scrname.ps1 and all configured functions as required."
}
catch
{
	# Advise of failure.
	$_ | Out-FriendlyErrorMessage | Write-StdErrMessage
	$exitCode = 1
	Write-Host "Failed to deploy all configured components of $scrname.ps1, please review log file at '$logPath' for further details."
}
finally
{
	Stop-Transcript
	exit $exitCode
}
