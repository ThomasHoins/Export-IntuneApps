@{
    RootModule        = 'Get-IntuneApps.psm1'
    ModuleVersion     = '1.0.8'
    GUID              = '13e3556a-006d-47ea-9ba7-4e8f6407c76d'
    Author            = 'Thomas Hoins'
    CompanyName       = 'Datagroup'
    Copyright         = '(c) 2026'
    Description       = 'Exports Microsoft Intune application inventory, assignments, and Win32 relationships to CSV.'
    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    RequiredModules   = @(
        @{
            ModuleName    = 'Microsoft.Graph.Authentication'
            ModuleVersion = '2.0.0'
        }
    )
    FunctionsToExport = @('Export-IntuneApps')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('Intune', 'MicrosoftGraph', 'CSV', 'Applications')
            ProjectUri = 'https://github.com/ThomasHoins/Get-IntuneApps'
            ReleaseNotes = 'Packaged the exporter as a PowerShell module and added CSV path and WhatIf support.'
        }
    }
}
