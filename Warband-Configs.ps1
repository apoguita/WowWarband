# Warband config replication
#
# This script carries the project's deliberate configuration changes, so a fresh clone of the
# repository behaves like the machine the changes were made on. It does NOT copy whole config files:
# a whole worldserver.conf carries database credentials and a machine-specific DataDir, and copying
# it over someone else's install would break their server. It carries key = value lines only, for
# the keys this project actually decided to change.
#
# The tracked set lives in data\configs\, mirroring the installed layout:
#
#     data\configs\worldserver.conf
#     data\configs\modules\playerbots.conf
#     ...
#
# Usage, after building and before (or after) the first start:
#
#     .\Warband-Configs.ps1 -Action check      # default: report drift, change nothing
#     .\Warband-Configs.ps1 -Action apply      # write the tracked values into the installed configs
#     .\Warband-Configs.ps1 -Action export     # capture the current install's deltas into data\configs
#
# apply preserves everything else in each file: only the keys named in data\configs are touched,
# and a key that is missing from the installed file is appended with a note saying where it came from.
#
# export is how a new decision gets recorded: tune the server, run export, commit data\configs.
# It compares the installed config against the shipped .dist template and keeps every difference
# except the exclusions below, which are machine-specific and must never be replicated.

[CmdletBinding()]
param(
    [ValidateSet('check', 'apply', 'export')]
    [string]$Action = 'check',

    # Where the installed configs are. Overridable so the script can be exercised against a copy.
    [string]$ConfigRoot,

    [string]$OverridesRoot
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not $ConfigRoot) { $ConfigRoot = Join-Path $projectRoot 'bin\RelWithDebInfo\configs' }
if (-not $OverridesRoot) { $OverridesRoot = Join-Path $projectRoot 'data\configs' }

# Keys that describe this machine rather than the project. Replicating them would overwrite someone
# else's database credentials or point their server at a path that does not exist.
$excludedKeys = @(
    'DataDir',
    'LoginDatabaseInfo',
    'WorldDatabaseInfo',
    'CharacterDatabaseInfo',
    'SOAP.Password'
)

# Installed config -> the shipped template it was copied from. export diffs against these.
function Get-TemplatePath([string]$relativePath) {
    # A root-level file such as worldserver.conf ships from src\server\apps\<name>\<name>.conf.dist.
    $leaf = Split-Path $relativePath -Leaf
    $stem = [System.IO.Path]::GetFileNameWithoutExtension($leaf)
    $appTemplate = Join-Path $projectRoot ("src\server\apps\" + $stem + "\" + $leaf + ".dist")
    if (Test-Path -LiteralPath $appTemplate) { return $appTemplate }

    if ($relativePath -like 'modules\*') {
        $modulesRoot = Join-Path $projectRoot 'modules'
        if (Test-Path -LiteralPath $modulesRoot) {
            $candidate = Get-ChildItem -Recurse -Path $modulesRoot -Filter ($leaf + '.dist') -ErrorAction SilentlyContinue |
                Select-Object -First 1
            if ($candidate) { return $candidate.FullName }
        }
    }

    return $null
}

function Read-Settings([string]$path) {
    $settings = [ordered]@{}
    if (-not (Test-Path -LiteralPath $path)) { return $settings }

    foreach ($line in Get-Content -LiteralPath $path) {
        $trimmed = $line.Trim()
        if ($trimmed -eq '' -or $trimmed.StartsWith('#')) { continue }
        if ($trimmed -match '^([A-Za-z0-9_.]+)\s*=\s*(.*)$') { $settings[$matches[1]] = $matches[2].Trim() }
    }

    return $settings
}

function Get-OverrideFiles {
    if (-not (Test-Path -LiteralPath $OverridesRoot)) { return @() }
    return @(Get-ChildItem -Recurse -LiteralPath $OverridesRoot -Filter '*.conf' -File)
}

function Test-Check {
    $files = Get-OverrideFiles
    if ($files.Count -eq 0) {
        Write-Host "No tracked overrides in $OverridesRoot - nothing to replicate."
        return 0
    }

    $drift = 0

    foreach ($file in $files) {
        $relative = $file.FullName.Substring($OverridesRoot.Length).TrimStart('\')
        $installed = Join-Path $ConfigRoot $relative
        $wanted = Read-Settings $file.FullName
        $actual = Read-Settings $installed

        $report = @()
        foreach ($key in $wanted.Keys) {
            if (-not $actual.Contains($key)) { $report += "    $key : missing (tracked value '$($wanted[$key])')" }
            elseif ($actual[$key] -ne $wanted[$key]) { $report += "    $key : installed '$($actual[$key])' but tracked '$($wanted[$key])'" }
        }

        if ($report.Count -gt 0) {
            Write-Host "out of step: $relative"
            $report | ForEach-Object { Write-Host $_ }
            $drift += $report.Count
        }
    }

    if ($drift -eq 0) { Write-Host "In step: every tracked setting matches the installed configuration." }
    else { Write-Host ""; Write-Host "Run .\Warband-Configs.ps1 -Action apply to write the tracked values." }

    return $drift
}

function Invoke-Apply {
    $files = Get-OverrideFiles
    if ($files.Count -eq 0) {
        Write-Host "No tracked overrides in $OverridesRoot - nothing to apply."
        return
    }

    $changed = 0

    foreach ($file in $files) {
        $relative = $file.FullName.Substring($OverridesRoot.Length).TrimStart('\')
        $installed = Join-Path $ConfigRoot $relative
        $wanted = Read-Settings $file.FullName

        if (-not (Test-Path -LiteralPath $installed)) {
            Write-Host "skipped (no installed file): $relative"
            continue
        }

        $lines = @(Get-Content -LiteralPath $installed)
        $touched = $false
        $appended = @()

        for ($index = 0; $index -lt $lines.Count; $index++) {
            $trimmed = $lines[$index].Trim()
            if ($trimmed -eq '' -or $trimmed.StartsWith('#')) { continue }
            if ($trimmed -notmatch '^([A-Za-z0-9_.]+)\s*=\s*(.*)$') { continue }

            $key = $matches[1]
            if (-not $wanted.Contains($key)) { continue }

            # Compare the value, not the line: the installed files pad the keys with spaces and a
            # rewrite for padding alone would make apply look busy on every run.
            if ($matches[2].Trim() -ne $wanted[$key]) {
                $lines[$index] = "$key = $($wanted[$key])"
                $touched = $true
                Write-Host "  $relative : $key = $($wanted[$key])"
            }

            $appended += $key
        }

        $missing = @($wanted.Keys | Where-Object { $appended -notcontains $_ })
        if ($missing.Count -gt 0) {
            $lines += ''
            $lines += '# Set by Warband (data\configs) - see Warband-Configs.ps1'
            foreach ($key in $missing) {
                $lines += "$key = $($wanted[$key])"
                $touched = $true
                Write-Host "  $relative : $key = $($wanted[$key]) (added)"
            }
        }

        if ($touched) {
            Set-Content -LiteralPath $installed -Value $lines -Encoding UTF8
            $changed++
        }
    }

    if ($changed -eq 0) { Write-Host "In step: nothing to write." }
    else { Write-Host ""; Write-Host "Wrote $changed config file(s). Restart the worldserver (and the authserver for its own file) to load them." }
}

function Invoke-Export {
    if (-not (Test-Path -LiteralPath $ConfigRoot)) {
        Write-Host "No installed configs at $ConfigRoot - nothing to capture."
        return
    }

    $captured = 0

    foreach ($installed in Get-ChildItem -Recurse -LiteralPath $ConfigRoot -Filter '*.conf' -File) {
        $relative = $installed.FullName.Substring($ConfigRoot.Length).TrimStart('\')
        $template = Get-TemplatePath $relative

        if (-not $template) {
            Write-Host "no template for $relative - skipped"
            continue
        }

        $actual = Read-Settings $installed.FullName
        $shipped = Read-Settings $template

        $lines = @()
        foreach ($key in $actual.Keys) {
            if ($excludedKeys -contains $key) { continue }
            if ($shipped.Contains($key) -and $shipped[$key] -eq $actual[$key]) { continue }
            $lines += "$key = $($actual[$key])"
        }

        $target = Join-Path $OverridesRoot $relative
        $targetDir = Split-Path -Parent $target
        if (-not (Test-Path -LiteralPath $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }

        if ($lines.Count -eq 0) {
            if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target }
            continue
        }

        $header = @(
            "# Warband config overrides for $relative",
            "# Generated by Warband-Configs.ps1 -Action export. Tune the server, re-run export, commit this file.",
            "# Only these keys are written by .\Warband-Configs.ps1 -Action apply; everything else in the",
            "# installed file is left alone.",
            ''
        )

        Set-Content -LiteralPath $target -Value ($header + $lines) -Encoding UTF8
        Write-Host "captured $relative : $($lines.Count) key(s)"
        $captured++
    }

    if ($captured -eq 0) { Write-Host "Nothing differs from the shipped templates." }
}

switch ($Action) {
    'check'  { [void](Test-Check) }
    'apply'  { Invoke-Apply }
    'export' { Invoke-Export }
}
