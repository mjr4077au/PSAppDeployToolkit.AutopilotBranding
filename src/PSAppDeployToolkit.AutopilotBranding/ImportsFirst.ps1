<#

.SYNOPSIS
PSAppDeployToolkit.AutopilotBranding - This module contains the logic used by PSAppDeployToolkit.AutopilotBranding.

.DESCRIPTION
This module can be directly imported from the command line via Import-Module, but it is usually imported by the Invoke-AppDeployToolkit.ps1 script.

PSAppDeployToolkit is licensed under the MIT License - Copyright © 2025 Mitch Richters. All rights reserved.

.NOTES
MIT License

Copyright © 2025 Mitch Richters

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.


#>

#-----------------------------------------------------------------------------
#
# MARK: Module Initialization Code
#
#-----------------------------------------------------------------------------

# Throw if this psm1 file isn't being imported via our manifest.
if (!([System.Environment]::StackTrace.Split("`n") -like '*Microsoft.PowerShell.Commands.ModuleCmdletBase.LoadModuleManifest(*'))
{
    throw [System.Management.Automation.ErrorRecord]::new(
        [System.InvalidOperationException]::new("This module must be imported via its .psd1 file, which is recommended for all modules that supply a .psd1 file."),
        'ModuleImportError',
        [System.Management.Automation.ErrorCategory]::InvalidOperation,
        $MyInvocation.MyCommand.ScriptBlock.Module
    )
}

# Rethrowing caught exceptions makes the error output from Import-Module look better.
try
{
    # Set up lookup table for all cmdlets used within module, using PSAppDeployToolkit's as a basis.
    $CommandTable = [System.Collections.Generic.Dictionary[System.String, System.Management.Automation.CommandInfo]](& (& 'Microsoft.PowerShell.Core\Get-Command' -Name Get-ADTCommandTable -FullyQualifiedModule @{ ModuleName = 'PSAppDeployToolkit'; Guid = '8c3c366b-8606-4576-9f2d-4051144f7ca2'; ModuleVersion = '4.0.5' }))

    # Expand command lookup table with cmdlets used through this module.
    & {
        # Set up list of modules this module depends upon.
        $RequiredModules = [System.Collections.Generic.List[Microsoft.PowerShell.Commands.ModuleSpecification]][Microsoft.PowerShell.Commands.ModuleSpecification[]]$(
            @{ ModuleName = "$PSScriptRoot\Submodules\psyml"; Guid = 'a88e2e67-a937-4d98-a4d3-0b03d3ade169'; ModuleVersion = '1.0.0' }
        )

        # Import required modules and add their commands to the command table.
        (Import-Module -FullyQualifiedName $RequiredModules -Global -Force -PassThru -ErrorAction Stop).ExportedCommands.Values | & { process { $CommandTable.Add($_.Name, $_) } }
    }

    # Set required variables to ensure module functionality.
    New-Variable -Name ErrorActionPreference -Value ([System.Management.Automation.ActionPreference]::Stop) -Option Constant -Force
    New-Variable -Name InformationPreference -Value ([System.Management.Automation.ActionPreference]::Continue) -Option Constant -Force
    New-Variable -Name ProgressPreference -Value ([System.Management.Automation.ActionPreference]::SilentlyContinue) -Option Constant -Force

    # Ensure module operates under the strictest of conditions.
    Set-StrictMode -Version 3

    # Store build information pertaining to this module's state.
    New-Variable -Name Module -Option Constant -Force -Value ([ordered]@{
            Manifest = Import-LocalizedData -BaseDirectory $PSScriptRoot -FileName 'PSAppDeployToolkit.AutopilotBranding.psd1'
            Compiled = $MyInvocation.MyCommand.Name.Equals('PSAppDeployToolkit.AutopilotBranding.psm1')
        }).AsReadOnly()

    # Remove any previous functions that may have been defined.
    if ($Module.Compiled)
    {
        New-Variable -Name FunctionPaths -Option Constant -Value ($MyInvocation.MyCommand.ScriptBlock.Ast.EndBlock.Statements | & { process { if ($_ -is [System.Management.Automation.Language.FunctionDefinitionAst]) { return "Microsoft.PowerShell.Core\Function::$($_.Name)" } } })
        Remove-Item -LiteralPath $FunctionPaths -Force -ErrorAction Ignore
    }
}
catch
{
    throw
}
