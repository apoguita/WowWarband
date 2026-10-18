<#
.SYNOPSIS
    Assembles a precompiled WoW Warband release from a finished build.

.DESCRIPTION
    Produces one zip that a player can unzip and run: the server binaries, ready-to-use
    configuration, the SQL that rebuilds the databases, the client addons, the maintenance scripts,
    the licence texts, a manifest and an install note.

    What it deliberately does NOT contain:
      * the WoW client (never redistributable), and
      * extracted server data (dbc/maps/vmaps/mmaps), which is generated from the client with the
        extractor tools that ship in the zip, and
      * a database dump. AzerothCore's own model is used instead: `data/sql/create` plus
        `data/sql/base` plus `data/sql/updates`, applied with the shipped dbimport.exe.

.EXAMPLE
    .\Package-WowWarband.ps1

.EXAMPLE
    .\Package-WowWarband.ps1 -Version 1.0.0 -OutputDir dist
#>
[CmdletBinding()]
param(
    [string]$BuildDir = "",
    [string]$OutputDir = "",
    [string]$Version = ""
)

$ErrorActionPreference = "Stop"

# $PSScriptRoot is empty when the script is launched through `powershell -File`, so the repository
# root is resolved from the script's own path instead.
$repo = $PSScriptRoot

if (-not $repo) {
    $repo = Split-Path -Parent $MyInvocation.MyCommand.Path
}

if (-not $repo) {
    $repo = (Get-Location).Path
}

if (-not $BuildDir) {
    $BuildDir = Join-Path $repo "bin\RelWithDebInfo"
}

if (-not $OutputDir) {
    $OutputDir = Join-Path $repo "dist"
}

if (-not (Test-Path $BuildDir)) {
    throw "Build directory not found: $BuildDir. Build the server first (Build-WowWarband.bat)."
}

if (-not (Test-Path (Join-Path $BuildDir "worldserver.exe"))) {
    throw "worldserver.exe is missing from $BuildDir - the build did not finish."
}

# A version string from the checkout when none is given, so every release can be traced back.
if (-not $Version) {
    $sha = (git -C $repo rev-parse --short HEAD 2>$null)
    if (-not $sha) {
        $sha = (Get-Date -Format "yyyyMMdd")
    }

    $Version = "$sha"
}

$packageName = "wow-warband-$Version-win64"
$stage = Join-Path ([System.IO.Path]::GetTempPath()) $packageName

if (Test-Path $stage) {
    Remove-Item $stage -Recurse -Force
}

New-Item -ItemType Directory -Path $stage -Force | Out-Null
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

function Copy-Tree([string]$from, [string]$to) {
    if (Test-Path $from) {
        New-Item -ItemType Directory -Path $to -Force | Out-Null
        Copy-Item -Path (Join-Path $from "*") -Destination $to -Recurse -Force
        Write-Host "  included  $from"
    } else {
        Write-Host "  skipped   $from (not present)"
    }
}

Write-Host "Assembling $packageName"

# 1) Binaries. Debug symbols, logs and import libraries are build by-products, not runtime files.
$bin = Join-Path $stage "bin"
New-Item -ItemType Directory -Path $bin -Force | Out-Null

$binaryPattern = @("*.exe", "*.dll")
$excluded = @("lua52_compiler.exe", "lua52_interpreter.exe", "lua52.lib")

Get-ChildItem $BuildDir -File | Where-Object {
    $name = $_.Name

    if ($_.Extension -eq ".pdb" -or $_.Extension -eq ".log" -or $_.Extension -eq ".lib") {
        return $false
    }

    return ($excluded -notcontains $name) -and (
        $_.Extension -eq ".exe" -or $_.Extension -eq ".dll" -or $_.Extension -eq ".yaml")
} | ForEach-Object {
    Copy-Item $_.FullName -Destination (Join-Path $bin $_.Name) -Force
}

Write-Host "  included  $BuildDir (binaries)"

# 2) Configuration: the shipped templates, plus ready-to-run files with the local paths removed.
$configTarget = Join-Path $bin "configs"
New-Item -ItemType Directory -Path $configTarget -Force | Out-Null

Get-ChildItem (Join-Path $BuildDir "configs") -File | Copy-Item -Destination $configTarget -Force
Copy-Tree (Join-Path $BuildDir "configs\modules") (Join-Path $configTarget "modules")

$dataDirLine = 'DataDir = "./data"'
foreach ($conf in @("worldserver.conf", "authserver.conf", "dbimport.conf")) {
    $path = Join-Path $configTarget $conf

    if (-not (Test-Path $path)) {
        continue
    }

    $text = Get-Content $path -Raw
    $text = [regex]::Replace($text, '(?m)^\s*DataDir\s*=.*$', $dataDirLine)
    Set-Content -Path $path -Value $text -NoNewline
}

# The auction bot needs a character of the player's own; a shipped GUID would be meaningless.
$ahConf = Join-Path $configTarget "modules\mod_ahbot.conf"
if (Test-Path $ahConf) {
    $text = Get-Content $ahConf -Raw
    $text = [regex]::Replace($text, '(?m)^\s*AuctionHouseBot\.GUIDs\s*=.*$',
        'AuctionHouseBot.GUIDs = 0')
    Set-Content -Path $ahConf -Value $text -NoNewline
}

# 3) SQL: the core's create/base/updates plus each module's own SQL, which dbimport applies.
$sqlTarget = Join-Path $stage "data\sql"
Copy-Tree (Join-Path $repo "data\sql\create") (Join-Path $sqlTarget "create")
Copy-Tree (Join-Path $repo "data\sql\base") (Join-Path $sqlTarget "base")
Copy-Tree (Join-Path $repo "data\sql\updates") (Join-Path $sqlTarget "updates")

foreach ($module in Get-ChildItem (Join-Path $repo "modules") -Directory) {
    $moduleSql = Join-Path $module.FullName "data\sql"

    if (Test-Path $moduleSql) {
        Copy-Tree $moduleSql (Join-Path $sqlTarget ("modules\" + $module.Name))
    }
}

# 4) Client addons.
$addonTarget = Join-Path $stage "Interface\AddOns"
foreach ($addon in @("Warband", "MultiBot", "PlayerbotManager")) {
    Copy-Tree (Join-Path $repo "addons\$addon") (Join-Path $addonTarget $addon)
}

# 5) Maintenance scripts.
$scriptTarget = Join-Path $stage "scripts"
New-Item -ItemType Directory -Path $scriptTarget -Force | Out-Null
Get-ChildItem $repo -File | Where-Object { $_.Extension -eq ".bat" -or $_.Extension -eq ".ps1" } |
    ForEach-Object { Copy-Item $_.FullName -Destination $scriptTarget -Force }

Write-Host "  included  $scriptTarget"

# 6) Licence texts.
Copy-Item (Join-Path $repo "LICENSE") (Join-Path $stage "LICENSE") -Force
foreach ($module in Get-ChildItem (Join-Path $repo "modules") -Directory) {
    $moduleLicense = Get-ChildItem $module.FullName -Filter "LICENSE*" -File -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($moduleLicense) {
        Copy-Item $moduleLicense.FullName (Join-Path $stage ("LICENSE-" + $module.Name + ".txt")) -Force
    }
}

# 7) Manifest: exactly what this build is made of.
$manifest = New-Object System.Collections.Generic.List[string]
$manifest.Add("WoW Warband release $Version")
$manifest.Add("Built      " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
$manifest.Add("")
$manifest.Add("Repository " + (git -C $repo remote get-url origin 2>$null))
$manifest.Add("Commit     " + (git -C $repo rev-parse HEAD 2>$null))
$manifest.Add("")
$manifest.Add("Modules:")

foreach ($module in Get-ChildItem (Join-Path $repo "modules") -Directory) {
    $sha = git -C $module.FullName rev-parse HEAD 2>$null

    if (-not $sha) {
        $sha = "(working tree, not a git checkout)"
    }

    $manifest.Add("  " + $module.Name.PadRight(28) + $sha)
}

$manifest.Add("")
$manifest.Add("Binaries:")
foreach ($file in Get-ChildItem $bin -File | Where-Object { $_.Extension -eq ".exe" -or $_.Extension -eq ".dll" }) {
    $manifest.Add("  " + $file.Name.PadRight(28) + [math]::Round($file.Length / 1MB, 1) + " MB")
}

$manifestPath = Join-Path $stage "MANIFEST.txt"
$manifest -join [Environment]::NewLine | Set-Content -Path $manifestPath -Encoding UTF8

# 8) Install note: the five steps, in the order that works.
$install = @"
WoW Warband $Version - install note

This package is a precompiled server. It does not contain the World of Warcraft client and does not
contain a database dump; the databases are rebuilt from SQL with the dbimport.exe in `bin`.

What you need before starting
  * World of Warcraft 3.3.5a (build 12340) - not included, never redistributable
  * MySQL 8.0 or later, installed and running, with a user that can create databases
  * about 8 GB of free disk space if you generate the map files yourself

Steps
  1. Unzip this package to the folder that will be the server, for example C:\WoWWarband.
  2. Create the databases. From bin\, run:

         .\dbimport.exe

     It reads bin\configs\dbimport.conf and applies data\sql\create, data\sql\base,
     data\sql\updates and every module's SQL under data\sql\modules. Set the MySQL login there
     (DatabaseInfo) first - the shipped default is acore / acore on 127.0.0.1:3306.
  3. Generate the missing world data. From bin\, with your client folder as the source:

         .\map_extractor.exe
         .\vmap4_extractor.exe
         .\vmap4_assembler.exe
         .\mmaps_generator.exe

     Put the results under data\ next to bin\ (dbc, maps, vmaps, mmaps). If you already have a
     previous Warband install, copy its data folder instead - it is the same format.
  4. Start the server: run scripts\Start-WowWarband.bat. The login server listens on 3724 and the
     world server on 8085.
  5. Copy the addons: run scripts\Deploy-WarbandAddon.ps1 for the Warband panel, and copy
     Interface\AddOns\MultiBot and Interface\AddOns\PlayerbotManager into your client's
     Interface\AddOns folder yourself.

Notes
  * The auction bot needs a character of your own: set AuctionHouseBot.GUIDs in
    bin\configs\modules\mod_ahbot.conf to that character's guid from acore_characters.characters.
  * Every Warband option is on the client panel ( /warband or /ww ) and in
    bin\configs\modules\mod_warband.conf.
  * Warband is GPL v2; the bundled modules keep their own licences, shipped here as
    LICENSE-<module>.txt. Source for all of it is in the public repository named in MANIFEST.txt.
"@

$install | Set-Content -Path (Join-Path $stage "INSTALL.txt") -Encoding UTF8

# 9) Zip it. Compress-Archive in PowerShell 5.1 chokes on some build outputs ("user-mapped section
# open"), so the framework's ZipFile is used directly, with tar.exe as a last resort.
$zipPath = Join-Path $OutputDir ("$packageName.zip")
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

$zipped = $false

try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory(
        $stage,
        $zipPath,
        [System.IO.Compression.CompressionLevel]::Optimal,
        $false)
    $zipped = $true
} catch {
    Write-Host "  ZipFile failed ($($_.Exception.Message)); falling back to tar" -ForegroundColor Yellow
}

if (-not $zipped) {
    tar.exe -a -c -f $zipPath -C $stage .
    $zipped = Test-Path $zipPath
}

if (-not $zipped) {
    throw "Could not create $zipPath. The staging folder is intact at $stage."
}

$size = [math]::Round((Get-Item $zipPath).Length / 1MB, 1)

Write-Host ""
Write-Host "Release ready: $zipPath ($size MB)" -ForegroundColor Green
Write-Host "Staging kept for inspection: $stage"
