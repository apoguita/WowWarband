# Warband-ClearClientCaches.ps1
#
# Rebuilds the WoW client's item data cache, so tooltips re-query the server instead of showing
# whatever was cached the last time the client asked.
#
# Why this exists: item stats (price, requirement, stats) are cached by the client per item and
# stored on disk under <client>\Cache\WDB. Nothing the worldserver sends can invalidate that cache,
# so after a Warband change - a price rule, the gold multiplier on sell prices, an item requirement
# - the tooltip keeps the old numbers until the cached entry is deleted. Start-WowWarband.bat runs
# this script before loading the stack, so a normal start always begins from fresh item data.
#
#   .\Warband-ClearClientCaches.ps1          clear the item data cache (the tooltip-relevant files)
#   .\Warband-ClearClientCaches.ps1 -All     clear every WDB cache (items, quests, creatures, npcs)
#
# The client must be closed when this runs; a cache file that is open is reported and left alone,
# and the script exits 0 either way so a launcher can ignore it.

param(
    [switch]$All
)

$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
$clientRoot = Join-Path $root 'var\client'

$itemCaches = @('itemcache.wdb', 'itemnamecache.wdb', 'itemtextcache.wdb')

if (-not (Test-Path -LiteralPath $clientRoot))
{
    Write-Host 'No client installation under var\client - nothing to clear.'
    exit 0
}

$cacheFiles = @(Get-ChildItem -LiteralPath $clientRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $wdb = Join-Path $_.FullName 'Cache\WDB'
    if (Test-Path -LiteralPath $wdb)
    {
        Get-ChildItem -LiteralPath $wdb -Recurse -Filter '*.wdb' -File -ErrorAction SilentlyContinue
    }
})

if (-not $cacheFiles)
{
    Write-Host 'No WDB cache found under var\client - nothing to clear.'
    exit 0
}

$cleared = 0
$locked = 0

foreach ($file in $cacheFiles)
{
    if (-not $All -and $itemCaches -notcontains $file.Name)
    {
        continue
    }

    try
    {
        Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
        Write-Host "cleared $($file.FullName)"
        ++$cleared
    }
    catch
    {
        Write-Host "could not clear (is the game client running?): $($file.FullName)"
        ++$locked
    }
}

if ($locked -eq 0)
{
    Write-Host "Item cache rebuilt: $cleared file(s) removed; the client re-queries them on next launch."
}
else
{
    Write-Host "Cleared $cleared file(s), $locked left alone - close the game client and run this again."
}

exit 0
