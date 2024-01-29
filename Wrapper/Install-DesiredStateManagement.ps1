
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

# Source hashes for all content to copy. Command to generate: Out-FileHashDataMap -LiteralPath "$PWD\Content" -PlainText
$dataMap = [ordered]@{
    "Autopilot.jpg" = 'E7B88BD693809CD30B5D3290D2D70B08E244F2465C49419F4EF13F72F5AF32DB'
    "Autopilot.theme" = 'DE06FD8C251BA3746754515DB16C63441AB4BE5A6034D3E9DD35576346A665EA'
    "CMTrace.exe" = '1246BE6E8CC2F0580A1B9806B1D470D6C9959D0A27163B20FAF033603122B068'
    "DefaultAssociations.xml" = 'AC8F0AF5B10BA3A0C98D608E40DE2B2ABBA557B2E20F3406CB1298EF0511016F'
    "DefaultLayouts.xml" = '914B74F6B9AE20E2066B063342A9BF4DC5DFFCF0935073AC794883204133A1B1'
    "file.json" = 'B452C2225F253DAA32AD43A9E60EEBD4A93C362DAA0D32D8AC78C15DD73C6BA7'
    "file.xml" = 'B21A4542C81015FCA788772C9331E8664D1A812E7DD62F54380C7D98DB6CB3DB'
    "Import-SalesLogixDBConnection.ps1" = 'C6B9C02A6B636D8D245F9960793305F5AAF8A2753FDB2C08756E53242A9805B7'
    "LanguageUnattend.xml" = '93E009C88E35C865A77088734A35AFB1519059C323C98443CC8CDC432EFC9CCB'
    "oemlogo.bmp" = 'CC7E68049AC3BD229064866842832132BE342FDC8B9AB0672A87951BCC937E18'
    "Out-AvayaConfigXmlDefault.ps1" = '168BAB56940C276DB672576333DF4D98CC7CDEADDEFF8AE2A4036A48321DEE65'
    "Out-SAPUILandscape.ps1" = 'BF04F21E0D616614CCABBBB34D45C9C636802585C7779849C8FA4515E79A6994'
    "Out-SAPUILandscapeGlobal.ps1" = 'C280D0BCC2747108DA04D881D4B0E63AD40CC71DD41842BDEEFB5F4E44E97CB8'
    "Reset-DisplayDpi.ps1" = '931F7E651D9213ADD3D642EA7A70F1996C4018A949DD806038D8574C1CE55AA7'
    "ServiceUI.exe" = '1BE85A64AAD2C3CAA0DC28705B49A1548E85157F4D2D522C20FEC4B4570A623F'
    "Set-InventorProfessional2018Defaults.ps1" = 'F2D1EB54410BA8D3A3B42EFFDB6DC4FE5E1288F57F3FA709526D99D6A567AB70'
    "Set-VaultProfessional2018Defaults.ps1" = '04BB32F0BADA252942E49825DB5E6B31BEFA9CF9C0FDDCB32BE71A6B10D9BE87'
}

# Config to load into Invoke-DesiredStateManagementOperation.ps1.
$config = @"
<Config Version="1.0">
	<Content>
		<!-- Note: If a Source is not specified, the script will require you to specify a content path and data map. -->
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

# Set up parameters.
if ($Install) {$PSBoundParameters.Add('ContentPath', "$PWD\Content")}
if (!$Remove) {$PSBoundParameters.Add('DataMap', $dataMap)}

# Call Invoke-DesiredStateManagementOperation.ps1 and do underlying operation.
Invoke-DesiredStateManagementOperation.ps1 @PSBoundParameters -Config $config
exit $LASTEXITCODE
