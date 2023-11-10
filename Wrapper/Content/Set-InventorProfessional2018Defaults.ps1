
<#PSScriptInfo

.VERSION 1.0

.GUID c2f10730-e9d4-45e3-b6fa-3f0ddfc40f78

.AUTHOR Mitch Richters (mitch.richters@crosspoint.com.au).

.COMPANYNAME CrossPoint Technology Solutions

.COPYRIGHT Copyright (C) 2021 CrossPoint Technology Solutions. All rights reserved.

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
This script installs Autodesk Inventor Professional 2018 defaults.

#>

# Set required variables to ensure script functionality.
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
Set-PSDebug -Strict
Set-StrictMode -Version Latest

# Define variables for application data.
$basepath = "$env:APPDATA\Autodesk\Inventor 2018"
$cadsetup = "$env:SystemDrive\`$CADSETUP"

# Store file templates.
$addinTemplate = @'
<?xml version="1.0" encoding="utf-16" standalone="no" ?>
<Addin>

  <!--Created by Autodesk Inventor Version 22.3 Production Candidate-->

  <!--Override settings for ApplicationAddIn: {0}-->

  <ClassId>{1}</ClassId>

  <ClientId>{1}</ClientId>

  <LoadOnStartUp>0</LoadOnStartUp>

</Addin>
'@
$ilogicTemplate = @'
<?xml version="1.0" encoding="utf-8"?>
<ShareableOptions xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <ExternalRuleDirectories>
	<string>{0}\IV\iLogic</string>
  </ExternalRuleDirectories>
</ShareableOptions>
'@
$optionsTemplate = @'
<?xml version="1.0" encoding="utf-16" standalone="no" ?>
<ApplicationOptions Platform="Vista" Version="22.3 Production Candidate">

  <!--Created by Autodesk Inventor Version 22.3 Production Candidate-->

  <!--The schema of this file is subject to change without notice and is not guaranteed to remain the same from one release to the next.-->

  <File DesignDataPath="{0}\IV\PAU\Design Data 2018\" SymbolLibPath="{0}\IV\PAU\Symbol Library 2018\" TemplatesPath="{0}\IV\PAU\Templates 2018\" UndoPath="{1}\"/>

  <Drawing ViewBlockInsPointViewCenter="0"/>

  <Sketch DisplayMinorGridLines="0"/>

  <Assembly AssemblyLiteUniqueDocCount="999999" EnableAssemblyLite="0" PartFeaturesInitiallyAdaptive="1"/>

  <ContentCenter DesktopContentDir="{0}\IV\CC2018\" OverwriteOutOfDateParts="1"/>

</ApplicationOptions>
'@

# Define functions for usage within script.
function Out-AddinFiles
{
	# Define hashtable of addins, using filename as key to hashtable with friendly name and GUID.
	$addins = @{
		'autodesk.studio.inventor.addin' = @{
			Name = 'Inventor Studio'
			GUID = '{F3D38928-74D1-4814-8C24-A74CE8F3B2E3}'
		}
		'autodesk.AdditiveMFG.inventor.addin' = @{
			Name = 'Additive Manufacturing'
			GUID = '{4E2D52FB-8288-4427-B912-20EF97F073C9}'
		}
		'autodesk.bimexchange.inventor.addin' = @{
			Name = 'BIM Content'
			GUID = '{842004D5-C360-43A8-A00D-D7EB72DAAB69}'
		}
		'autodesk.dynamicsimulation.inventor.addin' = @{
			Name = 'Simulation: Dynamic Simulation'
			GUID = '{24307C2D-2E7F-486F-94A0-0B45E11CB3F6}'
		}
		'autodesk.FeatureRecognition_NG.inventor.addin' = @{
			Name = 'BIM Simplify'
			GUID = '{71019C12-43F6-4C11-BA7A-AD9BDBC5EA0C}'
		}
		'autodesk.frameanalysis.inventor.addin' = @{
			Name = 'Frame Analysis'
			GUID = '{4E7C0152-6140-419F-B677-0466F03F013D}'
		}
		'autodesk.GrantaGateway.inventor.addin' = @{
			Name = 'Eco Materials Adviser'
			GUID = '{37A9F55E-9073-431A-9AD6-97840ABF765E}'
		}
		'autodesk.molddesign.inventor.addin' = @{
			Name = 'Mold Design'
			GUID = '{24E39891-3782-448F-8C33-0D8D137148AC}'
		}
		'autodesk.icopy.inventor.addin' = @{
			Name = 'iCopy'
			GUID = '{A2BE2CFE-CECC-4A49-BD04-A90939D1EB07}'
		}
		'autodesk.nastranincad.inventor.addin' = @{
			Name = 'Autodesk Nastran In-CAD 2018'
			GUID = '{4E5B55CA-564E-472F-8310-04F21EFC1399}'
		}
		'autodesk.simulationstressanalysis.inventor.addin' = @{
			Name = 'Simulation: Stress Analysis'
			GUID = '{B3D04494-EDD2-4FDC-9EC2-30BAF8D6B77B}'
		}
		'autodesk.routedsystemstube&pipe.inventor.addin' = @{
			Name = 'Routed Systems: Tube & Pipe'
			GUID = '{4D39D5F1-0985-4783-AA5A-FC16C288418C}'
		}
		'autodesk.routedsystemscable&harness.inventor.addin' = @{
			Name = 'Routed Systems: Cable & Harness'
			GUID = '{C6107C9D-C53F-4323-8768-F65F857F9F5A}'
		}
	}

	# Enumerate hashtable and generate output files.
	$outputdir = [System.IO.Directory]::CreateDirectory("$basepath\Addins").FullName
	$addins.GetEnumerator() | ForEach-Object {$addinTemplate -f $_.Value.Name, $_.Value.GUID | Out-File -FilePath "$outputdir\$($_.Name).xml" -Force}
}

function Out-iLogicOptions
{
	# Generate iLogicOptions.xml.
	$ilogicTemplate -f $cadsetup | Out-File -FilePath "$([System.IO.Directory]::CreateDirectory("$basepath\iLogicPreferences").FullName)\iLogicOptions.xml" -Encoding utf8 -Force
}

function Out-UserApplicationOptions
{
	# Generate UserApplicationOptions.xml.
	$optionsTemplate -f $cadsetup, $env:TEMP | Out-File -FilePath "$([System.IO.Directory]::CreateDirectory($basepath).FullName)\UserApplicationOptions.xml" -Force
}

function Get-AutodeskInventorUsername
{
	# Get name and store. This is expected to be in the format of "Surname, Firstname".
	$displayName = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\SessionData" | Get-ItemProperty | Where-Object {$_.LoggedOnUser -eq (whoami.exe 2>&1)} | Select-Object -ExpandProperty LoggedOnDisplayName

	# Get name constituents.
	$firstInitial = $displayName.Substring($displayName.IndexOf(',')+1).Trim().Substring(0, 1)
	$surname = $displayName.Substring(0, $displayName.IndexOf(',')).Trim()

	# Return format of first initial, dot, then surname.
	return "$firstInitial. $surname"
}

function Import-RegistryData
{
	# Define Inventor 2018 registry data.
	$regData = [ordered]@{
		'HKCU:\SOFTWARE\Autodesk\Inventor\RegistryVersion22.0\System\Preferences\Display' = @(
			@{
				Name         = 'VS Using Document Settings Option'
				Value        = 0x0
				PropertyType = [Microsoft.Win32.RegistryValueKind]::DWord
			}
			@{
				Name         = 'VisualStyle type'
				Value        = 0x6
				PropertyType = [Microsoft.Win32.RegistryValueKind]::DWord
			}
			@{
				Name         = 'VS Edge Color'
				Value        = '0,0,0,1'
				PropertyType = [Microsoft.Win32.RegistryValueKind]::String
			}
			@{
				Name         = 'TexturesOnOff'
				Value        = 0x0
				PropertyType = [Microsoft.Win32.RegistryValueKind]::DWord
			}
		)
		'HKCU:\SOFTWARE\Autodesk\Inventor\RegistryVersion22.0\System\Preferences\File' = @(
			@{
				Name         = 'UserName'
				Value        = Get-AutodeskInventorUsername
				PropertyType = [Microsoft.Win32.RegistryValueKind]::String
			}
		)
	}

	# Create registry items.
	foreach ($regKey in $regData.GetEnumerator()) {
		$keyPath = New-Item -Path $regKey.Key -Force
		$regKey.Value | ForEach-Object {$keyPath | New-ItemProperty @psitem -Force} | Out-Null
	}
}

# Don't apply if we have a log file from `Set-UserDefaults.ps1`.
if ([System.IO.Directory]::Exists("$env:LOCALAPPDATA\Schenck\ScriptLogs\Set-UserDefaults.ps1")) {exit}

# Do outputs and imports.
Out-UserApplicationOptions
Out-iLogicOptions
Out-AddinFiles
Import-RegistryData
