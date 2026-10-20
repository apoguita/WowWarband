<#
.SYNOPSIS
    Install the addon(s) from a zip into the Warband client's Interface\AddOns folder.

.DESCRIPTION
    This is an operator convenience, NOT part of the Warband setup: addons installed this way are
    third-party client tools, they are not bundled with the project, not a dependency of it and not
    part of any build. The project's own addon is deployed with Deploy-WarbandAddon.ps1.

    It exists because the usual failure when installing by hand is folder depth: a GitHub zip
    unpacks as  Skada-WoTLK-main\Skada\Skada.toc  and the client only loads  AddOns\Skada\.

    A zip can hold more than one addon (Skada ships Skada, SkadaImprovement and SkadaStorage); every
    folder that holds a .toc is installed, each under its own .toc name, which is what the client
    requires.

.PARAMETER Zip
    Path to the addon zip (GitHub "Download ZIP", CurseForge, anywhere).

.PARAMETER ClientPath
    The client install folder. Defaults to the Warband runtime client.

.PARAMETER Name
    Install only the addon whose .toc is named this (for example Skada).

.EXAMPLE
    .\Install-ClientAddon.ps1 -Zip "$env:USERPROFILE\Downloads\Skada-WoTLK-main.zip"

.EXAMPLE
    .\Install-ClientAddon.ps1 -Zip .\Skada.zip -Name Skada
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Zip,

    [string]$ClientPath,

    [string]$Name
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not $ClientPath) { $ClientPath = Join-Path $projectRoot 'var\client\world of warcraft 3.3.5a hd' }

$addonRoot = Join-Path $ClientPath 'Interface\AddOns'

if (-not (Test-Path -LiteralPath $Zip)) { throw "No such zip: $Zip" }
if (-not (Test-Path -LiteralPath $addonRoot)) { throw "No AddOns folder at: $addonRoot" }

$work = Join-Path $env:TEMP ('warband-addon-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work -Force | Out-Null

try {
    Expand-Archive -LiteralPath $Zip -DestinationPath $work -Force

    $tocs = @(Get-ChildItem -LiteralPath $work -Recurse -Filter '*.toc' -File |
        Sort-Object { ($_.FullName.Split('\').Count) })

    if ($tocs.Count -eq 0) { throw 'No .toc file in this zip - it is not a client addon.' }

    if ($Name) {
        $tocs = @($tocs | Where-Object { $_.BaseName -ieq $Name })
        if ($tocs.Count -eq 0) { throw "No addon named '$Name' in this zip." }
    }

    foreach ($toc in $tocs) {
        # The client loads AddOns\<folder>\<folder>.toc, so the folder is named after the .toc.
        $addonName = $toc.BaseName
        $target = Join-Path $addonRoot $addonName

        if (Test-Path -LiteralPath $target) {
            Remove-Item -LiteralPath $target -Recurse -Force
            Write-Host "replaced the existing $addonName"
        }

        Copy-Item -LiteralPath $toc.Directory.FullName -Destination $target -Recurse -Force

        $interfaceVersion = (Get-Content -LiteralPath (Join-Path $target $toc.Name) |
            Where-Object { $_ -match '^\s*##\s*Interface\s*:' } | Select-Object -First 1)

        Write-Host "installed: $target"
        Write-Host "  $($toc.Name)$(if ($interfaceVersion) { '  (' + $interfaceVersion.Trim() + ')' })"
        Write-Host "  files: $((Get-ChildItem -LiteralPath $target -Recurse -File).Count)"
    }

    Write-Host ""
    Write-Host "Restart the client (a new addon is only picked up at launch), then enable it under Addons"
    Write-Host "on the character screen."
}
finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
