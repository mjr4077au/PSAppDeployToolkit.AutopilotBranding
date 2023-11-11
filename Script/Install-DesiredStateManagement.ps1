
<#PSScriptInfo

.VERSION 2.2

.GUID dd1fb415-b54e-4773-938c-5c575c335bbd

.AUTHOR Mitch Richters

.COPYRIGHT Copyright © 2022 Mitchell James Richters. All rights reserved.

.TAGS

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
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
	Name = 'Install-DesiredStateManagement'  # Hard-coded as using script as detection script will mangle the filename.
	Version = '1.2'
	Config = 'https://intunendesuser-themitchcorporation.msappproxy.net/intune/desiredstate/config.xml'
	LogSuffix = ''
	Action = $PSCmdlet.ParameterSetName
	Divider = ([System.Char]0x2014).ToString() * 79
	StartDate = Get-Date
	ExitCode = 0
}

# Store XML schema.
$schema = @'
<?xml version="1.0" encoding="utf-8"?>
<xs:schema attributeFormDefault="qualified" elementFormDefault="qualified" xmlns:xs="http://www.w3.org/2001/XMLSchema">
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
									<xs:attribute name="Description" type="xs:string" use="optional" />
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
	if ($Host.Name.Equals('ConsoleHost')) {
		# Colour appropriately and directly write to stderr.
		[System.Console]::BackgroundColor = [System.ConsoleColor]::Black
		[System.Console]::ForegroundColor = [System.ConsoleColor]::Red
		[System.Console]::Error.WriteLine($_)
		[System.Console]::ResetColor()
	}
	else {
		# Use the Host's UI while in ISE.
		$Host.UI.WriteErrorLine($_)
	}
}

filter Out-FriendlyErrorMessage ([System.String]$ErrorPrefix)
{
	# Get command and store.
	$command = $_.InvocationInfo.MyCommand | Select-Object -ExpandProperty Name
	$logprefix = $(if ($ErrorPrefix) {"$ErrorPrefix`n"} else {'ERROR: '})

	# Process stack trace and pre-parse.
	$splitstack = $_.ScriptStackTrace -split "`n"
	$errorstack = $splitstack[$(if (!$splitstack[0].Contains('<No file>')) {0} elseif ($splitstack[1].Contains('Invoke-PipelineOperationBeta')) {2} else {1})]

	# Get variables from 1st line in the stack trace, as well as called command if available.
	if (![System.String]::IsNullOrWhiteSpace($errorstack)) {
		$function, $path, $file, $line = [System.Text.RegularExpressions.Regex]::Match($errorstack, '^at\s(.+),\s(.+)\\(.+):\sline\s(\d+)').Groups.Value[1..4]
		$cmdlet = $command | Where-Object {!$function.Equals($_)}
		return "$($logprefix)Line #$line`: $function`: $(if ($cmdlet) {"$cmdlet`: "})$($_.Exception.Message)"
	}
	elseif ($command) {
		return "$($logprefix)Line #$($_.InvocationInfo.ScriptLineNumber): $command`: $($_.Exception.Message)"
	}
	else {
		return "$($logprefix.Replace("`n",": "))$($_.Exception.Message)"
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
	return $(try {$((reg.exe QUERY "$($_.Key)" /v "$($_.Name)" /t "$($_.Type)" 2>&1) -match $pattern) -replace $pattern} catch {})
}

filter Install-RegistryDataItem
{
	[System.Void](reg.exe ADD "$($_.Key)" /v "$($_.Name)" /t "$($_.Type)" /d "$($_.Value)" /f 2>&1)
	Write-Host "Installed registry value '$($_.Key)\$($_.Name)'."
}

filter Remove-RegistryDataItem
{
	# Remove item.
	[System.Void](reg.exe DELETE "$(($key = $_.Key))" /v "$($_.Name)" /f 2>&1)

	# Remove key and any parents if there's no objects left within it.
	while ([System.String]::IsNullOrWhiteSpace($(try {reg.exe QUERY "$key" 2>&1} catch {$_.Exception.Message}))) {
		[System.Void](reg.exe DELETE "$key" /f 2>&1)
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
	foreach ($property in $_.Property.Where({!$_.Equals('(default)')})) {
		$data.$property = $_.GetValue($property, $null, 'DoNotExpandEnvironmentNames')
	}

	# Return pscustomobject to the pipeline if we have data.
	if ($data.GetEnumerator().Where({$_.Value})) {
		return [pscustomobject]$data
	}
}

filter Get-ContentFilePath
{
	# Confirm we have a 'Content' element specified.
	if ($xml.Config.ChildNodes.LocalName -notcontains 'Content') {
		throw "This element requires that 'Content' be configured to supply the required data."
	}

	# Test that the file is available and return path if it does.
	if ($moduledata.Content.ContainsKey('Destination') -and [System.IO.File]::Exists(($filepath = "$($moduledata.Content.Destination)\$_"))) {
		return $filepath
	}
	elseif ([System.IO.File]::Exists(($filepath = "$($moduledata.Content.TemporaryDir)\$_"))) {
		return $filepath
	}
	else {
		throw "The specified file '$_' was not available in hosted data source '$($xml.Config.Content.Source)'."
	}
}

function ConvertTo-BulletedList
{
	return "$($input -replace '^',"`n - ")"
}


#---------------------------------------------------------------------------
#
# Internal module data. None of this should really ever be touched.
#
#---------------------------------------------------------------------------

$moduledata = @{
	ActiveSetup = @{
		RegistryBase = 'HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components'
	}
	Content = @{
		DownloadFile = "$([System.IO.Path]::GetTempPath())\$(Get-Random).zip"
		TemporaryDir = "$([System.IO.Path]::GetTempPath())\$(Get-Random)"
	}
	DefaultAppAssociations = @{
		TagFile = "$env:WinDir\DefaultAppAssociations.tag"
	}
	DefaultStartLayout = @{
		BaseDirectory = ($basedir = "$(Get-DefaultUserLocalAppDataPath)\Microsoft\Windows\Shell")
		Archive = "$basedir\DefaultLayouts.$($script.StartDate.ToString('yyyyMMddTHHmmss')).backup"
		Destination = "$basedir\DefaultLayouts.xml"
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


#---------------------------------------------------------------------------
#
# Main callstack functions.
#
#---------------------------------------------------------------------------

function Out-ScriptHeader
{
	# Output initial log information.
	Write-Host "$($script.Name) v$($script.Version)"
	Write-Host "Written by: Mitch Richters"
	Write-Host "Running on: PowerShell $($Host.Version.ToString())"
	Write-Host "Started at: $($script.StartDate)"

	# Start transcription.
	$logPath = [System.IO.Directory]::CreateDirectory("$env:WinDir\Logs\DesiredStateManagement").FullName
	$logFile = "$logPath\$($script.Name)$($script.LogSuffix)_$($script.StartDate.ToString('yyyyMMddTHHmmss')).log"
	[System.Console]::WriteLine(($transcribing = Start-Transcript -LiteralPath $logFile))
	Write-Host "Commencing $($script.Action.ToLower()) process, please wait...`n$($script.Divider)"
}

function Import-DesiredStateConfig
{
	# Create error handler.
	$err = {throw $args[1].Exception.Message}

	# Get XML file and validate against our schema.
	New-Variable -Name xml -Value ([System.Xml.XmlDocument]::new()) -Scope Script -Option Constant,ReadOnly
	$xml.Schemas.Add([System.Xml.Schema.XmlSchema]::Read([System.Xml.XmlReader]::Create([System.IO.StringReader]::new($schema)), $err)) | Out-Null
	$xml.Load([System.Xml.XmlReader]::Create($script.Config))
	$xml.Validate($err)
}

function Get-DesiredStateOperations
{
	# Dynamically generate scriptblocks based on the incoming config and this script's available supporting functions.
	return $xml.Config.ChildNodes.LocalName | Where-Object {Get-Command -Name "$($script.Action)-$_" -ErrorAction Ignore} | ForEach-Object {
		[System.Management.Automation.ScriptBlock]::Create("$($script.Action)-$_$(if ($script.Action.Equals('Install')) {"; Write-Host $($script.Divider)"})")
	}
}

function Invoke-DesiredStateOperations
{
	# Execute piped in scriptblocks with ForEach-Object and process collected results.
	if ($results = ForEach-Object -Process $input.Where({$_})) {
		Write-Host "$($script.Divider)`n$($results -join "`n")`n$($script.Divider)"
		Write-Host "Please review transcription log and try again."
		$script.ExitCode = 1618
	}
	else {
		if (!$script.Action.Equals('Install')) {Write-Host $script.Divider}
		Write-Host "Successfully $($script.Action.ToLower().TrimEnd('e'))ed desired state management."
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
	return "$($xml.Config.ActiveSetup.Identifier) - $_"
}

function Get-ActiveSetupState
{
	# Store registry base locally to reduce line length.
	$regbase = $moduledata.ActiveSetup.RegistryBase

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
			(Compare-Object -ReferenceObject $_ -DifferenceObject $dest -Property $dest.PSObject.Properties.Name)
		}
	}
}

filter Install-ActiveSetupComponent ([ValidateSet('Install','Update')][System.String]$Action)
{
	# Set up component's key and associated properties.
	$key = (New-Item -LiteralPath $moduledata.ActiveSetup.RegistryBase -Name ($name = $_.Name | Out-ActiveSetupComponentName) -Value $name -Force).PSPath

	# Create item properties.
	@(
		[pscustomobject]@{Name = 'Version' ; Value = $_.Version ; PropertyType = 'String'}
		[pscustomobject]@{Name = 'StubPath'; Value = $_.StubPath; PropertyType = 'ExpandString'}
	) | New-ItemProperty -LiteralPath $key -Force | Out-Null

	switch ($Action) {
		'Install' {Write-Host "Installed missing ActiveSetup component '$name'."; break}
		'Update'  {Write-Host "Updated incorrect ActiveSetup component '$name'."; break}
	}
}

filter Remove-ActiveSetupComponent
{
	$_ | Remove-Item -Force -Confirm:$false
	Write-Host "Removed deprecated ActiveSetup component '$($_.PSChildName)'."
}

function Install-ActiveSetup
{
	# Advise commencement.
	Write-Host "Confirming ActiveSetup component installation state, please wait..."

	# Rectify state if needed.
	if (($components = Get-ActiveSetupState).PSObject.Properties.Where({$_.Value})) {
		$components.Deprecated | Remove-ActiveSetupComponent
		$components.Mismatched | Install-ActiveSetupComponent -Action Update
		$components.NotPresent | Install-ActiveSetupComponent -Action Install
		Write-Host "Successfully installed all ActiveSetup components."
	}
	else {
		Write-Host "Successfully confirmed all ActiveSetup components are correctly installed."
	}
}

function Confirm-ActiveSetup
{
	# Advise commencement.
	Write-Host "Confirming ActiveSetup component installation state, please wait..."

	# Get current state.
	$components = Get-ActiveSetupState

	# Output test results.
	if ($components.Deprecated) {"The following ActiveSetup components require removing:$($components.Deprecated.PSChildName | ConvertTo-BulletedList)"}
	if ($components.Mismatched) {"The following ActiveSetup components require amending:$($components.Mismatched.Name | ConvertTo-BulletedList)"}
	if ($components.NotPresent) {"The following ActiveSetup components require installing:$($components.NotPresent.Name | ConvertTo-BulletedList)"}
}

function Remove-ActiveSetup
{
	# Remove all items.
	Remove-Item -Path "$($moduledata.ActiveSetup.RegistryBase)\$($xml.Config.ActiveSetup.Identifier)*" -Force -Confirm:$false
	Write-Host "Successfully removed all ActiveSetup components."
}


#---------------------------------------------------------------------------
#
# Content.
#
#---------------------------------------------------------------------------

function Invoke-ContentPreOps
{
	# Advise commencement.
	Write-Host "Confirming Content state, please wait..."

	# Do basic sanity checks.
	try {
		# Download content file. If we can't get it, we can't proceed with anything.
		Invoke-WebRequest -UseBasicParsing -Uri $xml.Config.Content.Source -OutFile $moduledata.Content.DownloadFile

		# Extract contents to temp location. Do this first so the data is available for other modules.
		Expand-Archive -LiteralPath $moduledata.Content.DownloadFile -DestinationPath $moduledata.Content.TemporaryDir -Force

		# Set the destination path based off the incoming content. Do this via the registry in-case we're re-running in the same session.
		$moduledata.Content.Destination = Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' |
			Select-Object -ExpandProperty $xml.Config.Content.EnvironmentVariable -ErrorAction Ignore
	}
	catch {
		Write-Warning "Unable to confirm Content state. $($_.Exception.Message)"
		return 1
	}
}

function Test-ContentValidity
{
	# Test we have an environment variable first.
	if (!$moduledata.Content.Destination) {return $false}

	# Get file names from the source and destination, stripping off the path from each.
	$srcnames = Get-ChildItem -LiteralPath $moduledata.Content.TemporaryDir -Recurse |
		ForEach-Object {$_.FullName -replace "^$([System.Text.RegularExpressions.Regex]::Escape($moduledata.Content.TemporaryDir))\\"}
	$dstnames = Get-ChildItem -LiteralPath $moduledata.Content.Destination -Recurse |
		ForEach-Object {$_.FullName -replace "^$([System.Text.RegularExpressions.Regex]::Escape($moduledata.Content.Destination))\\"}

	# Test names for equality, returning false for any mismatch.
	Compare-Object -ReferenceObject $srcnames -DifferenceObject $dstnames -IncludeEqual | ForEach-Object {
		# Test whether file piped object matches left and right.
		if (!$_.SideIndicator.Equals('==')) {return $false}

		# Test whether files have a matching hash.
		$paths = @("$($moduledata.Content.TemporaryDir)\$($_.InputObject)", "$($moduledata.Content.Destination)\$($_.InputObject)")
		if ((Get-FileHash -LiteralPath $paths | Select-Object -ExpandProperty Hash -Unique) -isnot [System.String]) {return $false}
	}

	# We're all good if we reach here, the content cache is 100% valid with the source.
	return $true
}

function Install-Content
{
	# Do pre-ops and return if there was an error.
	if (Invoke-ContentPreOps) {return}

	# Get state and repair if needed.
	if (!(Test-ContentValidity)) {
		# Expand out incoming destination string.
		$destination = [System.Environment]::ExpandEnvironmentVariables($xml.Config.Content.Destination)

		# Mirror our extracted folder with our destination using Robocopy.
		(robocopy.exe "$($moduledata.Content.TemporaryDir)" "$($destination)" /MIR /FP 2>&1).ForEach({
			# Test the line to determine the action.
			switch ($_) {
				{$_.Contains('*EXTRA File')} {
					Write-Host "Removed deprecated file '$($_ -replace '^.+\\')'."
				}
				{$_.Contains('Newer')} {
					Write-Host "Updated existing file '$($_ -replace '^.+\\')'."
				}
				{$_.Contains('New File')} {
					Write-Host "Copied new file '$($_ -replace '^.+\\')'."
				}
			}
		})
		if ($LASTEXITCODE -ge 8) {throw "Transfer of Content via robocopy.exe failed with exit code $LASTEXITCODE."}

		# Install environment variable if it does not exist.
		if (!$moduledata.Content.Destination) {
			[System.Environment]::SetEnvironmentVariable($xml.Config.Content.EnvironmentVariable, $destination, 'Machine')
			$moduledata.Content.Destination = $destination
		}
		Write-Host "Successfully installed Content components."
	}
	else {
		Write-Host "Successfully confirmed all Content components are correctly deployed."
	}
}

function Confirm-Content
{
	# Do pre-ops and return if there was an error.
	if (Invoke-ContentPreOps) {return}

	# Output incorrect results, if any.
	if (!(Test-ContentValidity)) {"The following Content components require installing or amending:`n - Environment variable`n - File data"}
}

function Remove-Content
{
	# Delete the contents folder.
	if ([System.IO.Directory]::Exists(($path = [System.Environment]::ExpandEnvironmentVariables($xml.Config.Content.Destination)))) {
		[System.IO.Directory]::Delete($path, $true)
	}

	# Delete folders above so long as they're empty.
	while ([System.IO.Directory]::Exists(($path += "\..")) -and !(Get-ChildItem -LiteralPath $path)) {
		[System.IO.Directory]::Delete($path, $true)
	}

	# Remove environment variable.
	[System.Environment]::SetEnvironmentVariable($xml.Config.Content.EnvironmentVariable, [System.String]::Empty, 'Machine')
	Write-Host "Successfully removed all Content components."
}


#---------------------------------------------------------------------------
#
# DefaultAppAssociations.
#
#---------------------------------------------------------------------------

function Invoke-DefaultAppAssociationsPreOps
{
	# Advise commencement.
	Write-Host "Confirming DefaultAppAssociations state, please wait..."

	# Do basic sanity checks.
	try {
		# Get file path from our cache.
		$moduledata.DefaultAppAssociations.Source = $xml.Config.DefaultAppAssociations | Get-ContentFilePath

		# Store hash for the file in our client-side cache.
		$moduledata.DefaultAppAssociations.FileHash = Get-FileHash -LiteralPath $moduledata.DefaultAppAssociations.Source -ErrorAction Ignore |
			Select-Object -ExpandProperty Hash
	}
	catch {
		Write-Warning "Unable to confirm DefaultAppAssociations state. $($_.Exception.Message)"
		return 1
	}
}

function Test-DefaultAppAssociationsApplicability
{
	return ![System.IO.File]::Exists($moduledata.DefaultAppAssociations.TagFile) -or
		!$moduledata.DefaultAppAssociations.FileHash -or
		!$moduledata.DefaultAppAssociations.FileHash.Equals(([System.IO.File]::ReadAllText($moduledata.DefaultAppAssociations.TagFile)))
}

function Install-DefaultAppAssociations
{
	# Do pre-ops and return if there was an error.
	if (Invoke-DefaultAppAssociationsPreOps) {return}

	# Get state and repair if needed.
	if (Test-DefaultAppAssociationsApplicability) {
		[System.Void](dism.exe /Online /Import-DefaultAppAssociations:"$($moduledata.DefaultAppAssociations.Source)" 2>&1)
		[System.IO.File]::WriteAllText($moduledata.DefaultAppAssociations.TagFile, $moduledata.DefaultAppAssociations.FileHash)
		Write-Host "Successfully installed DefaultAppAssociations file."
	}
	else {
		Write-Host "Successfully confirmed DefaultAppAssociations state is correctly deployed."
	}
}

function Confirm-DefaultAppAssociations
{
	# Do pre-ops and return if there was an error.
	if (Invoke-DefaultAppAssociationsPreOps) {return}

	# Output incorrect results, if any.
	if (Test-DefaultAppAssociationsApplicability) {"The following DefaultAppAssociations components require installing or amending:`n - File"}
}

function Remove-DefaultAppAssociations
{
	Remove-Item -LiteralPath $moduledata.DefaultAppAssociations.TagFile -Force -Confirm:$false -ErrorAction Ignore
	Write-Host "Successfully removed DefaultAppAssociations tag file."
}


#---------------------------------------------------------------------------
#
# DefaultStartLayout.
#
#---------------------------------------------------------------------------

function Invoke-DefaultStartLayoutPreOps
{
	# Advise commencement.
	Write-Host "Confirming DefaultStartLayout state, please wait..."

	# Do basic sanity checks.
	try {
		# Get file path from our cache.
		$moduledata.DefaultStartLayout.Source = $xml.Config.DefaultStartLayout | Get-ContentFilePath
	}
	catch {
		Write-Warning "Unable to confirm DefaultStartLayout state. $($_.Exception.Message)"
		return 1
	}
}

function Test-DefaultStartLayoutValidity
{
	$src = $moduledata.DefaultStartLayout.Source; $dst = $moduledata.DefaultStartLayout.Destination
	return [System.IO.File]::Exists($src) -and [System.IO.File]::Exists($dst) -and
		((Get-FileHash -LiteralPath $src,$dst | Select-Object -ExpandProperty Hash -Unique) -is [System.String])
}

function Install-DefaultStartLayout
{
	# Do pre-ops and return if there was an error.
	if (Invoke-DefaultStartLayoutPreOps) {return}

	# Get state and repair if needed.
	if (!(Test-DefaultStartLayoutValidity)) {
		Copy-Item -LiteralPath $moduledata.DefaultStartLayout.Destination -Destination $moduledata.DefaultStartLayout.Archive | Out-Null
		Copy-Item -LiteralPath $moduledata.DefaultStartLayout.Source -Destination $moduledata.DefaultStartLayout.Destination -Force | Out-Null
		Write-Host "Successfully installed DefaultStartLayout values."
	}
	else {
		Write-Host "Successfully confirmed DefaultStartLayout configuration is correctly deployed."
	}
}

function Confirm-DefaultStartLayout
{
	# Do pre-ops and return if there was an error.
	if (Invoke-DefaultStartLayoutPreOps) {return}

	# Output incorrect results, if any.
	if (!(Test-DefaultStartLayoutValidity)) {"The following DefaultStartLayout components require installing or amending:`n - File"}
}

function Remove-DefaultStartLayout
{
	# Get oldest backup.
	$backup = Get-ChildItem -Path "$($moduledata.DefaultStartLayout.BaseDirectory)\*.backup" |
		Sort-Object -Property LastWriteTime | Select-Object -ExpandProperty FullName -First 1

	# Restore it if we have one.
	if ($backup) {
		Copy-Item -LiteralPath $backup -Destination $moduledata.DefaultStartLayout.Destination -Force -Confirm:$false
		Remove-Item -Path "$($moduledata.DefaultStartLayout.BaseDirectory)\*.backup" -Force -Confirm:$false
		Write-Host "Successfully restored DefaultStartLayout configuration."
	}
	else {
		Write-Host "Confirmed system is already running the DefaultStartLayout configuration, or has no valid backups to restore."
	}
}


#---------------------------------------------------------------------------
#
# DefaultTheme.
#
#---------------------------------------------------------------------------

function Invoke-DefaultThemePreOps
{
	# Advise commencement.
	Write-Host "Confirming DefaultTheme state, please wait..."

	# Do basic sanity checks.
	try {
		# Get file path from our cache.
		$xml.Config.DefaultTheme | Get-ContentFilePath | Out-Null

		# Set value to apply in registry.
		$moduledata.DefaultTheme.Value = "%DesiredStateContents%\$($xml.Config.DefaultTheme)"
	}
	catch {
		Write-Warning "Unable to confirm DefaultTheme state. $($_.Exception.Message)"
		return 1
	}
}

function Get-IncorrectDefaultTheme
{
	# Return results.
	return {!$moduledata.DefaultTheme.Value.Equals(($moduledata.DefaultTheme | Get-RegistryDataItemValue))} | Invoke-DefaultUserRegistryAction
}

function Install-DefaultTheme
{
	# Do pre-ops and return if there was an error.
	if (Invoke-DefaultThemePreOps) {return}

	# Get state and repair if needed.
	if (Get-IncorrectDefaultTheme) {
		{$moduledata.DefaultTheme | Install-RegistryDataItem} | Invoke-DefaultUserRegistryAction | Out-Null
		Write-Host "Successfully installed DefaultTheme components."
	}
	else {
		Write-Host "Successfully confirmed all DefaultTheme components are correctly deployed."
	}
}

function Confirm-DefaultTheme
{
	# Do pre-ops and return if there was an error.
	if (Invoke-DefaultThemePreOps) {return}

	# Output incorrect results, if any.
	if (Get-IncorrectDefaultTheme) {"The following DefaultTheme components require installing or amending:`n - Registry configuration"}
}

function Remove-DefaultTheme
{
	# Just remove the registry components so we don't risk breaking user experiences.
	{$moduledata.DefaultTheme | Where-Object {$_ | Get-RegistryDataItemValue} | Remove-RegistryDataItem} | Invoke-DefaultUserRegistryAction | Out-Null
	Write-Host "Successfully removed all DefaultTheme registry components."
}


#---------------------------------------------------------------------------
#
# LanguageDefaults.
#
#---------------------------------------------------------------------------

function Invoke-LanguageDefaultsPreOps
{
	# Advise commencement.
	Write-Host "Confirming LanguageDefaults state, please wait..."

	# Do basic sanity checks.
	try {
		# Get file path from our cache.
		$moduledata.LanguageDefaults.Source = $xml.Config.LanguageDefaults | Get-ContentFilePath

		# Store hash for the file in our client-side cache.
		$moduledata.LanguageDefaults.FileHash = Get-FileHash -LiteralPath $moduledata.LanguageDefaults.Source -ErrorAction Ignore |
			Select-Object -ExpandProperty Hash
	}
	catch {
		Write-Warning "Unable to confirm LanguageDefaults state. $($_.Exception.Message)"
		return 1
	}
}

function Test-LanguageDefaultsApplicability
{
	return ![System.IO.File]::Exists($moduledata.LanguageDefaults.TagFile) -or
		!$moduledata.LanguageDefaults.FileHash -or
		!$moduledata.LanguageDefaults.FileHash.Equals([System.IO.File]::ReadAllText($moduledata.LanguageDefaults.TagFile))
}

function Install-LanguageDefaults
{
	# Do pre-ops and return if there was an error.
	if (Invoke-LanguageDefaultsPreOps) {return}

	# Get state and repair if needed.
	if (Test-LanguageDefaultsApplicability) {
		control.exe "intl.cpl,,/f:`"$($moduledata.LanguageDefaults.Source)`"" 2>&1
		[System.IO.File]::WriteAllText($moduledata.LanguageDefaults.TagFile, $moduledata.LanguageDefaults.FileHash)
		Write-Host "Successfully installed LanguageDefaults unattend file."
	}
	else {
		Write-Host "Successfully confirmed LanguageDefaults state is correctly deployed."
	}
}

function Confirm-LanguageDefaults
{
	# Do pre-ops and return if there was an error.
	if (Invoke-LanguageDefaultsPreOps) {return}

	# Output incorrect results, if any.
	if (Test-LanguageDefaultsApplicability) {"The following LanguageDefaults components require installing or amending:`n - File"}
}

function Remove-LanguageDefaults
{
	Remove-Item -LiteralPath $moduledata.LanguageDefaults.TagFile -Force -Confirm:$false -ErrorAction Ignore
	Write-Host "Successfully removed LanguageDefaults tag file."
}


#---------------------------------------------------------------------------
#
# OemInformation.
#
#---------------------------------------------------------------------------

function Invoke-OemInformationPreOps
{
	# Advise commencement.
	Write-Host "Confirming OemInformation state, please wait..."

	# Do basic sanity checks.
	try {
		# Calculate some properties for future usage.
		$moduledata.OemInformation.Logo = $xml.Config.OemInformation.Logo | Get-ContentFilePath
		$moduledata.OemInformation.Model = (Get-CimInstance -ClassName Win32_ComputerSystem).Model
	}
	catch {
		Write-Warning "Unable to confirm OemInformation state. $($_.Exception.Message)"
		return 1
	}
}

function Get-OemInformationIncorrectChildNodes
{
	# Get all properties from the registry.
	$itemprops = Get-ItemProperty -LiteralPath ($regbase = $moduledata.OemInformation.RegistryBase) -ErrorAction Ignore

	# Return test results.
	return ($xml.Config.OemInformation.ChildNodes.LocalName + 'Model').ForEach({
		# Get calculated value from script's storage if present, otherwise use XML provided source.
		$value = $(if ($moduledata.OemInformation.ContainsKey($_)) {$moduledata.OemInformation.$_} else {$xml.Config.OemInformation.$_})
		if (!$itemprops -or !$value.Equals(($itemprops | Select-Object -ExpandProperty $_ -ErrorAction Ignore))) {
			[pscustomobject]@{Key = $regbase -replace ':'; Name = $_; Value = $value; Type = 'REG_SZ'}
		}
	})
}

function Install-OemInformation
{
	# Do pre-ops and return if there was an error.
	if (Invoke-OemInformationPreOps) {return}

	# Get state and repair if needed.
	if ($incorrect = Get-OemInformationIncorrectChildNodes) {
		# Install any missing properties.
		$incorrect | Install-RegistryDataItem
		Write-Host "Successfully installed OemInformation values."
	}
	else {
		Write-Host "Successfully confirmed all OemInformation values are correctly deployed."
	}
}

function Confirm-OemInformation
{
	# Do pre-ops and return if there was an error.
	if (Invoke-OemInformationPreOps) {return}

	# Output test results.
	if ($incorrect = Get-OemInformationIncorrectChildNodes) {
		"The following OemInformation values require installing or amending:$($incorrect.Name | ConvertTo-BulletedList)"
	}
}

function Remove-OemInformation
{
	Remove-Item -LiteralPath $moduledata.OemInformation.RegistryBase -Force -Confirm:$false -ErrorAction Ignore
	Write-Host "Successfully removed all OemInformation values."
}


#---------------------------------------------------------------------------
#
# RegistrationInfo.
#
#---------------------------------------------------------------------------

function Get-IncorrectRegistrationInfo
{
	# Get item properties and store.
	$itemprops = Get-ItemProperty -LiteralPath ($regbase = $moduledata.RegistrationInfo.RegistryBase)

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
	Write-Host "Confirming RegistrationInfo state, please wait..."

	# Get state and repair if needed.
	if ($incorrect = Get-IncorrectRegistrationInfo) {
		$incorrect | New-ItemProperty -Force | Out-Null
		Write-Host "Successfully installed RegistrationInfo values."
	}
	else {
		Write-Host "Successfully confirmed all RegistrationInfo values are correctly deployed."
	}
}

function Confirm-RegistrationInfo
{
	# Advise commencement.
	Write-Host "Confirming RegistrationInfo state, please wait..."

	# Output incorrect results, if any.
	if ($incorrect = Get-IncorrectRegistrationInfo) {
		"The following RegistrationInfo values require installing or amending:$($incorrect.Name | ConvertTo-BulletedList)"
	}
}

function Remove-RegistrationInfo
{
	$path = $moduledata.RegistrationInfo.RegistryBase; $Name = $xml.Config.RegistrationInfo.ChildNodes.LocalName
	Remove-ItemProperty -LiteralPath $path -Name $Name -Force -Confirm:$false -ErrorAction Ignore
	Write-Host "Successfully removed all RegistrationInfo values."
}


#---------------------------------------------------------------------------
#
# RegistryData.
#
#---------------------------------------------------------------------------

function Get-IncorrectRegistryData
{
	return $xml.Config.RegistryData.Item | Where-Object {!$_.Value.Equals(($_ | Get-RegistryDataItemValue))}
}

function Install-RegistryData
{
	# Advise commencement.
	Write-Host "Confirming RegistryData value installation state, please wait..."

	# Get incorrect items and rectify if needed.
	if ($incorrect = Get-IncorrectRegistryData) {
		$incorrect | Install-RegistryDataItem
		Write-Host "Successfully installed all RegistryData values."
	}
	else {
		Write-Host "Successfully confirmed all RegistryData values are correctly deployed."
	}
}

function Confirm-RegistryData
{
	# Advise commencement.
	Write-Host "Confirming RegistryData value installation state, please wait..."

	# Output incorrect results, if any.
	if ($incorrect = Get-IncorrectRegistryData) {
		"The following RegistryData values require installing or amending:$($incorrect | ForEach-Object {"`n - $($_.Key)\$($_.Name)"})"
	}
}

function Remove-RegistryData
{
	# Remove each item and the key if the item was the last.
	$xml.Config.RegistryData.Item | Where-Object {$_ | Get-RegistryDataItemValue} | Remove-RegistryDataItem
	Write-Host "Successfully removed all RegistryData values."
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
			($moduledata.RemoveApps.MandatoryApps -notcontains $_.Name) -and
			($xml.Config.RemoveApps.App -contains $_.Name) -and
			($_.PackageUserInformation.InstallState -contains 'Installed')
		}
		Provisioned = Get-AppxProvisionedPackage -Online | Where-Object {
			($moduledata.RemoveApps.MandatoryApps -notcontains $_.DisplayName) -and
			($xml.Config.RemoveApps.App -contains $_.DisplayName)
		}
	}
}

filter Remove-RemoveAppInstallation
{
	# Remove app for each user that currently has it installed.
	if ($users = $_.PackageUserInformation | Where-Object {$_.InstallState.Equals('Installed')}) {
		foreach ($user in $users.UserSecurityId) {
			$_ | Remove-AppxPackage -User $user.Sid
			Write-Host "Removed installed AppX package '$($_.Name)' for user '$($_.Username)'."
		}
		Write-Host "Removed installed AppX package '$($_.Name)' for all users."
	}
}

filter Remove-RemoveAppProvisionment
{
	$_ | Remove-AppxProvisionedPackage -AllUsers -Online | Out-Null
	Write-Host "Removed provisioned AppX package '$($_.DisplayName)'."
}

function Install-RemoveApps
{
	# Advise commencement.
	Write-Host "Confirming RemoveApps configuration state, please wait..."

	# Rectify state if needed.
	if (($apps = Get-RemoveAppsState).PSObject.Properties.Where({$_.Value})) {
		$apps.Installed | Remove-RemoveAppInstallation
		$apps.Provisioned | Remove-RemoveAppProvisionment
		Write-Host "Successfully processed RemoveApps configuration items."
	}
	else {
		Write-Host "Successfully confirmed all RemoveApps items are not installed."
	}
}

function Confirm-RemoveApps
{
	# Advise commencement.
	Write-Host "Confirming RemoveApps configuration state, please wait..."

	# Get AppX states.
	$apps = Get-RemoveAppsState

	# Output test results.
	if ($apps.Installed) {"The following apps in RemoveApps require uninstalling:$($apps.Installed.Name | ConvertTo-BulletedList)"}
	if ($apps.Provisioned) {"The following apps in RemoveApps require deprovisioning:$($apps.Provisioned.DisplayName | ConvertTo-BulletedList)"}
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
	[System.Void](icacls.exe $env:SystemDrive\ /grant "*$($moduledata.SystemDriveLockdown.SID):(OI)(CI)(IO)(M)" 2>&1)
	[System.Void](icacls.exe $env:SystemDrive\ /grant "*$($moduledata.SystemDriveLockdown.SID):(AD)" 2>&1)
}

function Install-SystemDriveLockdown
{
	# Advise commencement.
	Write-Host "Confirming SystemDriveLockdown state, please wait..."

	# Get state and repair if needed.
	if (Test-SystemDriveLockdownEnable) {
		[System.Void](icacls.exe $env:SystemDrive\ /remove:g *$($moduledata.SystemDriveLockdown.SID) 2>&1)
		Write-Host "Successfully enabled SystemDriveLockdown component."
	}
	elseif (Test-SystemDriveLockdownDisable) {
		Restore-SystemDriveLockdownDefaults
		Write-Host "Successfully disabled SystemDriveLockdown component."
	}
	else {
		Write-Host "Successfully confirmed SystemDriveLockdown state is correctly deployed."
	}
}

function Confirm-SystemDriveLockdown
{
	# Advise commencement.
	Write-Host "Confirming SystemDriveLockdown state, please wait..."

	# Output incorrect results, if any.
	if (Test-SystemDriveLockdownEnable) {
		"The following SystemDriveLockdown components requires enabling:`n - %SystemDrive% lockdown"
	}
	elseif (Test-SystemDriveLockdownDisable) {
		"The following SystemDriveLockdown components requires disabling:`n - %SystemDrive% lockdown"
	}
}

function Remove-SystemDriveLockdown
{
	if (!((icacls.exe $env:SystemDrive\ 2>&1) -match 'NT AUTHORITY\\Authenticated Users:(\(AD\)|\(OI\)\(CI\)\(IO\)\(M\))$').Count.Equals(2)) {
		Restore-SystemDriveLockdownDefaults
	}
	Write-Host "Successfully removed SystemDriveLockdown tag file."
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
	$toInstall = $xml.Config.WindowsCapabilities.Capability | Where-Object {$_.Action.Equals('Install')} | Select-Object -ExpandProperty '#text'
	$toRemove = $xml.Config.WindowsCapabilities.Capability | Where-Object {$_.Action.Equals('Remove')} | Select-Object -ExpandProperty '#text'

	# Get capability states and return to the pipeline.
	return [pscustomobject]@{
		Installed = $capabilities.Where({($toRemove -contains $_.Name) -and ($_.State.Equals([Microsoft.Dism.Commands.PackageFeatureState]::Installed))})
		Uninstalled = $capabilities.Where({($toInstall -contains $_.Name) -and (!$_.State.Equals([Microsoft.Dism.Commands.PackageFeatureState]::Installed))})
	}
}

filter Remove-ListedWindowsCapability
{
	$_ | Remove-WindowsCapability -Online | Out-Null
	Write-Host "Removed installed Windows Capability '$($_.Name)'."
}

filter Install-ListedWindowsCapability
{
	$_ | Add-WindowsCapability -Online | Out-Null
	Write-Host "Installed missing Windows Capability '$($_.Name)'."
}

function Install-WindowsCapabilities
{
	# Advise commencement.
	Write-Host "Confirming WindowsCapabilities configuration state, please wait..."

	# Get capability states and rectify as needed.
	if (($capabilities = Get-WindowsCapabilitiesState).PSObject.Properties.Where({$_.Value})) {
		$capabilities.Installed | Remove-ListedWindowsCapability
		$capabilities.Uninstalled | Install-ListedWindowsCapability
		Write-Host "Successfully processed WindowsCapabilities configuration."
	}
	else {
		Write-Host "Successfully confirmed all WindowsCapabilities are correctly deployed."
	}
}

function Confirm-WindowsCapabilities
{
	# Advise commencement.
	Write-Host "Confirming WindowsCapabilities configuration state, please wait..."

	# Get capability states.
	$capabilities = Get-WindowsCapabilitiesState

	# Output test results.
	if ($capabilities.Installed) {"The following Windows Capabilities require uninstalling:$($capabilities.Installed.Name | ConvertTo-BulletedList)"}
	if ($capabilities.Uninstalled) {"The following Windows Capabilities require installing:$($capabilities.Uninstalled.Name | ConvertTo-BulletedList)"}
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
	Write-Host "Disabled enabled Windows Optional Feature '$($_.FeatureName)'."
}

filter Enable-ListedWindowsOptionalFeature
{
	$_ | Enable-WindowsOptionalFeature -Online -NoRestart -WarningAction Ignore | Out-Null
	Write-Host "Enabled disabled Windows Optional Feature '$($_.FeatureName)'."
}

function Install-WindowsOptionalFeatures
{
	# Advise commencement.
	Write-Host "Confirming WindowsOptionalFeatures configuration state, please wait..."

	# Get capability states and rectify as needed.
	if (($features = Get-WindowsOptionalFeaturesState).PSObject.Properties.Where({$_.Value})) {
		$features.Enabled | Disable-ListedWindowsOptionalFeature
		$features.Disabled | Enable-ListedWindowsOptionalFeature
		Write-Host "Successfully processed WindowsOptionalFeatures configuration."
	}
	else {
		Write-Host "Successfully confirmed all WindowsOptionalFeatures are correctly deployed."
	}
}

function Confirm-WindowsOptionalFeatures
{
	# Advise commencement.
	Write-Host "Confirming WindowsOptionalFeatures configuration state, please wait..."

	# Get capability states.
	$features = Get-WindowsOptionalFeaturesState

	# Output test results.
	if ($features.Enabled) {"The following Windows Optional Features require disabling:$($features.Enabled.FeatureName | ConvertTo-BulletedList)"}
	if ($features.Disabled) {"The following Windows Optional Features require enabling:$($features.Disabled.FeatureName | ConvertTo-BulletedList)"}
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
	Out-ScriptHeader
	Import-DesiredStateConfig
	Get-DesiredStateOperations | Invoke-DesiredStateOperations
}
catch
{
	$_ | Out-FriendlyErrorMessage | Write-StdErrMessage
	Write-Host "Previously commenced operation did not complete successfully."
	Write-Host "$($script.Divider)`nPlease review transcription log and try again."
	$script.ExitCode = 1618
}
finally
{
	Stop-Transcript | Out-Null
	exit $script.ExitCode
}
