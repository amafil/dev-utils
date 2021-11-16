# General purpose dev-utilities

## Powershell

`Powershell\backup-restore-database.ps1 -DbName [-Restore]`

Parameters:

```powershell
[Parameter(
    HelpMessage = "Database name"
)]
[string]$DbName,
[Parameter(
    HelpMessage = "Execute sql database restore without performing backup"
)]
[switch]$Restore
```
