
<#PSScriptInfo

.VERSION 2.3

.GUID c2f10730-e9d4-45e3-b6fa-3f0ddfc40f78

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
- Re-wrote port change method to not stage printers on a temp port and recreate, but rather directly use WMI to modify the existing port.
- Added `-ErrorAction Stop` to all native printer cmdlets since they don't respect CmdletBinding.
- Reworked script so incoming source data is pre-processed into objects of hashtables to remove several calls to `ConvertTo-Hashtable`.

#>

<#

.SYNOPSIS
This script installs/removes/validates/detects/remediates printers from a supplied JSON list.

.DESCRIPTION 
This script is a wrapper around Powershell's PrintManagement module to facilitate following operations:

- Installation
- Removal
- Validation
- Detection
- Remedation

The following printer types have been tested and supported.

- IP printers (RAW/JetDirect & LPD/LPR)
- IPP printers
- WSD printers
- UNC printers

For IP/IPP/WSD printers, you can configure port, config and properties needed to support the printer as required.
For UNC printers, a simple UNC path to the printer on its server is all that's needed to map it (and is all that's supported).

Source data is supplied in the form of a JSON list, either from the local file system or an HTTP site in the below format.

[
	{
		"Printer": {
			"DriverName": "HP Designjet 110plus",
			"Name": "Printer1",
			"PortName": "Printer1"
		},
		"Port": {
			"PortNumber": 9100,
			"Name": "Printer1",
			"SNMPCommunity": "public",
			"PrinterHostAddress": "printer1.domain.local",
			"SNMP": 1
		},
		"Config": {
			"Color": true,
			"DuplexingMode": "TwoSidedLongEdge",
			"PaperSize": "A4"
		}
	},
	{
		"Printer": {
			"DriverName": "Xerox GPD PCL6 V5.810.8.0",
			"Name": "Printer2",
			"PortName": "Printer2"
		},
		"Port": {
			"LprQueueName": "lp",
			"SNMP": 1,
			"Name": "Printer2",
			"SNMPCommunity": "public",
			"LprHostAddress": "printer2.domain.local"
		},
		"Properties": [
			{
				"PropertyName": "Config:Tray7_install",
				"Value": "INSTALLED"
			},
			{
				"PropertyName": "Config:Tray8_install",
				"Value": "INSTALLED"
			},
			{
				"PropertyName": "Config:Tray9_install",
				"Value": "INSTALLED"
			}
		]
	},
	{
		"Printer": {
			"DriverName": "HP Universal Printing PCL 6 (v7.0.0)",
			"Name": "Printer3",
			"DeviceURL": "printer3.domain.local"
		},
		"Config": {
			"Color": true,
			"DuplexingMode": "TwoSidedLongEdge",
			"PaperSize": "A4"
		}
	},
	{
		"Printer": {
			"Name": "Printer4",
			"DeviceURL": "printer4.domain.local"
		}
	},
	{
		"Printer": {
			"ConnectionName": "\\\\printserver.domain.local\\Printer5"
		}
	},
	{
		"Printer": {
			"DriverName": "HP Universal Printing PCL 6 (v7.0.0)",
			"Name": "Printer6",
			"PortName": "http://printserver.companydomain.com/Printers/Printer6/.printer"
		}
	}
]

From the examples 1-6, we respectfully have:

- A declared printer and driver/config with associated RAW/JetDirect port.
- A declared printer and driver/properties with associated LPD/LPR port.
- A declared printer and driver/config using WSD (Web Services for Devices).
- A declared printer without driver/config using WSD (Windows will find a Type 4 driver).
- A declared printer from a network server.
- A declared printer from an IPP server.

The key names in each object map to the following Powershell cmdlets.

Key Name    |  Cmdlet
----------  |  ----------
Printer     |  Add-Printer
Port        |  Add-PrinterPort
Config      |  Set-PrintConfiguration
Properties  |  Set-PrinterProperty

Anything key names that are not in the above examples but are supported by the cmdlet can be added as required.

If specifying a driver, it is the resposibility of the engineer to ensure the driver is in the system's
driver store or in the spooler. This can be performed via pnputil.exe or Powershell's Add-PrinterDriver.

.PARAMETER Install
Instructs the script to install printers off the supplied data list.

.PARAMETER Remove
Instructs the script to remove all printers in the source data if they're installed.

.PARAMETER Validate
Instructs the script to validate that installed printers are valid. Does not validate the state of deprecated printers.

.PARAMETER Detect
Instructs the script to detect that installed printers are valid, including whether deprecated printers need removing.

.PARAMETER Remediate
Instructs the script to repair all issues discovered by the detection routine. Re-runs detection after remediation.

.PARAMETER SourceData
File system path or URI to a JSON file with source printers for the required user that should be installed/validated during remediation.

.PARAMETER DeprecatedData
File system path or URI to a JSON file with depreated printers for the required user that should be removed during remediation.

.EXAMPLE
PS> Invoke-ManagedPrinterOperation.ps1 -SourceData \\fileserver.domain.local\netlogon\printers.json -Install

Invoke-ManagedPrinterOperation.ps1, Updated 2021-10-16.
Running as: RICHTERS-GPC01\mjr40
Source printer data: \\fileserver.domain.local\netlogon\printers.json
Deprecated printer data: Undefined
———————————————————————————————————————————————————————————————————————————————
Installing managed printer 'Printer1', please wait.
Added defined printer port to spooler.
Printer driver already exists in spooler.
Added defined printer as required.
Set specified printer configuration as required.
Set specified printer properties as required.
Installed managed printer successfully.
———————————————————————————————————————————————————————————————————————————————
Installing managed printer 'Printer2', please wait.
Added defined printer port to spooler.
Added defined printer driver to spooler.
Added defined printer as required.
Installed managed printer successfully.
———————————————————————————————————————————————————————————————————————————————
Installing managed printer 'Printer3', please wait.
Added defined printer port to spooler.
Printer driver already exists in spooler.
Added defined printer as required.
Installed managed printer successfully.
———————————————————————————————————————————————————————————————————————————————
Installation of printers completed successfully.

.EXAMPLE
PS> Invoke-ManagedPrinterOperation.ps1 -SourceData \\fileserver.domain.local\netlogon\printers.json -Remove

Invoke-ManagedPrinterOperation.ps1, Updated 2021-10-16.
Running as: RICHTERS-GPC01\mjr40
Source printer data: \\fileserver.domain.local\netlogon\printers.json
Deprecated printer data: Undefined
———————————————————————————————————————————————————————————————————————————————
Uninstalling managed printer 'Printer3', please wait.
Removed defined printer as required.
Removed unused printer port 'Printer3'.
Uninstalled managed printer successfully.
———————————————————————————————————————————————————————————————————————————————
Uninstalling managed printer 'Printer2', please wait.
Removed defined printer as required.
Removed unused printer driver 'Generic / Text Only'.
Removed unused printer port 'Printer2'.
Uninstalled managed printer successfully.
———————————————————————————————————————————————————————————————————————————————
Uninstalling managed printer 'Printer1', please wait.
Removed defined printer as required.
Removed unused printer port 'Printer1'.
Uninstalled managed printer successfully.
———————————————————————————————————————————————————————————————————————————————
Removal of printers completed successfully.

.EXAMPLE
PS> Invoke-ManagedPrinterOperation.ps1 -SourceData https://www.website.com/printers.json -DeprecatedData https://www.website.com/deprecated.json -Remediate

Invoke-ManagedPrinterOperation.ps1, Updated 2021-10-16.
Running as: RICHTERS-GPC01\mjr40
Source printer data: https://www.website.com/printers.json
Deprecated printer data: https://www.website.com/deprecated.json
———————————————————————————————————————————————————————————————————————————————
Updated managed printer properties for 'Printer1'.
———————————————————————————————————————————————————————————————————————————————
Remediation of printers completed successfully.

.INPUTS
None. You cannot pipe objects to Invoke-ManagedPrinterOperation.ps1.

.OUTPUTS
stdout stream. Invoke-ManagedPrinterOperation.ps1 returns a log string via Write-Host that can be piped.
stderr stream. Invoke-ManagedPrinterOperation.ps1 writes all error text to stderr for catching externally to PowerShell if required.
Transcription. A transcript of the execution is written to %LocalAppData% for administrator review.

.NOTES
*Changelog*

2.2
- Improvements to error handling logic.
- Improvements to text output to console for enhanced debugging.
- Implementation of script transcription logging to aid debugging after execution via Intune Proactive Remediation, etc.

2.1
- Tabbified code.
- Repaired issue where printers bound to multiple ports for removal were not removing each port one-by-one.
- Repaired issue where removal of SMB printer was testing whether to remove local printer ports.
- Repaired issue where log output was trying to read from the wrong variable on SMB printers.
- Repaired issue with removing printer drivers from local printers.
- Removed some of the pipelining (Where-Object vs. .Where(), ForEach-Object vs. .ForEach()) where it made sense to do so.
- Removed some use of `-eq`/`-ne` for the .Equals() method as it's faster and provides better null checks.

2.0
- Complete re-write to manage all types of printers and not just SMB printers.

1.0
- Initial release.
- Provides automated installation/removal/validation/detection/remediation of SMB printers.
- Designed specifically to work with Intune and its Proactive Remediation routines, but can work with group policy or SCCM as well.

#>

[CmdletBinding()]
Param (
	[Parameter(Mandatory = $true, ParameterSetName = 'Installation')]
	[System.Management.Automation.SwitchParameter]$Install,

	[Parameter(Mandatory = $true, ParameterSetName = 'Removal')]
	[System.Management.Automation.SwitchParameter]$Remove,

	[Parameter(Mandatory = $true, ParameterSetName = 'Validation')]
	[System.Management.Automation.SwitchParameter]$Validate,

	[Parameter(Mandatory = $true, ParameterSetName = 'Detection')]
	[System.Management.Automation.SwitchParameter]$Detect,

	[Parameter(Mandatory = $true, ParameterSetName = 'Remediation')]
	[System.Management.Automation.SwitchParameter]$Remediate,

	[Parameter(Mandatory = $true, ParameterSetName = 'Installation')]
	[Parameter(Mandatory = $true, ParameterSetName = 'Removal')]
	[Parameter(Mandatory = $true, ParameterSetName = 'Validation')]
	[Parameter(Mandatory = $true, ParameterSetName = 'Detection')]
	[Parameter(Mandatory = $true, ParameterSetName = 'Remediation')]
	[ValidatePattern('^((http(s)?:\/\/[\w\-./]+\/[\w\-./]+|([A-Z]:|\\\\[\w\-. ]+)\\([\w\-. ]+\\)+?[\w\-. ]+)|(\.\\)?[\w\-. ]+)\.json$')]
	[System.String]$SourceData,

	[Parameter(Mandatory = $false, ParameterSetName = 'Detection')]
	[Parameter(Mandatory = $false, ParameterSetName = 'Remediation')]
	[ValidatePattern('^((http(s)?:\/\/[\w\-./]+\/[\w\-./]+|([A-Z]:|\\\\[\w\-. ]+)\\([\w\-. ]+\\)+?[\w\-. ]+)|(\.\\)?[\w\-. ]+)\.json$')]
	[System.String]$DeprecatedData
)

# Set required variables to ensure script functionality.
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
Set-PSDebug -Strict
Set-StrictMode -Version Latest

# Define script properties.
$script = @{
	Invocation = $MyInvocation
	Name = $MyInvocation.MyCommand.Name
	Action = $PSCmdlet.ParameterSetName
	Username = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
	LogDivider = ([System.Char]0x2014).ToString() * 79
	TestResults = $null
	ErrorCount = 0
	ExitCode = 0
	Regex = @{
		HTTP = '^http(s)?:\/\/'
		UNC  = '^\\\\[\w\-.]+\\'
	}
}


#---------------------------------------------------------------------------
#
# Writes a string to stderr. By default, Powershell writes everything to stdout, even errors.
#
#---------------------------------------------------------------------------

filter Write-StdErrMessage
{
	# Test if we're in a console host or ISE.
	if ($Host.Name.Equals('ConsoleHost')) {
		# Colour the host 'Red' before writing, then reset.
		[System.Console]::ForegroundColor = [System.ConsoleColor]::Red
		[System.Console]::Error.WriteLine($_)
		[System.Console]::ResetColor()
	}
	else {
		# Use the Host's UI while in ISE.
		$Host.UI.WriteErrorLine($_)
	}
}


#---------------------------------------------------------------------------
#
# Returns a pretty multi-line error message derived from the provided ErrorRecord.
#
#---------------------------------------------------------------------------

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


#---------------------------------------------------------------------------
#
# Returns the incoming list of strings into a multiline bulleted list.
#
#---------------------------------------------------------------------------

function ConvertTo-BulletedList
{
	return "$($input -replace '^',"`n- ")"
}


#---------------------------------------------------------------------------
#
# Convert any object into a hashtable. Inspired by code that's been floating around for years.
#
#---------------------------------------------------------------------------

filter ConvertTo-Hashtable
{
	Param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		$InputObject
	)

	# Process piped object if it's not null.
	if ($InputObject -ne $null) {
		if (($InputObject -is [System.Collections.IEnumerable]) -and ($InputObject -isnot [System.String])) {
			# Input is an array/collection and requires recursion, but cannot be enumerated upon return.
			Write-Output -InputObject ($InputObject | ForEach-Object {ConvertTo-Hashtable -InputObject $_}) -NoEnumerate
		}
		elseif (($InputObject -is [System.Management.Automation.PSObject]) -and ($InputObject -isnot [System.String])) {
			# Input is an object, loop through its values and return hashtable as required.
			$hash = @{}; $InputObject.PSObject.Properties.ForEach({$hash[$_.Name] = ConvertTo-Hashtable -InputObject $_.Value}); $hash
		}
		elseif (($InputObject -isnot [System.String]) -or (![System.String]::IsNullOrWhiteSpace($InputObject))) {
			# If we're here, just return the incoming item.
			$InputObject
		}
	}
}


#---------------------------------------------------------------------------
#
# Output script header to console.
#
#---------------------------------------------------------------------------

function Out-ScriptHeader
{
	# Commence log transcription.
	$logDir = [System.IO.Directory]::CreateDirectory("$Env:LocalAppData\ScriptLogs\$($script.Name)").FullName
	$script.LogFile = "$logDir\$($script.Name)_$((Get-Date).ToString('yyyyMMddTHHmmss')).log"
	[System.Void](Start-Transcript -Path $script.LogFile)
	Write-Host "$($script.Name), Updated $((Get-Item -Path $script.Invocation.MyCommand.Path).LastWriteTime.ToString('yyyy-MM-dd'))."
	Write-Host "Running as: $($script.Username)"
	Write-Host "Logging to: $($script.LogFile)"
}


#---------------------------------------------------------------------------
#
# Test for confirming that piped properties have no duplicates.
#
#---------------------------------------------------------------------------

function Get-Duplicates
{
	if ($pipeline = $input.Where({$_})) {
		Compare-Object -ReferenceObject $pipeline -DifferenceObject ($pipeline | Select-Object -Unique) | Select-Object -ExpandProperty InputObject
	}
}


#---------------------------------------------------------------------------
#
# Queries supplied path for JSON printer information and returns it after validation.
#
#---------------------------------------------------------------------------

filter Get-ManagedPrinterData
{
	# Process string if not empty.
	if (![System.String]::IsNullOrWhiteSpace($_)) {
		# Get data from input, testing whether its a URI or a file system path, then convert to hashtables except for the outer layer.
		$data = $(if ($_ -match $script.Regex.HTTP) {Invoke-RestMethod -UseBasicParsing -Uri $_} else {Get-Content -Path $_ | ConvertFrom-Json}) |
			ConvertTo-Hashtable |
				ForEach-Object {[pscustomobject]$_}

		# Process if we actually have some data. We may have none if it's an empty deprecated list, etc.
		if ($data) {
			# Ensure all printer Name fields are unique.
			if (($names = $data.Printer | Where-Object {$_.ContainsKey('Name')} | ForEach-Object {$_.Name}) | Get-Duplicates) {
				throw "Returned data from '$_' has multiple printers with identical 'Name' fields, this is not supported."
			}

			# Ensure all printer ConnectionName fields are unique.
			if (($connectionNames = $data.Printer | Where-Object {$_.ContainsKey('ConnectionName')} | ForEach-Object {$_.ConnectionName}) | Get-Duplicates) {
				throw "Returned data from '$_' has multiple printers with identical 'ConnectionName' fields, this is not supported."
			}

			# Test that we actually have any names at all.
			if (!$names -and !$connectionNames) {
				throw "Returned data from '$_' has no printers defined with a 'Name' or 'ConnectionName' field, this is not supported."
			}

			# Start testing the objects in the array.
			foreach ($item in $data) {
				# Test that this object at least has a printer definition.
				if (!$item.PSObject.Properties.Where({$_.Name.Equals('Printer')})) {
					throw "A printer is defined without a mandatory 'Printer' object, this is not supported."
				}

				# Test that each printer doesn't contain both a 'ConnectionName' key and a 'Name' key.
				if ($item.Printer.ContainsKey('ConnectionName') -and $item.Printer.ContainsKey('Name')) {
					throw "The printer '$($item.Printer.ConnectionName)'/'$($item.Printer.Name)' has both 'ConnectionName' and 'Name' properties defined, this is not supported."
				}

				# Test that each object is unique.
				$item.PSObject.Properties.Name | Get-Duplicates | ForEach-Object {
					throw "The printer '$($item.Printer | Get-ManagedPrinterDataName)' contains multiple '$_' definitions, this is not supported."
				}

				# Test that each key in each object is unique.
				$item.PSObject.Properties | Where-Object {$_.Value | ForEach-Object {$_.Keys | Get-Duplicates}} | ForEach-Object {
					throw "The printer '$($item.Printer | Get-ManagedPrinterDataName)' has duplicate properties in its '$($_.Name)' definition, this is not supported."
				}

				# If this is an SMB printer, test to ensure it has nothing else defined other than a ConnectionName.
				if ($item.Printer.ContainsKey('ConnectionName')) {
					# Test if we've got objects other than just 'Printer'.
					if ($item.PSObject.Properties.Name.Where({!$_.Equals('Printer')})) {
						throw "The printer '$($item.Printer.ConnectionName)' has objects other than 'Printer' defined, this is not supported."
					}

					# Test if the printer object has keys beyond 'ConnectionName'.
					if ($item.Printer.Keys.Where({!$_.Name.Equals('ConnectionName')})) {
						throw "The printer '$($item.Printer.ConnectionName)' has keys other than 'ConnectionName' specified, this is not supported."
					}

					# Test that printer's connection name is a UNC path.
					if ($item.Printer.ConnectionName -notmatch $script.Regex.UNC) {
						throw "The printer '$($item.Printer.ConnectionName)' has a ConnectionName that is not a valid UNC path, this is not supported."
					}
				}
			}

			# Return data to the pipeline.
			return $data
		}
	}
}


#---------------------------------------------------------------------------
#
# Processes incoming printer record and returns ConnectionName if it exists, otherwise Name.
#
#---------------------------------------------------------------------------

filter Get-ManagedPrinterDataName
{
	# Return ConnectionName if it exists, otherwise just Name. A printer can never have both.
	if ($_.ContainsKey('ConnectionName')) {$_.ConnectionName} else {$_.Name}
}


#---------------------------------------------------------------------------
#
# Get source and deprecated printer data for script.
#
#---------------------------------------------------------------------------

function Initialize-ScriptDatabase
{
	# Get data from all sources.
	$script.Data = @{
		Source = $SourceData | Get-ManagedPrinterData
		Deprecated = $DeprecatedData | Get-ManagedPrinterData
		Destination = Get-Printer
	}

	# Test that we actually received some source data.
	if (!$script.Data.Source) {
		throw "The query for source data from '$SourceData' returned a null result."
	}

	# Get ports and add to data set.
	$portnames = $script.Data.Source | Where-Object {$_.PSObject.Properties.Name -contains 'Port'} | ForEach-Object {$_.Port.Name}
	$script.Data.Ports = Get-WmiObject -Class Win32_TCPIPPrinterPort | Where-Object {$portnames -contains $_.Name}

	# Get all printer names and store.
	$script.PrinterNames = @{
		Source = $script.Data.Source.Printer | Get-ManagedPrinterDataName
		Deprecated = $script.Data.Deprecated | ForEach-Object {$_.Printer | Get-ManagedPrinterDataName}  # Deprecated data can be null.
		Destination = $script.Data.Destination | Select-Object -ExpandProperty Name
	}

	# Update console with printer statistics.
	Write-Host "Source printer data: $SourceData"
	Write-Host "Deprecated printer data: $(if ($DeprecatedData) {$DeprecatedData} else {'Not Provided'})"
	Write-Host $script.LogDivider
}


#---------------------------------------------------------------------------
#
# Get and return all installed printers that are specified in the source.
#
#---------------------------------------------------------------------------

function Get-ManagedPrinter ([ValidateSet('Current','Deprecated')][System.String[]]$Type)
{
	# Return all installed printer that are currently in the source data.
	if (!$Type -or ($Type -match 'Current')) {
		$script.Data.Destination | Where-Object {$script.PrinterNames.Source -contains $_.Name}
	}

	# Return all installed printer that are currently in the deprecated data.
	if (!$Type -or ($Type -match 'Deprecated')) {
		$script.Data.Destination | Where-Object {$script.PrinterNames.Deprecated -contains $_.Name}
	}
}


#---------------------------------------------------------------------------
#
# Filters incoming printers against source printers to determine what has an incorrect driver.
#
#---------------------------------------------------------------------------

filter Get-ManagedPrinterMismatchedDriver
{
	# Process only if this is not an SMB printer.
	if ($_.Name -notmatch $script.Regex.UNC) {
		# Get currently iterated printer from printers with driver defined.
		$sourcedriver = $script.Data.Source.Printer |
			Where-Object ([scriptblock]::Create("`$_.Name.Equals('$($_.Name)') -and `$_.ContainsKey('DriverName')")) |
				ForEach-Object {$_.DriverName}

		# Test printer's driver against source and output a hashtable if changes are required.
		if ($sourcedriver -and !$sourcedriver.Equals($_.DriverName)) {
			@{
				Name = $_.Name
				DriverName = $_.DriverName
			}
		}
	}
}


#---------------------------------------------------------------------------
#
# Filters incoming printers against source printers to determine has incorrect config.
#
#---------------------------------------------------------------------------

filter Get-ManagedPrinterMismatchedConfig
{
	# Get any printers with config.
	$config = $script.Data.Source |
		Where-Object ([scriptblock]::Create("`$_.Printer.Name.Equals('$($_.Name)') -and `$_.PSObject.Properties.Name -contains 'Config'")) |
			Select-Object -ExpandProperty Config

	# Process if we have config.
	if ($config) {
		# Get config from spooler.
		$current = Get-PrintConfiguration -PrinterName $_.Name

		# Output config hashtable if there's any found.
		if ($config.GetEnumerator().Where({!$current.($_.Name).Equals($_.Value)})) {
			$config.PrinterName = $_.Name; $config
		}
	}
}


#---------------------------------------------------------------------------
#
# Filters incoming printers against source printers to determine what has incorrect properties.
#
#---------------------------------------------------------------------------

filter Get-ManagedPrinterMismatchedProperties
{
	# Get any printers with properties.
	$props = $script.Data.Source |
		Where-Object ([scriptblock]::Create("`$_.Printer.Name.Equals('$($_.Name)') -and `$_.PSObject.Properties.Name -contains 'Properties'")) |
			Select-Object -ExpandProperty Properties

	# Process if we have properties.
	if ($props) {
		# Get properties from spooler.
		$existing = Get-PrinterProperty -PrinterName $_.Name

		# Determine whether changes are needed.
		$mismatches = foreach ($prop in $props) {
			# Test if the property is valid and throw if not, otherwise just compare it.
			if (!($current = $existing | Where-Object {$_.PropertyName.Equals($prop.PropertyName)})) {
				throw "The property '$($prop.PropertyName)' for printer '$($_.Name)' was not found."
			}
			elseif (!$current.Value.Equals($prop.Value)) {
				$prop.PrinterName = $_.Name; $prop
			}
		}

		# If there's a mismatch, return it in a non-enumerated way.
		if ($mismatches) {Write-Output -InputObject $mismatches -NoEnumerate}
	}
}


#---------------------------------------------------------------------------
#
# Filters incoming printer port against translator and returns new object to the pipeline.
#
#---------------------------------------------------------------------------

function Get-ManagedPrinterTranslatedPort
{
	begin {
		# Define translator for property names that differ between Add-PrinterPort and WMI. May require additions over time.
		$translator = @{
			SNMP = 'SNMPDevIndex'
			LprQueueName = 'Queue'
			LprHostAddress = 'HostAddress'
			PrinterHostAddress = 'HostAddress'
		}
	}

	process {
		# Open new hashtable, translate out the properties and return new object to the pipeline.
		$port = @{}; $_.Port.GetEnumerator().ForEach({$port.Add($(if ($translator.ContainsKey($_.Name)) {$translator[$_.Name]} else {$_.Name}), $_.Value)})
		[pscustomobject]$port
	}
}


#---------------------------------------------------------------------------
#
# Filters incoming printers against source printers to determine what port settings are incorrect.
#
#---------------------------------------------------------------------------

function Get-ManagedPrinterMismatchedPort
{
	# Get all unique port names from incoming printers and continue if there's ports to process.
	if ($portsinuse = $input.Where({$_.Name -notmatch $script.Regex.UNC}) | Select-Object -ExpandProperty PortName -Unique) {
		# Build list of unique ports.
		$ports = $script.Data.Source | Where-Object {($_.PSObject.Properties.Name -contains 'Port') -and ($portsinuse -contains $_.Port.Name)} |
			Get-ManagedPrinterTranslatedPort | Group-Object -Property Name | ForEach-Object {$_.Group | Select-Object -First 1}

		# Process each unique source port and test for differences.
		foreach ($port in $ports) {
			# Get port from spooler.
			$existing = $script.Data.Ports | Where-Object {$_.Name.Equals($port.Name)}

			# Determine needed changes and return with appended name if any are found.
			$changes = @{}; $port.PSObject.Properties.Where({!$existing.($_.Name).Equals($_.Value)}).ForEach({$changes.Add($_.Name, $_.Value)})
			if ($changes.Count) {$changes.Name = $port.Name; $changes}
		}
	}
}


#---------------------------------------------------------------------------
#
# Processes provided values to install managed printer to specification.
#
#---------------------------------------------------------------------------

filter Install-ManagedPrinter
{
	Param (
		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[ValidateNotNullOrEmpty()]
		[System.Collections.Hashtable]$Printer,

		[Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
		[ValidateNotNullOrEmpty()]
		[System.Collections.Hashtable]$Port,

		[Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
		[ValidateNotNullOrEmpty()]
		[System.Collections.Hashtable]$Config,

		[Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
		[ValidateNotNullOrEmpty()]
		[System.Collections.Hashtable[]]$Properties
	)

	# Test if this is an SMB printer and install accordingly.
	if ($Printer.ContainsKey('ConnectionName')) {
		Write-Host "Installing managed printer '$($Printer.ConnectionName)', please wait."
		try {
			Add-Printer -ConnectionName $Printer.ConnectionName -ErrorAction Stop
			Write-Host "Installed managed printer '$($Printer.ConnectionName)'."
		}
		catch {
			$_ | Out-FriendlyErrorMessage -ErrorPrefix "Error installing managed printer '$($Printer.ConnectionName)'." | Write-StdErrMessage
			$script.ErrorCount++
		}
	}
	else {
		# Commence printer installation.
		Write-Host "Installing managed printer '$($Printer.Name)', please wait."; $successful = $true

		# If printer includes a specified driver, process that before adding printer.
		if ($Printer.ContainsKey('DriverName')) {
			# Add driver to the spooler if it doesn't exist. This requires that the
			# driver be available in the system's central store prior to execution.
			if (!(Get-PrinterDriver -Name $Printer.DriverName -ErrorAction Ignore)) {
				try {
					Add-PrinterDriver -Name $Printer.DriverName -ErrorAction Stop
					Write-Host "Added defined printer driver to spooler."
				}
				catch {
					$_ | Out-FriendlyErrorMessage -ErrorPrefix "Error adding printer driver '$($Printer.DriverName)' to spooler." | Write-StdErrMessage
					$script.ErrorCount++
					Write-Host $script.LogDivider
					return
				}
			}
			else {
				Write-Host "Printer driver already exists in spooler."
			}
		}

		# If we're including a port definition, process that before adding printer.
		if ($Port) {
			# Add port to the spooler if it doesn't exist.
			if (!(Get-PrinterPort -Name $Printer.PortName -ErrorAction Ignore)) {
				try {
					Add-PrinterPort @Port -ErrorAction Stop
					Write-Host "Added defined printer port to spooler."
				}
				catch {
					$_ | Out-FriendlyErrorMessage -ErrorPrefix "Error adding printer port '$($Printer.PortName)' to spooler." | Write-StdErrMessage
					$script.ErrorCount++
					Write-Host $script.LogDivider
					return
				}
			}
			else {
				Write-Host "Printer port already exists in spooler."
			}
		}

		# Now, let's add the printer.
		try {
			Add-Printer @Printer -ErrorAction Stop
			Write-Host "Added defined printer as required."
		}
		catch {
			$_ | Out-FriendlyErrorMessage -ErrorPrefix "Error adding defined printer '$($Printer.Name)'." | Write-StdErrMessage
			$script.ErrorCount++
			Write-Host $script.LogDivider
			return
		}

		# If we're including a config definition, process it.
		if ($Config) {
			try {
				Set-PrintConfiguration -PrinterName $Printer.Name @Config -ErrorAction Stop
				Write-Host "Set specified printer configuration as required."
			}
			catch {
				$_ | Out-FriendlyErrorMessage -ErrorPrefix "Error setting printer configuration for '$($Printer.Name)'." | Write-StdErrMessage
				$script.ErrorCount++
				$successful = $false
			}
		}

		# If we're including a properties definition, process it.
		if ($Properties) {
			# Process each item in the properties array.
			$properrors = $false
			foreach ($prop in $Properties) {
				try {
					Set-PrinterProperty -PrinterName $Printer.Name @prop -ErrorAction Stop
				}
				catch {
					$_ | Out-FriendlyErrorMessage -ErrorPrefix "Error setting printer property '$($prop.PropertyName)' for '$($Printer.Name)'." | Write-StdErrMessage
					$script.ErrorCount++
					$successful = $false
					$properrors = $true
				}
			}

			# Advise of success if we had any.
			Write-Host "Set specified printer properties $(if (!$properrors) {'as required'} else {'with errors'})."
		}

		# Advise of success.
		Write-Host "Installed managed printer $(if ($successful) {'successfully'} else {'with errors. Please review and remediate as required'})."
	}

	# Insert line break for log legibility.
	Write-Host $script.LogDivider
}


#---------------------------------------------------------------------------
#
# Removes provided printer from spooler, and also removes driver and port of printer if no longer in use.
#
#---------------------------------------------------------------------------

filter Remove-ManagedPrinter
{
	# Commence printer installation.
	Write-Host "Uninstalling managed printer '$(($InputObject = $_).Name)', please wait."
	$successful = $true

	# Remove printer as required, but store before doing so as we need its data for later.
	try {
		$InputObject | Remove-Printer -ErrorAction Stop
		Write-Host "Removed defined printer as required."
	}
	catch {
		$_ | Out-FriendlyErrorMessage -ErrorPrefix "Error removing defined printer '$($InputObject.Name)'." | Write-StdErrMessage
		$script.ErrorCount++
		Write-Host $script.LogDivider
		return
	}

	# Test whether other printers are using the driver, and remove driver if not.
	if (!(Get-Printer | Where-Object {$_.DriverName.Equals($InputObject.DriverName)})) {
		try {
			Remove-PrinterDriver -Name $InputObject.DriverName -ErrorAction Stop
			Write-Host "Removed unused printer driver '$($InputObject.DriverName)'."
		}
		catch {
			$_ | Out-FriendlyErrorMessage -ErrorPrefix "Error removing printer driver '$($InputObject.PrinterDriver)' from spooler." | Write-StdErrMessage
			$script.ErrorCount++
			$successful = $false
		}
	}

	# If we're removing a local printer, test whether other printers are using the port and remove port if not.
	if (($InputObject.Name -notmatch $script.Regex.UNC) -and !(Get-Printer | Where-Object {$_.PortName.Equals($InputObject.PortName)})) {
		try {
			Remove-PrinterPort -Name $InputObject.PortName -ErrorAction Stop
			Write-Host "Removed unused printer port '$($InputObject.PortName)'."
		}
		catch {
			$_ | Out-FriendlyErrorMessage -ErrorPrefix "Error removing printer port '$($InputObject.PortName)' from spooler." | Write-StdErrMessage
			$script.ErrorCount++
			$successful = $false
		}
	}

	# Advise of success.
	Write-Host "Uninstalled managed printer $(if ($successful) {'successfully'} else {'with errors. Please review and remediate as required'})."
	Write-Host $script.LogDivider
}


#---------------------------------------------------------------------------
#
# Changes a printer's driver to the incoming value.
#
#---------------------------------------------------------------------------

function Update-ManagedPrinterDriver
{
	process {
		# Change driver to piped values.
		try {
			Set-Printer @_ -ErrorAction Stop
			Write-Host "Updated managed printer driver for '$($_.Name)'."
		}
		catch {
			$_ | Out-FriendlyErrorMessage -ErrorPrefix "Error updating managed printer driver for '$($input.Name)'." | Write-StdErrMessage
			$script.ErrorCount++
		}
	}

	end {
		# Insert line break for log legibility.
		Write-Host $script.LogDivider
	}
}


#---------------------------------------------------------------------------
#
# Changes a printer's config to the incoming values.
#
#---------------------------------------------------------------------------

function Update-ManagedPrinterConfig
{
	process {
		# Change config to piped values.
		try {
			Set-PrintConfiguration @_ -ErrorAction Stop
			Write-Host "Updated managed printer config for '$($_.PrinterName)'."
		}
		catch {
			$_ | Out-FriendlyErrorMessage -ErrorPrefix "Error updating managed printer config for '$($input.PrinterName)'." | Write-StdErrMessage
			$script.ErrorCount++
		}
	}

	end {
		# Insert line break for log legibility.
		Write-Host $script.LogDivider
	}
}


#---------------------------------------------------------------------------
#
# Changes a printer's properties to the incoming values.
#
#---------------------------------------------------------------------------

function Update-ManagedPrinterProperties
{
	process {
		# Apply properties as required.
		$properrors = $false; $printername = $_.PrinterName | Sort-Object -Unique
		foreach ($prop in $_) {
			try {
				Set-PrinterProperty @prop -ErrorAction Stop
			}
			catch {
				$_ | Out-FriendlyErrorMessage -ErrorPrefix "Error updating managed printer property '$($prop.PropertyName)' for '$printername'." | Write-StdErrMessage
				$script.ErrorCount++
				$properrors = $true
			}
		}

		# Advise on our success.
		Write-Host "Updated managed printer properties for '$printername'$(if ($properrors) {' with errors'})."
	}

	end {
		# Insert line break for log legibility.
		Write-Host $script.LogDivider
	}
}


#---------------------------------------------------------------------------
#
# Reconfigure a printer port as required.
#
#---------------------------------------------------------------------------

function Update-ManagedPrinterPort
{
	process {
		# Update printer port and advise of success.
		$port = $script.Data.Ports | Where-Object ([scriptblock]::Create("`$_.Name.Equals('$($_.Name)')"))
		$_.GetEnumerator().Where({!$_.Name.Equals('Name')}) | ForEach-Object {$port.($_.Name) = $_.Value}; [System.Void]$port.Put()
		Write-Host "Updated managed printer port '$($_.Name)'."
	}

	end {
		# Insert line break for log legibility.
		Write-Host $script.LogDivider
	}
}


#---------------------------------------------------------------------------
#
# Runs specified tests against all managed printers and returns results for further processing.
#
#---------------------------------------------------------------------------

function Get-ManagedPrinterState
{
	# Get currently installed printers first as we need this multiple times.
	$installed = Get-ManagedPrinter -Type Current

	# Return results from all specified tests.
	return [pscustomobject]@{
		Missing    = $script.Data.Source | Where-Object {$script.PrinterNames.Destination -notcontains ($_.Printer | Get-ManagedPrinterDataName)}
		Remaining  = Get-ManagedPrinter -Type Deprecated
		Driver     = $installed | Get-ManagedPrinterMismatchedDriver
		Config     = $installed | Get-ManagedPrinterMismatchedConfig
		Properties = $installed | Get-ManagedPrinterMismatchedProperties
		Port       = $installed | Get-ManagedPrinterMismatchedPort
	}
}


#---------------------------------------------------------------------------
#
# Advises of any printer issues found in the test results.
#
#---------------------------------------------------------------------------

function Test-ManagedPrinterState
{
	# Get printer test results and store.
	$results = Get-ManagedPrinterState

	# Process results to build issue array.
	$script.TestResults = $(
		if ($results.Missing) {
			"The following required printers are missing:$($results.Missing.Printer | Get-ManagedPrinterDataName | ConvertTo-BulletedList)"
		}
		if ($results.Remaining) {
			"The following deprecated printers need removing:$($results.Remaining.Name | ConvertTo-BulletedList)"
		}
		if ($results.Driver) {
			"The following printers have incorrect drivers:$($results.Driver.Name | ConvertTo-BulletedList)"
		}
		if ($results.Config) {
			"The following printers have incorrect defaults:$($results.Config.PrinterName | ConvertTo-BulletedList)"
		}
		if ($results.Properties) {
			"The following printers have incorrect properties:$($results.Properties.PrinterName | Select-Object -Unique | ConvertTo-BulletedList)"
		}
		if ($results.Port) {
			"The following printer ports are incorrect:$($results.Port.Name | ConvertTo-BulletedList)"
		}
	)

	# If any issues are found, throw with $script.TestResults array joined with line feeds.
	if ($script.TestResults) {throw $script.TestResults -join "`n"}
}


#---------------------------------------------------------------------------
#
# Remediates any printer issues found in the test results.
#
#---------------------------------------------------------------------------

function Resolve-ManagedPrinterState
{
	# Get printer test results and store.
	$results = Get-ManagedPrinterState

	# If we have something to remediate, proceed to do so.
	if ($results.Missing) {
		$results.Missing | Install-ManagedPrinter
	}
	if ($results.Remaining) {
		$results.Remaining | Remove-ManagedPrinter
	}
	if ($results.Driver) {
		$results.Driver | Update-ManagedPrinterDriver
	}
	if ($results.Config) {
		$results.Config | Update-ManagedPrinterConfig
	}
	if ($results.Properties) {
		$results.Properties | Update-ManagedPrinterProperties
	}
	if ($results.Port) {
		$results.Port | Update-ManagedPrinterPort
	}
}


#---------------------------------------------------------------------------
#
# Switch on the script's parameter set and perform any required operations.
#
#---------------------------------------------------------------------------

function Invoke-ManagedPrinterOperation
{
	# Start actions.
	switch -regex ($script.Action) {
		'^(Installation|Remediation)$' {
			# Install/Remediate printers as needed.
			Resolve-ManagedPrinterState
			break
		}
		'^Removal$' {
			# Remove printers as needed.
			# Just current printers for now, unsure whether to support deprecated printer operations in an install/remove/validate operation.
			Get-ManagedPrinter -Type Current | Remove-ManagedPrinter
			break
		}
		'^(Validation|Detection)$' {
			# Detect whether all printer states are valid.
			Test-ManagedPrinterState
		}
	}

	# Advise on success of action.
	$errsuffix = "with $($script.ErrorCount) error$(if (!$script.ErrorCount.Equals(1)) {'s'}). Please review the log file for further information"
	Write-Host "$($script.Action) of printers completed $(if (!$script.ErrorCount) {'successfully'} else {$errsuffix})."
}


#---------------------------------------------------------------------------
#
# Main execution code block for script.
#
#---------------------------------------------------------------------------

try
{
	Out-ScriptHeader
	Initialize-ScriptDatabase
	Invoke-ManagedPrinterOperation
}
catch
{
	# Test whether the exception are test results to remediate or its a proper hard throw.
	if ($_.Exception.Message.Equals($script.TestResults)) {
		$_.Exception.Message | Write-StdErrMessage
		Write-Host $script.LogDivider
		Write-Host "Please execute this script again with '-Remediate' to repair the reported issues."

		# Exit with 1 so Intune can remediate.
		$script.ExitCode = 1
	}
	else {
		$_ | Out-FriendlyErrorMessage -ErrorPrefix "Error occured during $($script.Action.ToLower()) process." | Write-StdErrMessage
		Write-Host $script.LogDivider
		Write-Host "Please review the log file at '$($script.LogFile)' for further information."

		# Exit with 1 only if we're not performing a detection. If we get here on a detection, it's a non-remediatable issue.
		if (!$script.Action.Equals('Detection')) {$script.ExitCode = 1}
	}
}
finally
{
	Stop-Transcript | Out-Null
	exit $script.ExitCode
}
