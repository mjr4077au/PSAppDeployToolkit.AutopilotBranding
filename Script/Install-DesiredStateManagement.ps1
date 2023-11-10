
<#PSScriptInfo

.VERSION 2.3

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
- Changed returns in `Test-DefaultStartLayoutValidity` to return 1 or higher on error, like other funcs.
- Clean up internals of `Get-OemInformationIncorrectChildNodes`.
- Removed needless quoting of variables passed to binary executables.
- Removed ignoring of `Get-Command` errors from `Get-DesiredStateOperations`.
- Optimised op generation loop within `Get-DesiredStateOperations`.
- Merge `Get-DesiredStateOperations` into `Invoke-DesiredStateOperations`.
- Repair hard-coded usage of `%DesiredStateContents%` in string.
- Added setup for `DefaultLayoutModification`, supporting Windows 10 and 11.
- Amend `Get-WindowsCapabilitiesState` to treat `InstallPending` as success.
- Consolidate `Write-Host` usage to `Write-LogEntry` cmdmet to quieten `Invoke-ScriptAnalyzer`.
- Remove unused `$transcribing` variable.
- Use `ConvertTo-BulletedList` everywhere.

#>

<#

.SYNOPSIS
Installs a preconfigured list of system defaults, validates them or removes them as required.

.DESCRIPTION
Inspired by Michael Niehaus' "AutopilotBranding" toolkit, this script is specifically designed to be used to install a set of system baseline defaults for workstations, extending from languages, removal of built-in apps/features, user defaults via Active Setup, and more.

An example setup via an XML configuration file would be:

<Config Version="1.0">
	<Content>
		<Source>https://www.mysite.com.au/intune/desiredstate/content.zip</Source>
		<Destination>%ProgramData%\DesiredStateManagement\Content</Destination>
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
		<LayoutModification Windows="10">LayoutModification.xml</LayoutModification>
		<LayoutModification Windows="11">LayoutModification.json</LayoutModification>
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
	<RegistryData>
		<Item Description="Disable Fast Startup">
			<Key>HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Power</Key>
			<Name>HiberbootEnabled</Name>
			<Value>0</Value>
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

.EXAMPLE
powershell.exe -ExecutionPolicy Bypass -NoProfile -NoLogo -NonInteractive -File Install-DesiredStateManagement.ps1

.EXAMPLE
powershell.exe -ExecutionPolicy Bypass -NoProfile -NoLogo -NonInteractive -File Install-DesiredStateManagement.ps1 -Install

.EXAMPLE
powershell.exe -ExecutionPolicy Bypass -NoProfile -NoLogo -NonInteractive -File Install-DesiredStateManagement.ps1 -Remove

.INPUTS
None. You cannot pipe objects to Install-DesiredStateManagement.ps1.

.OUTPUTS
stdout stream. Install-DesiredStateManagement.ps1 returns a log string via Write-Host that can be piped.
stderr stream. Install-DesiredStateManagement.ps1 writes all error text to stderr for catching externally to PowerShell if required.

.NOTES
*Changelog*

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

[CmdletBinding(DefaultParameterSetName = 'Confirm')]
Param (
	[Parameter(Mandatory = $true, ParameterSetName = 'Install')]
	[System.Management.Automation.SwitchParameter]$Install,

	[Parameter(Mandatory = $true, ParameterSetName = 'Remove')]
	[System.Management.Automation.SwitchParameter]$Remove
)

# Set required variables to ensure script functionality.
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
Set-PSDebug -Strict
Set-StrictMode -Version Latest

# Define script properties.
$script = @{
	Name = 'Install-DesiredStateManagement.ps1'  # Hard-coded as using script as detection script will mangle the filename.
	Info = Test-ScriptFileInfo -LiteralPath $MyInvocation.MyCommand.Source
	Config = 'https://intunendesuser-themitchcorporation.msappproxy.net/intune/desiredstate/config.xml'
	LogDiscriminator = [System.String]::Empty
	Action = $PSCmdlet.ParameterSetName
	Divider = ([System.Char]0x2014).ToString() * 79
	StartDate = [System.DateTime]::Now
	ExitCode = 0
}

# Store XML schema.
$schema = @'
<?xml version="1.0" encoding="utf-8"?>
<xs:schema attributeFormDefault="qualified" elementFormDefault="qualified" xmlns:xs="http://www.w3.org/2001/XMLSchema">
	<!--The base for LayoutModification is defined here because we can't restrict an element and attribute simultaneously in an XML schema-->
	<xs:simpleType name="lmBase">
		<xs:restriction base="xs:string">
			<xs:pattern value="^[^\s:\\]+\.(xml|json)$"/>
		</xs:restriction>
	</xs:simpleType>
	<xs:element name="Config">
		<xs:complexType>
			<xs:all>
				<xs:element name="Content" minOccurs="0">
					<xs:complexType>
						<xs:all>
							<xs:element name="Source">
								<xs:simpleType>
									<xs:restriction base="xs:string">
										<xs:pattern value="^https:\/\/.+\.zip$"/>
									</xs:restriction>
								</xs:simpleType>
							</xs:element>
							<xs:element name="Destination">
								<xs:simpleType>
									<xs:restriction base="xs:string">
										<xs:pattern value="^([A-Z]:|%[^%]+%)\\.+$"/>
									</xs:restriction>
								</xs:simpleType>
							</xs:element>
							<xs:element name="EnvironmentVariable">
								<xs:simpleType>
									<xs:restriction base="xs:string">
										<xs:pattern value="^(?=\S).*[^.\s]$"/>
									</xs:restriction>
								</xs:simpleType>
							</xs:element>
						</xs:all>
					</xs:complexType>
				</xs:element>
				<xs:element name="RegistrationInfo" minOccurs="0">
					<xs:complexType>
						<xs:all>
							<xs:element name="RegisteredOwner">
								<xs:simpleType>
									<xs:restriction base="xs:string">
										<xs:pattern value="^(?=\S).*[^.\s]$"/>
									</xs:restriction>
								</xs:simpleType>
							</xs:element>
							<xs:element name="RegisteredOrganization">
								<xs:simpleType>
									<xs:restriction base="xs:string">
										<xs:pattern value="^(?=\S).*[^.\s]$"/>
									</xs:restriction>
								</xs:simpleType>
							</xs:element>
						</xs:all>
					</xs:complexType>
				</xs:element>
				<xs:element name="OemInformation" minOccurs="0">
					<xs:complexType>
						<xs:all>
							<xs:element name="Manufacturer">
								<xs:simpleType>
									<xs:restriction base="xs:string">
										<xs:pattern value="^(?=\S).*[^.\s]$"/>
									</xs:restriction>
								</xs:simpleType>
							</xs:element>
							<xs:element name="Logo">
								<xs:simpleType>
									<xs:restriction base="xs:string">
										<xs:pattern value="^[^\s:\\]+\.bmp$"/>
									</xs:restriction>
								</xs:simpleType>
							</xs:element>
							<xs:element name="SupportPhone">
								<xs:simpleType>
									<xs:restriction base="xs:string">
										<xs:pattern value="^(?=\S).*[^.\s]$"/>
									</xs:restriction>
								</xs:simpleType>
							</xs:element>
							<xs:element name="SupportHours">
								<xs:simpleType>
									<xs:restriction base="xs:string">
										<xs:pattern value="^(?=\S).*[^.\s]$"/>
									</xs:restriction>
								</xs:simpleType>
							</xs:element>
							<xs:element name="SupportURL">
								<xs:simpleType>
									<xs:restriction base="xs:string">
										<xs:pattern value="^https?:\/\/.+[^\s]+$"/>
									</xs:restriction>
								</xs:simpleType>
							</xs:element>
						</xs:all>
					</xs:complexType>
				</xs:element>
				<xs:element name="SystemDriveLockdown" minOccurs="0">
					<xs:complexType>
						<xs:attribute name="Enabled" type="xs:nonNegativeInteger" use="required" />
					</xs:complexType>
				</xs:element>
				<xs:element name="DefaultStartLayout" minOccurs="0">
					<xs:simpleType>
						<xs:restriction base="xs:string">
							<xs:pattern value="^[^\s:\\]+\.xml$"/>
						</xs:restriction>
					</xs:simpleType>
				</xs:element>
				<xs:element name="DefaultLayoutModification" minOccurs="0">
					<xs:complexType>
						<xs:sequence>
							<xs:element maxOccurs="unbounded" name="LayoutModification">
								<xs:complexType>
									<xs:simpleContent>
										<xs:extension base="lmBase">
											<xs:attribute name="Windows">
												<xs:simpleType>
													<xs:restriction base="xs:integer">
														<xs:minInclusive value="10"/>
														<xs:maxInclusive value="11"/>
													</xs:restriction>
												</xs:simpleType>
											</xs:attribute>
										</xs:extension>
									</xs:simpleContent>
								</xs:complexType>
							</xs:element>
						</xs:sequence>
					</xs:complexType>
				</xs:element>
				<xs:element name="DefaultAppAssociations" minOccurs="0">
					<xs:simpleType>
						<xs:restriction base="xs:string">
							<xs:pattern value="^[^\s:\\]+\.xml$"/>
						</xs:restriction>
					</xs:simpleType>
				</xs:element>
				<xs:element name="LanguageDefaults" minOccurs="0">
					<xs:simpleType>
						<xs:restriction base="xs:string">
							<xs:pattern value="^[^\s:\\]+\.xml$"/>
						</xs:restriction>
					</xs:simpleType>
				</xs:element>
				<xs:element name="DefaultTheme" minOccurs="0">
					<xs:simpleType>
						<xs:restriction base="xs:string">
							<xs:pattern value="^[^\s:\\]+\.theme$"/>
						</xs:restriction>
					</xs:simpleType>
				</xs:element>
				<xs:element name="ActiveSetup" minOccurs="0">
					<xs:complexType>
						<xs:sequence>
							<xs:element maxOccurs="unbounded" name="Component">
								<xs:complexType>
									<xs:all>
										<xs:element name="Name">
											<xs:simpleType>
												<xs:restriction base="xs:string">
													<xs:pattern value="^(?=\S).*[^.\s]$"/>
												</xs:restriction>
											</xs:simpleType>
										</xs:element>
										<xs:element name="StubPath">
											<xs:simpleType>
												<xs:restriction base="xs:string">
													<xs:pattern value="^(?=\S).*[^.\s]$"/>
												</xs:restriction>
											</xs:simpleType>
										</xs:element>
									</xs:all>
									<xs:attribute name="Version" type="xs:positiveInteger" use="required" />
								</xs:complexType>
							</xs:element>
						</xs:sequence>
						<xs:attribute name="Identifier" type="xs:string" use="required" />
					</xs:complexType>
				</xs:element>
				<xs:element name="RegistryData" minOccurs="0">
					<xs:complexType>
						<xs:sequence>
							<xs:element maxOccurs="unbounded" name="Item">
								<xs:complexType>
									<xs:all>
										<xs:element name="Key">
											<xs:simpleType>
												<xs:restriction base="xs:string">
													<xs:pattern value="^HK(LM|CU|CR|U|CC).*[^.\s]$"/>
												</xs:restriction>
											</xs:simpleType>
										</xs:element>
										<xs:element name="Name">
											<xs:simpleType>
												<xs:restriction base="xs:string">
													<xs:pattern value="^(?=\S).*[^.\s]$"/>
												</xs:restriction>
											</xs:simpleType>
										</xs:element>
										<xs:element name="Value">
											<xs:simpleType>
												<xs:restriction base="xs:string">
													<xs:pattern value="^(?=\S).*[^.\s]$"/>
												</xs:restriction>
											</xs:simpleType>
										</xs:element>
										<xs:element name="Type">
											<xs:simpleType>
												<xs:restriction base="xs:string">
													<xs:pattern value="^REG_(SZ|MULTI_SZ|EXPAND_SZ|DWORD|BINARY)$"/>
												</xs:restriction>
											</xs:simpleType>
										</xs:element>
									</xs:all>
									<xs:attribute name="Description" type="xs:string" use="required" />
								</xs:complexType>
							</xs:element>
						</xs:sequence>
					</xs:complexType>
				</xs:element>
				<xs:element name="RemoveApps" minOccurs="0">
					<xs:complexType>
						<xs:sequence>
							<xs:element maxOccurs="unbounded" name="App">
								<xs:simpleType>
									<xs:restriction base="xs:string">
										<xs:pattern value="^(?=\S).*[^.\s]$"/>
									</xs:restriction>
								</xs:simpleType>
							</xs:element>
						</xs:sequence>
					</xs:complexType>
				</xs:element>
				<xs:element name="WindowsCapabilities" minOccurs="0">
					<xs:complexType>
						<xs:sequence>
							<xs:element maxOccurs="unbounded" name="Capability">
								<xs:complexType>
									<xs:simpleContent>
										<xs:extension base="xs:string">
											<xs:attribute name="Action" use="required">
												<xs:simpleType>
													<xs:restriction base="xs:string">
														<xs:pattern value="^(Install|Remove)$"/>
													</xs:restriction>
												</xs:simpleType>
											</xs:attribute>
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
							<xs:element maxOccurs="unbounded" name="Feature">
								<xs:complexType>
									<xs:simpleContent>
										<xs:extension base="xs:string">
											<xs:attribute name="Action" use="required">
												<xs:simpleType>
													<xs:restriction base="xs:string">
														<xs:pattern value="^(Disable|Enable)$"/>
													</xs:restriction>
												</xs:simpleType>
											</xs:attribute>
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

filter Out-FriendlyErrorMessage ([ValidateNotNullOrEmpty()][System.String]$ErrorPrefix)
{
	# Set up initial vars. We do some determination for the best/right stacktrace line.
	$ePrefix = $(if ($ErrorPrefix) {"$ErrorPrefix`n"} else {'ERROR: '})
	$command = $_.InvocationInfo.MyCommand | Select-Object -ExpandProperty Name
	$stArray = $_.ScriptStackTrace.Split("`n")
	$staLine = $stArray[$(if (!$stArray[0].Contains('<No file>')) {0} else {1})]

	# Get variables from stack trace line, as well as called command if available.
	if (![System.String]::IsNullOrWhiteSpace($staLine))
	{
		$function, $path, $file, $line = [System.Text.RegularExpressions.Regex]::Match($staLine, '^at\s(.+),\s(.+)\\(.+):\sline\s(\d+)').Groups.Value[1..4]
		$cmdlet = $command | Where-Object {!$function.Equals($_)}
		return "$($ePrefix)Line #$line`: $function`: $(if ($cmdlet) {"$cmdlet`: "})$($_.Exception.Message)"
	}
	elseif ($command)
	{
		return "$($ePrefix)Line #$($_.InvocationInfo.ScriptLineNumber): $command`: $($_.Exception.Message)"
	}
	else
	{
		return "$($ePrefix.Replace("`n",": "))$($_.Exception.Message)"
	}
}

function Get-DefaultUserProfilePath
{
	return (Get-ItemProperty -LiteralPath "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList").Default
}

function Get-DefaultUserLocalAppDataPath
{
	$path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{F1B32785-6FBA-4FCF-9D55-7B8E7F157091}"
	return "$(Get-DefaultUserProfilePath)\$((Get-ItemProperty -LiteralPath $path).RelativePath)"
}

filter Get-RegistryDataItemValue
{
	# This is designed to take an incoming System.Xml.XmlElement object.
	$pattern = "^\s{4}$([System.Text.RegularExpressions.Regex]::Escape($_.Name))\s{4}$([System.Text.RegularExpressions.Regex]::Escape($_.Type))\s{4}"
	return $(try {$((reg.exe QUERY $_.Key /v $_.Name /t $_.Type 2>&1) -match $pattern) -replace $pattern} catch {})
}

filter Install-RegistryDataItem
{
	[System.Void](reg.exe ADD $_.Key /v $_.Name /t $_.Type /d $_.Value /f 2>&1)
	Write-LogEntry -Message "Installed registry value '$($_.Key)\$($_.Name)'."
}

filter Remove-RegistryDataItem
{
	# Remove item.
	[System.Void](reg.exe DELETE ($key = $_.Key) /v $_.Name /f 2>&1)

	# Remove key and any parents if there's no objects left within it.
	while ([System.String]::IsNullOrWhiteSpace($(try {reg.exe QUERY $key 2>&1} catch {$_.Exception.Message})))
	{
		[System.Void](reg.exe DELETE $key /f 2>&1)
		$key = $key -replace '\\[^\\]+$'
	}
}

function Invoke-DefaultUserRegistryAction
{
	begin {
		# Mount default user hive under random key.
		[System.Void](reg.exe LOAD HKLM\TempUser "$(Get-DefaultUserProfilePath)\NTUSER.DAT" 2>&1)
	}

	process {
		# Invoke scriptblock.
		& $_
	}

	end {
		# Unmount hive.
		[System.Void](reg.exe UNLOAD HKLM\TempUser 2>&1)
	}
}

filter Get-ItemPropertyUnexpanded
{
	# Open hashtable to hold data.
	$data = @{}

	# Get data from incoming RegistryKey.
	foreach ($property in $_.Property.Where({!$_.Equals('(default)')}))
	{
		$data.Add($property, $_.GetValue($property, $null, 'DoNotExpandEnvironmentNames'))
	}

	# Return pscustomobject to the pipeline if we have data.
	if ($data.GetEnumerator().Where({$_.Value}))
	{
		return [pscustomobject]$data
	}
}

filter Get-ContentFilePath
{
	# Confirm we have a 'Content' element specified.
	if ($script.Config.ChildNodes.LocalName -notcontains 'Content')
	{
		throw "This element requires that 'Content' be configured to supply the required data."
	}

	# Test that the file is available and return path if it does.
	if ($script.ModuleData.Content.ContainsKey('Destination') -and [System.IO.File]::Exists(($filepath = "$($script.ModuleData.Content.Destination)\$_")))
	{
		return $filepath
	}
	elseif ([System.IO.File]::Exists(($filepath = "$($script.ModuleData.Content.TemporaryDir)\$_")))
	{
		return $filepath
	}
	else
	{
		throw "The specified file '$_' was not available in hosted data source '$($script.Config.Content.Source)'."
	}
}

function ConvertTo-BulletedList
{
	return "$($input -replace '^',"`n - ")"
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
	$logDisc = $(if ($script.LogDiscriminator) {"_$($script.LogDiscriminator)"})
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
	Stop-Transcript | Out-Null
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
			Destinations = @{
				'10' = "$basedir\LayoutModification.xml"
				'11' = "$basedir\LayoutModification.json"
			}
		}
		DefaultTheme = @{
			Key = 'HKLM\TempUser\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes'
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
	}
}

function Import-DesiredStateConfig
{
	# Create error handler.
	$err = {throw $args[1].Exception.Message}

	# Get XML file and validate against our schema.
	$xml = [System.Xml.XmlDocument]::new()
	$xml.Schemas.Add([System.Xml.Schema.XmlSchema]::Read([System.Xml.XmlReader]::Create([System.IO.StringReader]::new($schema)), $err)) | Out-Null
	$xml.Load([System.Xml.XmlReader]::Create($script.Config))
	$xml.Validate($err)
	$script.Config = $xml.Config
}

function Invoke-DesiredStateOperations
{
	# Dynamically generate scriptblocks based on the XML config and this script's available supporting functions.
	$div = $(if ($script.Action.Equals('Install')) {"; Write-LogEntry -Message '$($script.Divider)'"})
	$ops = $script.Config.ChildNodes.LocalName | ForEach-Object {
		if ($cmdlet = Get-Command -Name "$($script.Action)-$_") {
			[System.Management.Automation.ScriptBlock]::Create("$cmdlet$div")
		}
	}

	# Execute piped in scriptblocks with ForEach-Object and process collected results.
	# Only confirm/validation mode will return string literals.
	if ($results = ForEach-Object -Process $ops)
	{
		Write-LogEntry -Message "$($script.Divider)`n$($results -join "`n")`n$($script.Divider)"
		Write-LogEntry -Message "Please review transcription log and try again."
		$script.ExitCode = 1618
	}
	else
	{
		if (!$script.Action.Equals('Install')) {Write-LogEntry -Message $script.Divider}
		Write-LogEntry -Message "Successfully $($script.Action.ToLower().TrimEnd('e'))ed desired state management."
		if (!$script.Action.Equals('Confirm')) {$script.ExitCode = 3010}
	}
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
			(Compare-Object -ReferenceObject $_ -DifferenceObject $dest -Property $dest.PSObject.Properties.Name)
		}
	}
}

filter Install-ActiveSetupComponent ([ValidateSet('Install','Update')][System.String]$Action)
{
	# Set up component's key and associated properties.
	$name = $_.Name | Out-ActiveSetupComponentName
	$rkey = (New-Item -Path $script.ModuleData.ActiveSetup.RegistryBase -Name $name -Value $name -Force).PSPath

	# Create item properties.
	New-ItemProperty -LiteralPath $rkey -Name Version -Value $_.Version -PropertyType String -Force | Out-Null
	New-ItemProperty -LiteralPath $rkey -Name StubPath -Value $_.StubPath -PropertyType ExpandString -Force | Out-Null

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
		# Download content file. If we can't get it, we can't proceed with anything.
		Invoke-WebRequest -UseBasicParsing -Uri $script.Config.Content.Source -OutFile $script.ModuleData.Content.DownloadFile

		# Extract contents to temp location. Do this first so the data is available for other modules.
		Expand-Archive -LiteralPath $script.ModuleData.Content.DownloadFile -DestinationPath $script.ModuleData.Content.TemporaryDir -Force

		# Set the destination path based off the incoming content. Do this via the registry in-case we're re-running in the same session.
		$script.ModuleData.Content.Destination = Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' |
			Select-Object -ExpandProperty $script.Config.Content.EnvironmentVariable -ErrorAction Ignore
	}
	catch
	{
		Write-Warning "Unable to confirm Content state. $($_.Exception.Message)"
		return 1
	}
}

function Test-ContentValidity
{
	# Test we have an environment variable first.
	if (!$script.ModuleData.Content.Destination)
	{
		return 1
	}

	# Get hashes from each location, and exit with 2 if the comparison fails.
	$coParams = @{
		ReferenceObject = Get-ChildItem -LiteralPath $script.ModuleData.Content.TemporaryDir -Recurse | Get-FileHash
		DifferenceObject = Get-ChildItem -LiteralPath $script.ModuleData.Content.Destination -Recurse | Get-FileHash
		Property = 'Hash'
	}
	return 2 * !!(Compare-Object @coParams)
}

function Install-Content
{
	# Do pre-ops and return if there was an error.
	if (Invoke-ContentPreOps)
	{
		return
	}

	# Get state and repair if needed.
	if (Test-ContentValidity)
	{
		# Expand out incoming destination string.
		$destination = [System.Environment]::ExpandEnvironmentVariables($script.Config.Content.Destination)

		# Mirror our extracted folder with our destination using Robocopy.
		robocopy.exe $script.ModuleData.Content.TemporaryDir $destination /MIR /FP 2>&1 | ForEach-Object {
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
		if ($LASTEXITCODE -ge 8)
		{
			throw "Transfer of Content via robocopy.exe failed with exit code $LASTEXITCODE."
		}

		# Install environment variable if it does not exist.
		if (!$script.ModuleData.Content.Destination)
		{
			[System.Environment]::SetEnvironmentVariable($script.Config.Content.EnvironmentVariable, $destination, 'Machine')
			$script.ModuleData.Content.Destination = $destination
		}
		Write-LogEntry -Message "Successfully installed Content components."
	}
	else
	{
		Write-LogEntry -Message "Successfully confirmed all Content components are correctly deployed."
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
	if (Test-ContentValidity)
	{
		"The following Content components require installing or amending:$('Environment variable', 'File data' | ConvertTo-BulletedList)"
	}
}

function Remove-Content
{
	# Delete the contents folder.
	if ([System.IO.Directory]::Exists(($path = [System.Environment]::ExpandEnvironmentVariables($script.Config.Content.Destination))))
	{
		[System.IO.Directory]::Delete($path, $true)
	}

	# Delete folders above so long as they're empty.
	while ([System.IO.Directory]::Exists(($path += "\..")) -and !(Get-ChildItem -LiteralPath $path))
	{
		[System.IO.Directory]::Delete($path, $true)
	}

	# Remove environment variable.
	[System.Environment]::SetEnvironmentVariable($script.Config.Content.EnvironmentVariable, [System.String]::Empty, 'Machine')
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
		# Get file path from our cache.
		$script.ModuleData.DefaultAppAssociations.Source = $script.Config.DefaultAppAssociations | Get-ContentFilePath

		# Store hash for the file in our client-side cache.
		$script.ModuleData.DefaultAppAssociations.FileHash = Get-FileHash -LiteralPath $script.ModuleData.DefaultAppAssociations.Source -ErrorAction Ignore |
			Select-Object -ExpandProperty Hash
	}
	catch
	{
		Write-Warning "Unable to confirm DefaultAppAssociations state. $($_.Exception.Message)"
		return 1
	}
}

function Test-DefaultAppAssociationsApplicability
{
	return ![System.IO.File]::Exists($script.ModuleData.DefaultAppAssociations.TagFile) -or
		!$script.ModuleData.DefaultAppAssociations.FileHash -or
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

	# Do basic sanity checks.
	try
	{
		# Get file path from our cache.
		$script.ModuleData.DefaultStartLayout.Source = $script.Config.DefaultStartLayout | Get-ContentFilePath
	}
	catch
	{
		Write-Warning "Unable to confirm DefaultStartLayout state. $($_.Exception.Message)"
		return 1
	}
}

function Test-DefaultStartLayoutValidity
{
	# Alias our source/dest as the lines are too long.
	$src = $script.ModuleData.DefaultStartLayout.Source
	$dst = $script.ModuleData.DefaultStartLayout.Destination

	# Confirm whether start layout is valid by testing whether src/dest hash match.
	return ![System.IO.File]::Exists($src) -or ![System.IO.File]::Exists($dst) -or
		((Get-FileHash -LiteralPath $src,$dst | Select-Object -ExpandProperty Hash -Unique) -isnot [System.String])
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

	# Do basic sanity checks.
	try
	{
		# Get the operating system version and store it for getting the right element.
		$osVersion = (Get-CimInstance -ClassName Win32_OperatingSystem).Version.Split('.')[0]

		# Get file path from our cache.
		$script.ModuleData.DefaultLayoutModification.Source = $script.Config.DefaultLayoutModification.LayoutModification |
			Where-Object {$_.Windows.Equals($osVersion)} | Select-Object -ExpandProperty '#text' | Get-ContentFilePath

		# Set up destination based on version.
		$script.ModuleData.DefaultLayoutModification.Destination = $script.ModuleData.DefaultLayoutModification.Destinations.$osVersion

		# Confirm extension is correct for operating system (too complex to do in the XML schema).
		$srcext = [System.IO.Path]::GetExtension($script.ModuleData.DefaultLayoutModification.Source)
		$dstext = [System.IO.Path]::GetExtension($script.ModuleData.DefaultLayoutModification.Destination)
		if (!$srcext.Equals($dstext))
		{
			throw "The extension for '$($script.ModuleData.DefaultLayoutModification.Source)' is not correct for this operating system."
		}
	}
	catch
	{
		Write-Warning "Unable to confirm DefaultLayoutModification state. $($_.Exception.Message)"
		return 1
	}
}

function Test-DefaultLayoutModificationValidity
{
	# Alias our source/dest as the lines are too long.
	$src = $script.ModuleData.DefaultLayoutModification.Source
	$dst = $script.ModuleData.DefaultLayoutModification.Destination

	# Confirm whether start layout is valid by testing whether src/dest hash match.
	return ![System.IO.File]::Exists($src) -or ![System.IO.File]::Exists($dst) -or
		((Get-FileHash -LiteralPath $src,$dst | Select-Object -ExpandProperty Hash -Unique) -isnot [System.String])
}

function Install-DefaultLayoutModification
{
	# Do pre-ops and return if there was an error.
	if (Invoke-DefaultLayoutModificationPreOps)
	{
		return
	}

	# Get state and repair if needed.
	if (Test-DefaultLayoutModificationValidity)
	{
		Copy-Item -LiteralPath $script.ModuleData.DefaultLayoutModification.Source -Destination $script.ModuleData.DefaultLayoutModification.Destination -Force | Out-Null
		Write-LogEntry -Message "Successfully installed DefaultLayoutModification file."
	}
	else
	{
		Write-LogEntry -Message "Successfully confirmed DefaultLayoutModification configuration is correctly deployed."
	}
}

function Confirm-DefaultLayoutModification
{
	# Do pre-ops and return if there was an error.
	if (Invoke-DefaultLayoutModificationPreOps)
	{
		return
	}

	# Output incorrect results, if any.
	if (Test-DefaultLayoutModificationValidity)
	{
		"The following DefaultLayoutModification components require installing or amending:$('File' | ConvertTo-BulletedList)"
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
		# Get file path from our cache.
		$script.Config.DefaultTheme | Get-ContentFilePath | Out-Null

		# Set value to apply in registry.
		$script.ModuleData.DefaultTheme.Value = "$($script.ModuleData.Content.Destination)\$($script.Config.DefaultTheme)"
	}
	catch
	{
		Write-Warning "Unable to confirm DefaultTheme state. $($_.Exception.Message)"
		return 1
	}
}

function Get-IncorrectDefaultTheme
{
	# Return results.
	return {!$script.ModuleData.DefaultTheme.Value.Equals(($script.ModuleData.DefaultTheme | Get-RegistryDataItemValue))} | Invoke-DefaultUserRegistryAction
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
		{$script.ModuleData.DefaultTheme | Install-RegistryDataItem} | Invoke-DefaultUserRegistryAction | Out-Null
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
	{$script.ModuleData.DefaultTheme | Where-Object {$_ | Get-RegistryDataItemValue} | Remove-RegistryDataItem} | Invoke-DefaultUserRegistryAction | Out-Null
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
		# Get file path from our cache.
		$script.ModuleData.LanguageDefaults.Source = $script.Config.LanguageDefaults | Get-ContentFilePath

		# Store hash for the file in our client-side cache.
		$script.ModuleData.LanguageDefaults.FileHash = Get-FileHash -LiteralPath $script.ModuleData.LanguageDefaults.Source -ErrorAction Ignore |
			Select-Object -ExpandProperty Hash
	}
	catch
	{
		Write-Warning "Unable to confirm LanguageDefaults state. $($_.Exception.Message)"
		return 1
	}
}

function Test-LanguageDefaultsApplicability
{
	return ![System.IO.File]::Exists($script.ModuleData.LanguageDefaults.TagFile) -or
		!$script.ModuleData.LanguageDefaults.FileHash -or
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
		Write-Warning "Unable to confirm OemInformation state. $($_.Exception.Message)"
		return 1
	}
}

function Get-OemInformationIncorrectChildNodes
{
	# Get all properties from the registry.
	$itemprops = Get-ItemProperty -LiteralPath ($regbase = $script.ModuleData.OemInformation.RegistryBase) -ErrorAction Ignore

	# Return test results.
	return ($script.Config.OemInformation.ChildNodes.LocalName + 'Model').ForEach({
		# Get calculated value from script's storage if present, otherwise use XML provided source.
		$value = $(if ($script.ModuleData.OemInformation.ContainsKey($_)) {$script.ModuleData.OemInformation.$_} else {$script.Config.OemInformation.$_})

		# Output objects for the properties that need correction.
		if (!$itemprops -or !$value.Equals(($itemprops | Select-Object -ExpandProperty $_ -ErrorAction Ignore)))
		{
			[pscustomobject]@{Key = $regbase.Replace(':', $null); Name = $_; Value = $value; Type = 'REG_SZ'}
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
	if ($incorrect = Get-OemInformationIncorrectChildNodes)
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
	if ($incorrect = Get-OemInformationIncorrectChildNodes)
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
	return $script.Config.RegistryData.Item | Where-Object {!$_.Value.Equals(($_ | Get-RegistryDataItemValue))}
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
	$script.Config.RegistryData.Item | Where-Object {$_ | Get-RegistryDataItemValue} | Remove-RegistryDataItem
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
		Installed = Get-AppxPackage -AllUsers | Where-Object {
			($script.ModuleData.RemoveApps.MandatoryApps -notcontains $_.Name) -and
			($script.Config.RemoveApps.App -contains $_.Name) -and
			($_.PackageUserInformation.InstallState -contains 'Installed')
		}
		Provisioned = Get-AppxProvisionedPackage -Online | Where-Object {
			($script.ModuleData.RemoveApps.MandatoryApps -notcontains $_.DisplayName) -and
			($script.Config.RemoveApps.App -contains $_.DisplayName)
		}
	}
}

filter Remove-RemoveAppInstallation
{
	# Remove app for each user that currently has it installed.
	if ($users = $_.PackageUserInformation | Where-Object {$_.InstallState.Equals('Installed')})
	{
		foreach ($user in $users.UserSecurityId)
		{
			$_ | Remove-AppxPackage -User $user.Sid
			Write-LogEntry -Message "Removed installed AppX package '$($_.Name)' for user '$($user.Username)'."
		}
	}
}

filter Remove-RemoveAppProvisionment
{
	$_ | Remove-AppxProvisionedPackage -AllUsers -Online | Out-Null
	Write-LogEntry -Message "Removed provisioned AppX package '$($_.DisplayName)'."
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
		Write-LogEntry -Message "Successfully processed RemoveApps configuration items."
	}
	else
	{
		Write-LogEntry -Message "Successfully confirmed all RemoveApps items are not installed."
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
	Write-Warning "Removal/reversal of RemoveApps configuration is not supported."
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
	Write-LogEntry -Message "Removed installed Windows Capability '$($_.Name)'."
}

filter Install-ListedWindowsCapability
{
	$_ | Add-WindowsCapability -Online | Out-Null
	Write-LogEntry -Message "Installed missing Windows Capability '$($_.Name)'."
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
	Write-Warning "Removal/reversal of WindowsCapabilities configuration is not supported."
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
	Write-LogEntry -Message "Disabled enabled Windows Optional Feature '$($_.FeatureName)'."
}

filter Enable-ListedWindowsOptionalFeature
{
	$_ | Enable-WindowsOptionalFeature -Online -NoRestart -WarningAction Ignore | Out-Null
	Write-LogEntry -Message "Enabled disabled Windows Optional Feature '$($_.FeatureName)'."
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
	Write-Warning "Removal/reversal of WindowsOptionalFeatures configuration is not supported."
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
	$_ | Out-FriendlyErrorMessage | Write-StdErrMessage
	Write-LogEntry -Message "Previously commenced operation did not complete successfully."
	Write-LogEntry -Message "$($script.Divider)`nPlease review transcription log and try again."
	$script.ExitCode = 1603
}
finally
{
	Close-Log
	exit $script.ExitCode
}
