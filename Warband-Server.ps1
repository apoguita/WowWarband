<#
.SYNOPSIS
    Loads, unloads and inspects the local WowWarband stack one component at a time.

.DESCRIPTION
    The stack has three independent components: the database (mysqld), the login server
    (authserver) and the world server (worldserver). This script can start and stop each of
    them on its own and reports what is actually alive, so that no component is left running
    invisibly holding a port, a data directory or a console window.

    Stops are graceful wherever the component supports it:

      db     mysqld is stopped with `mysqladmin shutdown` (clean InnoDB shutdown). Any mysqld
             process that is still alive afterwards - such as the stub process that owns the
             "WowWarband database" console window - is reported and reaped, because closing
             that window does not reliably stop the real server.

      auth   CTRL+C is delivered to the server console, where the signal handler in Main.cpp
      world  (SIGINT/SIGTERM/SIGBREAK) calls World::StopNow(SHUTDOWN_EXIT_CODE): the server shuts
             down cleanly and saves every online character. If it does not react, the ladder
             continues with CTRL+BREAK, then closing the console window, and only as a last
             resort a hard kill - which can lose up to PlayerSaveInterval (15 minutes) of
             character progress.

.PARAMETER Action
    status (default)  - show every component, its PID, port and whether the stack is joinable.
    start             - start the selected component(s) and wait until they are ready.
    stop              - stop the selected component(s) gracefully.
    restart           - stop then start the selected component(s).
    cleanup           - stop everything, then reap any orphaned WowWarband process.
    logs              - show the tail of the selected component's log.
    help              - show this help.

.PARAMETER Component
    all (default), db, auth or world.

.PARAMETER Force
    Do not attempt a graceful stop; terminate the processes immediately.

.PARAMETER TimeoutSeconds
    Override the readiness/shutdown timeout. 0 uses the per-component default
    (db 120s, auth 90s, world 900s to become ready and 180s to shut down).

.PARAMETER Tail
    Number of log lines shown by `logs` and after a start that fails.

.EXAMPLE
    .\Warband-Server.ps1 status

.EXAMPLE
    .\Warband-Server.ps1 start all

.EXAMPLE
    .\Warband-Server.ps1 stop world

.EXAMPLE
    .\Warband-Server.ps1 restart db

.EXAMPLE
    .\Warband-Server.ps1 cleanup
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('status', 'start', 'stop', 'restart', 'cleanup', 'logs', 'realm', 'help')]
    [string]$Action = 'status',

    [Parameter(Position = 1)]
    [ValidateSet('all', 'db', 'auth', 'world')]
    [string]$Component = 'all',

    [switch]$Force,

    [int]$TimeoutSeconds = 0,

    [int]$Tail = 25
)

$ErrorActionPreference = 'Stop'

# --- Layout ---------------------------------------------------------------------------------

$projectRoot        = Split-Path -Parent $MyInvocation.MyCommand.Path
$binDirectory       = Join-Path $projectRoot 'bin\RelWithDebInfo'
$mysqlBinDirectory  = 'C:\Program Files\MySQL\MySQL Server 8.4\bin'
$mysqlBaseDirectory = 'C:\Program Files\MySQL\MySQL Server 8.4'
$clientOptions      = Join-Path $projectRoot 'var\mysql-client.ini'
$dataDirectory      = Join-Path $projectRoot 'var\mysql'
$mysqlAdmin         = Join-Path $mysqlBinDirectory 'mysqladmin.exe'
$mysqlClient        = Join-Path $mysqlBinDirectory 'mysql.exe'

# Start order (dependencies first) and stop order (dependents first).
$startOrder = @('db', 'auth', 'world')
$stopOrder  = @('world', 'auth', 'db')

$components = [ordered]@{
    db    = @{
        Key          = 'db'
        Display      = 'database'
        Process      = 'mysqld'
        Port         = 3306
        Executable   = Join-Path $mysqlBinDirectory 'mysqld.exe'
        StartTimeout = 120
        StopTimeout  = 120
        LogPath      = Join-Path $dataDirectory '*.err'
        LogLabel     = 'MySQL error log'
    }
    auth  = @{
        Key          = 'auth'
        Display      = 'login server'
        Process      = 'authserver'
        Port         = 3724
        Executable   = Join-Path $binDirectory 'authserver.exe'
        StartTimeout = 90
        StopTimeout  = 60
        LogPath      = Join-Path $binDirectory 'Auth.log'
        LogLabel     = 'Auth.log'
    }
    world = @{
        Key          = 'world'
        Display      = 'world server'
        Process      = 'worldserver'
        Port         = 8085
        Executable   = Join-Path $binDirectory 'worldserver.exe'
        StartTimeout = 900
        StopTimeout  = 180
        LogPath      = Join-Path $binDirectory 'Server.log'
        LogLabel     = 'Server.log'
    }
}

# --- Output helpers -------------------------------------------------------------------------

function Write-Step { param([string]$Message) Write-Host $Message -ForegroundColor Cyan }
function Write-Ok   { param([string]$Message) Write-Host $Message -ForegroundColor Green }
function Write-Note { param([string]$Message) Write-Host $Message -ForegroundColor DarkGray }
function Write-Warn { param([string]$Message) Write-Host $Message -ForegroundColor Yellow }
function Write-Bad  { param([string]$Message) Write-Host $Message -ForegroundColor Red }

# --- Discovery helpers ----------------------------------------------------------------------

# Native tools (mysqladmin, netstat) write diagnostics to stderr even when nothing is actually
# wrong, and Windows PowerShell turns that into a terminating error under
# $ErrorActionPreference = 'Stop'. Every external command therefore goes through here, which
# captures the output and the exit code instead of aborting the script.
function Invoke-NativeCommand {
    param([string]$FilePath, [string[]]$Arguments)

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $exitCode = 1
    $output = @()
    try {
        $output = @(& $FilePath @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    }
    catch {
        $output = @($_.Exception.Message)
        $exitCode = 1
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }

    return [pscustomobject]@{ ExitCode = $exitCode; Output = $output }
}

# Single netstat pass, cached for the duration of one operation.
$script:portMapCache = $null

function Get-ListeningPortMap {
    param([switch]$Refresh)

    if ($script:portMapCache -and -not $Refresh) {
        return $script:portMapCache
    }

    $map = @{}
    $netstat = Invoke-NativeCommand -FilePath 'netstat' -Arguments @('-ano', '-p', 'TCP')
    foreach ($line in $netstat.Output) {
        $parts = @($line -split '\s+' | Where-Object { $_ -ne '' })
        if ($parts.Count -lt 5 -or $parts[0] -ne 'TCP' -or $parts[3] -ne 'LISTENING') {
            continue
        }

        $localAddress = $parts[1]
        $portText = $localAddress.Substring($localAddress.LastIndexOf(':') + 1)
        $portNumber = 0
        $ownerPid = 0
        if (-not [int]::TryParse($portText, [ref]$portNumber)) { continue }
        if (-not [int]::TryParse($parts[4], [ref]$ownerPid)) { continue }
        $map[$portNumber] = $ownerPid
    }

    $script:portMapCache = $map
    return $map
}

function Get-ComponentProcesses {
    param([string]$ProcessName)
    return @(Get-Process -Name $ProcessName -ErrorAction SilentlyContinue)
}

function Test-DatabaseReachable {
    if (-not (Test-Path -LiteralPath $mysqlAdmin)) { return $false }
    if (-not (Test-Path -LiteralPath $clientOptions)) { return $false }
    $ping = Invoke-NativeCommand -FilePath $mysqlAdmin -Arguments @(
        "--defaults-file=$clientOptions", '--protocol=TCP', '--host=127.0.0.1', '--port=3306',
        '--connect-timeout=2', 'ping'
    )
    return ($ping.ExitCode -eq 0)
}

# --- Realm rows ------------------------------------------------------------------------------

# A realm row with flag 3 (REALM_FLAG_VERSION_MISMATCH | REALM_FLAG_OFFLINE) is excluded by the
# login server's realm query (LoginDatabase.cpp: "WHERE flag <> 3"), so the login server exits
# with "No valid realms specified" and clients see no realm at all.
#
# That combination is left behind by a world server that was interrupted while loading: it clears
# OFFLINE and sets VERSION_MISMATCH when it starts (worldserver/Main.cpp), and only clears
# VERSION_MISMATCH once the world is fully loaded. The login server then ORs OFFLINE onto that
# leftover flag, producing exactly 3.
function Get-RealmRows {
    if (-not (Test-Path -LiteralPath $mysqlClient)) { return @() }
    $result = Invoke-NativeCommand -FilePath $mysqlClient -Arguments @(
        "--defaults-file=$clientOptions", '--batch', '--skip-column-names',
        '--execute=SELECT id, name, address, port, flag FROM acore_auth.realmlist ORDER BY id'
    )
    if ($result.ExitCode -ne 0) { return @() }
    return @($result.Output | Where-Object { $_ -match '\S' })
}

function Test-RealmFlagsBlocked {
    foreach ($row in (Get-RealmRows)) {
        $fields = @($row -split "`t")
        if ($fields.Count -ge 5 -and $fields[4].Trim() -eq '3') { return $true }
    }
    return $false
}

function Reset-RealmFlags {
    $result = Invoke-NativeCommand -FilePath $mysqlClient -Arguments @(
        "--defaults-file=$clientOptions",
        '--execute=UPDATE acore_auth.realmlist SET flag = 0 WHERE flag = 3'
    )
    return ($result.ExitCode -eq 0)
}

function Get-LogFile {
    param([hashtable]$Definition)

    $candidates = @(Get-ChildItem -Path $Definition.LogPath -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending)
    if ($candidates.Count -eq 0) { return $null }
    return $candidates[0]
}

function Get-LogTail {
    param([hashtable]$Definition, [int]$Lines = 20)

    $logFile = Get-LogFile -Definition $Definition
    if (-not $logFile) { return @() }
    try {
        return @(Get-Content -LiteralPath $logFile.FullName -Tail $Lines -ErrorAction Stop)
    }
    catch {
        return @()
    }
}

# --- Component state ------------------------------------------------------------------------

function Get-ComponentState {
    param([hashtable]$Definition)

    $portMap = Get-ListeningPortMap
    $ownerPid = $portMap[$Definition.Port]
    $processes = Get-ComponentProcesses -ProcessName $Definition.Process

    $state = 'stopped'
    $activePid = $null
    $detail = 'not running'

    if ($Definition.Key -eq 'db') {
        $reachable = Test-DatabaseReachable
        if ($reachable) {
            $state = 'running'
            if ($ownerPid) { $activePid = $ownerPid }
            $detail = 'accepting connections'
        }
        elseif ($processes.Count -gt 0) {
            $state = 'leftover'
            $activePid = $processes[0].Id
            $detail = 'process alive but not accepting connections'
        }
    }
    elseif ($ownerPid) {
        $state = 'running'
        $activePid = $ownerPid
        $detail = "listening on $($Definition.Port)"
    }
    elseif ($processes.Count -gt 0) {
        $state = 'loading'
        $activePid = $processes[0].Id
        $detail = 'process alive, port not open yet'
    }

    $started = $null
    if ($activePid) {
        $process = $processes | Where-Object { $_.Id -eq $activePid } | Select-Object -First 1
        if (-not $process) { $process = Get-Process -Id $activePid -ErrorAction SilentlyContinue }
        if ($process -and $process.StartTime) { $started = $process.StartTime }
        # A process that owns the port before it is known by name (db) still deserves a start time.
        if (-not $started -and $processes.Count -gt 0) { $started = $processes[0].StartTime }
    }

    # Anything with the same image name that is not the component we just identified.
    $extras = @($processes | Where-Object { $_.Id -ne $activePid })

    return [pscustomobject]@{
        Key       = $Definition.Key
        Display   = $Definition.Display
        State     = $state
        Pid       = $activePid
        Port      = $Definition.Port
        Started   = $started
        Detail    = $detail
        Extras    = $extras
        Processes = $processes
    }
}

function Get-StateColor {
    param([string]$State)
    switch ($State) {
        'running'  { return 'Green' }
        'loading'  { return 'Yellow' }
        'leftover' { return 'Red' }
        default    { return 'DarkGray' }
    }
}

function Show-Status {
    param([string[]]$Keys)

    Write-Host ''
    Write-Step 'WowWarband stack'
    Write-Host ''
    Write-Host ("  {0,-6} {1,-9} {2,-7} {3,-6} {4,-20} {5}" -f `
        'comp', 'state', 'pid', 'port', 'started', 'detail')
    Write-Host ("  {0,-6} {1,-9} {2,-7} {3,-6} {4,-20} {5}" -f `
        '------', '---------', '-------', '------', '--------------------', '------')

    $states = @{}
    $extras = @()
    foreach ($key in $Keys) {
        $state = Get-ComponentState -Definition $components[$key]
        $states[$key] = $state

        $pidText = '-'
        if ($state.Pid) { $pidText = [string]$state.Pid }
        $portText = '-'
        if ($state.State -eq 'running') { $portText = [string]$state.Port }
        $startedText = '-'
        if ($state.Started) { $startedText = $state.Started.ToString('MM/dd/yyyy HH:mm:ss') }

        Write-Host ("  {0,-6} " -f $state.Key) -NoNewline
        Write-Host ("{0,-9} " -f $state.State) -NoNewline -ForegroundColor (Get-StateColor -State $state.State)
        Write-Host ("{0,-7} {1,-6} {2,-20} {3}" -f $pidText, $portText, $startedText, $state.Detail)

        foreach ($extra in $state.Extras) {
            $extras += [pscustomobject]@{
                Name      = $state.Display
                Process   = $extra.ProcessName
                Pid       = $extra.Id
                Title     = $extra.MainWindowTitle
                Companion = ($state.State -eq 'running')
            }
        }
    }

    # mysqld on Windows runs alongside a companion process that owns the console window and
    # lives exactly as long as the server, so it is not a leftover while the component runs.
    $companions = @($extras | Where-Object { $_.Companion })
    $orphans = @($extras | Where-Object { -not $_.Companion })

    if ($companions.Count -gt 0) {
        Write-Host ''
        Write-Note '  Companion process of the running component (owns its console window, exits with it):'
        foreach ($extra in $companions) {
            $title = ''
            if ($extra.Title) { $title = " - console window ""$($extra.Title)""" }
            Write-Note ("    {0} {1} (PID {2}){3}" -f $extra.Process, $extra.Name, $extra.Pid, $title)
        }
    }

    if ($orphans.Count -gt 0) {
        Write-Host ''
        Write-Warn "  Orphaned processes (same component, not the active one):"
        foreach ($extra in $orphans) {
            $title = ''
            if ($extra.Title) { $title = " - console window ""$($extra.Title)""" }
            Write-Host ("    {0} {1} (PID {2}){3}" -f $extra.Process, $extra.Name, $extra.Pid, $title) `
                -ForegroundColor Yellow
        }
        Write-Note '    Run `.\Warband-Server.ps1 cleanup` to unload them.'
    }

    Write-Host ''
    $authReady  = $states.ContainsKey('auth')  -and $states['auth'].State -eq 'running'
    $worldReady = $states.ContainsKey('world') -and $states['world'].State -eq 'running'
    if ($authReady -and $worldReady) {
        Write-Ok '  Stack ready: the login server and the world server are both listening.'
    }
    elseif ($worldReady) {
        Write-Warn "  World server is up but the login server is not: clients cannot reach the realm list."
    }
    elseif ($states.ContainsKey('world') -and $states['world'].State -eq 'loading') {
        Write-Warn '  World server is still loading. A world server is only reachable once it is listening'
        Write-Warn '  on 8085; interrupting it earlier is what makes a relaunch look broken.'
    }
    else {
        Write-Warn '  Clients cannot connect yet: the world server is not listening on 8085.'
    }

    if ($states.ContainsKey('db') -and $states['db'].State -eq 'running') {
        Write-Note '  The database stays up until you unload it: .\Warband-Server.ps1 stop db'
    }
    Write-Host ''
}

# --- Process control -------------------------------------------------------------------------

function Wait-ForProcessExit {
    param([int]$ProcessId, [int]$TimeoutSeconds)

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (-not (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue)) { return $true }
        Start-Sleep -Milliseconds 500
    }
    return $false
}

# Delivers a console control event to the target's console. The work happens in a throw-away
# PowerShell process because the helper must detach from its own console before attaching to the
# server's console, and doing that inside the caller would detach the caller's own terminal.
#
# Verified behaviour: the event is queued on the target's console, the target's own handler decides
# what happens (worldserver.exe maps it to SIGINT/SIGBREAK -> World::StopNow -> clean shutdown).
# A helper sending CTRL_BREAK is killed by its own signal (STATUS_CONTROL_C_EXIT = 0xC000013A),
# which is expected, so only exit codes 3 and 4 count as a failure here.
function Send-ConsoleSignal {
    param([int]$TargetProcessId, [ValidateSet(0, 1)][int]$ControlEvent)

    $helperScript = @'
$ErrorActionPreference = 'Stop'
try {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class WarbandConsole
{
    [DllImport("kernel32.dll", SetLastError = true)] public static extern bool FreeConsole();
    [DllImport("kernel32.dll", SetLastError = true)] public static extern bool AttachConsole(uint dwProcessId);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool GenerateConsoleCtrlEvent(uint dwCtrlEvent, uint dwProcessGroupId);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetConsoleCtrlHandler(IntPtr handler, bool add);
}
"@ -ErrorAction Stop

    $target = [uint32]$env:WARBAND_TARGET_PID
    $controlEvent = [uint32]$env:WARBAND_CTRL_EVENT

    [void][WarbandConsole]::FreeConsole()
    if (-not [WarbandConsole]::AttachConsole($target)) { exit 3 }

    # A NULL handler with TRUE makes this process ignore CTRL_C, so it survives to report back.
    if ($controlEvent -eq 0) { [void][WarbandConsole]::SetConsoleCtrlHandler([IntPtr]::Zero, $true) }

    # Group 0 = every process sharing that console, which for a server console is the server.
    if (-not [WarbandConsole]::GenerateConsoleCtrlEvent($controlEvent, 0)) { exit 5 }

    Start-Sleep -Milliseconds 500
    [void][WarbandConsole]::FreeConsole()
    exit 0
}
catch { exit 4 }
'@

    $env:WARBAND_TARGET_PID = [string]$TargetProcessId
    $env:WARBAND_CTRL_EVENT = [string]$ControlEvent
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($helperScript))
    $shell = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName

    try {
        $helper = Start-Process -FilePath $shell -ArgumentList '-NoProfile', '-NonInteractive', `
            '-EncodedCommand', $encoded -WindowStyle Hidden -PassThru -ErrorAction Stop
        [void]$helper.WaitForExit(20000)
        return ($helper.ExitCode -ne 3 -and $helper.ExitCode -ne 4 -and $helper.ExitCode -ne 5)
    }
    catch {
        return $false
    }
    finally {
        Remove-Item Env:\WARBAND_TARGET_PID, Env:\WARBAND_CTRL_EVENT -ErrorAction SilentlyContinue
    }
}

# Closing the console window degrades to CTRL_CLOSE_EVENT, which Windows force-terminates after
# a few seconds. Kept as a fallback only.
function Send-WindowClose {
    param([int]$TargetProcessId)

    try {
        if (-not ('Warband.Window' -as [type])) {
            Add-Type -Namespace Warband -Name Window -MemberDefinition @'
[DllImport("user32.dll", SetLastError = true)]
public static extern bool PostMessage(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);
'@ -ErrorAction Stop
        }
    }
    catch {
        return $false
    }

    $process = Get-Process -Id $TargetProcessId -ErrorAction SilentlyContinue
    if (-not $process) { return $false }
    if ($process.MainWindowHandle -eq [IntPtr]::Zero) { return $false }
    [void][Warband.Window]::PostMessage($process.MainWindowHandle, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
    return $true
}

function Get-StopTimeout {
    param([hashtable]$Definition)
    if ($TimeoutSeconds -gt 0) { return $TimeoutSeconds }
    return $Definition.StopTimeout
}

function Get-StartTimeout {
    param([hashtable]$Definition)
    if ($TimeoutSeconds -gt 0) { return $TimeoutSeconds }
    return $Definition.StartTimeout
}

function Stop-Database {
    param([hashtable]$Definition)

    $reachable = Test-DatabaseReachable
    $processes = Get-ComponentProcesses -ProcessName $Definition.Process
    if (-not $reachable -and $processes.Count -eq 0) {
        Write-Note '  database is already stopped'
        return $true
    }

    if ($reachable -and -not $Force) {
        Write-Step '  stopping database (mysqladmin shutdown, clean InnoDB shutdown)'
        $shutdown = Invoke-NativeCommand -FilePath $mysqlAdmin -Arguments @(
            "--defaults-file=$clientOptions", '--protocol=TCP', '--host=127.0.0.1', '--port=3306',
            '--connect-timeout=5', 'shutdown'
        )

        $deadline = (Get-Date).AddSeconds((Get-StopTimeout -Definition $Definition))
        while ((Get-Date) -lt $deadline) {
            if (-not (Test-DatabaseReachable)) { break }
            Start-Sleep -Seconds 1
        }

        if (Test-DatabaseReachable) {
            Write-Warn '  database did not shut down in time'
            foreach ($line in $shutdown.Output) { Write-Note ("    mysqladmin: " + $line) }
        }
        else {
            Write-Ok '  database shut down cleanly'
            # mysqladmin frequently loses its connection while the server is already stopping.
            if ($shutdown.ExitCode -ne 0) {
                Write-Note '    (mysqladmin reported a lost connection while stopping; harmless)'
            }
        }
    }
    elseif ($reachable) {
        Write-Warn '  -Force: terminating the database without a clean shutdown'
    }

    # Anything alive here either never accepted connections (a stub or a wedged server, which
    # nothing can use and which keeps the data directory and a console window occupied) or it
    # refused to stop on request.
    $remaining = Get-ComponentProcesses -ProcessName $Definition.Process
    $stillServing = Test-DatabaseReachable
    foreach ($process in $remaining) {
        $title = ''
        if ($process.MainWindowTitle) { $title = " holding console window ""$($process.MainWindowTitle)""" }
        if ($stillServing) {
            Write-Warn "  terminating database (PID $($process.Id))$title; InnoDB will recover on the next start"
        }
        else {
            Write-Warn "  reaping leftover mysqld (PID $($process.Id))$title"
        }
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        [void](Wait-ForProcessExit -ProcessId $process.Id -TimeoutSeconds 10)
    }

    $script:portMapCache = $null
    return $true
}

function Stop-Server {
    param([hashtable]$Definition)

    $processes = Get-ComponentProcesses -ProcessName $Definition.Process
    if ($processes.Count -eq 0) {
        Write-Note "  $($Definition.Display) is already stopped"
        return $true
    }

    $ok = $true
    foreach ($process in $processes) {
        Write-Step "  stopping $($Definition.Display) (PID $($process.Id))"

        if (-not $Force) {
            # Ladder, gentlest first:
            #   1. CTRL_C   -> SIGINT   -> World::StopNow -> clean shutdown (saves characters)
            #   2. CTRL_BREAK -> SIGBREAK -> the same handler, for a console that ignored step 1
            #   3. WM_CLOSE -> closing the console window, which Windows force-kills after ~5s
            #   4. hard kill, reported as a warning because progress can be lost
            $signalled = Send-ConsoleSignal -TargetProcessId $process.Id -ControlEvent 0
            if ($signalled) {
                Write-Note '    sent CTRL+C, waiting for a clean shutdown (online characters are saved)'
                $stopTimeout = Get-StopTimeout -Definition $Definition
                if (Wait-ForProcessExit -ProcessId $process.Id -TimeoutSeconds $stopTimeout) {
                    Write-Ok "    $($Definition.Display) stopped cleanly"
                    continue
                }
            }
            else {
                Write-Warn '    could not attach to the console to send CTRL+C'
            }

            $signalled = Send-ConsoleSignal -TargetProcessId $process.Id -ControlEvent 1
            if ($signalled) {
                Write-Warn '    still running, sent CTRL+BREAK'
                if (Wait-ForProcessExit -ProcessId $process.Id -TimeoutSeconds 30) {
                    Write-Ok "    $($Definition.Display) stopped cleanly"
                    continue
                }
            }

            Write-Warn '    no clean shutdown; closing the console window'
            [void](Send-WindowClose -TargetProcessId $process.Id)
            if (Wait-ForProcessExit -ProcessId $process.Id -TimeoutSeconds 15) {
                Write-Ok "    $($Definition.Display) stopped (console window closed)"
                continue
            }
        }

        Write-Warn "    terminating $($Definition.Display) (PID $($process.Id)); progress since the last save is lost"
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        [void](Wait-ForProcessExit -ProcessId $process.Id -TimeoutSeconds 10)
        $ok = $false
    }

    $script:portMapCache = $null
    return $ok
}

function Stop-OneComponent {
    param([string]$Key)
    $definition = $components[$Key]
    if ($Key -eq 'db') { return (Stop-Database -Definition $definition) }
    return (Stop-Server -Definition $definition)
}

# --- Starting ---------------------------------------------------------------------------------

function Wait-ForPort {
    param([hashtable]$Definition, [System.Diagnostics.Process]$Process, [int]$TimeoutSeconds)

    $portMap = Get-ListeningPortMap -Refresh
    if ($portMap[$Definition.Port]) { return $true }

    $started = Get-Date
    $deadline = $started.AddSeconds($TimeoutSeconds)
    $logFile = Get-LogFile -Definition $Definition
    $lastLogWrite = $null
    if ($logFile) { $lastLogWrite = $logFile.LastWriteTime }
    $lastReport = Get-Date
    $stallWarned = $false

    while ((Get-Date) -lt $deadline) {
        if ($Process -and $Process.HasExited) { return $false }

        $portMap = Get-ListeningPortMap -Refresh
        if ($portMap[$Definition.Port]) {
            Write-Host ''
            return $true
        }

        if (((Get-Date) - $lastReport).TotalSeconds -ge 5) {
            $elapsed = [int]((Get-Date) - $started).TotalSeconds
            $lastLine = ''
            # @() matters: a one-line tail is returned as a bare string, and indexing a string
            # would hand back its last character instead of the last line.
            $tailLines = @(Get-LogTail -Definition $Definition -Lines 1)
            if ($tailLines.Count -gt 0) { $lastLine = $tailLines[-1].Trim() }
            if ($lastLine.Length -gt 90) { $lastLine = $lastLine.Substring(0, 90) + '...' }

            $logFile = Get-LogFile -Definition $Definition
            if ($logFile) {
                if ($logFile.LastWriteTime -gt $lastLogWrite) {
                    $lastLogWrite = $logFile.LastWriteTime
                    $stallWarned = $false
                }
                elseif (-not $stallWarned -and ((Get-Date) - $lastLogWrite).TotalSeconds -ge 60) {
                    Write-Warn ("    no new log output for {0}s - check the {1} console window" -f `
                        [int]((Get-Date) - $lastLogWrite).TotalSeconds, $Definition.Display)
                    $stallWarned = $true
                }
            }

            if ($lastLine) {
                Write-Note ("    [{0,4}s] still loading: {1}" -f $elapsed, $lastLine)
            }
            else {
                Write-Note ("    [{0,4}s] waiting for port {1}" -f $elapsed, $Definition.Port)
            }
            $lastReport = Get-Date
        }

        Start-Sleep -Seconds 2
    }

    return $false
}

function Start-OneComponent {
    param([string]$Key)

    $definition = $components[$Key]
    $state = Get-ComponentState -Definition $definition

    if ($state.State -eq 'running') {
        Write-Ok "  $($definition.Display) is already running (PID $($state.Pid))"
        return $true
    }
    if ($state.State -eq 'loading') {
        Write-Warn "  $($definition.Display) is already running (PID $($state.Pid)) but not listening yet."
        Write-Note ("    It is most likely still starting. Stop it with: .\Warband-Server.ps1 stop {0}" -f $Key)
        return $true
    }
    if ($state.State -eq 'leftover') {
        Write-Warn "  a $($definition.Process) process (PID $($state.Pid)) is alive but the database is not answering"
        Write-Note '    waiting for it to become ready before treating it as a leftover'
        $deadline = (Get-Date).AddSeconds(20)
        while ((Get-Date) -lt $deadline) {
            if (Test-DatabaseReachable) { break }
            Start-Sleep -Seconds 2
        }
        if (Test-DatabaseReachable) {
            Write-Ok '  database became ready, nothing to clean up'
            return $true
        }
        Write-Warn '  the leftover database process cannot serve connections and would block a new one'
        foreach ($process in $state.Processes) {
            $title = ''
            if ($process.MainWindowTitle) { $title = " holding console window ""$($process.MainWindowTitle)"""}
            Write-Warn "  reaping leftover mysqld (PID $($process.Id))$title"
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            [void](Wait-ForProcessExit -ProcessId $process.Id -TimeoutSeconds 10)
        }
        $script:portMapCache = $null
    }

    if ($Key -eq 'db') {
        if (-not (Test-Path -LiteralPath $definition.Executable)) {
            Write-Bad "  missing executable: $($definition.Executable)"
            return $false
        }
        if (-not (Test-Path -LiteralPath (Join-Path $dataDirectory 'auto.cnf'))) {
            Write-Bad "  the local database has not been initialized: $dataDirectory"
            return $false
        }

        Write-Step '  starting database (minimized database console window)'
        # Paths must be quoted: mysqld aborts with "Too many arguments" if --basedir is split on
        # the spaces in "C:\Program Files\...". The command line is therefore built by hand
        # instead of letting Start-Process join an array of arguments.
        $databaseArgumentLine = @(
            '--no-defaults'
            "--basedir=`"$mysqlBaseDirectory`""
            "--datadir=`"$dataDirectory`""
            '--port=3306'
            '--bind-address=127.0.0.1'
            '--mysqlx=0'
        ) -join ' '
        $process = Start-Process -FilePath $definition.Executable -ArgumentList $databaseArgumentLine `
            -WorkingDirectory $mysqlBinDirectory -WindowStyle Minimized -PassThru

        $timeout = Get-StartTimeout -Definition $definition
        $deadline = (Get-Date).AddSeconds($timeout)
        while ((Get-Date) -lt $deadline) {
            if (Test-DatabaseReachable) {
                Write-Ok '  database is accepting connections on 3306'
                $script:portMapCache = $null
                return $true
            }
            if ($process.HasExited) {
                Write-Bad "  mysqld exited with code $($process.ExitCode) during startup"
                Show-LogProblems -Definition $definition
                Show-ComponentLog -Definition $definition -Lines $Tail
                return $false
            }
            Start-Sleep -Seconds 1
        }

        Write-Bad "  database did not become ready within ${timeout}s"
        Show-LogProblems -Definition $definition
        Show-ComponentLog -Definition $definition -Lines $Tail
        return $false
    }

    # authserver / worldserver both need the database first.
    if (-not (Test-DatabaseReachable)) {
        Write-Bad "  the database is not reachable; start it first: .\Warband-Server.ps1 start db"
        return $false
    }
    if (-not (Test-Path -LiteralPath $definition.Executable)) {
        Write-Bad "  missing executable: $($definition.Executable). Build the stack first."
        return $false
    }

    $configFile = "configs\$($definition.Process).conf"
    Write-Step "  starting $($definition.Display)"
    $process = Start-Process -FilePath $definition.Executable -ArgumentList '-c', $configFile `
        -WorkingDirectory $binDirectory -PassThru

    $timeout = Get-StartTimeout -Definition $definition
    $ready = Wait-ForPort -Definition $definition -Process $process -TimeoutSeconds $timeout

    if ($ready) {
        Write-Ok "  $($definition.Display) is listening on $($definition.Port) (PID $($process.Id))"
        $script:portMapCache = $null
        return $true
    }

    if ($process.HasExited) {
        Write-Bad "  $($definition.Display) exited with code $($process.ExitCode) during startup"
    }
    else {
        Write-Bad "  $($definition.Display) did not start listening within ${timeout}s (PID $($process.Id))"
    }
    Show-LogProblems -Definition $definition
    Show-ComponentLog -Definition $definition -Lines $Tail
    $script:portMapCache = $null
    return $false
}

function Start-OneComponentWithDependencies {
    param([string]$Key)
    return (Start-OneComponent -Key $Key)
}

# --- Log display -------------------------------------------------------------------------------

# Pulls the lines that actually explain a failure out of a log, so a failed start says why
# instead of leaving the reason buried in a wall of loading messages.
function Show-LogProblems {
    param([hashtable]$Definition, [int]$MaxLines = 10)

    $tailLines = @(Get-LogTail -Definition $Definition -Lines 300)
    if ($tailLines.Count -eq 0) { return }

    $problems = @($tailLines |
        Where-Object { $_ -match '(?i)\[error\]|\[warning\]|aborting|failed|cannot|could not|no such|denied' } |
        Select-Object -Last $MaxLines)
    if ($problems.Count -eq 0) { return }

    Write-Bad '  reported problems:'
    foreach ($line in $problems) { Write-Host ("    " + $line.Trim()) -ForegroundColor Red }
}

function Show-ComponentLog {
    param([hashtable]$Definition, [int]$Lines = 20)

    $logFile = Get-LogFile -Definition $Definition
    if (-not $logFile) {
        Write-Note "  no $($Definition.LogLabel) found at $($Definition.LogPath)"
        return
    }

    Write-Host ''
    Write-Step "  last $Lines lines of $($logFile.FullName)"
    $tailLines = @(Get-LogTail -Definition $Definition -Lines $Lines)
    if ($tailLines.Count -eq 0) {
        Write-Note '    (empty or unreadable)'
        return
    }
    foreach ($line in $tailLines) { Write-Host "    $line" }
}

# --- Actions ------------------------------------------------------------------------------------

function Invoke-Start {
    param([string[]]$Keys)

    $ok = $true
    foreach ($key in $Keys) {
        if (Start-OneComponent -Key $key) { continue }

        # The login server refuses to start while every realm row has flag 3, which is precisely
        # what a world server interrupted during loading leaves behind. Repair it once and retry.
        if ($key -eq 'auth' -and (Test-RealmFlagsBlocked)) {
            Write-Host ''
            Write-Warn '  the realm row is marked VERSION_MISMATCH|OFFLINE (flag 3), so the login server'
            Write-Warn '  excludes it and refuses to start. An interrupted world server leaves that behind.'
            if (Reset-RealmFlags) {
                Write-Ok '  realm flags reset to 0, retrying the login server'
                Write-Host ''
                if (Start-OneComponent -Key $key) { continue }
            }
            else {
                Write-Bad '  could not reset the realm flags'
            }
        }

        $ok = $false
        break
    }

    if ($ok) {
        Write-Host ''
        Write-Ok 'All requested components are up.'
        Write-Note 'Unload them later with: .\Warband-Server.ps1 stop all  (this stops the database too)'
        Write-Host ''
    }
    return $ok
}

function Invoke-Stop {
    param([string[]]$Keys)

    $ok = $true
    foreach ($key in $Keys) {
        if (-not (Stop-OneComponent -Key $key)) { $ok = $false }
    }
    return $ok
}

function Invoke-Cleanup {
    $ok = Invoke-Stop -Keys $stopOrder

    # Anything still running under a WowWarband image name was not ours to stop above.
    foreach ($key in $startOrder) {
        $definition = $components[$key]
        foreach ($process in (Get-ComponentProcesses -ProcessName $definition.Process)) {
            $title = ''
            if ($process.MainWindowTitle) { $title = " holding console window ""$($process.MainWindowTitle)"""}
            Write-Warn "  reaping orphaned $($process.ProcessName) (PID $($process.Id))$title"
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            [void](Wait-ForProcessExit -ProcessId $process.Id -TimeoutSeconds 10)
        }
    }

    $script:portMapCache = $null
    Write-Host ''
    if ($ok) { Write-Ok 'Cleanup complete: no WowWarband process is left running.' }
    else { Write-Warn 'Cleanup complete, but at least one component had to be force-terminated.' }
    Write-Host ''
    return $ok
}

function Show-RealmState {
    $rows = @(Get-RealmRows)

    Write-Host ''
    Write-Step 'Realm rows (acore_auth.realmlist)'
    Write-Host ''

    if ($rows.Count -eq 0) {
        Write-Warn '  no realm rows found, or the database is not reachable'
        Write-Host ''
        return
    }

    Write-Host ("  {0,-4} {1,-20} {2,-16} {3,-6} {4,-6} {5}" -f 'id', 'name', 'address', 'port', 'flag', 'state')
    foreach ($row in $rows) {
        $fields = @($row -split "`t")
        if ($fields.Count -lt 5) { continue }
        $flag = $fields[4].Trim()
        $state = 'visible to clients'
        if ($flag -eq '3') { $state = 'EXCLUDED: version mismatch + offline (world server never finished loading)' }
        elseif ($flag -eq '1') { $state = 'hidden until the world server finishes loading' }
        elseif ($flag -eq '2') { $state = 'offline: no world server has connected' }
        Write-Host ("  {0,-4} {1,-20} {2,-16} {3,-6} {4,-6} {5}" -f `
            $fields[0], $fields[1], $fields[2], $fields[3], $flag, $state)
    }

    if (Test-RealmFlagsBlocked) {
        Write-Host ''
        Write-Warn '  With a flag-3 realm the login server exits with "No valid realms specified".'
        Write-Note '  `start all` repairs this automatically. Manually:'
        Write-Note '    UPDATE acore_auth.realmlist SET flag = 0 WHERE flag = 3;'
    }
    Write-Host ''
}

function Show-Help {
    Write-Host ''
    Write-Step 'Warband-Server.ps1 - load/unload the local WowWarband stack component by component'
    Write-Host ''
    Write-Host '  .\Warband-Server.ps1 status [db|auth|world]'
    Write-Host '      what is running, on which PID/port, and whether clients can connect'
    Write-Host ''
    Write-Host '  .\Warband-Server.ps1 start  <db|auth|world|all>   [-TimeoutSeconds N]'
    Write-Host '      start a component and wait until it is ready (world server progress is printed)'
    Write-Host ''
    Write-Host '  .\Warband-Server.ps1 stop   <db|auth|world|all>   [-Force] [-TimeoutSeconds N]'
    Write-Host '      graceful stop: mysqladmin shutdown, CTRL+C / CTRL+BREAK to the server consoles'
    Write-Host ''
    Write-Host '  .\Warband-Server.ps1 restart <db|auth|world|all>  [-Force]'
    Write-Host ''
    Write-Host '  .\Warband-Server.ps1 cleanup'
    Write-Host '      stop everything and reap orphaned mysqld/authserver/worldserver processes'
    Write-Host ''
    Write-Host '  .\Warband-Server.ps1 logs <db|auth|world> [-Tail N]'
    Write-Host '      show the tail of that component''s log'
    Write-Host ''
    Write-Host '  .\Warband-Server.ps1 realm'
    Write-Host '      show the realmlist row and whether clients can see the realm'
    Write-Host ''
    Write-Note '  Start order is db -> auth -> world; stop order is world -> auth -> db.'
    Write-Note '  A world server is only reachable after it logs that it is listening on 8085.'
    Write-Host ''
}

# --- Entry point ---------------------------------------------------------------------------------

function Resolve-Keys {
    param([string]$Selector, [string[]]$Order)
    if ($Selector -eq 'all') { return $Order }
    return @($Selector)
}

$success = $true
$selectedKeys = Resolve-Keys -Selector $Component -Order $startOrder

switch ($Action) {
    'status' {
        Show-Status -Keys $selectedKeys
    }
    'start' {
        $null = Invoke-Start -Keys $selectedKeys
        Show-Status -Keys $startOrder
        $ready = $true
        foreach ($key in $selectedKeys) {
            $state = Get-ComponentState -Definition $components[$key]
            if ($state.State -ne 'running') { $ready = $false }
        }
        $success = $ready
    }
    'stop' {
        $success = Invoke-Stop -Keys (Resolve-Keys -Selector $Component -Order $stopOrder)
        Show-Status -Keys $startOrder
    }
    'restart' {
        $success = Invoke-Stop -Keys (Resolve-Keys -Selector $Component -Order $stopOrder)
        if ($success) { $success = Invoke-Start -Keys $selectedKeys }
        Show-Status -Keys $startOrder
    }
    'cleanup' {
        $success = Invoke-Cleanup
        Show-Status -Keys $startOrder
    }
    'logs' {
        if ($Component -eq 'all') {
            foreach ($key in $startOrder) { Show-ComponentLog -Definition $components[$key] -Lines $Tail }
        }
        else {
            Show-ComponentLog -Definition $components[$Component] -Lines $Tail
        }
    }
    'realm' {
        Show-RealmState
    }
    'help' {
        Show-Help
    }
}

if ($Action -in @('start', 'stop', 'restart', 'cleanup')) {
    if ($success) { exit 0 } else { exit 1 }
}
exit 0
