<#
.SYNOPSIS
    Keeps the .github copy of the project README in step with the root one.

.DESCRIPTION
    README.md at the repository root is the source of truth. .github/README.md is
    the same document with every relative link rewritten to climb out of .github/
    (doc/x.md becomes ../doc/x.md). GitHub renders a README from either location,
    so the two must never disagree: a feature status updated in one and forgotten
    in the other is a wrong answer about the project.

    No arguments: check the two files and exit 1 when they differ, listing the
    first few differing lines. Use this before committing.
    -Fix: regenerate .github/README.md from README.md.

.EXAMPLE
    .\Sync-ProjectReadme.ps1
    .\Sync-ProjectReadme.ps1 -Fix
#>
[CmdletBinding()]
param(
    [switch]$Fix,
    [string]$Source,
    [string]$Copy
)

$ErrorActionPreference = "Stop"

# $PSScriptRoot is empty when the script is invoked through some wrappers, so fall back to the
# current directory rather than failing on a default that cannot be resolved.
$repoRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
if (-not $Source) { $Source = Join-Path $repoRoot "README.md" }
if (-not $Copy) { $Copy = Join-Path $repoRoot ".github\README.md" }

foreach ($path in @($Source, $Copy)) {
    if (-not (Test-Path $path)) {
        throw "README not found: $path"
    }
}

function Read-Text([string]$Path) {
    # Normalise to LF so a line-ending difference never reads as a content difference.
    return ([System.IO.File]::ReadAllText($Path)) -replace "`r`n", "`n"
}

# Prefix ../ on every relative markdown link, leaving absolute URLs, in-page anchors and
# links that already climb out alone.
function Convert-ToCopy([string]$Text) {
    return $Text -replace '\]\((?!#|https?:|\.\./|/)([^)]+)\)', '](../$1)'
}

$expected = (Convert-ToCopy (Read-Text $Source)).TrimEnd("`n")
$actual = (Read-Text $Copy).TrimEnd("`n")

if ($expected -ceq $actual) {
    Write-Host "In step: $([System.IO.Path]::GetFileName((Split-Path $Copy))) matches $([System.IO.Path]::GetFileName($Source))"
    exit 0
}

if (-not $Fix) {
    Write-Warning "The .github README is out of step with the root README."
    $expectedLines = $expected -split "`n"
    $actualLines = $actual -split "`n"
    $shown = 0
    for ($i = 0; $i -lt [Math]::Max($expectedLines.Count, $actualLines.Count); $i++) {
        $e = if ($i -lt $expectedLines.Count) { $expectedLines[$i] } else { "<missing>" }
        $a = if ($i -lt $actualLines.Count) { $actualLines[$i] } else { "<missing>" }
        if ($e -cne $a) {
            Write-Host ("  line {0}" -f ($i + 1))
            Write-Host ("    root  : {0}" -f $e)
            Write-Host ("    github: {0}" -f $a)
            $shown++
            if ($shown -ge 8) {
                Write-Host "  ..."
                break
            }
        }
    }
    Write-Host ""
    Write-Host "Regenerate it with: .\Sync-ProjectReadme.ps1 -Fix"
    exit 1
}

[System.IO.File]::WriteAllText($Copy, $expected + "`n", (New-Object System.Text.UTF8Encoding($false)))
Write-Host "Regenerated .github/README.md from README.md"
