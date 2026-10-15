[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$mysqlHome = 'C:\Program Files\MySQL\MySQL Server 8.4'
$mysqlBin = Join-Path $mysqlHome 'bin'
$clientOptions = Join-Path $projectRoot 'var\mysql-client.ini'
$backupScript = Join-Path $projectRoot 'Backup-WowWarband.ps1'
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$testRoot = Join-Path $projectRoot "var\backups\restore-validation-$timestamp"
$testData = Join-Path $testRoot 'data'
$testPort = 3307
$serverProcess = $null
$restoreVerified = $false

$mysqld = Join-Path $mysqlBin 'mysqld.exe'
$mysql = Join-Path $mysqlBin 'mysql.exe'
$mysqlAdmin = Join-Path $mysqlBin 'mysqladmin.exe'

if (-not (Test-Path -LiteralPath $clientOptions)) {
    throw "Missing local database options file: $clientOptions"
}

$existingListener = Get-NetTCPConnection -State Listen -LocalPort $testPort -ErrorAction SilentlyContinue
if ($existingListener) {
    throw "Port $testPort is already in use; refusing to touch another database process."
}

$backupPath = [string](& $backupScript | Select-Object -Last 1)
if (-not (Test-Path -LiteralPath $backupPath)) {
    throw "Backup script did not produce a readable SQL file: $backupPath"
}

New-Item -ItemType Directory -Force -Path $testRoot | Out-Null
& $mysqld '--no-defaults' '--initialize-insecure' "--basedir=$mysqlHome" "--datadir=$testData"
if ($LASTEXITCODE -ne 0) {
    throw "Could not initialize the isolated restore-test database (exit code $LASTEXITCODE)."
}

$serverArguments = @(
    '--no-defaults'
    "--basedir=`"$mysqlHome`""
    "--datadir=`"$testData`""
    "--port=$testPort"
    '--bind-address=127.0.0.1'
    '--mysqlx=0'
    "--pid-file=`"$(Join-Path $testRoot 'restore-test.pid')`""
    "--log-error=`"$(Join-Path $testRoot 'restore-test.err')`""
)
$serverProcess = Start-Process -FilePath $mysqld -ArgumentList $serverArguments -WindowStyle Hidden -PassThru

try {
    $ready = $false
    for ($attempt = 0; $attempt -lt 120; $attempt++) {
        if ($serverProcess.HasExited) {
            throw "Isolated MySQL exited during startup. See $(Join-Path $testRoot 'restore-test.err')"
        }

        & $mysqlAdmin '--no-defaults' '--protocol=TCP' '--host=127.0.0.1' "--port=$testPort" '--user=root' '--connect-timeout=1' 'ping' *> $null
        if ($LASTEXITCODE -eq 0) {
            $ready = $true
            break
        }
        Start-Sleep -Seconds 1
    }
    if (-not $ready) {
        throw "Isolated MySQL did not become ready. See $(Join-Path $testRoot 'restore-test.err')"
    }

    $backupSqlPath = $backupPath.Replace('\', '/')
    & $mysql '--no-defaults' '--protocol=TCP' '--host=127.0.0.1' "--port=$testPort" '--user=root' '-e' "source $backupSqlPath"
    if ($LASTEXITCODE -ne 0) {
        throw "Restoring the backup into the isolated database failed with exit code $LASTEXITCODE."
    }

    $query = "SELECT CONCAT(TABLE_SCHEMA, ':', COUNT(*)) FROM information_schema.tables WHERE TABLE_SCHEMA IN ('acore_auth','acore_characters','acore_world','acore_playerbots') GROUP BY TABLE_SCHEMA ORDER BY TABLE_SCHEMA"
    $liveCounts = @(& $mysql "--defaults-file=$clientOptions" '--batch' '--skip-column-names' '--execute' $query)
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not inspect the source database table counts.'
    }

    $restoredCounts = @(& $mysql '--no-defaults' '--protocol=TCP' '--host=127.0.0.1' "--port=$testPort" '--user=root' '--batch' '--skip-column-names' '--execute' $query)
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not inspect the restored database table counts.'
    }
    if (($liveCounts -join "`n") -ne ($restoredCounts -join "`n")) {
        throw "Restored table counts do not match the source.`nSource:`n$($liveCounts -join "`n")`nRestored:`n$($restoredCounts -join "`n")"
    }

    $restoreVerified = $true
    Write-Host "Restore verified. Table counts match for all four databases: $($restoredCounts -join ', ')"
    Write-Host "Backup tested: $backupPath"
}
finally {
    if ($serverProcess -and -not $serverProcess.HasExited) {
        & $mysqlAdmin '--no-defaults' '--protocol=TCP' '--host=127.0.0.1' "--port=$testPort" '--user=root' 'shutdown' *> $null
        $serverProcess.WaitForExit(30000)
    }

    if ($restoreVerified -and (Test-Path -LiteralPath $testRoot)) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
    elseif (Test-Path -LiteralPath $testRoot) {
        Write-Warning "Restore-test files kept for diagnosis at $testRoot"
    }
}
