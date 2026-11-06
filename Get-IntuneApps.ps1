<#
.SYNOPSIS
    Exports Intune applications, assignments, and Win32 relationships to CSV.

.DESCRIPTION
    Connects to Microsoft Graph and exports application inventory data,
    including resolved assignment group names, to IntuneAppsInventory.csv.

.VERSION
    1.0.8

.REQUIREMENTS
    Install-Module Microsoft.Graph -Scope CurrentUser
#>

Import-Module Microsoft.Graph

Connect-MgGraph -Scopes `
    DeviceManagementApps.Read.All, `
    DeviceManagementConfiguration.Read.All, `
    Group.Read.All

$ExportFile = ".\IntuneAppsInventory.csv"

Write-Host "Reading groups..." -ForegroundColor Cyan

$GroupCache = @{}
$GroupUri = "https://graph.microsoft.com/v1.0/groups?`$select=id,displayName"

while ($GroupUri)
{
    $GroupPage = Invoke-MgGraphRequest -Method GET -Uri $GroupUri

    foreach ($Group in $GroupPage.value)
    {
        $GroupCache[$Group.id] = $Group.displayName
    }

    $GroupUri = $GroupPage.'@odata.nextLink'
}

Write-Host "Cached $($GroupCache.Count) groups." -ForegroundColor Cyan

Write-Host "Reading apps..." -ForegroundColor Cyan

$Apps = Invoke-MgGraphRequest `
    -Method GET `
    -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps?`$expand=assignments"

$Result = [System.Collections.Generic.List[object]]::new()

foreach ($App in $Apps.value)
{
    # Determine the application type.
    $AppType = $App.'@odata.type'

    switch -Wildcard ($AppType)
    {
        "*win32LobApp*" {$AppTypeName = "Win32"}
        "*windowsStoreApp*" {$AppTypeName = "Store App"}
        "*windowsMicrosoftEdgeApp*" {$AppTypeName = "Edge"}
        "*webApp*" {$AppTypeName = "Web Link"}
        "*officeSuiteApp*" {$AppTypeName = "Microsoft 365 Apps"}
        default {$AppTypeName = $AppType}
    }

    # Read Win32 relationships once per app and combine them into one field.
    $Relations = @()

    if ($App.'@odata.type' -like "*win32LobApp*")
    {
        try
        {
            $Dependencies = Invoke-MgGraphRequest `
                -Method GET `
                -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$($App.id)/relationships"

            foreach ($Rel in $Dependencies.value)
            {
                $Relations += "$($Rel.targetType): $($Rel.targetDisplayName)"
            }
        }
        catch
        {
            Write-Warning "Could not read relationships for app '$($App.displayName)' (ID '$($App.id)'): $_"
        }
    }

    $RelationsText = $Relations -join " | "

    # Use assignments included in the app response; fetch separately only if omitted.
    if ($App.PSObject.Properties.Name -contains "assignments")
    {
        $Assignments = @{ value = @($App.assignments) }
    }
    else
    {
        $Assignments = Invoke-MgGraphRequest `
            -Method GET `
            -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$($App.id)/assignments"
    }

    if (($Assignments.value | Measure-Object).Count -eq 0)
    {
        $Assignments = @{ value = @($null) }
    }

    $AssignmentPairs = @()

    foreach ($Assignment in $Assignments.value)
    {
        $GroupName = ""
        $Intent = ""

        if ($Assignment)
        {
            $Intent = $Assignment.intent

            if ($Assignment.target.groupId)
            {
                $GroupId = $Assignment.target.groupId

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
        }

        if ($Assignment)
        {
            $AssignmentPairs += "${Intent}: $GroupName"
        }
    }

    $ExcelVersion = '="' + ([string]$App.displayVersion).Replace('"', '""') + '"'

    $Result.Add([PSCustomObject]@{
        AppName              = $App.displayName
        Publisher            = $App.publisher
        Version              = $ExcelVersion
        AppType              = $AppTypeName
        CreatedDateTime      = $App.createdDateTime
        LastModifiedDateTime = $App.lastModifiedDateTime
        Assignments          = $AssignmentPairs -join " | "
        Relations            = $RelationsText
        AppId                = $App.id
    })
}

$Result |
    Sort-Object AppName |
    Export-Csv $ExportFile -NoTypeInformation -Encoding UTF8 -Delimiter ';'

Write-Host ""
Write-Host "Export created:" -ForegroundColor Green
Write-Host $ExportFile
