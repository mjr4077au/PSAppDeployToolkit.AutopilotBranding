
<#PSScriptInfo

.VERSION 2.9

.GUID dd1fb415-b54e-4773-938c-5c575c335bbd

.AUTHOR Mitch Richters

.COMPANYNAME The Missing Link Network Integration Pty Ltd

.COPYRIGHT Copyright © 2024 Mitchell James Richters. All rights reserved.

#>

<#

.SYNOPSIS
Installs a preconfigured list of system defaults, validates them or uninstalls them as required.

.DESCRIPTION
Inspired by Michael Niehaus' "AutopilotBranding" toolkit, this script is specifically designed to be used to install a set of system baseline defaults for workstations, extending from languages, removal of built-in apps/features, user defaults via Active Setup, and more.

An example setup via an XML configuration file would be:

<Config Version="1.0">
	<Content>
		<!-- Note: If a Source is not specified, the script will require you to specify a content path and data map. -->
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
		<Capability Action="Add">NetFX3~~~~</Capability>
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

.PARAMETER Uninstall
Instructs the script to uninstall changed defaults as per the supplied configuration.

.PARAMETER Discriminator
Specifies an extra identifier for logging purposes, such as country or region.

.PARAMETER Config
Specifies the file path/URI, or raw XML to use as the configuration source for the script.

.PARAMETER ContentPath
Specifies the path to Content when not hosting it in a HTTPS location.

.PARAMETER DataMap
Specifies the file/hash map of Content when not hosting it in a HTTPS location.

.EXAMPLE
powershell.exe -ExecutionPolicy Bypass -NoProfile -NoLogo -NonInteractive -File Invoke-DesiredStateManagementOperation.ps1

.EXAMPLE
powershell.exe -ExecutionPolicy Bypass -NoProfile -NoLogo -NonInteractive -File Invoke-DesiredStateManagementOperation.ps1 -Install

.EXAMPLE
powershell.exe -ExecutionPolicy Bypass -NoProfile -NoLogo -NonInteractive -File Invoke-DesiredStateManagementOperation.ps1 -Uninstall

.EXAMPLE
powershell.exe -ExecutionPolicy Bypass -NoProfile -NoLogo -NonInteractive -File Invoke-DesiredStateManagementOperation.ps1 -Mode Install

.EXAMPLE
powershell.exe -ExecutionPolicy Bypass -NoProfile -NoLogo -NonInteractive -File Invoke-DesiredStateManagementOperation.ps1 -Mode Install -Config 'C:\Path\To\Config.xml'

.INPUTS
None. You cannot pipe objects to Invoke-DesiredStateManagementOperation.ps1.

.OUTPUTS
stdout stream. Invoke-DesiredStateManagementOperation.ps1 returns a log string via Write-Host that can be piped.
stderr stream. Invoke-DesiredStateManagementOperation.ps1 writes all error text to stderr for catching externally to PowerShell if required.

.NOTES
**Changelog**

2.9
- Optimise output check in script's main catch block.
- Replace all `-f` operators with `[System.String]::Format()` static method.
- Add some missing parameter help comments.
- Throw proper errors for our unexpected/unsupported issues.
- Overhaul parameter setup for $ContentPath and $DataMap.
- Use the `.Add()` method on all hashtables so we can error out if we try to overwrite data.
- Make `Get-ItemPropertyUnexpanded` API 1:1 with `Get-ItemProperty`.
- Remove `Get-ItemPropertyUnexpanded` as it's now in TMLSTL.
- Indent script to properly fit within the begin/end blocks.
- Avoid `.Invoke()` on scriptblocks as it returns a collection rather than enumerated output.
- Consistency fix for reporting on deprecated ActiveSetup components.
- Ensure all non-terminating errors go via `Invoke-ErrorHandler`.
- Get rid of `$Mode` parameter.
- Ensure verbose output from `Remove-ItemsAndEmptyDirectory` is logged appropriately.

2.8
- Migrate script to common backend utilities.

2.7
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
- Cleaned up log messages in `Remove-AppProvisionment` and `Remove-AppInstallation`.
- Cleaned up log messages in `Remove-ListedWindowsCapability` and `Add-ListedWindowsCapability`.
- Cleaned up log messages in `Disable-ListedWindowsOptionalFeature` and `Enable-ListedWindowsOptionalFeature`.
- Change all filters that call native executables to functions and give them a begin {} block to clear $LASTEXITCODE.
- Rework `Uninstall-RegistryData` to test $LASTEXITCODE to determine whether a reboot is needed or not.
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
- Improve logging for `Uninstall-RegistryDataItem` which did not report its operations.
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
- Reworked `Get-RemoveAppsState` and `Remove-AppInstallation` to be compatible with PowerShell 5.1 and 7.3.x.
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
- Removed `$Action` parameter from `Uninstall-ActiveSetupComponent` that was remaining after copy-pasting `Install-ActiveSetupComponent`.
- Slightly tidied up `Uninstall-DefaultTheme` and `Get-ContentFilePath`.
- Added missed error handling to `Invoke-ContentPreOps` to match other module pre-op functions.
- Partially re-wrote `Test-ContentValidity` for greater clarity.
- Use `Test-Path` in place of silencing errors where suited.
- Add heading that was missing for DefaultStartLayout code segment.
- Added better handling of obtaining default user profile locations from the registry vs. hard-coded paths.
- Improve logic used in `Uninstall-DefaultStartLayout` function.
- Fixed state detection issue in `OemInformation` section.

2.1
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

# Set our requirements here.
#Requires -Version 5.1
#Requires -Modules @{ ModuleName="TMLSTL.Logging"; ModuleVersion="5.5" }, @{ ModuleName="TMLSTL.Utilities"; ModuleVersion="5.5" }

[CmdletBinding(DefaultParameterSetName = 'Confirm')]
Param
(
	[Parameter(Mandatory = $true, ParameterSetName = 'Install', HelpMessage = "Instructs the script to install the Desired State Management config.")]
	[System.Management.Automation.SwitchParameter]$Install,

	[Parameter(Mandatory = $true, ParameterSetName = 'Uninstall', HelpMessage = "Instructs the script to uninstall the Desired State Management config.")]
	[System.Management.Automation.SwitchParameter]$Uninstall,

	[Parameter(Mandatory = $false, ParameterSetName = 'Install', HelpMessage = "Provides a unique log filename identifier for layered/inherited deployments.")]
	[Parameter(Mandatory = $false, ParameterSetName = 'Uninstall', HelpMessage = "Provides a unique log filename identifier for layered/inherited deployments.")]
	[Parameter(Mandatory = $false, ParameterSetName = 'Confirm', HelpMessage = "Provides a unique log filename identifier for layered/inherited deployments.")]
	[ValidateNotNullOrEmpty()]
	[System.String]$Discriminator,

	[Parameter(Mandatory = $true, ParameterSetName = 'Install', HelpMessage = "Provide the path/URI to the config, or raw XML input.")]
	[Parameter(Mandatory = $true, ParameterSetName = 'Uninstall', HelpMessage = "Provide the path/URI to the config, or raw XML input.")]
	[Parameter(Mandatory = $true, ParameterSetName = 'Confirm', HelpMessage = "Provide the path/URI to the config, or raw XML input.")]
	[ValidateScript({
		# Open a new XML document and add out schema.
		$Script:xml = [System.Xml.XmlDocument]::new()
		[System.Void]$xml.Schemas.Add([System.Xml.Schema.XmlSchema]::Read([System.IO.StringReader]::new('<?xml version="1.0" encoding="utf-8"?>
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

				<xs:simpleType name="baseAddRemove">
					<xs:restriction base="xs:string">
						<xs:pattern value="^(Add|Remove)$"/>
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
														<xs:attribute name="Action" use="required" type="baseAddRemove"/>
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
			</xs:schema>'
		), $null))

		# Load our file in, attempting as a URI first and then validate it before returning success.
		$xml.Load($(try {[System.Xml.XmlReader]::Create($Config)} catch {[System.IO.StringReader]::new($Config)}))
		$xml.Validate($null)
		return $true
	})]
	[System.String]$Config
)

DynamicParam
{
	# Set required variables to ensure script functionality.
	$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
	$ProgressPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
	Set-PSDebug -Strict
	Set-StrictMode -Version Latest

	# Add additional parameters only if we're not removing the toolkit and the config specifies content without a source.
	if ($Uninstall -or !$xml.Config.ChildNodes.LocalName.Contains('Content') -or $xml.Config.Content.ChildNodes.LocalName.Contains('Source'))
	{
		return
	}

	# Define parameter dictionary for returning at the end.
	$paramDictionary = [System.Management.Automation.RuntimeDefinedParameterDictionary]::new()

	# Add $ContentPath only for installations.
	if ($Install)
	{
		$paramDictionary.Add('ContentPath', [System.Management.Automation.RuntimeDefinedParameter]::new(
			'ContentPath', [System.String], [System.Collections.Generic.List[System.Attribute]]@(
				[System.Management.Automation.ParameterAttribute]@{Mandatory = $true; ParameterSetName = 'Install'; HelpMessage = 'Provide the path to Content source if not hosted on a web server.'}
				[System.Management.Automation.ValidateScriptAttribute]::new({[System.IO.Directory]::Exists($_) -and !!(Get-ChildItem -LiteralPath $_)})
			)
		))
	}

	# Add $DataMap all non-uninstall operations.
	$paramDictionary.Add('DataMap', [System.Management.Automation.RuntimeDefinedParameter]::new(
		'DataMap', [System.Collections.IDictionary], [System.Collections.Generic.List[System.Attribute]]@(
			[System.Management.Automation.ParameterAttribute]@{Mandatory = $true; ParameterSetName = 'Install'; HelpMessage = 'Provide the file/hash map to Content source if not hosted on a web server.'}
			[System.Management.Automation.ParameterAttribute]@{Mandatory = $true; ParameterSetName = 'Confirm'; HelpMessage = 'Provide the file/hash map to Content source if not hosted on a web server.'}
			[System.Management.Automation.ValidateScriptAttribute]::new({!!$_.Count})
		)
	))

	# Return the populated dictionary.
	return $paramDictionary
}

begin
{
	#---------------------------------------------------------------------------
	#
	# Miscellaneous functions.
	#
	#---------------------------------------------------------------------------

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

	function Uninstall-RegistryDataItem
	{
		begin {
			# Reset the global exit code before starting.
			$global:LASTEXITCODE = $null
		}

		process {
			# Uninstall item.
			[System.Void](reg.exe DELETE ($key = $_.Key) /v $_.Name /f 2>&1)
			Write-LogEntry -Message "Uninstalled registry value '$key\$($_.Name)'."

			# Uninstall key and any parents if there's no objects left within it.
			while ([System.String]::IsNullOrWhiteSpace($(try {reg.exe QUERY $key 2>&1} catch {$_.Exception.Message})))
			{
				[System.Void](reg.exe DELETE $key /f 2>&1); $key = $key -replace '\\[^\\]+$'
				Write-LogEntry -Message "Uninstalled empty registry key '$key'."
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

	filter Get-ContentFilePath
	{
		# Confirm we have a 'Content' element specified.
		if ($xml.Config.ChildNodes.LocalName -notcontains 'Content')
		{
			throw [System.Management.Automation.ErrorRecord]::new(
				[System.InvalidOperationException]::new("The 'Content' element has not been configured to supply the required data."),
				'XmlConfigMissingContentConfig',
				[System.Management.Automation.ErrorCategory]::InvalidOperation,
				$xml
			)
		}

		# Confirm Content has been initialised (should be given how the script operates).
		if (!$data.Content.ContainsKey('DataMap'))
		{
			throw [System.Management.Automation.ErrorRecord]::new(
				[System.InvalidOperationException]::new("The 'Content' element has not been initialised. This is unexpected behaviour."),
				'XmlContentConfigNotInitialised',
				[System.Management.Automation.ErrorCategory]::InvalidOperation,
				[pscustomobject]@{Config = $xml; Database = $data}
			)
		}

		# Test that the piped file path is in the Content's DataMap keys.
		if ($data.Content.DataMap.Keys -notcontains $_)
		{
			throw [System.Management.Automation.ErrorRecord]::new(
				[System.InvalidOperationException]::new("The specified file '$_' was not available in the provided Content location."),
				'ContentFileNotFound',
				[System.Management.Automation.ErrorCategory]::InvalidOperation,
				$($data.Content.DataMap.Keys)
			)
		}

		# Return the full path to the file within the Content element's destination.
		return "$($data.Content.Destination)\$($_)"
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
		throw [System.Management.Automation.ErrorRecord]::new(
			[System.InvalidOperationException]::new("The current OS with version '$([System.Environment]::OSVersion.Version)' is unknown/not supported."),
			'OperatingSystemNotSupported',
			[System.Management.Automation.ErrorCategory]::InvalidOperation,
			[System.Environment]::OSVersion
		)
	}


	#---------------------------------------------------------------------------
	#
	# Main callstack functions.
	#
	#---------------------------------------------------------------------------

	function Initialize-ModuleData
	{
		# Nothing here should ever require changing/manipulation.
		return @{
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
				Archive = "$basedir\DefaultLayouts.$(Get-ScriptStartDateTime -AsFilestamp).backup"
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
					'.lnk' = $wsShell.CreateShortcut("$tempdir\$(Get-Random).lnk").PSObject.Properties.Name
					'.url' = $wsShell.CreateShortcut("$tempdir\$(Get-Random).url").PSObject.Properties.Name
				}
				ExpandProperties = 'TargetPath', 'IconLocation', 'RelativePath', 'WorkingDirectory'
			}
		}
	}

	function Invoke-DesiredStateOperations ([Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][System.String]$Action)
	{
		# Initialise variables for desired state ops.
		$wsShell = New-Object -ComObject WScript.Shell
		$data = Initialize-ModuleData

		# Dynamically generate and invoke scriptblocks based on the XML config and what this script supports.
		$res = [System.String]::Join("`n", $xml.Config.ChildNodes.LocalName.ForEach({
			& "$Action-$_"; if ($Action.Equals('Install')) {Write-LogDivider}
		}))

		# Release the WScript.Shell COM object.
		[System.Void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($wsShell)
		$wsShell = $null; Remove-Variable -Name wsShell -Force -Confirm:$false

		# Return any output to the caller.
		if (![System.String]::IsNullOrWhiteSpace($res))
		{
			Write-LogDivider
			return $res
		}
	}


	#---------------------------------------------------------------------------
	#
	# ActiveSetup.
	#
	#---------------------------------------------------------------------------

	filter Out-ActiveSetupComponentName
	{
		return "$($xml.Config.ActiveSetup.Identifier) - $_"
	}

	function Get-ActiveSetupState
	{
		# Store registry base locally to reduce line length.
		$regbase = $data.ActiveSetup.RegistryBase

		# Return state to the pipeline.
		return [pscustomobject]@{
			NotPresent = $xml.Config.ActiveSetup.Component | Where-Object {
				!(Test-Path -LiteralPath "$regbase\$($_.Name | Out-ActiveSetupComponentName)" -PathType Container)
			}
			Deprecated = Get-Item -Path "$regbase\$(($prefix = "$($xml.Config.ActiveSetup.Identifier) - "))*" | Where-Object {
				$xml.Config.ActiveSetup.Component.Name -notcontains $_.PSChildName.Replace($prefix, $null)
			}
			Mismatched = $xml.Config.ActiveSetup.Component | Where-Object {
				($dest = Get-Item -LiteralPath "$regbase\$($_.Name | Out-ActiveSetupComponentName)" -ErrorAction Ignore | Get-ItemPropertyUnexpanded) -and
				(Compare-Object -ReferenceObject $_ -DifferenceObject $dest -Property Version,StubPath)
			}
		}
	}

	filter Install-ActiveSetupComponent ([ValidateSet('Install','Update')][System.String]$Action)
	{
		# Set up component's key and associated properties.
		$name = $_.Name | Out-ActiveSetupComponentName
		$path = (New-Item -Path $data.ActiveSetup.RegistryBase -Name $name -Value $name -Force).Name

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

	filter Uninstall-ActiveSetupComponent
	{
		$_ | Remove-Item -Force -Confirm:$false
		Write-LogEntry -Message "Uninstalled deprecated ActiveSetup component '$($_.PSChildName)'."
	}

	function Install-ActiveSetup
	{
		# Advise commencement.
		Write-LogEntry -Message "Confirming ActiveSetup component installation state, please wait..."

		# Rectify state if needed.
		if (($components = Get-ActiveSetupState).PSObject.Properties.Where({$_.Value}))
		{
			$components.Deprecated | Uninstall-ActiveSetupComponent
			$components.Mismatched | Install-ActiveSetupComponent -Action Update
			$components.NotPresent | Install-ActiveSetupComponent -Action Install
			Write-LogEntry -Message "Successfully installed all ActiveSetup components."
			Update-ExitCode -Value 3010
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
			$deprecated = $components.Deprecated.PSChildName.Replace("$($xml.Config.ActiveSetup.Identifier) - ", $null)
			"The following ActiveSetup components require removing:$($deprecated | ConvertTo-BulletedList)"
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

	function Uninstall-ActiveSetup
	{
		# Uninstall all items.
		Remove-Item -Path "$($data.ActiveSetup.RegistryBase)\$($xml.Config.ActiveSetup.Identifier)*" -Force -Confirm:$false
		Write-LogEntry -Message "Successfully uninstalled all ActiveSetup components."
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
			# Check whether we've got a hosted source as defined in the config, or we've given the toolkit content to work with.
			if ($xml.Config.Content.ChildNodes.LocalName.Contains('Source'))
			{
				# Download the source content and extract it for mapping and copying to destination.
				Invoke-WebRequest -UseBasicParsing -Uri $xml.Config.Content.Source -OutFile $data.Content.DownloadFile
				Expand-Archive -LiteralPath $data.Content.DownloadFile -DestinationPath $data.Content.TemporaryDir -Force
				$data.Content.Add('DataMap', (Out-FileHashDataMap -LiteralPath $data.Content.TemporaryDir))
			}
			else
			{
				# A Content path is only available for installations.
				if ($Action.Equals('Install'))
				{
					$data.Content.TemporaryDir = $Script:PSBoundParameters['ContentPath']
				}
				$data.Content.Add('DataMap', $Script:PSBoundParameters['DataMap'])
			}

			# Set the destination path based off the incoming content, expanding any environment variables as required.
			$data.Content.Add('Destination', [System.Environment]::ExpandEnvironmentVariables($xml.Config.Content.Destination))
		}
		catch
		{
			$_ | Invoke-ErrorHandler -ErrorPrefix "Error confirming Content state." -NoStackTrace
			return 1
		}
	}

	function Test-ContentValidity
	{
		# Store return value.
		$exitCode = 0

		# Test we have an environment variable first.
		if (!(Get-EnvironmentVariableValue -Variable $xml.Config.Content.EnvironmentVariable -Target Machine) -or
			!(Get-EnvironmentVariableValue -Variable Path -Target Machine).Split(';').Contains($data.Content.Destination))
		{
			$exitCode += 1
		}

		# Test the validity of the destination data.
		$gifParams = @{LiteralPath = $data.Content.Destination; DataMap = $data.Content.DataMap}
		$exitCode += 2 * !!$(try {Get-InvalidFiles @gifParams} catch {1})

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
				Invoke-RobocopyTransfer -Source $data.Content.TemporaryDir -Destination $data.Content.Destination -Verbose 4>&1 | Send-VerboseRecordsToLog
				Write-LogEntry -Message "Successfully installed Content files."
			}
			{$_ -gt 0} {
				# Add content to system's path environment variable, as well as our dedicated variable.
				Set-SystemPathVariable -NewValue "$($data.Content.Destination);$(Get-EnvironmentVariableValue -Variable Path -Target Machine)"
				[System.Environment]::SetEnvironmentVariable($xml.Config.Content.EnvironmentVariable, $data.Content.Destination, 'Machine')
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

	function Uninstall-Content
	{
		# Store expanded destination and delete the contents folder.
		Remove-ItemsAndEmptyDirectory -LiteralPath ($dest = [System.Environment]::ExpandEnvironmentVariables($xml.Config.Content.Destination)) -Verbose 4>&1 | Send-VerboseRecordsToLog

		# Uninstall all references to the destination from the system's environment variables.
		Set-SystemPathVariable -NewValue ([System.String]::Join(';', (Get-EnvironmentVariableValue -Variable Path -Target Machine).Split(';').Where({!$_.Equals($dest)})))
		[System.Environment]::SetEnvironmentVariable($xml.Config.Content.EnvironmentVariable, $null, 'Machine')
		Write-LogEntry -Message "Successfully uninstalled all Content components."
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
			$data.DefaultAppAssociations.Add('Source', ($xml.Config.DefaultAppAssociations | Get-ContentFilePath))
			$data.DefaultAppAssociations.Add('FileHash', $data.Content.DataMap[$xml.Config.DefaultAppAssociations])
		}
		catch
		{
			$_ | Invoke-ErrorHandler -ErrorPrefix "Error confirming DefaultAppAssociations state." -NoStackTrace
			return 1
		}
	}

	function Test-DefaultAppAssociationsApplicability
	{
		return ![System.IO.File]::Exists($data.DefaultAppAssociations.TagFile) -or
			!$data.DefaultAppAssociations.FileHash.Equals(([System.IO.File]::ReadAllText($data.DefaultAppAssociations.TagFile)))
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
			[System.Void](dism.exe /Online /Import-DefaultAppAssociations:$data.DefaultAppAssociations.Source 2>&1)
			[System.IO.File]::WriteAllText($data.DefaultAppAssociations.TagFile, $data.DefaultAppAssociations.FileHash)
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

	function Uninstall-DefaultAppAssociations
	{
		Remove-Item -LiteralPath $data.DefaultAppAssociations.TagFile -Force -Confirm:$false -ErrorAction Ignore
		Write-LogEntry -Message "Successfully uninstalled DefaultAppAssociations tag file."
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
			Write-LogEntry -Message "The DefaultStartLayout element is only supported on Windows 10." -Warning -Prefix
			return 1
		}

		# Do basic sanity checks.
		try
		{
			# Get file path from our cache.
			$data.DefaultStartLayout.Add('Source', ($xml.Config.DefaultStartLayout | Get-ContentFilePath))
		}
		catch
		{
			$_ | Invoke-ErrorHandler -ErrorPrefix "Error confirming DefaultStartLayout state." -NoStackTrace
			return 1
		}
	}

	function Test-DefaultStartLayoutValidity
	{
		# Confirm whether start layout is valid by testing whether src/dest hash match.
		$src = $data.DefaultStartLayout.Source
		$dst = $data.DefaultStartLayout.Destination
		return ![System.IO.File]::Exists($dst) -or !(Get-FileHash -LiteralPath $dst).Hash.Equals($data.Content.DataMap[$src])
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
			Copy-Item -LiteralPath $data.DefaultStartLayout.Destination -Destination $data.DefaultStartLayout.Archive | Out-Null
			Copy-Item -LiteralPath $data.DefaultStartLayout.Source -Destination $data.DefaultStartLayout.Destination -Force | Out-Null
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

	function Uninstall-DefaultStartLayout
	{
		# Get oldest backup.
		$backup = Get-ChildItem -Path "$($data.DefaultStartLayout.BaseDirectory)\*.backup" |
			Sort-Object -Property LastWriteTime | Select-Object -ExpandProperty FullName -First 1

		# Restore it if we have one.
		if ($backup)
		{
			Copy-Item -LiteralPath $backup -Destination $data.DefaultStartLayout.Destination -Force -Confirm:$false
			Remove-Item -Path "$($data.DefaultStartLayout.BaseDirectory)\*.backup" -Force -Confirm:$false
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
			Write-LogEntry -Message "The DefaultLayoutModification element is only supported on Windows 11." -Warning -Prefix
			return 1
		}

		# Do basic sanity checks.
		try
		{
			# Format a string for use as our destination for files.
			$dest = "$($data.DefaultLayoutModification.BaseDirectory)\$($data.DefaultLayoutModification.FileNameBase){0}"

			# Get file path(s) from our cache.
			$filePaths = $xml.Config.DefaultLayoutModification.ChildNodes |
				ForEach-Object {$xml.Config.DefaultLayoutModification.$_} | Get-ContentFilePath |
					ForEach-Object {@{LiteralPath = $_; Destination = [System.String]::Format($dest, [System.IO.Path]::GetExtension($_))}}

			# Add file path(s) into our running data.
			$data.DefaultLayoutModification.Add('FilePaths', $filePaths)
		}
		catch
		{
			$_ | Invoke-ErrorHandler -ErrorPrefix "Error confirming DefaultLayoutModification state." -NoStackTrace
			return 1
		}
	}

	function Get-IncorrectDefaultLayoutModifications
	{
		# Confirm whether start layout is valid by testing whether src/dest hash match.
		return $data.DefaultLayoutModification.FilePaths | Where-Object {
			![System.IO.File]::Exists($_.Destination) -or
			!(Get-FileHash -LiteralPath $_.Destination).Hash.Equals($data.Content.DataMap[$_.LiteralPath.Replace("$($data.Content.Destination)\", $null)])
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

	function Uninstall-DefaultLayoutModification
	{
		# Uninstall the file completely.
		Remove-Item -Path "$($data.DefaultLayoutModification.BaseDirectory)\LayoutModification.*" -Force -Confirm:$false
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
			$data.DefaultTheme.Add('Value', ($xml.Config.DefaultTheme | Get-ContentFilePath))
		}
		catch
		{
			$_ | Invoke-ErrorHandler -ErrorPrefix "Error confirming DefaultTheme state." -NoStackTrace
			return 1
		}
	}

	function Get-IncorrectDefaultTheme
	{
		# Return results.
		return Invoke-DefaultUserRegistryAction -Expression {!$data.DefaultTheme.Value.Equals(($data.DefaultTheme | Get-RegistryDataItemValue))}
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
			Invoke-DefaultUserRegistryAction -Expression {$data.DefaultTheme | Install-RegistryDataItem} | Out-Null
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

	function Uninstall-DefaultTheme
	{
		# Just remove the registry components so we don't risk breaking user experiences.
		Invoke-DefaultUserRegistryAction -Expression {($data.DefaultTheme | Where-Object {$_ | Get-RegistryDataItemValue} | Uninstall-RegistryDataItem) 6>$null} | Out-Null
		Write-LogEntry -Message "Successfully uninstalled all DefaultTheme registry components."
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
			$data.LanguageDefaults.Add('Source', ($xml.Config.LanguageDefaults | Get-ContentFilePath))
			$data.LanguageDefaults.Add('FileHash', $data.Content.DataMap[$xml.Config.LanguageDefaults])
		}
		catch
		{
			$_ | Invoke-ErrorHandler -ErrorPrefix "Error confirming LanguageDefaults state." -NoStackTrace
			return 1
		}
	}

	function Test-LanguageDefaultsApplicability
	{
		return ![System.IO.File]::Exists($data.LanguageDefaults.TagFile) -or
			!$data.LanguageDefaults.FileHash.Equals([System.IO.File]::ReadAllText($data.LanguageDefaults.TagFile))
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
			control.exe "intl.cpl,,/f:`"$($data.LanguageDefaults.Source)`"" 2>&1
			[System.IO.File]::WriteAllText($data.LanguageDefaults.TagFile, $data.LanguageDefaults.FileHash)
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

	function Uninstall-LanguageDefaults
	{
		Remove-Item -LiteralPath $data.LanguageDefaults.TagFile -Force -Confirm:$false -ErrorAction Ignore
		Write-LogEntry -Message "Successfully uninstalled LanguageDefaults tag file."
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
			$data.OemInformation.Add('Logo', ($xml.Config.OemInformation.Logo | Get-ContentFilePath))
			$data.OemInformation.Add('Model', (Get-CimInstance -ClassName Win32_ComputerSystem).Model)
		}
		catch
		{
			$_ | Invoke-ErrorHandler -ErrorPrefix "Error confirming OemInformation state." -NoStackTrace
			return 1
		}
	}

	function Get-IncorrectOemInformation
	{
		# Get all properties from the registry.
		$itemprops = Get-ItemProperty -LiteralPath ($regbase = $data.OemInformation.RegistryBase) -ErrorAction Ignore

		# Return test results.
		return ($xml.Config.OemInformation.ChildNodes.LocalName + 'Model').ForEach({
			# Get calculated value from script's storage if present, otherwise use XML provided source.
			$value = if ($data.OemInformation.ContainsKey($_)) {$data.OemInformation.$_} else {$xml.Config.OemInformation.$_}

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

	function Uninstall-OemInformation
	{
		Remove-Item -LiteralPath $data.OemInformation.RegistryBase -Force -Confirm:$false -ErrorAction Ignore
		Write-LogEntry -Message "Successfully uninstalled all OemInformation values."
	}


	#---------------------------------------------------------------------------
	#
	# RegistrationInfo.
	#
	#---------------------------------------------------------------------------

	function Get-IncorrectRegistrationInfo
	{
		# Get item properties and store.
		$itemprops = Get-ItemProperty -LiteralPath ($regbase = $data.RegistrationInfo.RegistryBase)

		# Return any mismatches.
		return $xml.Config.RegistrationInfo.ChildNodes.LocalName.ForEach({
			if (!$itemprops -or !$xml.Config.RegistrationInfo.($_).Equals(($itemprops | Select-Object -ExpandProperty $_ -ErrorAction Ignore))) {
				[pscustomobject]@{LiteralPath = $regbase; Name = $_; Value = $xml.Config.RegistrationInfo.$_; PropertyType = 'String'}
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

	function Uninstall-RegistrationInfo
	{
		$ripParams = @{LiteralPath = $data.RegistrationInfo.RegistryBase; Name = $xml.Config.RegistrationInfo.ChildNodes.LocalName}
		Remove-ItemProperty @ripParams -Force -Confirm:$false -ErrorAction Ignore
		Write-LogEntry -Message "Successfully uninstalled all RegistrationInfo values."
	}


	#---------------------------------------------------------------------------
	#
	# RegistryData.
	#
	#---------------------------------------------------------------------------

	function Get-IncorrectRegistryData
	{
		return $xml.Config.RegistryData.Item | Where-Object {($_ | Get-RegistryDataItemValue) -ne $_.Value}
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
			Update-ExitCode -Value 3010
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

	function Uninstall-RegistryData
	{
		# Uninstall each item and the key if the item was the last.
		if (($xml.Config.RegistryData.Item | Where-Object {$_ | Get-RegistryDataItemValue} | Uninstall-RegistryDataItem) 6>&1) {Update-ExitCode -Value 3010}
		Write-LogEntry -Message "Successfully uninstalled all RegistryData values."
	}


	#---------------------------------------------------------------------------
	#
	# RemoveApps.
	#
	#---------------------------------------------------------------------------

	function Get-RemoveAppsState
	{
		return [pscustomobject]@{
			Installed = Get-AppxPackage -AllUsers | Where-Object {$xml.Config.RemoveApps.App -contains $_.Name} | ForEach-Object {
				if ($data.RemoveApps.MandatoryApps -contains $_.Name)
				{
					Write-LogEntry -Message "Cannot remove app '$($_.Name)' as it is considered mandatory." -Warning -Prefix
				}
				elseif ($_.NonRemovable)
				{
					Write-LogEntry -Message "Cannot remove app '$($_.Name)' as it is flagged as non-removable by the system." -Warning -Prefix
				}
				elseif ($_.PackageUserInformation.ForEach({$_.ToString()}) -match 'Installed$')
				{
					$_
				}
			}
			Provisioned = Get-AppxProvisionedPackage -Online | Where-Object {$xml.Config.RemoveApps.App -contains $_.DisplayName} | ForEach-Object {
				if ($data.RemoveApps.MandatoryApps -contains $_.DisplayName)
				{
					Write-LogEntry -Message "Cannot deprovision app '$($_.DisplayName)' as it is considered mandatory." -Warning -Prefix
				}
				else
				{
					$_
				}
			}
		}
	}

	filter Remove-AppInstallation
	{
		# We deliberately don't use the `-AllUsers` parameter as it doesn't work.
		$_ | Remove-AppxPackage
		Write-LogEntry -Message "Removed AppX package '$($_.Name)' for all users."
	}

	filter Remove-AppProvisionment
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
			$apps.Installed | Remove-AppInstallation
			$apps.Provisioned | Remove-AppProvisionment
			Write-LogEntry -Message "Successfully processed RemoveApps list."
			Update-ExitCode -Value 3010
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
			"The following apps in RemoveApps require removing:$($apps.Installed.Name | ConvertTo-BulletedList)"
		}
		if ($apps.Provisioned)
		{
			"The following apps in RemoveApps require deprovisioning:$($apps.Provisioned.DisplayName | ConvertTo-BulletedList)"
		}
	}

	function Uninstall-RemoveApps
	{
		Write-LogEntry -Message "Reversal of RemoveApps configuration is not supported." -Warning -Prefix
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
		return [System.Boolean][System.UInt32]$xml.Config.SystemDriveLockdown.Enabled
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
		[System.Void](icacls.exe $env:SystemDrive\ /grant "*$($data.SystemDriveLockdown.SID):(OI)(CI)(IO)(M)" 2>&1)
		[System.Void](icacls.exe $env:SystemDrive\ /grant "*$($data.SystemDriveLockdown.SID):(AD)" 2>&1)
	}

	function Install-SystemDriveLockdown
	{
		# Advise commencement.
		Write-LogEntry -Message "Confirming SystemDriveLockdown state, please wait..."

		# Get state and repair if needed.
		if (Test-SystemDriveLockdownEnable)
		{
			[System.Void](icacls.exe $env:SystemDrive\ /remove:g *$($data.SystemDriveLockdown.SID) 2>&1)
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

	function Uninstall-SystemDriveLockdown
	{
		if (!((icacls.exe $env:SystemDrive\ 2>&1) -match 'NT AUTHORITY\\Authenticated Users:(\(AD\)|\(OI\)\(CI\)\(IO\)\(M\))$').Count.Equals(2))
		{
			Restore-SystemDriveLockdownDefaults
		}
		Write-LogEntry -Message "Successfully uninstalled SystemDriveLockdown tag file."
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
		$props = $data.SystemShortcuts.ShortcutProperties.$scext

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
		$xml.Config.SystemShortcuts.Shortcut | Convert-SystemShortcutsToComProperties | Where-Object {
			$shortcut = $wsShell.CreateShortcut($_.FullName)
			$_.PSObject.Properties.Where({$_.Value -ne $shortcut.($_.Name)})
		}
	}

	filter Sync-SystemShortcuts
	{
		# Update all properties and save out shortcut.
		$_.PSObject.Properties.Where({!$_.Name.Equals('FullName')}).ForEach({
			begin {
				$shortcut = $wsShell.CreateShortcut($_.FullName)
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

	function Uninstall-SystemShortcuts
	{
		# Uninstall each shortcut, ignoring errors as the shortcut might have already been removed.
		$xml.Config.SystemShortcuts.Shortcut | Get-SystemShortcutsFilePath | Remove-Item -Force -Confirm:$false -ErrorAction Ignore
		Write-LogEntry -Message "Successfully uninstalled all SystemShortcuts."
	}


	#---------------------------------------------------------------------------
	#
	# WindowsCapabilities.
	#
	#---------------------------------------------------------------------------

	function Get-WindowsCapabilitiesState
	{
		# Get current system capabilities and add/remove data.
		$capabilities = Get-WindowsCapability -Online
		$regexMatch = '^(Installed|InstallPending)$'
		$toInstall = $xml.Config.WindowsCapabilities.Capability | Where-Object {$_.Action.Equals('Add')} | Select-Object -ExpandProperty '#text'
		$toRemove = $xml.Config.WindowsCapabilities.Capability | Where-Object {$_.Action.Equals('Remove')} | Select-Object -ExpandProperty '#text'

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

	filter Add-ListedWindowsCapability
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
			$capabilities.Uninstalled | Add-ListedWindowsCapability
			Write-LogEntry -Message "Successfully processed WindowsCapabilities configuration."
			Update-ExitCode -Value 3010
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
			"The following Windows Capabilities require removing:$($capabilities.Installed.Name | ConvertTo-BulletedList)"
		}
		if ($capabilities.Uninstalled)
		{
			"The following Windows Capabilities require adding:$($capabilities.Uninstalled.Name | ConvertTo-BulletedList)"
		}
	}

	function Uninstall-WindowsCapabilities
	{
		Write-LogEntry -Message "Removal/reversal of WindowsCapabilities configuration is not supported." -Warning -Prefix
	}


	#---------------------------------------------------------------------------
	#
	# WindowsOptionalFeatures.
	#
	#---------------------------------------------------------------------------

	function Get-WindowsOptionalFeaturesState
	{
		# Get current system features and enable/disable data.
		$features = Get-WindowsOptionalFeature -Online
		$toEnable = $xml.Config.WindowsOptionalFeatures.Feature | Where-Object {$_.Action.Equals('Enable')} | Select-Object -ExpandProperty '#text'
		$toDisable = $xml.Config.WindowsOptionalFeatures.Feature | Where-Object {$_.Action.Equals('Disable')} | Select-Object -ExpandProperty '#text'

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
			Update-ExitCode -Value 3010
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

	function Uninstall-WindowsOptionalFeatures
	{
		Write-LogEntry -Message "Removal/reversal of WindowsOptionalFeatures configuration is not supported." -Warning -Prefix
	}
}

end
{
	#---------------------------------------------------------------------------
	#
	# Main code execution block.
	#
	#---------------------------------------------------------------------------

	try
	{
		# Open log file and commence operations.
		Open-LogFile -Cmdlet $PSCmdlet -Action $PSCmdlet.ParameterSetName -Discriminator $Discriminator
		if ($output = Invoke-DesiredStateOperations -Action $PSCmdlet.ParameterSetName) {throw $output}
	}
	catch
	{
		# Process the caught error message.
		$_ | Invoke-GlobalErrorHandler

		# Add an extra divider when throwing test results.
		if ($_.Exception.Message.Equals((Get-Variable -Name output -ValueOnly -ErrorAction Ignore)))
		{
			Write-LogDivider
			Write-LogEntry -Message "Please execute this script again with '-Install' to repair the reported state issues."
		}
	}
	finally
	{
		# Always ensure this is called to finalise the script.
		Close-LogFile
	}
}
