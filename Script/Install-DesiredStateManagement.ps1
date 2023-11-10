
<#PSScriptInfo

.VERSION 2.7

.GUID dd1fb415-b54e-4773-938c-5c575c335bbd

.AUTHOR Mitch Richters

.COPYRIGHT Copyright © 2023 Mitchell James Richters. All rights reserved.

.TAGS

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
- Made `DefaultStartLayout` supported on Window 10 systems only.
- Made `DefaultLayoutModification` supported on Window 10 systems only.
- Removed checks for Windows version in `DefaultLayoutModification` module.
- Reworked XML schema to support taskbar and start menu elements under `DefaultLayoutModification`.
- Defined `baseJsonFile` schema element for parsing input to `DefaultLayoutModification`.
- Cleaned up remains of legacy `DefaultLayoutModification` from XML schema.
- Updated example XML file to reflect changes.
- Reworked `DefaultLayoutModification` module around changes to underlying XML file.
- Amend extension getting in `Get-SystemShortcutsFilePath` to use [System.IO.Path]::GetExtension() instead of doing a split.
- Rename `Get-IncorrectOemInformation` to `Get-IncorrectOemInformation`.
- Clean up some local variable names within functions for consistency.
- Don't ignore errors from `Get-FileHash` within `Invoke-DefaultAppAssociationsPreOps`.
- Don't ignore errors from `Get-FileHash` within `Invoke-LanguageDefaultsPreOps`.
- Simplify test performed in `Test-DefaultAppAssociationsApplicability`.
- Simplify test performed in `Test-LanguageDefaultsApplicability`.
- Simplify test performed in `Test-DefaultStartLayoutValidity`.

#>

<#

.SYNOPSIS
Installs a preconfigured list of system defaults, validates them or removes them as required.

.DESCRIPTION
Inspired by Michael Niehaus' "AutopilotBranding" toolkit, this script is specifically designed to be used to install a set of system baseline defaults for workstations, extending from languages, removal of built-in apps/features, user defaults via Active Setup, and more.

An example setup via an XML configuration file would be:

<Config Version="1.0">
	<Content>
		<!--Note: If a Source is not specified, the script will assume you've provided data in the destination yourself-->
		<Source>https://www.mysite.com.au/intune/desiredstate/content.zip</Source>
		<Destination>%ProgramData%\DesiredStateManagement\Content</Destination>
		<EnvironmentVariable>DesiredStateContents</EnvironmentVariable>
	</Content>
	<RegistrationInfo>
		<RegisteredOwner>Registered Owner</RegisteredOwner>
		<RegisteredOrganization>Registered Organisation</RegisteredOrganization>
	</RegistrationInfo>
	<OemInformation>
		<Manufacturer>Contoso</Manufacturer>
		<Logo>https://www.contoso.com/Contoso.bmp</Logo>
		<SupportPhone>+1 800-555-1212</SupportPhone>
		<SupportHours>8am-5pm PST</SupportHours>
		<SupportURL>http://www.contoso.com</SupportURL>
	</OemInformation>
	<SystemDriveLockdown Enabled="1" />
	<DefaultStartLayout>DefaultLayouts.xml</DefaultStartLayout>
	<DefaultLayoutModification>
		<Taskbar>LayoutModification.xml</Taskbar>
		<StartMenu>LayoutModification.json</StartMenu>
	</DefaultLayoutModification>
	<DefaultAppAssociations>DefaultAssociations.xml</DefaultAppAssociations>
	<LanguageDefaults>LanguageUnattend.xml</LanguageDefaults>
	<DefaultTheme>Autopilot.theme</DefaultTheme>
	<ActiveSetup Identifier="User Defaults">
		<!--Note: Once you set this identifier for your customer, don't ever change it!-->
		<!--Note: Only increment version numbers if you wish to re-trigger the default on next logon, not necessarily because you made a change!-->
		<Component Version="1">
			<Name>Reduce Taskbar Searchbox</Name>
			<StubPath>reg.exe add HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search /v SearchboxTaskbarMode /t REG_DWORD /d 1 /f</StubPath>
		</Component>
	</ActiveSetup>
	<SystemShortcuts>
		<!--Note: For 'IconLocation', please ensure the index of the icon is provided at the end, separated by a comma ("file.ico,0", etc)-->
		<Shortcut Location="CommonDesktopDirectory" Name="WebApp.lnk">
			<TargetPath>%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe</TargetPath>
			<Arguments>https://www.company.com/path/to/webapp</Arguments>
		</Shortcut>
		<Shortcut Location="CommonDesktopDirectory" Name="Google.url">
			<TargetPath>https://www.google.com</TargetPath>
		</Shortcut>
	</SystemShortcuts>
	<RegistryData>
		<Item Description="Disable Fast Startup">
			<Key>HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Power</Key>
			<Name>HiberbootEnabled</Name>
			<Value>0x0</Value>
			<Type>REG_DWORD</Type>
		</Item>
	</RegistryData>
	<RemoveApps>
		<App>Microsoft.GetHelp</App>
	</RemoveApps>
	<WindowsCapabilities>
		<Capability Action="Install">NetFX3~~~~</Capability>
		<Capability Action="Remove">App.Support.QuickAssist~~~~0.0.1.0</Capability>
		<Capability Action="Remove">Browser.InternetExplorer~~~~0.0.11.0</Capability>
	</WindowsCapabilities>
	<WindowsOptionalFeatures>
		<Feature Action="Disable">MicrosoftWindowsPowerShellV2</Feature>
		<Feature Action="Enable">TelnetClient</Feature>
		<Feature Action="Enable">TFTP</Feature>
	</WindowsOptionalFeatures>
</Config>

Each element within <Config></Config> is supported by a submodule containing code to handle the element as required. The config is supported by a schema that governs the provided data.

CmdletBinding() is specified on the script and can be called with all supported common parameters as required.

.PARAMETER Install
Instructs the script to install missing defaults as per the supplied configuration.

.PARAMETER Remove
Instructs the script to remove installed defaults as per the supplied configuration.

.PARAMETER Mode
Instructs the script to operate in one of the modes supported by the switch parameters. Sometimes its easier to pass a string for this.

.PARAMETER Config
Specifies the file path/URI, or raw XML to use as the configuration source for the script.

.EXAMPLE
powershell.exe -ExecutionPolicy Bypass -NoProfile -NoLogo -NonInteractive -File Install-DesiredStateManagement.ps1

.EXAMPLE
powershell.exe -ExecutionPolicy Bypass -NoProfile -NoLogo -NonInteractive -File Install-DesiredStateManagement.ps1 -Install

.EXAMPLE
powershell.exe -ExecutionPolicy Bypass -NoProfile -NoLogo -NonInteractive -File Install-DesiredStateManagement.ps1 -Remove

.EXAMPLE
powershell.exe -ExecutionPolicy Bypass -NoProfile -NoLogo -NonInteractive -File Install-DesiredStateManagement.ps1 -Mode Install

.EXAMPLE
powershell.exe -ExecutionPolicy Bypass -NoProfile -NoLogo -NonInteractive -File Install-DesiredStateManagement.ps1 -Mode Install -Config 'C:\Path\To\Config.xml'

.INPUTS
None. You cannot pipe objects to Install-DesiredStateManagement.ps1.

.OUTPUTS
stdout stream. Install-DesiredStateManagement.ps1 returns a log string via Write-Host that can be piped.
stderr stream. Install-DesiredStateManagement.ps1 writes all error text to stderr for catching externally to PowerShell if required.

.NOTES
*Changelog*

2.6
- Added `Get-WindowsNameVersion` to enumerate an OS build number down to its named version (10, 11, 7, XP, etc).
- Clean up `Convert-SystemShortcutsToComProperties` by just attempting to expand all properties.
- Clean up setup in `Sync-SystemShortcuts` by making better usage of the ForEach() method loop.
- Add `baseAnyPath` to XML schema for SystemShortcuts to allow the usage of a URL in the TargetPath.
- Repair handling inside `Convert-SystemShortcutsToComProperties` to accomodate .url files as well as .lnk.
- Overhaul `Get-RemoveAppsState` to ensure the caller is advised when apps are considered mandatory.
- Ensure `Get-RemoveAppsState` testes whether an app as returned by `Get-AppxPackage` is considered non-removable.
- Repair `Get-RegistryDataItemValue` to ensure the value is tested for null before trying to convert a binary array.
- Cast path in `Get-SystemShortcutsFilePath` to [System.IO.FileInfo] so a proper object is returned.
- Cleaned up log messages in `Install-RemoveApps`.
- Cleaned up log messages in `Remove-RemoveAppProvisionment` and `Remove-RemoveAppInstallation`.
- Cleaned up log messages in `Remove-ListedWindowsCapability` and `Install-ListedWindowsCapability`.
- Cleaned up log messages in `Disable-ListedWindowsOptionalFeature` and `Enable-ListedWindowsOptionalFeature`.
- Change all filters that call native executables to functions and give them a begin {} block to clear $LASTEXITCODE.
- Rework `Remove-RegistryData` to test $LASTEXITCODE to determine whether a reboot is needed or not.
- Use [Microsoft.Win32.Registry] accesses/setting where possible. Avoids nulling `Set-ItemProperty` and is faster.

2.5
- Rework script to allow providing config externally, either as a file path/URI, or as raw XML input.
- Rework script to allow content to be externally provided by opting out of specifying a source.
- Rework Content module setup to not have the environment variable be the linchpin on whether the destination is valid or not.
- Externalise variable check in Content module to `Get-EnvironmentVariableValue`, specifically handling the retrieval of variables set within the same execution context.
- Fix `Get-ChildItem` calls within `Test-ContentValidity` to ensure that the `-File` argument is passed to exclude any directories being piped into `Get-FileHash`.
- Make `Invoke-DefaultUserRegistryAction` accept input via a parameter as well as the pipeline.
- Added `$Mode` argument to allow specifying mode based on a string rather than a switch.
- Replace all `-join` operations with `[System.String]::Join()`, which is 2-3x faster.
- Updated Content module to inject Content path into system's path variable.
- Improve logging for `Remove-RegistryDataItem` which did not report its operations.
- Improve logging consistency for `Install-OemInformation` with rest of script.
- Only perform a reboot if a module requires it rather than unconditionally.

2.4
- Added setup for `DefaultLayoutModification`, supporting Windows 10 and 11.
- Added setup for deploying system shortcuts, currently limited to common desktop/start menu/startup locations.
- Massive re-write of XML schema to allow reuse of repeated code blocks. The end result is over 100 lines of reduction.
- Re-wrote regex restrictions for a number of areas to work how I originally intended them to work.
- Ensure regex restrictions apply to `WindowsCapabilities` elements.
- Ensure regex restrictions apply to `WindowsOptionalFeatures` elements.
- Use `[Microsoft.Win32.Registry]` inside `Get-RegistryDataItemValue` for better `REG_BINARY` operability.
- Updated XML schema to mandate full HKEY name usage as required for `[Microsoft.Win32.Registry]`.
- Uplift `Out-FriendlyErrorMessage` to be able to handle InnerExceptions where available.
- Updated formula in `ConvertTo-BulletedList` to prevent trailing spaces on lines.
- Remove some unnecessary sub-expressions.

2.3
- Bump copyright to 2023.
- Reflectively get the script's version instead of hard-coding it.
- Reflectively get the script's author instead of hard-coding it.
- Replace `Get-Date` calls with `[System.DateTime]::Now` as its more performant.
- Move `$moduledata` to $Script hashtable and set up from within `Initialize-ModuleData`.
- Move `$xml` to $Script hashtable. Table can now be globalised for debug purposes.
- Rename `Out-ScriptHeader` to `Open-Log`.
- Create `Close-Log` for consistent setup with `Open-Log`.
- Change failed exit code from 1618 to 1603.
- Rename `$script.LogSuffix` to `$script.LogDiscriminator`.
- Add `$script.Action` to log filename, right after `$script.LogDiscriminator`.
- Clean up braces in all funcs as I use Allman styling, not Stroustrup these days.
- Use [System.Collections.Hashtable]::Add() for adding new items as its faster.
- Replace `System.Collections.Hashtable` `[]` accesses with member accesses.
- Clean up internals of `Out-FriendlyErrorMessage`.
- Clean up internals of `Install-ActiveSetupComponent`.
- Clean up internals of `Test-ContentValidity`.
- Change switch in `Install-Content` to do case-sensitive regex matching.
- Add missing breaks to each switch case in aforementioned switch.
- Changed log setup in `Install-Content` to use pipeline for more accurate logging.
- Changed returns in `Test-ContentValidity` to return 1 or higher on error, like other funcs.
- Repair logic issue in `Test-ContentValidity` where ForEach-Object loop can't do early return.
- Repair issue where `[System.IO.Path]::GetTempPath()` sometimes returns a trailing slash.
- Repair incorrect schema for <RegistryData><Item Description=""> not being required, but optional.
- Repair issue with `Get-ActiveSetupState` `Mismatched` calculation that wasn't depending on correct properties.
- Changed returns in `Test-DefaultStartLayoutValidity` to return 1 or higher on error, like other funcs.
- Write validation output to StdErr instead of StdOut so that it's coloured and Intune Management Extension separates it correctly.
- Reworked `Get-RemoveAppsState` and `Remove-RemoveAppInstallation` to be compatible with PowerShell 5.1 and 7.3.x.
- Re-write `Get-ItemPropertyUnexpanded` to take better advantage of `.ForEach()` method of incoming object.
- Clean up internals of `Get-OemInformationIncorrectChildNodes`.
- Removed needless quoting of variables passed to binary executables.
- Optimised op generation loop within `Get-DesiredStateOperations`.
- Merge `Get-DesiredStateOperations` into `Invoke-DesiredStateOperations`.
- Repair hard-coded usage of `%DesiredStateContents%` in string.
- Amend `Get-WindowsCapabilitiesState` to treat `InstallPending` as success.
- Consolidate `Write-Host` usage to `Write-LogEntry` cmdmet to quieten `Invoke-ScriptAnalyzer`.
- Remove unused `$transcribing` variable.
- Use `ConvertTo-BulletedList` everywhere.

2.2
- Repair Remove-AppxPackage calls by ensuring harvesting of apps to remove tests `$_.PackageUserInformation.InstallState` is installed for anyone first.
- Repaired issues with `Remove-AppxPackage` calls by not using `-AllUsers`, but rather loop through the installed user SIDs and remove individually.
- Replace `Where-Object` pipeline operations with `.Where()` method calls on stored arrays of data.
- Consolidated some uses of Where with ForEach by just doing a branch check in the ForEach block.
- Replace all -eq/-ne with .Equals() method calls. It's faster and also will hard stop on null data for better error checking.
- Changed casts of native cmdlets to `Out-Null` for legibility, only use casts for native binaries.
- Removed `$Action` parameter from `Remove-ActiveSetupComponent` that was remaining after copy-pasting `Install-ActiveSetupComponent`.
- Slightly tidied up `Remove-DefaultTheme` and `Get-ContentFilePath`.
- Added missed error handling to `Invoke-ContentPreOps` to match other module pre-op functions.
- Partially re-wrote `Test-ContentValidity` for greater clarity.
- Use `Test-Path` in place of silencing errors where suited.
- Add heading that was missing for DefaultStartLayout code segment.
- Added better handling of obtaining default user profile locations from the registry vs. hard-coded paths.
- Improve logic used in `Remove-DefaultStartLayout` function.
- Fixed state detection issue in `OemInformation` section.

1.1
- Functionalised some more code for better clarity.
- Fixed `-Force` argument against `New-ItemProperty` for RegistrationInfo section that was in piped object and not on the cmdlet call.
- Change main execution block to test for function existence, not just that $moduledata has a supporting key.
- Externalised the Content environment variable to be configurable in the config file.
- Added variable '$script.LogSuffix' to set a suffix to the log file generated (optional, handy for mult-region clients).
- Remove 2nd call to `Get-Date` in $moduledata.DefaultStartLayout.Archive, we now rely on $script.StartDate instead.
- Consolidate all `reg.exe ADD` calls to use `Install-RegistryDataItem` from the `RegistryData` module.

2.0
- Initial release.

#>

[CmdletBinding(DefaultParameterSetName = 'Confirm')]
Param (
	[Parameter(Mandatory = $true, ParameterSetName = 'Install')]
	[System.Management.Automation.SwitchParameter]$Install,

	[Parameter(Mandatory = $true, ParameterSetName = 'Remove')]
	[System.Management.Automation.SwitchParameter]$Remove,

	[Parameter(Mandatory = $true, ParameterSetName = 'ModeSelect')]
	[ValidateSet('Confirm', 'Install', 'Remove')]
	[System.String]$Mode,

	[Parameter(Mandatory = $false, ParameterSetName = 'Install', HelpMessage = "Provide the path/URI to the config, or raw XML input.")]
	[Parameter(Mandatory = $false, ParameterSetName = 'Remove', HelpMessage = "Provide the path/URI to the config, or raw XML input.")]
	[Parameter(Mandatory = $false, ParameterSetName = 'Confirm', HelpMessage = "Provide the path/URI to the config, or raw XML input.")]
	[Parameter(Mandatory = $false, ParameterSetName = 'ModeSelect', HelpMessage = "Provide the path/URI to the config, or raw XML input.")]
	[ValidateNotNullOrEmpty()]
	[System.String]$Config
)

# Set required variables to ensure script functionality.
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
Set-PSDebug -Strict
Set-StrictMode -Version Latest

# Define script properties.
$script = @{
	Name = 'Install-DesiredStateManagement.ps1'  # Hard-coded as using script as detection script will mangle the filename.
	Info = Test-ScriptFileInfo -LiteralPath $MyInvocation.MyCommand.Source
	LogDiscriminator = [System.String]::Empty
	Action = if ($Mode) {$Mode} else {$PSCmdlet.ParameterSetName}
	Divider = ([System.Char]0x2014).ToString() * 79
	StartDate = [System.DateTime]::Now
	WScriptShell = New-Object -ComObject WScript.Shell
	ExitCode = 0
}

# Store XML schema.
$schema = @'
<?xml version="1.0" encoding="utf-8"?>
<xs:schema attributeFormDefault="qualified" elementFormDefault="qualified" xmlns:xs="http://www.w3.org/2001/XMLSchema">
	<!--Element/attribute restriction definitions-->
	<xs:simpleType name="baseStandardString">
		<xs:restriction base="xs:string">
			<xs:pattern value="^[^\s].+[^\s]$"/>
		</xs:restriction>
	</xs:simpleType>

	<xs:simpleType name="baseAnyPath">
		<xs:restriction base="xs:string">
			<xs:pattern value="^((%[^%]+%|\\\\.+)(\\[^\\]+)+(?&lt;=\w)|(\w+:\/\/)?.+(?&lt;=(\w|\/)))$"/>
		</xs:restriction>
	</xs:simpleType>

	<xs:simpleType name="baseAnyFilePath">
		<xs:restriction base="xs:string">
			<xs:pattern value="^(%[^%]+%|\\\\.+)(\\[^\\]+)+(?&lt;=\w)$"/>
		</xs:restriction>
	</xs:simpleType>

	<xs:simpleType name="baseShortcutRelativePath">
		<xs:restriction base="xs:string">
			<xs:pattern value="^(%[^%]+%|\\\\.+|\.{2})(\\[^\\]+)+(?&lt;=\w)$"/>
		</xs:restriction>
	</xs:simpleType>

	<xs:simpleType name="baseShortcutIconLocation">
		<xs:restriction base="xs:string">
			<xs:pattern value="^(%[^%]+%|\\\\.+)(\\[^\\]+)+(?&lt;=\w),\d+$"/>
		</xs:restriction>
	</xs:simpleType>

	<xs:simpleType name="baseShortcutWindowStyle">
		<xs:restriction base="xs:integer">
			<xs:pattern value="^(1|3|7)$"/>
		</xs:restriction>
	</xs:simpleType>

	<xs:simpleType name="baseContentSource">
		<xs:restriction base="xs:string">
			<xs:pattern value="^https:\/\/.+\.zip$"/>
		</xs:restriction>
	</xs:simpleType>

	<xs:simpleType name="baseContentDestination">
		<xs:restriction base="xs:string">
			<xs:pattern value="^%[^%]+%\\.+[^.\s]$"/>
		</xs:restriction>
	</xs:simpleType>

	<xs:simpleType name="baseXmlFile">
		<xs:restriction base="xs:string">
			<xs:pattern value="^(?!\w:|:|\\|\s)[^%]+\.xml$"/>
		</xs:restriction>
	</xs:simpleType>

	<xs:simpleType name="baseBmpFile">
		<xs:restriction base="xs:string">
			<xs:pattern value="^(?!\w:|:|\\|\s)[^%]+\.bmp$"/>
		</xs:restriction>
	</xs:simpleType>

	<xs:simpleType name="baseJsonFile">
		<xs:restriction base="xs:string">
			<xs:pattern value="^(?!\w:|:|\\|\s)[^%]+\.json$"/>
		</xs:restriction>
	</xs:simpleType>

	<xs:simpleType name="baseThemeFile">
		<xs:restriction base="xs:string">
			<xs:pattern value="^(?!\w:|:|\\|\s)[^%]+\.theme$"/>
		</xs:restriction>
	</xs:simpleType>

	<xs:simpleType name="baseShortcutFile">
		<xs:restriction base="xs:string">
			<xs:pattern value="^(?!\w:|:|\\|\s)[^%]+\.(lnk|url)$"/>
		</xs:restriction>
	</xs:simpleType>

	<xs:simpleType name="baseShortcutLocation">
		<xs:restriction base="xs:string">
			<xs:pattern value="^Common(DesktopDirectory|StartMenu|Startup)$"/>
		</xs:restriction>
	</xs:simpleType>

	<xs:simpleType name="baseRegistryDataKey">
		<xs:restriction base="xs:string">
			<xs:pattern value="^HKEY_(LOCAL_MACHINE|CURRENT_(CONFIG|USER)|CLASSES_ROOT|USERS).*[^.\s]$"/>
		</xs:restriction>
	</xs:simpleType>

	<xs:simpleType name="baseRegistryDataType">
		<xs:restriction base="xs:string">
			<xs:pattern value="^REG_(SZ|MULTI_SZ|EXPAND_SZ|DWORD|BINARY)$"/>
		</xs:restriction>
	</xs:simpleType>

	<xs:simpleType name="baseInstallRemove">
		<xs:restriction base="xs:string">
			<xs:pattern value="^(Install|Remove)$"/>
		</xs:restriction>
	</xs:simpleType>

	<xs:simpleType name="baseEnableDisable">
		<xs:restriction base="xs:string">
			<xs:pattern value="^(Enable|Disable)$"/>
		</xs:restriction>
	</xs:simpleType>

	<!--The main XML schema for the source file-->
	<xs:element name="Config">
		<xs:complexType>
			<xs:all>
				<xs:element name="DefaultStartLayout" type="baseXmlFile" minOccurs="0"/>
				<xs:element name="DefaultAppAssociations" type="baseXmlFile" minOccurs="0"/>
				<xs:element name="LanguageDefaults" type="baseXmlFile" minOccurs="0"/>
				<xs:element name="DefaultTheme" type="baseThemeFile" minOccurs="0"/>

				<xs:element name="Content" minOccurs="0">
					<xs:complexType>
						<xs:all>
							<!--If no source is provided, it is assumed the data has been externally provided-->
							<xs:element name="Source" type="baseContentSource" minOccurs="0"/>
							<xs:element name="Destination" type="baseContentDestination"/>
							<xs:element name="EnvironmentVariable" type="baseStandardString"/>
						</xs:all>
					</xs:complexType>
				</xs:element>

				<xs:element name="RegistrationInfo" minOccurs="0">
					<xs:complexType>
						<xs:all>
							<xs:element name="RegisteredOwner" type="baseStandardString"/>
							<xs:element name="RegisteredOrganization" type="baseStandardString"/>
						</xs:all>
					</xs:complexType>
				</xs:element>

				<xs:element name="OemInformation" minOccurs="0">
					<xs:complexType>
						<xs:all>
							<xs:element name="Manufacturer" type="baseStandardString"/>
							<xs:element name="Logo" type="baseBmpFile"/>
							<xs:element name="SupportPhone" type="baseStandardString"/>
							<xs:element name="SupportHours" type="baseStandardString"/>
							<xs:element name="SupportURL" type="baseStandardString"/>
						</xs:all>
					</xs:complexType>
				</xs:element>

				<xs:element name="SystemDriveLockdown" minOccurs="0">
					<xs:complexType>
						<xs:attribute name="Enabled" type="xs:nonNegativeInteger" use="required" />
					</xs:complexType>
				</xs:element>

				<xs:element name="DefaultLayoutModification" minOccurs="0">
					<xs:complexType>
						<xs:all>
							<xs:element name="Taskbar" type="baseXmlFile"/>
							<xs:element name="StartMenu" type="baseJsonFile" minOccurs="0"/>
						</xs:all>
					</xs:complexType>
				</xs:element>

				<xs:element name="ActiveSetup" minOccurs="0">
					<xs:complexType>
						<xs:sequence>
							<xs:element name="Component" maxOccurs="unbounded">
								<xs:complexType>
									<xs:all>
										<xs:element name="Name" type="baseStandardString"/>
										<xs:element name="StubPath" type="baseStandardString"/>
									</xs:all>
									<xs:attribute name="Version" type="xs:positiveInteger" use="required" />
								</xs:complexType>
							</xs:element>
						</xs:sequence>
						<xs:attribute name="Identifier" type="baseStandardString" use="required" />
					</xs:complexType>
				</xs:element>

				<xs:element name="SystemShortcuts" minOccurs="0">
					<xs:complexType>
						<xs:sequence>
							<xs:element name="Shortcut" maxOccurs="unbounded">
								<xs:complexType>
									<xs:all>
										<xs:element name="TargetPath" type="baseAnyPath"/>
										<xs:element name="Arguments" type="baseStandardString" minOccurs="0"/>
										<xs:element name="Description" type="baseStandardString" minOccurs="0"/>
										<xs:element name="Hotkey" type="baseStandardString" minOccurs="0"/>
										<xs:element name="IconLocation" type="baseShortcutIconLocation" minOccurs="0"/>
										<xs:element name="RelativePath" type="baseShortcutRelativePath" minOccurs="0"/>
										<xs:element name="WindowStyle" type="baseShortcutWindowStyle" minOccurs="0"/>
										<xs:element name="WorkingDirectory" type="baseAnyFilePath" minOccurs="0"/>
									</xs:all>
									<xs:attribute name="Location" type="baseShortcutLocation"/>
									<xs:attribute name="Name" type="baseShortcutFile"/>
								</xs:complexType>
							</xs:element>
						</xs:sequence>
					</xs:complexType>
				</xs:element>

				<xs:element name="RegistryData" minOccurs="0">
					<xs:complexType>
						<xs:sequence>
							<xs:element name="Item" maxOccurs="unbounded">
								<xs:complexType>
									<xs:all>
										<xs:element name="Key" type="baseRegistryDataKey"/>
										<xs:element name="Name" type="baseStandardString"/>
										<xs:element name="Value" type="baseStandardString"/>
										<xs:element name="Type" type="baseRegistryDataType"/>
									</xs:all>
									<xs:attribute name="Description" type="baseStandardString" use="required" />
								</xs:complexType>
							</xs:element>
						</xs:sequence>
					</xs:complexType>
				</xs:element>

				<xs:element name="RemoveApps" minOccurs="0">
					<xs:complexType>
						<xs:sequence>
							<xs:element name="App" type="baseStandardString" maxOccurs="unbounded"/>
						</xs:sequence>
					</xs:complexType>
				</xs:element>

				<xs:element name="WindowsCapabilities" minOccurs="0">
					<xs:complexType>
						<xs:sequence>
							<xs:element name="Capability" maxOccurs="unbounded">
								<xs:complexType>
									<xs:simpleContent>
										<xs:extension base="baseStandardString">
											<xs:attribute name="Action" use="required" type="baseInstallRemove"/>
										</xs:extension>
									</xs:simpleContent>
								</xs:complexType>
							</xs:element>
						</xs:sequence>
					</xs:complexType>
				</xs:element>

				<xs:element name="WindowsOptionalFeatures" minOccurs="0">
					<xs:complexType>
						<xs:sequence>
							<xs:element name="Feature" maxOccurs="unbounded">
								<xs:complexType>
									<xs:simpleContent>
										<xs:extension base="baseStandardString">
											<xs:attribute name="Action" use="required" type="baseEnableDisable"/>
										</xs:extension>
									</xs:simpleContent>
								</xs:complexType>
							</xs:element>
						</xs:sequence>
					</xs:complexType>
				</xs:element>
			</xs:all>
			<xs:attribute name="Version" type="xs:decimal" use="required" />
		</xs:complexType>
	</xs:element>
</xs:schema>
'@


#---------------------------------------------------------------------------
#
# Miscellaneous functions.
#
#---------------------------------------------------------------------------

filter Write-StdErrMessage
{
	# Test if we're in a console host or ISE.
	if ($Host.Name.Equals('ConsoleHost'))
	{
		# Colour appropriately and directly write to stderr.
		[System.Console]::BackgroundColor = [System.ConsoleColor]::Black
		[System.Console]::ForegroundColor = [System.ConsoleColor]::Red
		[System.Console]::Error.WriteLine($_)
		[System.Console]::ResetColor()
	}
	else
	{
		# Use the Host's UI while in ISE.
		$Host.UI.WriteErrorLine($_)
	}
}

filter Get-ErrorRecord
{
	# Preference an inner exception's error record if it's available, otherwise just return the piped object.
	try {($err = $_).Exception.InnerException.ErrorRecord} catch {$err}
}

filter Out-FriendlyErrorMessage ([ValidateNotNullOrEmpty()][System.String]$ErrorPrefix)
{
	# Set up initial vars. We do some determination for the best/right stacktrace line.
	$eRecord = $_ | Get-ErrorRecord
	$ePrefix = if ($ErrorPrefix) {"$ErrorPrefix`n"} else {'ERROR: '}
	$command = $eRecord.InvocationInfo.MyCommand | Select-Object -ExpandProperty Name
	$message = $eRecord.Exception.Message.Split("`n").Where({![System.String]::IsNullOrWhiteSpace($_)})
	$stArray = $eRecord.ScriptStackTrace.Split("`n")
	$staLine = $stArray[$stArray[0].Contains('<No file>')]

	# Get variables from stack trace line, as well as called command if available.
	if (![System.String]::IsNullOrWhiteSpace($staLine))
	{
		$function, $path, $file, $line = [System.Text.RegularExpressions.Regex]::Match($staLine, '^at\s(.+),\s(.+)\\(.+):\sline\s(\d+)').Groups.Value[1..4]
		$cmdlet = $command | Where-Object {!$function.Equals($_)}
		return "$($ePrefix)Line #$line`: $function`: $(if ($cmdlet) {"$cmdlet`: "})$message"
	}
	elseif ($command)
	{
		return "$($ePrefix)Line #$($_.InvocationInfo.ScriptLineNumber): $command`: $message"
	}
	else
	{
		return "$($ePrefix.Replace("`n",": "))$message"
	}
}

function Get-DefaultUserProfilePath
{
	return [Microsoft.Win32.Registry]::GetValue('HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList', 'Default', $null)
}

function Get-DefaultUserLocalAppDataPath
{
	$path = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{F1B32785-6FBA-4FCF-9D55-7B8E7F157091}"
	return "$(Get-DefaultUserProfilePath)\$([Microsoft.Win32.Registry]::GetValue($path, 'RelativePath', $null))"
}

filter Get-RegistryDataItemValue
{
	# If we're doing a binary value, convert the byte array into a registry-style string.
	if (($value = [Microsoft.Win32.Registry]::GetValue($_.Key, $_.Name, $null)) -and $_.Type.Equals('REG_BINARY'))
	{
		return [System.String]::Join($null, ($value.ForEach({$_.ToString('x')}) -replace '^(.)$','0$1'))
	}
	else
	{
		return $value
	}
}

function Install-RegistryDataItem
{
	begin {
		# Reset the global exit code before starting.
		$global:LASTEXITCODE = $null
	}

	process {
		# Unfortunately reg.exe is still the best way to quickly set a registry key.
		# Using reg.exe will allow for future expansion for allowing 32-bit or 64-bit registry accesses.
		[System.Void](reg.exe ADD $_.Key /v $_.Name /t $_.Type /d $_.Value /f 2>&1)
		Write-LogEntry -Message "Installed registry value '$($_.Key)\$($_.Name)'."
	}
}

function Remove-RegistryDataItem
{
	begin {
		# Reset the global exit code before starting.
		$global:LASTEXITCODE = $null
	}

	process {
		# Remove item.
		[System.Void](reg.exe DELETE ($key = $_.Key) /v $_.Name /f 2>&1)
		Write-LogEntry -Message "Removed registry value '$key\$($_.Name)'."

		# Remove key and any parents if there's no objects left within it.
		while ([System.String]::IsNullOrWhiteSpace($(try {reg.exe QUERY $key 2>&1} catch {$_.Exception.Message})))
		{
			[System.Void](reg.exe DELETE $key /f 2>&1); $key = $key -replace '\\[^\\]+$'
			Write-LogEntry -Message "Removed empty registry key '$key'."
		}
	}
}

function Invoke-DefaultUserRegistryAction
{
	Param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		[System.Management.Automation.ScriptBlock]$Expression
	)

	begin {
		# Mount default user hive under random key.
		[System.Void](reg.exe LOAD HKEY_LOCAL_MACHINE\TempUser "$(Get-DefaultUserProfilePath)\NTUSER.DAT" 2>&1)
	}

	process {
		# Invoke scriptblock.
		& $Expression
	}

	end {
		# Unmount hive.
		[System.Void](reg.exe UNLOAD HKEY_LOCAL_MACHINE\TempUser 2>&1)
	}
}

filter Get-ItemPropertyUnexpanded
{
	Param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.Win32.RegistryKey]$InputObject
	)

	# Return object with unexpanded registry values. This requires some hoops.
	$_.Property.Where({!$_.Equals('(default)')}).ForEach({
		begin {
			# Open hashtable to hold data.
			$data = @{}
		}
		process {
			# Get data from incoming RegistryKey.
			$data.Add($_, $InputObject.GetValue($_, $null, 'DoNotExpandEnvironmentNames'))
		}
		end {
			# Return pscustomobject to the pipeline if we have data.
			if ($data.GetEnumerator().Where({$_.Value}))
			{
				return [pscustomobject]$data
			}
		}
	})
}

filter Get-ContentFilePath
{
	# Confirm we have a 'Content' element specified.
	if ($script.Config.ChildNodes.LocalName -notcontains 'Content')
	{
		throw "This element requires that 'Content' be configured to supply the required data."
	}

	# Store local copies of some variables we need to test.
	$dest = if ($script.ModuleData.Content.ContainsKey('Destination')) {$script.ModuleData.Content.Destination}
	$temp = if ($script.ModuleData.Content.ContainsKey('TemporaryDir')) {$script.ModuleData.Content.TemporaryDir}

	# Test that the file is available and return path if it does.
	if ([System.IO.File]::Exists(($filepath = "$dest\$_")))
	{
		return $filepath
	}
	elseif ($script.Action.Equals('Confirm') -and [System.IO.File]::Exists(($filepath = "$temp\$_")))
	{
		return $filepath
	}
	else
	{
		throw "The specified file '$_' was not available in the provided Content location."
	}
}

function ConvertTo-BulletedList ([System.Management.Automation.SwitchParameter]$NoDateTimeStamp)
{
	return "`n$([System.String]::Join("`n", ($input.Where({![System.String]::IsNullOrWhiteSpace($_)}) -replace "^","> ")))"
}

function Get-EnvironmentVariableValue
{
	<#

	.NOTES
	While we have `[System.Environment]::GetEnvironmentVariable()` available to us, this will not retrieve a variable set within the same session.

	#>

	Param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[System.String]$Variable,

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[System.EnvironmentVariableTarget]$Target
	)

	# Set up paths based on target.
	$path = switch ($Target) {
		'Machine' {
			'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
			break
		}
		'User' {
			'HKEY_CURRENT_USER\Environment'
			'HKEY_CURRENT_USER\Volatile Environment'
			break
		}
		default {
			throw "An unsupported target has been specified."
		}
	}

	# Return the value to the caller.
	return [Microsoft.Win32.Registry]::GetValue($path, $Variable, $null)
}

function Set-SystemPathVariable ([Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][System.String]$NewValue)
{
	# Update the variable and refresh it system-wide via the comamnd prompt.
	[System.Environment]::SetEnvironmentVariable('Path', $NewValue, [System.EnvironmentVariableTarget]::Machine)
	[System.Void](cmd.exe /c "SET PATH=C")
}

function Get-WindowsNameVersion
{
	# Test if we're doing a server SKU or not first.
	if (![Microsoft.Win32.Registry]::GetValue('HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion', 'ProductName', $null).Contains('Server'))
	{
		switch ([System.Version][System.Environment]::OSVersion.Version.ToString(3))
		{
			{$_ -ge '10.0.22000'} {return '11'}
			{$_ -ge '10.0.10240'} {return '10'}
			{$_ -ge '6.3.9600'}   {return '8.1'}
			{$_ -ge '6.2.9200'}   {return '8'}
			{$_ -ge '6.1.7600'}   {return '7'}
			{$_ -ge '6.0.6000'}   {return 'Vista'}
			{$_ -ge '5.1.2600'}   {return 'XP'}
			{$_ -ge '5.0.2195'}   {return '2000'}
		}
	}
	else
	{
		switch ([System.Version][System.Environment]::OSVersion.Version.ToString(3))
		{
			{$_ -ge '10.0.20348'} {return '2022'}
			{$_ -ge '10.0.17763'} {return '2019'}
			{$_ -ge '10.0.14393'} {return '2016'}
			{$_ -ge '6.3.9600'}   {return '2012 R2'}
			{$_ -ge '6.2.9200'}   {return '2012'}
			{$_ -ge '6.1.7600'}   {return '2008 R2'}
			{$_ -ge '6.0.6000'}   {return '2008'}
			{$_ -ge '5.2.3790'}   {return '2003'}
			{$_ -ge '5.0.2195'}   {return '2000'}
		}
	}

	# If we're here, we couldn't return a value.
	throw 'Unsupported OS detected.'
}


#---------------------------------------------------------------------------
#
# Main callstack functions.
#
#---------------------------------------------------------------------------

function Open-Log
{
	# Output initial log information.
	Write-LogEntry -Message "$($script.Name) $($script.Info.Version)"
	Write-LogEntry -Message "Written by: $($script.Info.Author)"
	Write-LogEntry -Message "Running on: PowerShell $($Host.Version.ToString())"
	Write-LogEntry -Message "Started at: $($script.StartDate)"

	# Start transcription.
	$logPath = [System.IO.Directory]::CreateDirectory("$env:WinDir\Logs\DesiredStateManagement").FullName
	$logDisc = if ($script.LogDiscriminator) {"_$($script.LogDiscriminator)"}
	$logFile = "$($script.Name)$($logDisc)_$($script.Action)_$($script.StartDate.ToString('yyyyMMddTHHmmss')).log"
	[System.Console]::WriteLine((Start-Transcript -LiteralPath "$logPath\$logFile"))
	Write-LogEntry -Message "Commencing $($script.Action.ToLower()) process, please wait...`n$($script.Divider)"
}

function Write-LogEntry ([Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][System.String]$Message)
{
	# This is here to shut `Invoke-ScriptAnalyzer` up... Write-Host is fine in PS 5.1+ environments.
	Write-Host $Message
}

function Close-Log
{
	# Close out transcription and null redundant output.
	[System.Void]$(try {Stop-Transcript} catch {$null})
}

function Initialize-ModuleData
{
	# Nothing here should ever require changing/manipulation.
	$script.ModuleData = @{
		ActiveSetup = @{
			RegistryBase = 'HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components'
		}
		Content = @{
			DownloadFile = "$(($tempdir = [System.IO.Path]::GetTempPath().TrimEnd('\')))\$(Get-Random).zip"
			TemporaryDir = "$tempdir\$(Get-Random)"
		}
		DefaultAppAssociations = @{
			TagFile = "$env:WinDir\DefaultAppAssociations.tag"
		}
		DefaultStartLayout = @{
			BaseDirectory = ($basedir = "$(Get-DefaultUserLocalAppDataPath)\Microsoft\Windows\Shell")
			Archive = "$basedir\DefaultLayouts.$($script.StartDate.ToString('yyyyMMddTHHmmss')).backup"
			Destination = "$basedir\DefaultLayouts.xml"
		}
		DefaultLayoutModification = @{
			BaseDirectory = $basedir
			FileNameBase = "LayoutModification"
		}
		DefaultTheme = @{
			Key = 'HKEY_LOCAL_MACHINE\TempUser\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes'
			Name = 'InstallTheme'
			Type = 'REG_EXPAND_SZ'
		}
		LanguageDefaults = @{
			TagFile = "$env:WinDir\LanguageDefaults.tag"
		}
		OemInformation = @{
			RegistryBase = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation'
		}
		RegistrationInfo = @{
			RegistryBase = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
		}
		RemoveApps = @{
			MandatoryApps = @(
				'Microsoft.DesktopAppInstaller'
				'Microsoft.HEIFImageExtension'
				'Microsoft.MicrosoftEdge.Stable'
				'Microsoft.StorePurchaseApp'
				'Microsoft.VCLibs.140.00'
				'Microsoft.VP9VideoExtensions'
				'Microsoft.WebMediaExtensions'
				'Microsoft.WebpImageExtension'
				'Microsoft.WindowsStore'
				'Microsoft.Xbox.TCUI'
			)
		}
		SystemDriveLockdown = @{
			SID = 'S-1-5-11'  # Authenticated Users
		}
		SystemShortcuts = @{
			ShortcutProperties = @{
				'.lnk' = $script.WScriptShell.CreateShortcut("$tempdir\$(Get-Random).lnk").PSObject.Properties.Name
				'.url' = $script.WScriptShell.CreateShortcut("$tempdir\$(Get-Random).url").PSObject.Properties.Name
			}
			ExpandProperties = 'TargetPath', 'IconLocation', 'RelativePath', 'WorkingDirectory'
		}
	}
}

function Import-DesiredStateConfig
{
	# Create error handler.
	$err = {throw $args[1].Exception.Message}

	# Get XML file and validate against our schema.
	$xml = [System.Xml.XmlDocument]::new()
	$xml.Schemas.Add([System.Xml.Schema.XmlSchema]::Read([System.IO.StringReader]::new($schema), $err)) | Out-Null
	$xml.Load($(try {[System.Xml.XmlReader]::Create($Config)} catch {[System.IO.StringReader]::new($Config)}))
	$xml.Validate($err)
	$script.Config = $xml.Config
}

function Invoke-DesiredStateOperations
{
	# Dynamically generate scriptblocks based on the XML config and this script's available supporting functions.
	$div = if ($script.Action.Equals('Install')) {"; Write-LogEntry -Message '$($script.Divider)'"}
	$ops = $script.Config.ChildNodes.LocalName | ForEach-Object {
		if ($cmdlet = Get-Command -Name "$($script.Action)-$_" -ErrorAction Ignore) {
			[System.Management.Automation.ScriptBlock]::Create("$cmdlet$div")
		}
	}

	# Invoke operations and store any output.
	$script.TestResults = if ($res = $ops.Invoke()) {[System.String]::Join("`n", $res)}
	if (!$script.Action.Equals('Install')) {Write-LogEntry -Message $script.Divider}

	# Throw if we receive any test results.
	if ($script.TestResults)
	{
		throw $script.TestResults
	}

	# Indicate success and whether a reboot is needed or not.
	Write-LogEntry -Message "Successfully $($script.Action.ToLower().TrimEnd('e'))ed desired state management."
	if ($script.ExitCode.Equals(3010)) {Write-LogEntry -Message "Please restart this computer for the changes to take effect."}
}


#---------------------------------------------------------------------------
#
# ActiveSetup.
#
#---------------------------------------------------------------------------

filter Out-ActiveSetupComponentName
{
	return "$($script.Config.ActiveSetup.Identifier) - $_"
}

function Get-ActiveSetupState
{
	# Store registry base locally to reduce line length.
	$regbase = $script.ModuleData.ActiveSetup.RegistryBase

	# Return state to the pipeline.
	return [pscustomobject]@{
		NotPresent = $script.Config.ActiveSetup.Component | Where-Object {
			!(Test-Path -LiteralPath "$regbase\$($_.Name | Out-ActiveSetupComponentName)" -PathType Container)
		}
		Deprecated = Get-Item -Path "$regbase\$(($prefix = "$($script.Config.ActiveSetup.Identifier) - "))*" | Where-Object {
			$script.Config.ActiveSetup.Component.Name -notcontains $_.PSChildName.Replace($prefix, $null)
		}
		Mismatched = $script.Config.ActiveSetup.Component | Where-Object {
			($dest = Get-Item -LiteralPath "$regbase\$($_.Name | Out-ActiveSetupComponentName)" -ErrorAction Ignore | Get-ItemPropertyUnexpanded) -and
			(Compare-Object -ReferenceObject $_ -DifferenceObject $dest -Property Version,StubPath)
		}
	}
}

filter Install-ActiveSetupComponent ([ValidateSet('Install','Update')][System.String]$Action)
{
	# Set up component's key and associated properties.
	$name = $_.Name | Out-ActiveSetupComponentName
	$path = (New-Item -Path $script.ModuleData.ActiveSetup.RegistryBase -Name $name -Value $name -Force).Name

	# Create item properties.
	[Microsoft.Win32.Registry]::SetValue($path, 'Version', $_.Version, [Microsoft.Win32.RegistryValueKind]::String)
	[Microsoft.Win32.Registry]::SetValue($path, 'StubPath', $_.StubPath, [Microsoft.Win32.RegistryValueKind]::ExpandString)

	# Update log with action taken.
	switch ($Action)
	{
		'Install' {
			Write-LogEntry -Message "Installed missing ActiveSetup component '$name'."
			break
		}
		'Update' {
			Write-LogEntry -Message "Updated incorrect ActiveSetup component '$name'."
			break
		}
	}
}

filter Remove-ActiveSetupComponent
{
	$_ | Remove-Item -Force -Confirm:$false
	Write-LogEntry -Message "Removed deprecated ActiveSetup component '$($_.PSChildName)'."
}

function Install-ActiveSetup
{
	# Advise commencement.
	Write-LogEntry -Message "Confirming ActiveSetup component installation state, please wait..."

	# Rectify state if needed.
	if (($components = Get-ActiveSetupState).PSObject.Properties.Where({$_.Value}))
	{
		$components.Deprecated | Remove-ActiveSetupComponent
		$components.Mismatched | Install-ActiveSetupComponent -Action Update
		$components.NotPresent | Install-ActiveSetupComponent -Action Install
		Write-LogEntry -Message "Successfully installed all ActiveSetup components."
		$script.ExitCode = 3010
	}
	else
	{
		Write-LogEntry -Message "Successfully confirmed all ActiveSetup components are correctly installed."
	}
}

function Confirm-ActiveSetup
{
	# Advise commencement and get current state.
	Write-LogEntry -Message "Confirming ActiveSetup component installation state, please wait..."
	$components = Get-ActiveSetupState

	# Output test results.
	if ($components.Deprecated)
	{
		"The following ActiveSetup components require removing:$($components.Deprecated.PSChildName | ConvertTo-BulletedList)"
	}
	if ($components.Mismatched)
	{
		"The following ActiveSetup components require amending:$($components.Mismatched.Name | ConvertTo-BulletedList)"
	}
	if ($components.NotPresent)
	{
		"The following ActiveSetup components require installing:$($components.NotPresent.Name | ConvertTo-BulletedList)"
	}
}

function Remove-ActiveSetup
{
	# Remove all items.
	Remove-Item -Path "$($script.ModuleData.ActiveSetup.RegistryBase)\$($script.Config.ActiveSetup.Identifier)*" -Force -Confirm:$false
	Write-LogEntry -Message "Successfully removed all ActiveSetup components."
}


#---------------------------------------------------------------------------
#
# Content.
#
#---------------------------------------------------------------------------

function Invoke-ContentPreOps
{
	# Advise commencement.
	Write-LogEntry -Message "Confirming Content state, please wait..."

	# Do basic sanity checks.
	try
	{
		# If we've specified a source, set it up. If none is specified, we assume the content is pre-seeded.
		if ($script.Config.Content.ChildNodes.LocalName.Contains('Source'))
		{
			# Download content file. If we can't get it, we can't proceed with anything.
			Invoke-WebRequest -UseBasicParsing -Uri $script.Config.Content.Source -OutFile $script.ModuleData.Content.DownloadFile

			# Extract contents to temp location. Do this first so the data is available for other modules.
			Expand-Archive -LiteralPath $script.ModuleData.Content.DownloadFile -DestinationPath $script.ModuleData.Content.TemporaryDir -Force
		}

		# Set the destination path based off the incoming content, expanding any environment variables as required.
		$script.ModuleData.Content.Destination = [System.Environment]::ExpandEnvironmentVariables($script.Config.Content.Destination)
	}
	catch
	{
		Write-Warning -Message "Unable to confirm Content state. $($_.Exception.Message)"
		return 1
	}
}

function Test-ContentValidity
{
	# Store return value.
	$exitCode = 0

	# Test we have an environment variable first.
	if (!(Get-EnvironmentVariableValue -Variable $script.Config.Content.EnvironmentVariable -Target Machine) -or
		!(Get-EnvironmentVariableValue -Variable Path -Target Machine).Split(';').Contains($script.ModuleData.Content.Destination))
	{
		$exitCode += 1
	}

	# If we've provided source content, test its validity.
	if ($script.Config.Content.ChildNodes.LocalName.Contains('Source'))
	{
		$coParams = @{
			ReferenceObject = Get-ChildItem -LiteralPath $script.ModuleData.Content.TemporaryDir -File -Recurse | Get-FileHash
			DifferenceObject = Get-ChildItem -LiteralPath $script.ModuleData.Content.Destination -File -Recurse -ErrorAction Ignore | Get-FileHash
		}
		$exitCode += 2 * (!$coParams.DifferenceObject -or !!(Compare-Object @coParams -Property Hash))
	}

	# Exit with results.
	return $exitCode
}

function Install-Content
{
	# Do pre-ops and return if there was an error.
	if (Invoke-ContentPreOps)
	{
		return
	}

	# Get state and repair if needed.
	switch (Test-ContentValidity)
	{
		{$_ -gt 1} {
			# Mirror our extracted folder with our destination using Robocopy.
			robocopy.exe $script.ModuleData.Content.TemporaryDir $script.ModuleData.Content.Destination /MIR /FP 2>&1 | ForEach-Object {
				# Test the line to determine the action.
				switch -Regex -CaseSensitive ($_) {
					'\*EXTRA File' {
						Write-LogEntry -Message "Removed deprecated file '$($_ -replace '^.+\\')'."
						break
					}
					'Newer' {
						Write-LogEntry -Message "Updated existing file '$($_ -replace '^.+\\')'."
						break
					}
					'New File' {
						Write-LogEntry -Message "Copied new file '$($_ -replace '^.+\\')'."
						break
					}
				}
			}

			# Exit codes 8 or greater mean something went wrong.
			if ($global:LASTEXITCODE -ge 8)
			{
				throw "Transfer of Content via robocopy.exe failed with exit code $global:LASTEXITCODE."
			}
			Write-LogEntry -Message "Successfully installed Content files."
		}
		{$_ -gt 0} {
			# Add content to system's path environment variable, as well as our dedicated variable.
			Set-SystemPathVariable -NewValue ([System.String]::Join(';', @($script.ModuleData.Content.Destination) + (Get-EnvironmentVariableValue -Variable Path -Target Machine).Split(';')))
			[System.Environment]::SetEnvironmentVariable($script.Config.Content.EnvironmentVariable, $script.ModuleData.Content.Destination, 'Machine')
			Write-LogEntry -Message "Successfully installed Content environment variable."
		}
		default {
			Write-LogEntry -Message "Successfully confirmed all Content components are correctly deployed."
		}
	}
}

function Confirm-Content
{
	# Do pre-ops and return if there was an error.
	if (Invoke-ContentPreOps)
	{
		return
	}

	# Output incorrect results, if any.
	if ($components = switch (Test-ContentValidity) {{$_ -gt 1} {'File data'} {$_ -gt 0} {'Environment variable'}})
	{
		"The following Content components require installing or amending:$($components | ConvertTo-BulletedList)"
	}
}

function Remove-Content
{
	# Store expanded destination.
	$dest = [System.Environment]::ExpandEnvironmentVariables($script.Config.Content.Destination)

	# Delete the contents folder.
	if ([System.IO.Directory]::Exists(($path = $dest)))
	{
		[System.IO.Directory]::Delete($path, $true)
	}

	# Delete folders above so long as they're empty.
	while ([System.IO.Directory]::Exists(($path += "\..")) -and !(Get-ChildItem -LiteralPath $path))
	{
		[System.IO.Directory]::Delete($path, $true)
	}

	# Remove all references to the destination from the system's environment variables.
	Set-SystemPathVariable -NewValue ([System.String]::Join(';', (Get-EnvironmentVariableValue -Variable Path -Target Machine).Split(';').Where({!$_.Equals($dest)})))
	[System.Environment]::SetEnvironmentVariable($script.Config.Content.EnvironmentVariable, $null, 'Machine')
	Write-LogEntry -Message "Successfully removed all Content components."
}


#---------------------------------------------------------------------------
#
# DefaultAppAssociations.
#
#---------------------------------------------------------------------------

function Invoke-DefaultAppAssociationsPreOps
{
	# Advise commencement.
	Write-LogEntry -Message "Confirming DefaultAppAssociations state, please wait..."

	# Do basic sanity checks.
	try
	{
		# Get file path from our cache, along with its hash.
		$script.ModuleData.DefaultAppAssociations.Source = $script.Config.DefaultAppAssociations | Get-ContentFilePath
		$script.ModuleData.DefaultAppAssociations.FileHash = (Get-FileHash -LiteralPath $script.ModuleData.DefaultAppAssociations.Source).Hash
	}
	catch
	{
		Write-Warning -Message "Unable to confirm DefaultAppAssociations state. $($_.Exception.Message)"
		return 1
	}
}

function Test-DefaultAppAssociationsApplicability
{
	return ![System.IO.File]::Exists($script.ModuleData.DefaultAppAssociations.TagFile) -or
		!$script.ModuleData.DefaultAppAssociations.FileHash.Equals(([System.IO.File]::ReadAllText($script.ModuleData.DefaultAppAssociations.TagFile)))
}

function Install-DefaultAppAssociations
{
	# Do pre-ops and return if there was an error.
	if (Invoke-DefaultAppAssociationsPreOps)
	{
		return
	}

	# Get state and repair if needed.
	if (Test-DefaultAppAssociationsApplicability)
	{
		[System.Void](dism.exe /Online /Import-DefaultAppAssociations:$script.ModuleData.DefaultAppAssociations.Source 2>&1)
		[System.IO.File]::WriteAllText($script.ModuleData.DefaultAppAssociations.TagFile, $script.ModuleData.DefaultAppAssociations.FileHash)
		Write-LogEntry -Message "Successfully installed DefaultAppAssociations file."
	}
	else
	{
		Write-LogEntry -Message "Successfully confirmed DefaultAppAssociations state is correctly deployed."
	}
}

function Confirm-DefaultAppAssociations
{
	# Do pre-ops and return if there was an error.
	if (Invoke-DefaultAppAssociationsPreOps)
	{
		return
	}

	# Output incorrect results, if any.
	if (Test-DefaultAppAssociationsApplicability)
	{
		"The following DefaultAppAssociations components require installing or amending:$('File' | ConvertTo-BulletedList)"
	}
}

function Remove-DefaultAppAssociations
{
	Remove-Item -LiteralPath $script.ModuleData.DefaultAppAssociations.TagFile -Force -Confirm:$false -ErrorAction Ignore
	Write-LogEntry -Message "Successfully removed DefaultAppAssociations tag file."
}


#---------------------------------------------------------------------------
#
# DefaultStartLayout.
#
#---------------------------------------------------------------------------

function Invoke-DefaultStartLayoutPreOps
{
	# Advise commencement.
	Write-LogEntry -Message "Confirming DefaultStartLayout state, please wait..."

	# Warn and bomb out if we're not on Windows 10.
	if (!(Get-WindowsNameVersion).Equals('10'))
	{
		Write-Warning -Message "The DefaultStartLayout element is only supported on Windows 10."
		return 1
	}

	# Do basic sanity checks.
	try
	{
		# Get file path from our cache.
		$script.ModuleData.DefaultStartLayout.Source = $script.Config.DefaultStartLayout | Get-ContentFilePath
	}
	catch
	{
		Write-Warning -Message "Unable to confirm DefaultStartLayout state. $($_.Exception.Message)"
		return 1
	}
}

function Test-DefaultStartLayoutValidity
{
	# Confirm whether start layout is valid by testing whether src/dest hash match.
	$src = $script.ModuleData.DefaultStartLayout.Source
	$dst = $script.ModuleData.DefaultStartLayout.Destination
	return ![System.IO.File]::Exists($dst) -or ((Get-FileHash -LiteralPath $src,$dst | Select-Object -ExpandProperty Hash -Unique) -isnot [System.String])
}

function Install-DefaultStartLayout
{
	# Do pre-ops and return if there was an error.
	if (Invoke-DefaultStartLayoutPreOps)
	{
		return
	}

	# Get state and repair if needed.
	if (Test-DefaultStartLayoutValidity)
	{
		Copy-Item -LiteralPath $script.ModuleData.DefaultStartLayout.Destination -Destination $script.ModuleData.DefaultStartLayout.Archive | Out-Null
		Copy-Item -LiteralPath $script.ModuleData.DefaultStartLayout.Source -Destination $script.ModuleData.DefaultStartLayout.Destination -Force | Out-Null
		Write-LogEntry -Message "Successfully installed DefaultStartLayout values."
	}
	else
	{
		Write-LogEntry -Message "Successfully confirmed DefaultStartLayout configuration is correctly deployed."
	}
}

function Confirm-DefaultStartLayout
{
	# Do pre-ops and return if there was an error.
	if (Invoke-DefaultStartLayoutPreOps)
	{
		return
	}

	# Output incorrect results, if any.
	if (Test-DefaultStartLayoutValidity)
	{
		"The following DefaultStartLayout components require installing or amending:$('File' | ConvertTo-BulletedList)"
	}
}

function Remove-DefaultStartLayout
{
	# Get oldest backup.
	$backup = Get-ChildItem -Path "$($script.ModuleData.DefaultStartLayout.BaseDirectory)\*.backup" |
		Sort-Object -Property LastWriteTime | Select-Object -ExpandProperty FullName -First 1

	# Restore it if we have one.
	if ($backup)
	{
		Copy-Item -LiteralPath $backup -Destination $script.ModuleData.DefaultStartLayout.Destination -Force -Confirm:$false
		Remove-Item -Path "$($script.ModuleData.DefaultStartLayout.BaseDirectory)\*.backup" -Force -Confirm:$false
		Write-LogEntry -Message "Successfully restored DefaultStartLayout configuration."
	}
	else
	{
		Write-LogEntry -Message "Confirmed system is already running the DefaultStartLayout configuration, or has no valid backups to restore."
	}
}


#---------------------------------------------------------------------------
#
# DefaultLayoutModification.
#
#---------------------------------------------------------------------------

function Invoke-DefaultLayoutModificationPreOps
{
	# Advise commencement.
	Write-LogEntry -Message "Confirming DefaultLayoutModification state, please wait..."

	# Only support this on Windows 11.
	if (!(Get-WindowsNameVersion).Equals('11'))
	{
		Write-Warning -Message "The DefaultLayoutModification element is only supported on Windows 11."
		return 1
	}

	# Do basic sanity checks.
	try
	{
		# Format a string for use as our destination for files.
		$dest = "$($script.ModuleData.DefaultLayoutModification.BaseDirectory)\$($script.ModuleData.DefaultLayoutModification.FileNameBase){0}"

		# Get file path(s) from our cache.
		$script.ModuleData.DefaultLayoutModification.FilePaths = $script.Config.DefaultLayoutModification.ChildNodes |
			ForEach-Object {$script.Config.DefaultLayoutModification.$_} | Get-ContentFilePath |
				ForEach-Object {@{LiteralPath = $_; Destination = $dest -f [System.IO.Path]::GetExtension($_)}}
	}
	catch
	{
		Write-Warning -Message "Unable to confirm DefaultLayoutModification state. $($_.Exception.Message)"
		return 1
	}
}

function Get-IncorrectDefaultLayoutModifications
{
	# Confirm whether start layout is valid by testing whether src/dest hash match.
	return $script.ModuleData.DefaultLayoutModification.FilePaths | Where-Object {
		![System.IO.File]::Exists($_.Destination) -or ((Get-FileHash -LiteralPath $_.Values | Select-Object -ExpandProperty Hash -Unique) -isnot [System.String])
	}
}

function Install-DefaultLayoutModification
{
	# Do pre-ops and return if there was an error.
	if (Invoke-DefaultLayoutModificationPreOps)
	{
		return
	}

	# Get state and repair if needed.
	if ($incorrect = Get-IncorrectDefaultLayoutModifications)
	{
		$incorrect | ForEach-Object {Copy-Item @_ -Force} | Out-Null
		Write-LogEntry -Message "Successfully installed DefaultLayoutModification components."
	}
	else
	{
		Write-LogEntry -Message "Successfully confirmed DefaultLayoutModification components are correctly deployed."
	}
}

function Confirm-DefaultLayoutModification
{
	# Do pre-ops and return if there was an error.
	if (Invoke-DefaultLayoutModificationPreOps)
	{
		return
	}

	# Ouput incorrect results, if any.
	if ($incorrect = Get-IncorrectDefaultLayoutModifications)
	{
		$list = $incorrect | ForEach-Object {[System.IO.Path]::GetFileName($_.LiteralPath)}
		"The following DefaultLayoutModification components require installing or amending:$($list | ConvertTo-BulletedList)"
	}
}

function Remove-DefaultLayoutModification
{
	# Remove the file completely.
	Remove-Item -Path "$($script.ModuleData.DefaultLayoutModification.BaseDirectory)\LayoutModification.*" -Force -Confirm:$false
	Write-LogEntry -Message "Successfully restored DefaultLayoutModification configuration."
}


#---------------------------------------------------------------------------
#
# DefaultTheme.
#
#---------------------------------------------------------------------------

function Invoke-DefaultThemePreOps
{
	# Advise commencement.
	Write-LogEntry -Message "Confirming DefaultTheme state, please wait..."

	# Do basic sanity checks.
	try
	{
		# Set value to apply in registry.
		$script.ModuleData.DefaultTheme.Value = $script.Config.DefaultTheme | Get-ContentFilePath
	}
	catch
	{
		Write-Warning -Message "Unable to confirm DefaultTheme state. $($_.Exception.Message)"
		return 1
	}
}

function Get-IncorrectDefaultTheme
{
	# Return results.
	return Invoke-DefaultUserRegistryAction -Expression {!$script.ModuleData.DefaultTheme.Value.Equals(($script.ModuleData.DefaultTheme | Get-RegistryDataItemValue))}
}

function Install-DefaultTheme
{
	# Do pre-ops and return if there was an error.
	if (Invoke-DefaultThemePreOps)
	{
		return
	}

	# Get state and repair if needed.
	if (Get-IncorrectDefaultTheme)
	{
		Invoke-DefaultUserRegistryAction -Expression {$script.ModuleData.DefaultTheme | Install-RegistryDataItem} | Out-Null
		Write-LogEntry -Message "Successfully installed DefaultTheme components."
	}
	else
	{
		Write-LogEntry -Message "Successfully confirmed all DefaultTheme components are correctly deployed."
	}
}

function Confirm-DefaultTheme
{
	# Do pre-ops and return if there was an error.
	if (Invoke-DefaultThemePreOps)
	{
		return
	}

	# Output incorrect results, if any.
	if (Get-IncorrectDefaultTheme)
	{
		"The following DefaultTheme components require installing or amending:$('Registry configuration' | ConvertTo-BulletedList)"
	}
}

function Remove-DefaultTheme
{
	# Just remove the registry components so we don't risk breaking user experiences.
	Invoke-DefaultUserRegistryAction -Expression {($script.ModuleData.DefaultTheme | Where-Object {$_ | Get-RegistryDataItemValue} | Remove-RegistryDataItem) 6>$null} | Out-Null
	Write-LogEntry -Message "Successfully removed all DefaultTheme registry components."
}


#---------------------------------------------------------------------------
#
# LanguageDefaults.
#
#---------------------------------------------------------------------------

function Invoke-LanguageDefaultsPreOps
{
	# Advise commencement.
	Write-LogEntry -Message "Confirming LanguageDefaults state, please wait..."

	# Do basic sanity checks.
	try
	{
		# Get file path from our cache, along with its hash.
		$script.ModuleData.LanguageDefaults.Source = $script.Config.LanguageDefaults | Get-ContentFilePath
		$script.ModuleData.LanguageDefaults.FileHash = (Get-FileHash -LiteralPath $script.ModuleData.LanguageDefaults.Source).Hash
	}
	catch
	{
		Write-Warning -Message "Unable to confirm LanguageDefaults state. $($_.Exception.Message)"
		return 1
	}
}

function Test-LanguageDefaultsApplicability
{
	return ![System.IO.File]::Exists($script.ModuleData.LanguageDefaults.TagFile) -or
		!$script.ModuleData.LanguageDefaults.FileHash.Equals([System.IO.File]::ReadAllText($script.ModuleData.LanguageDefaults.TagFile))
}

function Install-LanguageDefaults
{
	# Do pre-ops and return if there was an error.
	if (Invoke-LanguageDefaultsPreOps)
	{
		return
	}

	# Get state and repair if needed.
	if (Test-LanguageDefaultsApplicability)
	{
		control.exe "intl.cpl,,/f:`"$($script.ModuleData.LanguageDefaults.Source)`"" 2>&1
		[System.IO.File]::WriteAllText($script.ModuleData.LanguageDefaults.TagFile, $script.ModuleData.LanguageDefaults.FileHash)
		Write-LogEntry -Message "Successfully installed LanguageDefaults unattend file."
	}
	else
	{
		Write-LogEntry -Message "Successfully confirmed LanguageDefaults state is correctly deployed."
	}
}

function Confirm-LanguageDefaults
{
	# Do pre-ops and return if there was an error.
	if (Invoke-LanguageDefaultsPreOps)
	{
		return
	}

	# Output incorrect results, if any.
	if (Test-LanguageDefaultsApplicability)
	{
		"The following LanguageDefaults components require installing or amending:$('File' | ConvertTo-BulletedList)"
	}
}

function Remove-LanguageDefaults
{
	Remove-Item -LiteralPath $script.ModuleData.LanguageDefaults.TagFile -Force -Confirm:$false -ErrorAction Ignore
	Write-LogEntry -Message "Successfully removed LanguageDefaults tag file."
}


#---------------------------------------------------------------------------
#
# OemInformation.
#
#---------------------------------------------------------------------------

function Invoke-OemInformationPreOps
{
	# Advise commencement.
	Write-LogEntry -Message "Confirming OemInformation state, please wait..."

	# Do basic sanity checks.
	try
	{
		# Calculate some properties for future usage.
		$script.ModuleData.OemInformation.Logo = $script.Config.OemInformation.Logo | Get-ContentFilePath
		$script.ModuleData.OemInformation.Model = (Get-CimInstance -ClassName Win32_ComputerSystem).Model
	}
	catch
	{
		Write-Warning -Message "Unable to confirm OemInformation state. $($_.Exception.Message)"
		return 1
	}
}

function Get-IncorrectOemInformation
{
	# Get all properties from the registry.
	$itemprops = Get-ItemProperty -LiteralPath ($regbase = $script.ModuleData.OemInformation.RegistryBase) -ErrorAction Ignore

	# Return test results.
	return ($script.Config.OemInformation.ChildNodes.LocalName + 'Model').ForEach({
		# Get calculated value from script's storage if present, otherwise use XML provided source.
		$value = if ($script.ModuleData.OemInformation.ContainsKey($_)) {$script.ModuleData.OemInformation.$_} else {$script.Config.OemInformation.$_}

		# Output objects for the properties that need correction.
		if (!$itemprops -or !$value.Equals(($itemprops | Select-Object -ExpandProperty $_ -ErrorAction Ignore)))
		{
			[pscustomobject]@{Key = $regbase.Replace('HKLM:', 'HKEY_LOCAL_MACHINE'); Name = $_; Value = $value; Type = 'REG_SZ'}
		}
	})
}

function Install-OemInformation
{
	# Do pre-ops and return if there was an error.
	if (Invoke-OemInformationPreOps)
	{
		return
	}

	# Get state and repair if needed.
	if ($incorrect = Get-IncorrectOemInformation)
	{
		# Install any missing properties.
		$incorrect | Install-RegistryDataItem
		Write-LogEntry -Message "Successfully installed OemInformation values."
	}
	else
	{
		Write-LogEntry -Message "Successfully confirmed all OemInformation values are correctly deployed."
	}
}

function Confirm-OemInformation
{
	# Do pre-ops and return if there was an error.
	if (Invoke-OemInformationPreOps)
	{
		return
	}

	# Output test results.
	if ($incorrect = Get-IncorrectOemInformation)
	{
		"The following OemInformation values require installing or amending:$($incorrect.Name | ConvertTo-BulletedList)"
	}
}

function Remove-OemInformation
{
	Remove-Item -LiteralPath $script.ModuleData.OemInformation.RegistryBase -Force -Confirm:$false -ErrorAction Ignore
	Write-LogEntry -Message "Successfully removed all OemInformation values."
}


#---------------------------------------------------------------------------
#
# RegistrationInfo.
#
#---------------------------------------------------------------------------

function Get-IncorrectRegistrationInfo
{
	# Get item properties and store.
	$itemprops = Get-ItemProperty -LiteralPath ($regbase = $script.ModuleData.RegistrationInfo.RegistryBase)

	# Return any mismatches.
	return $script.Config.RegistrationInfo.ChildNodes.LocalName.ForEach({
		if (!$itemprops -or !$script.Config.RegistrationInfo.($_).Equals(($itemprops | Select-Object -ExpandProperty $_ -ErrorAction Ignore))) {
			[pscustomobject]@{LiteralPath = $regbase; Name = $_; Value = $script.Config.RegistrationInfo.$_; PropertyType = 'String'}
		}
	})
}

function Install-RegistrationInfo
{
	# Advise commencement.
	Write-LogEntry -Message "Confirming RegistrationInfo state, please wait..."

	# Get state and repair if needed.
	if ($incorrect = Get-IncorrectRegistrationInfo)
	{
		$incorrect | New-ItemProperty -Force | Out-Null
		Write-LogEntry -Message "Successfully installed RegistrationInfo values."
	}
	else
	{
		Write-LogEntry -Message "Successfully confirmed all RegistrationInfo values are correctly deployed."
	}
}

function Confirm-RegistrationInfo
{
	# Advise commencement.
	Write-LogEntry -Message "Confirming RegistrationInfo state, please wait..."

	# Output incorrect results, if any.
	if ($incorrect = Get-IncorrectRegistrationInfo)
	{
		"The following RegistrationInfo values require installing or amending:$($incorrect.Name | ConvertTo-BulletedList)"
	}
}

function Remove-RegistrationInfo
{
	$path = $script.ModuleData.RegistrationInfo.RegistryBase; $Name = $script.Config.RegistrationInfo.ChildNodes.LocalName
	Remove-ItemProperty -LiteralPath $path -Name $Name -Force -Confirm:$false -ErrorAction Ignore
	Write-LogEntry -Message "Successfully removed all RegistrationInfo values."
}


#---------------------------------------------------------------------------
#
# RegistryData.
#
#---------------------------------------------------------------------------

function Get-IncorrectRegistryData
{
	return $script.Config.RegistryData.Item | Where-Object {($_ | Get-RegistryDataItemValue) -ne $_.Value}
}

function Install-RegistryData
{
	# Advise commencement.
	Write-LogEntry -Message "Confirming RegistryData value installation state, please wait..."

	# Get incorrect items and rectify if needed.
	if ($incorrect = Get-IncorrectRegistryData)
	{
		$incorrect | Install-RegistryDataItem
		Write-LogEntry -Message "Successfully installed all RegistryData values."
		$script.ExitCode = 3010
	}
	else
	{
		Write-LogEntry -Message "Successfully confirmed all RegistryData values are correctly deployed."
	}
}

function Confirm-RegistryData
{
	# Advise commencement.
	Write-LogEntry -Message "Confirming RegistryData value installation state, please wait..."

	# Output incorrect results, if any.
	if ($incorrect = Get-IncorrectRegistryData)
	{
		"The following RegistryData values require installing or amending:$($incorrect | ForEach-Object {"$($_.Key)\$($_.Name)"} | ConvertTo-BulletedList)"
	}
}

function Remove-RegistryData
{
	# Remove each item and the key if the item was the last.
	if (($script.Config.RegistryData.Item | Where-Object {$_ | Get-RegistryDataItemValue} | Remove-RegistryDataItem) 6>&1) {$script.ExitCode = 3010}
	Write-LogEntry -Message "Successfully removed all RegistryData values."
}


#---------------------------------------------------------------------------
#
# RemoveApps.
#
#---------------------------------------------------------------------------

function Get-RemoveAppsState
{
	return [pscustomobject]@{
		Installed = Get-AppxPackage -AllUsers | Where-Object {$script.Config.RemoveApps.App -contains $_.Name} | ForEach-Object {
			if ($script.ModuleData.RemoveApps.MandatoryApps -contains $_.Name)
			{
				Write-Warning -Message "Cannot uninstall app '$($_.Name)' as it is considered mandatory by $($script.Name)."
			}
			elseif ($_.NonRemovable)
			{
				Write-Warning -Message "Cannot uninstall app '$($_.Name)' as it is flagged as non-removable by the system."
			}
			elseif ($_.PackageUserInformation.ForEach({$_.ToString()}) -match 'Installed$')
			{
				$_
			}
		}
		Provisioned = Get-AppxProvisionedPackage -Online | Where-Object {$script.Config.RemoveApps.App -contains $_.DisplayName} | ForEach-Object {
			if ($script.ModuleData.RemoveApps.MandatoryApps -contains $_.DisplayName)
			{
				Write-Warning -Message "Cannot deprovision app '$($_.DisplayName)' as it is considered mandatory by $($script.Name)."
			}
			else
			{
				$_
			}
		}
	}
}

filter Remove-RemoveAppInstallation
{
	# We deliberately don't use the `-AllUsers` parameter as it doesn't work.
	$_ | Remove-AppxPackage
	Write-LogEntry -Message "Uninstalled AppX package '$($_.Name)' for all users."
}

filter Remove-RemoveAppProvisionment
{
	$_ | Remove-AppxProvisionedPackage -AllUsers -Online | Out-Null
	Write-LogEntry -Message "Deprovisioned AppX package '$($_.DisplayName)'."
}

function Install-RemoveApps
{
	# Advise commencement.
	Write-LogEntry -Message "Confirming RemoveApps configuration state, please wait..."

	# Rectify state if needed.
	if (($apps = Get-RemoveAppsState).PSObject.Properties.Where({$_.Value}))
	{
		$apps.Installed | Remove-RemoveAppInstallation
		$apps.Provisioned | Remove-RemoveAppProvisionment
		Write-LogEntry -Message "Successfully processed RemoveApps list."
		$script.ExitCode = 3010
	}
	else
	{
		Write-LogEntry -Message "Successfully confirmed RemoveApps state."
	}
}

function Confirm-RemoveApps
{
	# Advise commencement and get AppX states.
	Write-LogEntry -Message "Confirming RemoveApps configuration state, please wait..."
	$apps = Get-RemoveAppsState

	# Output test results.
	if ($apps.Installed)
	{
		"The following apps in RemoveApps require uninstalling:$($apps.Installed.Name | ConvertTo-BulletedList)"
	}
	if ($apps.Provisioned)
	{
		"The following apps in RemoveApps require deprovisioning:$($apps.Provisioned.DisplayName | ConvertTo-BulletedList)"
	}
}

function Remove-RemoveApps
{
	Write-Warning -Message "Removal/reversal of RemoveApps configuration is not supported."
}


#---------------------------------------------------------------------------
#
# SystemDriveLockdown.
#
#---------------------------------------------------------------------------

function Get-SystemDriveLockdownBoolean
{
	# XML stores everything as a string and .NET's XML parser does not attempt to coerce types upon parsing.
	# This cast to integer is safe here as the value type on 'Enabled' is `nonNegativeInteger` and not `boolean` where it may be true/false.
	return [System.Boolean][System.UInt32]$script.Config.SystemDriveLockdown.Enabled
}

function Test-SystemDriveLockdownEnable
{
	return (Get-SystemDriveLockdownBoolean) -and ((icacls.exe $env:SystemDrive\ 2>&1) -match '^.+NT AUTHORITY\\Authenticated Users.+$')
}

function Test-SystemDriveLockdownDisable
{
	return !(Get-SystemDriveLockdownBoolean) -and !((icacls.exe $env:SystemDrive\ 2>&1) -match '^.+NT AUTHORITY\\Authenticated Users.+$')
}

function Restore-SystemDriveLockdownDefaults
{
	[System.Void](icacls.exe $env:SystemDrive\ /grant "*$($script.ModuleData.SystemDriveLockdown.SID):(OI)(CI)(IO)(M)" 2>&1)
	[System.Void](icacls.exe $env:SystemDrive\ /grant "*$($script.ModuleData.SystemDriveLockdown.SID):(AD)" 2>&1)
}

function Install-SystemDriveLockdown
{
	# Advise commencement.
	Write-LogEntry -Message "Confirming SystemDriveLockdown state, please wait..."

	# Get state and repair if needed.
	if (Test-SystemDriveLockdownEnable)
	{
		[System.Void](icacls.exe $env:SystemDrive\ /remove:g *$($script.ModuleData.SystemDriveLockdown.SID) 2>&1)
		Write-LogEntry -Message "Successfully enabled SystemDriveLockdown component."
	}
	elseif (Test-SystemDriveLockdownDisable)
	{
		Restore-SystemDriveLockdownDefaults
		Write-LogEntry -Message "Successfully disabled SystemDriveLockdown component."
	}
	else
	{
		Write-LogEntry -Message "Successfully confirmed SystemDriveLockdown state is correctly deployed."
	}
}

function Confirm-SystemDriveLockdown
{
	# Advise commencement.
	Write-LogEntry -Message "Confirming SystemDriveLockdown state, please wait..."

	# Output incorrect results, if any.
	if (Test-SystemDriveLockdownEnable)
	{
		"The following SystemDriveLockdown components requires enabling:$('%SystemDrive% lockdown' | ConvertTo-BulletedList)"
	}
	elseif (Test-SystemDriveLockdownDisable)
	{
		"The following SystemDriveLockdown components requires disabling:$('%SystemDrive% lockdown' | ConvertTo-BulletedList)"
	}
}

function Remove-SystemDriveLockdown
{
	if (!((icacls.exe $env:SystemDrive\ 2>&1) -match 'NT AUTHORITY\\Authenticated Users:(\(AD\)|\(OI\)\(CI\)\(IO\)\(M\))$').Count.Equals(2))
	{
		Restore-SystemDriveLockdownDefaults
	}
	Write-LogEntry -Message "Successfully removed SystemDriveLockdown tag file."
}


#---------------------------------------------------------------------------
#
# SystemShortcuts.
#
#---------------------------------------------------------------------------

filter Get-SystemShortcutsFilePath
{
	return [System.IO.FileInfo]"$([System.Environment]::GetFolderPath($_.Location))\$($_.Name)"
}

filter Convert-SystemShortcutsToComProperties
{
	# Setup hashtable for returning at the end.
	$hash = @{FullName = ($_ | Get-SystemShortcutsFilePath).ToString()}

	# Get properties for the shortcut type we're processing.
	$scext = [System.IO.Path]::GetExtension($hash.FullName)
	$props = $script.ModuleData.SystemShortcuts.ShortcutProperties.$scext

	# We need to expand variables and other things from the source.
	$_.PSObject.Properties.Where({$props.Contains($_.Name)}).ForEach({
		$hash.Add($_.Name, [System.Environment]::ExpandEnvironmentVariables($_.Value))
	})

	# Set up some defaults if the source doesn't provide them.
	if ($scext -eq '.lnk')
	{
		if (!$hash.ContainsKey('RelativePath'))
		{
			$hash.Add('RelativePath', $null)
		}
		if (!$hash.ContainsKey('IconLocation'))
		{
			$hash.Add('IconLocation', ',0')
		}
		if (!$hash.ContainsKey('WindowStyle'))
		{
			$hash.Add('WindowStyle', 1)
		}
	}

	# Add empties for the remaining values the source doesn't provide. It eases the comparison burden.
	$props.Where({!$hash.ContainsKey($_)}).ForEach({$hash.Add($_, [System.String]::Empty)})

	# Convert to an object for comparisons in other funcs.
	return [pscustomobject]$hash
}

function Get-IncorrectSystemShortcuts
{
	# Iterate each shortcut and return objects for amendment to the pipeline.
	$script.Config.SystemShortcuts.Shortcut | Convert-SystemShortcutsToComProperties | Where-Object {
		$shortcut = $script.WScriptShell.CreateShortcut($_.FullName)
		$_.PSObject.Properties.Where({$_.Value -ne $shortcut.($_.Name)})
	}
}

filter Sync-SystemShortcuts
{
	# Update all properties and save out shortcut.
	$_.PSObject.Properties.Where({!$_.Name.Equals('FullName')}).ForEach({
		begin {
			$shortcut = $script.WScriptShell.CreateShortcut($_.FullName)
		}
		process {
			$shortcut.($_.Name) = $_.Value
		}
		end {
			$shortcut.Save()
		}
	})
	Write-LogEntry -Message "Installed shortcut '$($_.FullName)'."
}

function Install-SystemShortcuts
{
	# Advise commencement.
	Write-LogEntry -Message "Confirming SystemShortcuts installation state, please wait..."

	# Get incorrect items and rectify if needed.
	if ($incorrect = Get-IncorrectSystemShortcuts)
	{
		$incorrect | Sync-SystemShortcuts
		Write-LogEntry -Message "Successfully installed all SystemShortcuts."
	}
	else
	{
		Write-LogEntry -Message "Successfully confirmed all SystemShortcuts are correctly deployed."
	}
}

function Confirm-SystemShortcuts
{
	# Advise commencement.
	Write-LogEntry -Message "Confirming SystemShortcuts installation state, please wait..."

	# Output incorrect results, if any.
	if ($incorrect = Get-IncorrectSystemShortcuts)
	{
		"The following SystemShortcuts require installing or amending:$($incorrect.FullName | ConvertTo-BulletedList)"
	}
}

function Remove-SystemShortcuts
{
	# Remove each shortcut, ignoring errors as the shortcut might have already been removed.
	$script.Config.SystemShortcuts.Shortcut | Get-SystemShortcutsFilePath | Remove-Item -Force -Confirm:$false -ErrorAction Ignore
	Write-LogEntry -Message "Successfully removed all SystemShortcuts."
}


#---------------------------------------------------------------------------
#
# WindowsCapabilities.
#
#---------------------------------------------------------------------------

function Get-WindowsCapabilitiesState
{
	# Get current system capabilities and install/remove data.
	$capabilities = Get-WindowsCapability -Online
	$regexMatch = '^(Installed|InstallPending)$'
	$toInstall = $script.Config.WindowsCapabilities.Capability | Where-Object {$_.Action.Equals('Install')} | Select-Object -ExpandProperty '#text'
	$toRemove = $script.Config.WindowsCapabilities.Capability | Where-Object {$_.Action.Equals('Remove')} | Select-Object -ExpandProperty '#text'

	# Get capability states and return to the pipeline.
	return [pscustomobject]@{
		Installed = $capabilities.Where({($toRemove -contains $_.Name) -and ($_.State -match $regexMatch)})
		Uninstalled = $capabilities.Where({($toInstall -contains $_.Name) -and ($_.State -notmatch $regexMatch)})
	}
}

filter Remove-ListedWindowsCapability
{
	$_ | Remove-WindowsCapability -Online | Out-Null
	Write-LogEntry -Message "Removed Windows Capability '$($_.Name)'."
}

filter Install-ListedWindowsCapability
{
	$_ | Add-WindowsCapability -Online | Out-Null
	Write-LogEntry -Message "Added Windows Capability '$($_.Name)'."
}

function Install-WindowsCapabilities
{
	# Advise commencement.
	Write-LogEntry -Message "Confirming WindowsCapabilities configuration state, please wait..."

	# Get capability states and rectify as needed.
	if (($capabilities = Get-WindowsCapabilitiesState).PSObject.Properties.Where({$_.Value}))
	{
		$capabilities.Installed | Remove-ListedWindowsCapability
		$capabilities.Uninstalled | Install-ListedWindowsCapability
		Write-LogEntry -Message "Successfully processed WindowsCapabilities configuration."
		$script.ExitCode = 3010
	}
	else
	{
		Write-LogEntry -Message "Successfully confirmed all WindowsCapabilities are correctly deployed."
	}
}

function Confirm-WindowsCapabilities
{
	# Advise commencement and get capability states.
	Write-LogEntry -Message "Confirming WindowsCapabilities configuration state, please wait..."
	$capabilities = Get-WindowsCapabilitiesState

	# Output test results.
	if ($capabilities.Installed)
	{
		"The following Windows Capabilities require uninstalling:$($capabilities.Installed.Name | ConvertTo-BulletedList)"
	}
	if ($capabilities.Uninstalled)
	{
		"The following Windows Capabilities require installing:$($capabilities.Uninstalled.Name | ConvertTo-BulletedList)"
	}
}

function Remove-WindowsCapabilities
{
	Write-Warning -Message "Removal/reversal of WindowsCapabilities configuration is not supported."
}


#---------------------------------------------------------------------------
#
# WindowsOptionalFeatures.
#
#---------------------------------------------------------------------------

function Get-WindowsOptionalFeaturesState
{
	# Get current system features and install/remove data.
	$features = Get-WindowsOptionalFeature -Online
	$toEnable = $script.Config.WindowsOptionalFeatures.Feature | Where-Object {$_.Action.Equals('Enable')} | Select-Object -ExpandProperty '#text'
	$toDisable = $script.Config.WindowsOptionalFeatures.Feature | Where-Object {$_.Action.Equals('Disable')} | Select-Object -ExpandProperty '#text'

	# Get capability states and return to the pipeline.
	return [pscustomobject]@{
		Enabled = $features.Where({($toDisable -contains $_.FeatureName) -and ($_.State.Equals([Microsoft.Dism.Commands.FeatureState]::Enabled))})
		Disabled = $features.Where({($toEnable -contains $_.FeatureName) -and ($_.State.Equals([Microsoft.Dism.Commands.FeatureState]::Disabled))})
	}
}

filter Disable-ListedWindowsOptionalFeature
{
	$_ | Disable-WindowsOptionalFeature -Online -NoRestart -WarningAction Ignore | Out-Null
	Write-LogEntry -Message "Disabled Windows Optional Feature '$($_.FeatureName)'."
}

filter Enable-ListedWindowsOptionalFeature
{
	$_ | Enable-WindowsOptionalFeature -Online -NoRestart -WarningAction Ignore | Out-Null
	Write-LogEntry -Message "Enabled Windows Optional Feature '$($_.FeatureName)'."
}

function Install-WindowsOptionalFeatures
{
	# Advise commencement.
	Write-LogEntry -Message "Confirming WindowsOptionalFeatures configuration state, please wait..."

	# Get capability states and rectify as needed.
	if (($features = Get-WindowsOptionalFeaturesState).PSObject.Properties.Where({$_.Value}))
	{
		$features.Enabled | Disable-ListedWindowsOptionalFeature
		$features.Disabled | Enable-ListedWindowsOptionalFeature
		Write-LogEntry -Message "Successfully processed WindowsOptionalFeatures configuration."
		$script.ExitCode = 3010
	}
	else
	{
		Write-LogEntry -Message "Successfully confirmed all WindowsOptionalFeatures are correctly deployed."
	}
}

function Confirm-WindowsOptionalFeatures
{
	# Advise commencement and get feature states.
	Write-LogEntry -Message "Confirming WindowsOptionalFeatures configuration state, please wait..."
	$features = Get-WindowsOptionalFeaturesState

	# Output test results.
	if ($features.Enabled)
	{
		"The following Windows Optional Features require disabling:$($features.Enabled.FeatureName | ConvertTo-BulletedList)"
	}
	if ($features.Disabled)
	{
		"The following Windows Optional Features require enabling:$($features.Disabled.FeatureName | ConvertTo-BulletedList)"
	}
}

function Remove-WindowsOptionalFeatures
{
	Write-Warning -Message "Removal/reversal of WindowsOptionalFeatures configuration is not supported."
}


#---------------------------------------------------------------------------
#
# Main code execution block.
#
#---------------------------------------------------------------------------

try
{
	Open-Log
	Initialize-ModuleData
	Import-DesiredStateConfig
	Invoke-DesiredStateOperations
}
catch
{
	# Don't prefix TestResults output from Confirm operations.
	if ($script.ContainsKey('TestResults') -and $_.Exception.Message.Equals($script.TestResults))
	{
		$script.TestResults | Write-StdErrMessage
		$script.ExitCode = 1618
	}
	else
	{
		$_ | Out-FriendlyErrorMessage | Write-StdErrMessage
		$script.ExitCode = 1603
	}
	Write-LogEntry -Message "$($script.Divider)`nPlease review transcription log and try again."
}
finally
{
	Close-Log
	exit $script.ExitCode
}
