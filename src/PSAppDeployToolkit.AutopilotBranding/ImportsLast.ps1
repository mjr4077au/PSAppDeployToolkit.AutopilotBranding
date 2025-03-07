#-----------------------------------------------------------------------------
#
# MARK: Module Constants and Function Exports
#
#-----------------------------------------------------------------------------

# Rethrowing caught exceptions makes the error output from Import-Module look better.
try
{
    # Set all functions as read-only, export all public definitions and finalise the CommandTable.
    Set-Item -LiteralPath $FunctionPaths -Options ReadOnly
    Get-Item -LiteralPath $FunctionPaths | & { process { $CommandTable.Add($_.Name, $_) } }
    New-Variable -Name CommandTable -Value ([System.Collections.ObjectModel.ReadOnlyDictionary[System.String, System.Management.Automation.CommandInfo]]::new($CommandTable)) -Option Constant -Force -Confirm:$false
    Export-ModuleMember -Function $Module.Manifest.FunctionsToExport

    # Store module globals needed for the lifetime of the module.
    New-Variable -Name ADT -Option Constant -Value ([pscustomobject]@{
        })

    # Announce successful importation of module.
    Write-ADTLogEntry -Message "Module [PSAppDeployToolkit.AutopilotBranding] imported successfully." -ScriptSection Initialization -Source 'PSAppDeployToolkit.AutopilotBranding.psm1'
}
catch
{
    throw
}
