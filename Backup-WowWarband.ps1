[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$mysqlBin = 'C:\Program Files\MySQL\MySQL Server 8.4\bin'
$clientOptions = Join-Path $projectRoot 'var\mysql-client.ini'
$backupDirectory = Join-Path $projectRoot 'var\backups'

if (-not (Test-Path -LiteralPath $clientOptions)) {
    throw "Missing local database options file: $clientOptions"
}

$mysqlAdmin = Join-Path $mysqlBin 'mysqladmin.exe'
$pingOutput = & $mysqlAdmin "--defaults-file=$clientOptions" '--connect-timeout=2' 'ping' 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "The local WowWarband database is not running. Start it with Start-WowWarband.bat first. $pingOutput"
}

New-Item -ItemType Directory -Force -Path $backupDirectory | Out-Null
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupPath = Join-Path $backupDirectory "WowWarband-$timestamp.sql"
$mysqlDump = Join-Path $mysqlBin 'mysqldump.exe'
$dumpArguments = @(
    "--defaults-file=$clientOptions"
    '--no-tablespaces'
    '--single-transaction'
    '--routines'
    '--events'
    '--triggers'
    '--hex-blob'
    "--result-file=$backupPath"
    '--databases'
    'acore_auth'
    'acore_characters'
    'acore_world'
    'acore_playerbots'
)

& $mysqlDump @dumpArguments
if ($LASTEXITCODE -ne 0) {
    throw "MySQL backup failed with exit code $LASTEXITCODE. Any partial file was left in place for diagnosis: $backupPath"
}

$backup = Get-Item -LiteralPath $backupPath
if ($backup.Length -eq 0) {
    throw "MySQL returned an empty backup: $backupPath"
}

$hash = (Get-FileHash -LiteralPath $backupPath -Algorithm SHA256).Hash
Write-Host ("Backup complete: {0} ({1:N0} bytes; SHA-256 {2})" -f $backupPath, $backup.Length, $hash)
Write-Output $backupPath
