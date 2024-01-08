# Invoke-DesiredStateManagementOperation.ps1
Inspired by Michael Niehaus' "AutopilotBranding" toolkit, this toolkit is specifically designed to be used to install a set of system baseline defaults for workstations, extending from languages, removal of built-in apps/features, user defaults via Active Setup, and more.

## Capabilities
These customizations are currently supported:

- Transfer of content to device. This can be wallpapers, start menu layouts, scripts, or anything you need cached locally.
- Configuration of Registration Information (Name/Organisation you see when running `winver.exe`).
- Configuration of OEM Information (Make/Model/Support information in Settings/System Properties).
- Ability to lock down the system drive to prevent standard users from creating folders.
- Complete overriding of the start menu layout for Windows 10.
- Deployment of start menu layout modifications for Windows 10 and 11.
- Configuration of default application associations.
- Configure language settings. Adding a language pack isn't enough - you have to tell Windows that you want it to be configured for all users. This is done through an XML file fed to INTL.CPL.
- Configure background image. A custom theme is deployed with a background image; the default user profile is then configured to use this theme. (Note that this won't work if the user is enabled for Enterprise State Roaming and has previously configured a background image.)
- Configuration of "Active Setup" items. These are run-once actions that occur before `explorer.exe` starts when a user logs onto a device.
- Deployment of shortcuts to the system. Supports well-known public folders like Desktop and Start Menu.
- Deployment of system registry keys/values onto device. For user registry keys, leverage Active Setup.
- Ability to remove and deprovision AppX packages on system. The toolkit has a whitelist that forbids unsafe removals.
- Ability to install/remove Windows Capabilities (Features on Demand). Such items are .NET Framework 3.5, Internet Explorer, etc.
- Ability to enable/disable Windows Features. Such items are Windows PowerShell 2.0 engine, Telnet client, etc.

## Requirements and Dependencies
This uses the Microsoft Win32 Content Prep Tool (a.k.a. IntuneWinAppUtil.exe, available from https://github.com/Microsoft/Microsoft-Win32-Content-Prep-Tool) to package the PowerShell script and related files into a .intunewin file that can be uploaded to Intune as a Win32 app.

## Example Config
An example setup via an XML configuration file would be:
```XML
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
```
Each element within `<Config></Config>` is supported by a submodule containing code to handle the element as required. The config is supported by a schema that governs the provided data.
## Example Log Files
* [Installed.txt](https://github.com/TheMissingLinkGithub/Install-DesiredStateManagement.ps1/files/13727435/Installed.txt)
* [Installing.txt](https://github.com/TheMissingLinkGithub/Install-DesiredStateManagement.ps1/files/13727430/Installing.txt)
* [Not Installed.txt](https://github.com/TheMissingLinkGithub/Install-DesiredStateManagement.ps1/files/13727431/Not.Installed.txt)
