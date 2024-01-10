
<#PSScriptInfo

.VERSION 1.0

.GUID c2f10730-e9d4-45e3-b6fa-3f0ddfc40f78

.AUTHOR Mitch Richters (mrichters@themissinglink.com.au).

.COMPANYNAME The Missing Link Network Integration Pty Ltd

.COPYRIGHT Copyright (C) 2023 The Missing Link Network Integration Pty Ltd. All rights reserved.

.TAGS

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
- Initial release.

#>

<#

.DESCRIPTION
This script install/removes/validates Desired State within a PC, wrapping around Invoke-DesiredStateManagementOperation.ps1.

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
$ProgressPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
Set-PSDebug -Strict
Set-StrictMode -Version Latest

# Set required variables for install operation.
$scrName = 'Install-DesiredStateManagement.ps1'
$scrMode = $PSCmdlet.ParameterSetName

# Store list of hashes for all content files. Set this variable to null if we're not processing content.
# To regenerate, run the following from the Content folder and paste results here: Get-ChildItem -File -Recurse | Get-FileHash | ForEach-Object -Begin {'$srcHashes = @('} -Process {"'$($_.Hash)'"} -End {')'}
$srcHashes = @(
	'18BD6E51B6BBC3D219C20E4479A3D2F03B398DE0C7F0349EDB1BB99DFAB3AA5F'
	'B7D3E2ECC2663CC3814C6FF96A88A80EFE5B78301C098543B7BD5422E6703599'
	'E7B88BD693809CD30B5D3290D2D70B08E244F2465C49419F4EF13F72F5AF32DB'
	'A26ED8240C9B71765887FE539B4334AF4034486428270318AD54368824E6AE2C'
	'1246BE6E8CC2F0580A1B9806B1D470D6C9959D0A27163B20FAF033603122B068'
	'B1D6EEA453C9E142C6817592AC0182025871DCFB0235E31CDCC944A4215C7DD5'
	'8A754B081343650EB5BB21486FCC21F99B17932507E4C064BDC5B7335FA3F867'
	'F17F6273414522803F59856EBEB524E6E2DA981764A6A4F1943B58A3E0F1905A'
	'A8488763A0E9F6FBA351EFC9697D29A272FC436D5B683043AA42736E9CD3919D'
	'C34BA0EB2729DBF6A160F2F766AD5C445A841BA8D710DAD2F94D0D016AA3F4B5'
	'A7A70DAC2C1EB6ECB894102E59982BE1CF4ED3F997D07DF33830ED204BAEFC9D'
	'44A0D1A833285A2504A6B1BBE605217B49B8EF168D15641A60649F3262BD51F3'
	'CC7E68049AC3BD229064866842832132BE342FDC8B9AB0672A87951BCC937E18'
	'F886BBC3E890499F7087654A806403DEA3A42C5B23873AC1F234FD4C6ECC896C'
	'5C841D8C77038B787FF120EAB4DD587D6D4A493FE6581D275BED62BA9320DA14'
	'0547CFC1110D7FC14B653652AA851191D4D23BA924F0622685DDB6156FB8DB8C'
	'C94B4152ED8B1F8E4A8804416F9A306D3E5E30EFDBC06D27EEFF6B18F810ABCC'
	'1BE85A64AAD2C3CAA0DC28705B49A1548E85157F4D2D522C20FEC4B4570A623F'
	'0277083A65F058C5CC9A8A579FF2EFD588A0AB05A9A196313AB920BE3DEEAB30'
	'88C3CADEFD320D8371297CFF060937D6FFA5F72CDFB2AC8B0DBD039E61134DC8'
)

# Config to load into Invoke-DesiredStateManagementOperation.ps1.
$config = @"
<Config Version="1.0">
	<Content>
		<!--Note: If a Source is not specified, the script will assume you've provided data in the destination yourself-->
		<Destination>%ProgramData%\Schenck\DesiredStateManagement\Content</Destination>
		<EnvironmentVariable>DesiredStateContents</EnvironmentVariable>
	</Content>
	<RegistrationInfo>
		<RegisteredOwner>SPG User</RegisteredOwner>
		<RegisteredOrganization>Schenck Process Group APAC</RegisteredOrganization>
	</RegistrationInfo>
	<OemInformation>
		<Manufacturer>Schenck Process Group APAC</Manufacturer>
		<Logo>oemlogo.bmp</Logo>
		<SupportPhone>+61 2 9886 6806</SupportPhone>
		<SupportHours>07:30 to 18:30</SupportHours>
		<SupportURL>https://www.schenckprocess.com/</SupportURL>
	</OemInformation>
	<SystemDriveLockdown Enabled="1"/>
	<DefaultStartLayout>DefaultLayouts.xml</DefaultStartLayout>
	<DefaultLayoutModification>
		<Taskbar>file.xml</Taskbar>
		<StartMenu>file.json</StartMenu>
	</DefaultLayoutModification>
	<DefaultAppAssociations>DefaultAssociations.xml</DefaultAppAssociations>
	<LanguageDefaults>LanguageUnattend.xml</LanguageDefaults>
	<DefaultTheme>Autopilot.theme</DefaultTheme>
	<ActiveSetup Identifier="Schenck Defaults">
		<!-- Note: Once you set this identifier for your customer, don't ever change it! -->
		<!-- Note: Only increment version numbers if you wish to re-trigger the default on next logon, not necessarily because you made a change! -->
		<Component Version="1">
			<Name>Reduce Taskbar Searchbox</Name>
			<StubPath>reg.exe add HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search /v SearchboxTaskbarMode /t REG_DWORD /d 1 /f</StubPath>
		</Component>
		<Component Version="1">
			<Name>Reduce News and Interests</Name>
			<StubPath>reg.exe add HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Feeds /v ShellFeedsTaskbarViewMode /t REG_DWORD /d 1 /f</StubPath>
		</Component>
		<Component Version="1">
			<Name>Disable News and Interests Hover</Name>
			<StubPath>reg.exe add HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Feeds /v ShellFeedsTaskbarOpenOnHover /t REG_DWORD /d 0 /f</StubPath>
		</Component>
		<Component Version="1">
			<Name>Disable Taskbar AutoTray</Name>
			<StubPath>reg.exe add HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer /v EnableAutoTray /t REG_DWORD /d 0 /f</StubPath>
		</Component>
		<Component Version="1">
			<Name>Default Explorer to 'This PC'</Name>
			<StubPath>reg.exe add HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced /v TaskbarAl /t REG_DWORD /d 0 /f</StubPath>
		</Component>
		<Component Version="1">
			<Name>Left-align Taskbar</Name>
			<StubPath>reg.exe add HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search /v SearchboxTaskbarMode /t REG_DWORD /d 1 /f</StubPath>
		</Component>
		<Component Version="1">
			<Name>SalesLogix DB Connection</Name>
			<StubPath>powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -NoProfile -File "%DesiredStateContents%\Import-SalesLogixDBConnection.ps1"</StubPath>
		</Component>
		<Component Version="1">
			<Name>Avaya Config File</Name>
			<StubPath>powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -NoProfile -File "%DesiredStateContents%\Out-AvayaConfigXmlDefault.ps1"</StubPath>
		</Component>
		<Component Version="1">
			<Name>SAP UI Config File</Name>
			<StubPath>powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -NoProfile -File "%DesiredStateContents%\Out-SAPUILandscape.ps1"</StubPath>
		</Component>
		<Component Version="1">
			<Name>SAP UI Global Config File</Name>
			<StubPath>powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -NoProfile -File "%DesiredStateContents%\Out-SAPUILandscapeGlobal.ps1"</StubPath>
		</Component>
		<Component Version="1">
			<Name>Reset Display DPI</Name>
			<StubPath>powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -NoProfile -File "%DesiredStateContents%\Reset-DisplayDpi.ps1"</StubPath>
		</Component>
		<Component Version="1">
			<Name>Inventor Professional 2018</Name>
			<StubPath>powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -NoProfile -File "%DesiredStateContents%\Set-InventorProfessional2018Defaults.ps1"</StubPath>
		</Component>
		<Component Version="1">
			<Name>Vault Professional 2018</Name>
			<StubPath>powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -NoProfile -File "%DesiredStateContents%\Set-VaultProfessional2018Defaults.ps1"</StubPath>
		</Component>
	</ActiveSetup>
	<SystemShortcuts>
		<Shortcut Location="CommonDesktopDirectory" Name="WebApp1.lnk">
			<TargetPath>%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe</TargetPath>
			<Arguments>https://www.company.com/path/to/webapp</Arguments>
		</Shortcut>
		<Shortcut Location="CommonDesktopDirectory" Name="WebApp2.lnk">
			<TargetPath>%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe</TargetPath>
			<Arguments>https://www.company.com/path/to/webapp</Arguments>
		</Shortcut>
	</SystemShortcuts>
	<RegistryData>
		<Item Description="Disable Fast Startup">
			<Key>HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Power</Key>
			<Name>HiberbootEnabled</Name>
			<Value>0x0</Value>
			<Type>REG_DWORD</Type>
		</Item>
		<Item Description="Disable Hibernation">
			<Key>HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Power</Key>
			<Name>HibernateEnabled</Name>
			<Value>0x0</Value>
			<Type>REG_DWORD</Type>
		</Item>
		<Item Description="Disable Local Storage of Passwords and Credentials">
			<Key>HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa</Key>
			<Name>DisableDomainCreds</Name>
			<Value>0x1</Value>
			<Type>REG_DWORD</Type>
		</Item>
		<Item Description="Enable Local Security Authority (LSA) Protection">
			<Key>HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa</Key>
			<Name>RunAsPPL</Name>
			<Value>0x1</Value>
			<Type>REG_DWORD</Type>
		</Item>
		<Item Description="Disable Network Drive Reconnection">
			<Key>HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\NetworkProvider</Key>
			<Name>RestoreConnection</Name>
			<Value>0x0</Value>
			<Type>REG_DWORD</Type>
		</Item>
		<Item Description="Disable Network Location Wizard">
			<Key>HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Network\NewNetworkWindowOff</Key>
			<Name>NewNetworkWindowOff</Name>
			<Value>0x1</Value>
			<Type>REG_DWORD</Type>
		</Item>
	</RegistryData>
	<RemoveApps>
		<App>Microsoft.GetHelp</App>
		<App>Microsoft.Getstarted</App>
		<App>Microsoft.MicrosoftOfficeHub</App>
		<App>Microsoft.MicrosoftSolitaireCollection</App>
		<App>Microsoft.MixedReality.Portal</App>
		<App>Microsoft.Office.OneNote</App>
		<App>Microsoft.People</App>
		<App>Microsoft.SkypeApp</App>
		<App>Microsoft.Wallet</App>
		<App>microsoft.windowscommunicationsapps</App>
		<App>Microsoft.WindowsFeedbackHub</App>
		<App>Microsoft.XboxApp</App>
		<App>Microsoft.XboxGameOverlay</App>
		<App>Microsoft.XboxGamingOverlay</App>
		<App>Microsoft.XboxIdentityProvider</App>
		<App>Microsoft.XboxSpeechToTextOverlay</App>
	</RemoveApps>
	<WindowsCapabilities>
		<Capability Action="Remove">App.Support.QuickAssist~~~~0.0.1.0</Capability>
		<Capability Action="Remove">Browser.InternetExplorer~~~~0.0.11.0</Capability>
	</WindowsCapabilities>
	<WindowsOptionalFeatures>
		<Feature Action="Disable">MicrosoftWindowsPowerShellV2</Feature>
		<Feature Action="Enable">TelnetClient</Feature>
		<Feature Action="Enable">TFTP</Feature>
	</WindowsOptionalFeatures>
</Config>
"@

# Define functions main script actions.
filter Write-StdErrMessage
{
	# We can only truly write to stderr in a ConsoleHost.
	if (!$Host.Name.Equals('ConsoleHost'))
	{
		$Host.UI.WriteErrorLine($_)
		return
	}

	# Colour just like Write-Error and directly write to stderr.
	[System.Console]::BackgroundColor = [System.ConsoleColor]::Black
	[System.Console]::ForegroundColor = [System.ConsoleColor]::Red
	[System.Console]::Error.WriteLine($_)
	[System.Console]::ResetColor()
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

function Get-LogTimestamp
{
	return [System.DateTime]::Now.ToString('yyyy-MM-ddTHH:mm:ss')
}

filter Format-LogEntry
{
	return "[$(Get-LogTimestamp)] $_"
}

function Write-LogEntry ([Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][System.String]$Message)
{
	$Message | Format-LogEntry | Write-Host
}

function Install-Content
{
	# Mirror our extracted folder with our destination using Robocopy.
	robocopy.exe "$PWD\Content" $content /MIR /FP 2>&1 | ForEach-Object {
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

	# Switch on the exit code and update appropriately.
	switch ($LASTEXITCODE) {
		{$_ -ge 8} {
			throw "Transfer of content via robocopy.exe failed with exit code $LASTEXITCODE."
			break
		}
		{$_ -eq 0} {
			Write-LogEntry -Message "The required content is already correctly installed."
			break
		}
		default {
			Write-LogEntry -Message "Successfully installed required content."
			break
		}
	}
}

function Confirm-Content
{
	# Get all hashes from the destination.
	$dstHashes = Get-ChildItem -LiteralPath $content -Recurse -ErrorAction Ignore | Get-FileHash | Select-Object -ExpandProperty Hash

	# Throw if we have any invalid hashes.
	if (!$dstHashes -or (Compare-Object -ReferenceObject $srcHashes -DifferenceObject $dstHashes))
	{
		throw "The current content state is inconsistent with the source content."
	}
	Write-LogEntry -Message "Successfully confirmed content state."
}

# Get path to content.
$content = try {[System.Environment]::ExpandEnvironmentVariables(($xml = [xml]$config).Config.Content.Destination)} catch {$null}

# Install content if conditions are correct.
if (!$scrMode.Equals('Remove') -and $srcHashes -and $content -and !$xml.Config.Content.ChildNodes.LocalName.Contains('Source'))
{
	try
	{
		# Set up log file and start transcription.
		$logPath = [System.IO.Directory]::CreateDirectory("$Env:SystemRoot\Logs\$scrName").FullName
		$logFile = "$logPath\$($scrName)_$($scrMode)_$((Get-LogTimestamp).Replace(':',$null))_{0}.log"
		[System.Console]::WriteLine((Start-Transcript -LiteralPath ($logFile -f 'Transcript')))
		Write-LogEntry -Message "Commencing $($scrMode.ToLower()) process."

		# Perform content actions.
		[System.Management.Automation.ScriptBlock]::Create("$($scrMode)-Content").Invoke()
	}
	catch
	{
		# Get an inner exception if we have one.
		$thisError = $_ | Get-ErrorRecord

		# Handle messages we throw vs. cmdlets throwing exceptions.
		if (($thisError.CategoryInfo.Category -eq 'OperationStopped') -and ($thisError.CategoryInfo.Reason -eq 'RuntimeException'))
		{
			# Write the direct error message to StdErr.
			$thisError.Exception.Message | Format-LogEntry | Write-StdErrMessage
		}
		else
		{
			# A native cmdlet has errored out. Pretty up the message before writing it out.
			$thisError | Out-FriendlyErrorMessage | Format-LogEntry | Write-StdErrMessage
		}

		# Set an exit code that'll indicate failure.
		$exitCode = 1603
	}
	finally
	{
		# The Start/Stop-Transcript commands return actual strings that we don't want captured.
		[System.Console]::WriteLine((Stop-Transcript))

		# Exit if we have an exit code set.
		if (Get-Variable -Name exitCode -ErrorAction Ignore) {exit $exitCode}

		# Insert a peace-keeping line break before calling external script.
		[System.Console]::WriteLine()
	}
}

# With content potentially pre-seeded, finally call Invoke-DesiredStateManagementOperation.ps1 and do underlying operation.
Invoke-DesiredStateManagementOperation.ps1 -Mode $PSCmdlet.ParameterSetName -Config $config
exit $LASTEXITCODE
