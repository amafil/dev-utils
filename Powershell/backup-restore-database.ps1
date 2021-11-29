[CmdletBinding()]
Param(
  [Parameter(
      HelpMessage = "Database server"
  )]
  [string]$DbServer = "localhost",
  [Parameter(
      HelpMessage = "Database name"
  )]
  [string]$DbName,
  [Parameter(
      HelpMessage = "Execute SQL database restore"
  )]
  [switch]$Restore,
  [Parameter(
      HelpMessage = "Execute SQL database backup"
  )]
  [switch]$Backup
)

$available = Get-Module -ListAvailable -Name SQLPS
Clear-Host
if ($null -eq $available) {
  Write-Error "SQLPS mmodule not available"
  Exit 1
}

if(!$Backup -And ! $Restore) {
  Write-Error "-Backup or -Restore parameters are mandatory"
  Exit 1
}

[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
$srv = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $DbServer
$rs = New-Object('Microsoft.SqlServer.Management.Smo.Restore')

$backupPath = $srv.Settings.BackupDirectory
$dbDataPath = $srv.Settings.DefaultFile

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
if($Backup) {
  Write-Host "Backup database $DbServer => $DbName..." -NoNewline    
  if(Test-Path $bakFullPath) {        
      Remove-Item $bakFullPath -Force    
  }
  Backup-SqlDatabase -ServerInstance $DbServer -Database $DbName -Credential $cred -CompressionOption On -Initialize
  Write-Host "[OK]"
}

if($Restore) { 
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

  $RelocateData = New-Object Microsoft.SqlServer.Management.Smo.RelocateFile($logname[0], "$dbDataPath\$DbName.mdf")
  $RelocateLog = New-Object Microsoft.SqlServer.Management.Smo.RelocateFile($logname[1], "$dbDataPath\$DbName_Log.ldf")
  Restore-SqlDatabase -ServerInstance $DbServer -Credential $cred -Database "MotusTesting" -BackupFile "$DbName.bak" -RelocateFile @($RelocateData,$RelocateLog) -RestoreAction Database -ErrorAction Ignore -ReplaceDatabase

  Write-Host "[OK]"
}
