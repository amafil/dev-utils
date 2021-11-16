# General purpose dev-utilities

## Powershell

`Powershell\backup-restore-database.ps1 -DbName [-Restore]`

Parameters:

```powershell
Param(
  [Parameter(
      HelpMessage = "Database name"
  )]
  [string]$DbName,
  [Parameter(
      HelpMessage = "Execute SQL database restore"
  )]
  [switch]$Restore
  [Parameter(
      HelpMessage = "Execute SQL database backup"
  )]
  [switch]$Backup
)
```
