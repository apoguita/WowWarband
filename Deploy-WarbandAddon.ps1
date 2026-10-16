<#
.SYNOPSIS
    Copies the WoW Warband client addon into the local client's addon folder.

.DESCRIPTION
    The addon source of truth is addons\Warband in this repository. The client keeps its own
    copy under var\client, and WoW reads addon files only when it starts, so restart the client
    after running this. A /reload is NOT enough: it re-runs already loaded files and will not
    pick up changed ones.

    Client-only changes such as this addon need no server build and no worldserver restart.

.EXAMPLE
    .\Deploy-WarbandAddon.ps1
#>
[CmdletBinding()]
param(
    [string]$Source = (Join-Path $PSScriptRoot "addons\Warband"),
    [string]$Client = (Join-Path $PSScriptRoot "var\client\world of warcraft 3.3.5a hd")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $Source)) {
    throw "Addon source folder not found: $Source"
}

if (-not (Test-Path $Client)) {
    throw "Client folder not found: $Client"
}

$interfaceDir = Get-ChildItem $Client -Directory | Where-Object { $_.Name -ieq "Interface" } | Select-Object -First 1
if (-not $interfaceDir) {
    throw "No Interface folder under $Client"
}

$addonsDir = Get-ChildItem $interfaceDir.FullName -Directory | Where-Object { $_.Name -ieq "AddOns" } | Select-Object -First 1
if (-not $addonsDir) {
    throw "No AddOns folder under $($interfaceDir.FullName)"
}

$target = Join-Path $addonsDir.FullName "Warband"
New-Item -ItemType Directory -Force -Path $target | Out-Null

$copied = 0
foreach ($file in Get-ChildItem $Source -File) {
    Copy-Item $file.FullName (Join-Path $target $file.Name) -Force
    $copied++
    Write-Host ("copied  {0}" -f $file.Name)
}

$mismatch = $false
foreach ($file in Get-ChildItem $Source -File) {
    $deployed = Join-Path $target $file.Name
    if (-not (Test-Path $deployed)) {
        Write-Warning "missing after copy: $($file.Name)"
        $mismatch = $true
        continue
    }
    if ((Get-FileHash $file.FullName).Hash -ne (Get-FileHash $deployed).Hash) {
        Write-Warning "hash differs: $($file.Name)"
        $mismatch = $true
    }
}

Write-Host ""
Write-Host ("Deployed {0} file(s) to {1}" -f $copied, $target)
if ($mismatch) {
    Write-Warning "Deployment did not verify cleanly - check the warnings above."
    exit 1
}

Write-Host "Now restart the WoW client, then open the panel with /warband or /ww."
