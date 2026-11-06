function Get-GraphCollection
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Uri
    )

    $Items = [System.Collections.Generic.List[object]]::new()
    $NextUri = $Uri

    while ($NextUri)
    {
        $Page = Invoke-MgGraphRequest -Method GET -Uri $NextUri -ErrorAction Stop

        foreach ($Item in $Page.value)
        {
            $Items.Add($Item)
        }

        $NextUri = $Page.'@odata.nextLink'
    }

    return $Items.ToArray()
}

function Export-IntuneApps
{
    <#
    .SYNOPSIS
        Exports Intune applications, assignments, and Win32 relationships to CSV.

    .DESCRIPTION
        Connects to Microsoft Graph and exports the Intune application inventory
        to a CSV file. Assignment group IDs are resolved to group names. The
        output path defaults to IntuneAppsInventory.csv in the current
        directory, and the delimiter defaults to a semicolon.

    .PARAMETER Path
        Destination path for the CSV file.

    .PARAMETER Delimiter
        Single-character CSV delimiter. Defaults to a semicolon.

    .EXAMPLE
        Export-IntuneApps

    .EXAMPLE
        Export-IntuneApps -Path C:\Reports\IntuneApps.csv -Verbose

    .EXAMPLE
        Export-IntuneApps -Path C:\Reports\IntuneApps.csv -Delimiter ','
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Path = (Join-Path -Path (Get-Location) -ChildPath 'IntuneAppsInventory.csv'),

        [Parameter()]
        [char]$Delimiter = ';'
    )

    if (-not $PSCmdlet.ShouldProcess($Path, 'Export Intune application inventory'))
    {
        return
    }

    $Scopes = @(
        'DeviceManagementApps.Read.All'
        'DeviceManagementConfiguration.Read.All'
        'Group.Read.All'
    )

    Connect-MgGraph -Scopes $Scopes -NoWelcome -ErrorAction Stop | Out-Null

    Write-Verbose 'Reading groups from Microsoft Graph.'

    $GroupCache = @{}
    $Groups = Get-GraphCollection -Uri 'https://graph.microsoft.com/v1.0/groups?$select=id,displayName'

    foreach ($Group in $Groups)
    {
        $GroupCache[$Group.id] = $Group.displayName
    }

    Write-Verbose "Cached $($GroupCache.Count) groups."
    Write-Verbose 'Reading applications from Microsoft Graph.'

    $Apps = Get-GraphCollection -Uri 'https://graph.microsoft.com/beta/deviceAppManagement/mobileApps?$expand=assignments'
    $Result = [System.Collections.Generic.List[object]]::new()

    foreach ($App in $Apps)
    {
        $AppType = $App.'@odata.type'

        switch -Wildcard ($AppType)
        {
            '*win32LobApp*' { $AppTypeName = 'Win32' }
            '*windowsStoreApp*' { $AppTypeName = 'Store App' }
            '*windowsMicrosoftEdgeApp*' { $AppTypeName = 'Edge' }
            '*webApp*' { $AppTypeName = 'Web Link' }
            '*officeSuiteApp*' { $AppTypeName = 'Microsoft 365 Apps' }
            default { $AppTypeName = $AppType }
        }

        $Relations = @()

        if ($App.'@odata.type' -like '*win32LobApp*')
        {
            try
            {
                $Dependencies = Get-GraphCollection -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$($App.id)/relationships"

                foreach ($Relation in $Dependencies)
                {
                    $Relations += "$($Relation.targetType): $($Relation.targetDisplayName)"
                }
            }
            catch
            {
                Write-Warning "Could not read relationships for app '$($App.displayName)' (ID '$($App.id)'): $_"
            }
        }

        if ($App.PSObject.Properties.Name -contains 'assignments')
        {
            $Assignments = @($App.assignments)
        }
        else
        {
            $Assignments = Get-GraphCollection -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$($App.id)/assignments"
        }

        $AssignmentPairs = @()

        foreach ($Assignment in $Assignments)
        {
            if ($null -eq $Assignment)
            {
                continue
            }

            $GroupName = ''
            $Intent = $Assignment.intent
            $GroupId = $Assignment.target.groupId

            if ($GroupId)
            {
                if ($GroupCache.ContainsKey($GroupId))
                {
                    $GroupName = $GroupCache[$GroupId]
                }
                else
                {
                    Write-Warning "Group ID '$GroupId' was not found in the group cache."
                    $GroupName = $GroupId
                }
            }

            $AssignmentPairs += "${Intent}: $GroupName"
        }

        $ExcelVersion = '="' + ([string]$App.displayVersion).Replace('"', '""') + '"'

        $Result.Add([PSCustomObject]@{
            AppName              = $App.displayName
            Publisher            = $App.publisher
            Version              = $ExcelVersion
            AppType              = $AppTypeName
            CreatedDateTime      = $App.createdDateTime
            LastModifiedDateTime = $App.lastModifiedDateTime
            Assignments          = $AssignmentPairs -join ' | '
            Relations            = $Relations -join ' | '
            AppId                = $App.id
        })
    }

    $ResolvedPath = [System.IO.Path]::GetFullPath($Path)
    $Result |
        Sort-Object AppName |
        Export-Csv -LiteralPath $ResolvedPath -NoTypeInformation -Encoding UTF8 -Delimiter $Delimiter -ErrorAction Stop

    Write-Information "Export created: $ResolvedPath"
    return $ResolvedPath
}

Export-ModuleMember -Function Export-IntuneApps
