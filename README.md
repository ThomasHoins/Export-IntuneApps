# Get-IntuneApps

PowerShell module for exporting the Intune app inventory from Microsoft Graph
to a CSV file. The export includes app metadata, assignments with resolved
group names, and Win32 app relationships.

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- Read permissions for Intune apps, Intune configurations, and groups in
  Microsoft Graph
- The `Microsoft.Graph.Authentication` module

The module requests the following delegated permissions when connecting:

- `DeviceManagementApps.Read.All`
- `DeviceManagementConfiguration.Read.All`
- `Group.Read.All`

Depending on your tenant configuration, an administrator may need to grant
consent to these permissions. The signed-in account must also have access to
the relevant Intune data.

## Import the module

From the repository directory, import the module manifest:

```powershell
Import-Module .\Get-IntuneApps.psd1
```

## Usage

By default, `IntuneAppsInventory.csv` is written to the current directory:

```powershell
Export-IntuneApps
```

To specify a different destination path:

```powershell
Export-IntuneApps -Path 'C:\Reports\IntuneAppsInventory.csv'
```

The CSV delimiter defaults to a semicolon (`;`). Use `-Delimiter` to select
another single-character delimiter, for example a comma:

```powershell
Export-IntuneApps -Path '.\IntuneAppsInventory.csv' -Delimiter ','
```

Use `-WhatIf` to preview the planned action without connecting to Graph or
writing a file. Use `-Verbose` to display processing status messages:

```powershell
Export-IntuneApps -Path '.\IntuneAppsInventory.csv' -WhatIf
Export-IntuneApps -Verbose
```

On success, the command returns the full file path. The CSV uses the selected
delimiter and UTF-8 encoding. The default semicolon is suitable for use with
localized versions of Excel, including German installations.

## CSV file contents

| Column | Description |
| --- | --- |
| `AppName` | Intune app display name |
| `Publisher` | Publisher |
| `Version` | App version formatted for display in Excel |
| `AppType` | Detected type, such as Win32, Store App, Edge, or Web Link |
| `CreatedDateTime` | Creation date and time |
| `LastModifiedDateTime` | Date and time of the last modification |
| `Assignments` | Assignment intent and group name; multiple values are separated by vertical bars |
| `Relations` | Win32 app relationships; multiple values are separated by vertical bars |
| `AppId` | Application ID in Microsoft Graph |

For Win32 apps, relationships are retrieved from the Graph app relationships
endpoint. If a group is not present in the group inventory, its ID is included
in the export and a warning is displayed. Errors retrieving relationships for
an individual app are also reported as warnings; other Graph or export errors
are propagated as errors.

## PowerShell verbs

The public command is named `Export-IntuneApps`. `Export` is an approved
PowerShell verb. The internal helper function `Get-GraphCollection` also uses
the approved verb `Get`; it is not exported from the module.
