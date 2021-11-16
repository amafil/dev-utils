[CmdletBinding()]
Param(
  [Parameter(
      HelpMessage = "Database name"
  )]
  [string]$DbName,
  [Parameter(
      HelpMessage = "Execute sql database restore without performing backup"
  )]
  [switch]$Restore  
)

Clear-Host

$server = "localhost"
$backupPath = "c:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\Backup\"
$dbDataPath = "c:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA\"

$configJson = ".\config.json"
$credJson = $null
if(!(Test-Path $configJson)) {    
    $password =Read-Host -AsSecureString -Prompt "Password" | ConvertFrom-SecureString
    $credFile = @"
{    
    "password": "$password"
}
"@ 
    $credFile | Out-File $configJson    
}
$credJson = (Get-Content -Raw -Path $configJson | ConvertFrom-Json)
$cred = New-Object -TypeName System.Management.Automation.PSCredential -Argumentlist "sa", ($credJson.password | ConvertTo-SecureString)

$bakFullPath = "$backupPath\$DbName.bak"
if(!$Restore) {
    Write-Host "Backup database $DbName..." -NoNewline    
    if(Test-Path $bakFullPath) {        
        Remove-Item $bakFullPath -Force    
    }
    Backup-SqlDatabase -ServerInstance $server -Database $DbName -Credential $cred -CompressionOption On -Initialize
    Write-Host "[OK]"
}

$srv = New-Object ('Microsoft.SqlServer.Management.Smo.Server')
$rs = New-Object('Microsoft.SqlServer.Management.Smo.Restore')
$bdi = New-Object ('Microsoft.SqlServer.Management.Smo.BackupDeviceItem') ($bakFullPath, 'File')
$rs.Devices.Add($bdi)
$fl = $rs.ReadFileList($srv)
$logname = $fl.logicalname 

Write-Host "Restore database $DbName..." -NoNewline

# If the database exists then drop it otherwise Restore-SqlDatabase may fail if connections are open to it
if ($null -ne $srv.Databases[$DbName])
{
    $srv.KillAllProcesses($DbName)
    $srv.KillDatabase($DbName)
}

$RelocateData = New-Object Microsoft.SqlServer.Management.Smo.RelocateFile($logname[0], "$dbDataPath\MotusTesting.mdf")
$RelocateLog = New-Object Microsoft.SqlServer.Management.Smo.RelocateFile($logname[1], "$dbDataPath\MotusTesting_Log.ldf")
Restore-SqlDatabase -ServerInstance localhost  -Credential $cred -Database "MotusTesting" -BackupFile "$DbName.bak" -RelocateFile @($RelocateData,$RelocateLog) -RestoreAction Database -ErrorAction Ignore -ReplaceDatabase

Write-Host "[OK]"