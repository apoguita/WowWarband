# Warband-Module-Patches.ps1
#
# Warband adds features to two third-party module submodules it does not own:
#
#   mod-item-level-scaling  a required int32 cast in the item snapshot, and quest reward
#                           equipment scaling (ItemScaling.QuestRewards)
#   mod-zone-scaling        the group-level anchor (ZoneScaling.GroupAnchor)
#
# Those changes are committed inside the submodules, but the submodules point at upstream
# remotes the project cannot push to. So that a clone carries every Warband feature without
# depending on a fork existing, the changes are also tracked here as plain diffs under
# modules\patches\<module>\warband.patch and applied with this script.
#
# The script is idempotent: a submodule that already carries the patch is left alone, and a
# patch that no longer applies cleanly is reported instead of being forced.
#
#   .\Warband-Module-Patches.ps1                 report whether each patch is applied
#   .\Warband-Module-Patches.ps1 -Action apply   apply the missing patches
#
# Run it after git submodule update --init, before configuring or building.

param(
    [ValidateSet('status', 'apply')]
    [string]$Action = 'status'
)

$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot

$modules = @(
    [pscustomobject]@{
        Name  = 'mod-item-level-scaling'
        Path  = Join-Path $root 'modules\mod-item-level-scaling'
        Patch = Join-Path $root 'modules\patches\mod-item-level-scaling\warband.patch'
    },
    [pscustomobject]@{
        Name  = 'mod-zone-scaling'
        Path  = Join-Path $root 'modules\mod-zone-scaling'
        Patch = Join-Path $root 'modules\patches\mod-zone-scaling\warband.patch'
    }
)

$exitCode = 0

# Windows PowerShell turns a native command's stderr into an error record, and
# $ErrorActionPreference = 'Stop' (set above for a safe default) would then abort this script on
# the expected "patch does not apply" probe. Run the probes with Continue and read only the exit
# code, which is the signal git actually communicates.
function Invoke-GitCheck
{
    param(
        [string]$RepoPath,
        [string[]]$GitArguments
    )

    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try
    {
        & git -C $RepoPath @GitArguments 2>$null | Out-Null
        return $LASTEXITCODE
    }
    finally
    {
        $ErrorActionPreference = $previous
    }
}

foreach ($module in $modules)
{
    if (-not (Test-Path -LiteralPath $module.Path))
    {
        Write-Host "$($module.Name): submodule not checked out - run 'git submodule update --init' first"
        $exitCode = 1
        continue
    }

    if (-not (Test-Path -LiteralPath $module.Patch))
    {
        Write-Host "$($module.Name): patch file missing at $($module.Patch)"
        $exitCode = 1
        continue
    }

    # A patch that reverse-applies cleanly is already in the working tree.
    if ((Invoke-GitCheck -RepoPath $module.Path -GitArguments @('apply', '--reverse', '--check', $module.Patch)) -eq 0)
    {
        Write-Host "$($module.Name): Warband patch already applied"
        continue
    }

    if ((Invoke-GitCheck -RepoPath $module.Path -GitArguments @('apply', '--check', $module.Patch)) -ne 0)
    {
        Write-Host "$($module.Name): Warband patch does not apply cleanly (upstream changed?) - inspect modules\patches\$($module.Name)\warband.patch"
        $exitCode = 1
        continue
    }

    if ($Action -eq 'apply')
    {
        git -C $module.Path apply $module.Patch
        Write-Host "$($module.Name): Warband patch applied"
    }
    else
    {
        Write-Host "$($module.Name): Warband patch NOT applied - run '.\Warband-Module-Patches.ps1 -Action apply'"
        $exitCode = 1
    }
}

exit $exitCode
