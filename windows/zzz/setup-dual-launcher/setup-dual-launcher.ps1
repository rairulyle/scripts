#Requires -RunAsAdministrator
#
# ZZZ Dual Launcher Setup
# Shares game data between Steam and Epic via NTFS junctions + hard links.
# Each launcher keeps its own HoYoPlay and channel-specific files.

# Channel/platform-specific files -- never shared, each launcher downloads its own
$exclude = @(
    'config.ini',             # channel identifier (cps=Steam or cps=mihoyo etc.)
    'pkg_version',            # Sophon file manifest, per-channel
    'file_category_launcher', # Sophon category manifest, per-channel
    'sdk_pkg_version',        # Sophon SDK manifest, per-channel
    'version_info',           # per-channel version record
    'steam_appid.txt'         # Steam-only, must not exist on Epic side
)

$defaultPaths = @{
    Epic  = 'D:\Program Files\Epic Games\ZenlessZoneZero\games\ZenlessZoneZero Game'
    Steam = 'D:\Program Files (x86)\Steam\steamapps\common\Zenless Zone Zero\games\ZenlessZoneZero Game'
}

function Test-GameFolder($path) {
    # A valid ZZZ game folder must contain ZenlessZoneZero.exe
    return (Test-Path -LiteralPath (Join-Path $path 'ZenlessZoneZero.exe'))
}

# --- Step 1: Choose source launcher ---
Write-Host ""
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "  ZZZ Dual Launcher Setup" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Which launcher has the FULL game install (the source)?" -ForegroundColor White
Write-Host "  [1] Epic Games  (default)" -ForegroundColor Yellow
Write-Host "  [2] Steam" -ForegroundColor Yellow
Write-Host ""
$choice = Read-Host "Enter 1 or 2 (or press Enter for default)"
if ($choice -eq '2') {
    $sourceName = 'Steam'
    $destName   = 'Epic'
} else {
    $sourceName = 'Epic'
    $destName   = 'Steam'
}
Write-Host "  Source  : $sourceName" -ForegroundColor Green
Write-Host "  Target  : $destName (will receive junctions/hard links)" -ForegroundColor Green

# --- Step 2: Confirm/enter directories ---
Write-Host ""
Write-Host "Source game folder path?" -ForegroundColor White
Write-Host "  This should be the folder containing ZenlessZoneZero.exe" -ForegroundColor Yellow
Write-Host "  Default: $($defaultPaths[$sourceName])" -ForegroundColor DarkGray
Write-Host "  Press Enter to use default, or paste a custom path." -ForegroundColor DarkGray

$srcGame = $null
while (-not $srcGame) {
    Write-Host ""
    $inputPath = Read-Host "Source path"
    $candidate = if ([string]::IsNullOrWhiteSpace($inputPath)) { $defaultPaths[$sourceName] } else { $inputPath.Trim().Trim('"') }

    if (-not (Test-Path -LiteralPath $candidate)) {
        Write-Host "  ERROR: Path does not exist -- try again." -ForegroundColor Red
        Write-Host "    $candidate" -ForegroundColor Red
    } elseif (-not (Test-GameFolder $candidate)) {
        Write-Host "  ERROR: ZenlessZoneZero.exe not found in that folder -- try again." -ForegroundColor Red
        Write-Host "    $candidate" -ForegroundColor Red
        Write-Host "  Make sure you select the 'ZenlessZoneZero Game' subfolder, not the launcher root." -ForegroundColor Yellow
    } else {
        $srcGame = $candidate
        Write-Host "  Source verified." -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Destination game folder path?" -ForegroundColor White
Write-Host "  This is where junctions/hard links will be created (the $destName install)." -ForegroundColor Yellow
Write-Host "  Default: $($defaultPaths[$destName])" -ForegroundColor DarkGray
Write-Host "  Press Enter to use default, or paste a custom path." -ForegroundColor DarkGray

$destGame = $null
while (-not $destGame) {
    Write-Host ""
    $inputDest = Read-Host "Destination path"
    $candidate = if ([string]::IsNullOrWhiteSpace($inputDest)) { $defaultPaths[$destName] } else { $inputDest.Trim().Trim('"') }

    $srcRoot  = [System.IO.Path]::GetPathRoot($srcGame)
    $destRoot = [System.IO.Path]::GetPathRoot($candidate)

    if ($candidate -eq $srcGame) {
        Write-Host "  ERROR: Destination cannot be the same as source -- try again." -ForegroundColor Red
    } elseif ($srcRoot -ine $destRoot) {
        Write-Host "  ERROR: Source and destination are on different drives -- try again." -ForegroundColor Red
        Write-Host "    Source drive      : $srcRoot" -ForegroundColor Red
        Write-Host "    Destination drive : $destRoot" -ForegroundColor Red
        Write-Host "  NTFS hard links cannot cross volumes, so both installs must live on the same drive." -ForegroundColor Yellow
    } elseif (Test-Path -LiteralPath $candidate) {
        $destItem = Get-Item -LiteralPath $candidate -Force
        if ($destItem.LinkType -eq 'Junction') {
            Write-Host "  ERROR: That path is already a junction. Remove it first:" -ForegroundColor Red
            Write-Host "    (Get-Item '$candidate').Delete()" -ForegroundColor Red
        } else {
            $destGame = $candidate
            Write-Host "  Destination verified." -ForegroundColor Green
        }
    } else {
        $destGame = $candidate
        Write-Host "  Destination will be created." -ForegroundColor Green
    }
}

# --- Step 3: Preview summary ---
$items   = Get-ChildItem -LiteralPath $srcGame -Force
$folders = $items | Where-Object { $_.PSIsContainer }
$files   = $items | Where-Object { -not $_.PSIsContainer }
$toLink  = $files | Where-Object { $exclude -notcontains $_.Name }
$toExcl  = $files | Where-Object { $exclude -contains $_.Name }

$totalSizeGB = [math]::Round(($toLink | Measure-Object -Property Length -Sum).Sum / 1GB, 2)
$dataGB      = [math]::Round(($folders | ForEach-Object {
    (Get-ChildItem -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue |
     Measure-Object -Property Length -Sum).Sum
} | Measure-Object -Sum).Sum / 1GB, 2)

Write-Host ""
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "  Summary" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Source  : $srcGame" -ForegroundColor White
Write-Host "  Target  : $destGame" -ForegroundColor White
Write-Host ""
Write-Host "  JUNCTIONS  -- $($folders.Count) folders, ~$dataGB GB shared, zero extra disk:" -ForegroundColor Cyan
foreach ($f in $folders) { Write-Host "    + $($f.Name)" -ForegroundColor Green }
Write-Host ""
Write-Host "  HARD LINKS  -- $($toLink.Count) files, ~$totalSizeGB GB, zero extra disk:" -ForegroundColor Cyan
foreach ($f in $toLink) { Write-Host "    + $($f.Name)" -ForegroundColor Green }
Write-Host ""
Write-Host "  EXCLUDED    -- $($toExcl.Count) files, $destName launcher will download these fresh:" -ForegroundColor DarkGray
foreach ($f in $toExcl) { Write-Host "    - $($f.Name)" -ForegroundColor DarkGray }
Write-Host ""

$confirm = Read-Host "Proceed? [Y/N]"
if ($confirm -notmatch '^[Yy]') {
    Write-Host "Aborted." -ForegroundColor Yellow
    exit 0
}

# --- Step 4: Execute ---
Write-Host ""
if (-not (Test-Path -LiteralPath $destGame)) {
    New-Item -ItemType Directory -Path $destGame -Force | Out-Null
    Write-Host "Created destination folder: $destGame" -ForegroundColor Cyan
}

$failures = @()

Write-Host ""
Write-Host "=== Creating junctions ===" -ForegroundColor Cyan
foreach ($item in $folders) {
    $link = Join-Path $destGame $item.Name
    if (Test-Path -LiteralPath $link) {
        $ex = Get-Item -LiteralPath $link -Force
        if ($ex.LinkType -eq 'Junction') {
            Write-Host "  SKIP (already linked)  $($item.Name)" -ForegroundColor DarkGray
        } else {
            Write-Warning "  SKIP (real folder exists): $($item.Name)"
        }
        continue
    }
    try {
        New-Item -ItemType Junction -Path $link -Target $item.FullName -ErrorAction Stop | Out-Null
        Write-Host "  JUNCTION  $($item.Name)" -ForegroundColor Green
    } catch {
        $failures += "Junction $($item.Name): $($_.Exception.Message)"
        Write-Host "  FAILED    $($item.Name) -- $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== Creating hard links ===" -ForegroundColor Cyan
foreach ($item in $toLink) {
    $dest = Join-Path $destGame $item.Name
    if (Test-Path -LiteralPath $dest) {
        Write-Host "  SKIP (exists)  $($item.Name)" -ForegroundColor DarkGray
        continue
    }
    try {
        New-Item -ItemType HardLink -Path $dest -Target $item.FullName -ErrorAction Stop | Out-Null
        Write-Host "  HARDLINK  $($item.Name)" -ForegroundColor Green
    } catch {
        $failures += "HardLink $($item.Name): $($_.Exception.Message)"
        Write-Host "  FAILED    $($item.Name) -- $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
if ($failures.Count -gt 0) {
    Write-Host "===================================================" -ForegroundColor Red
    Write-Host "  Completed with $($failures.Count) error(s)" -ForegroundColor Red
    Write-Host "===================================================" -ForegroundColor Red
    foreach ($f in $failures) { Write-Host "  - $f" -ForegroundColor Red }
    Write-Host ""
    Write-Host "  The install is only partially linked. Review the errors above before resuming." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

Write-Host "===================================================" -ForegroundColor Green
Write-Host "  Done!" -ForegroundColor Green
Write-Host "===================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Resume the $destName download." -ForegroundColor White
Write-Host "  Sophon will scan the folder and only download the excluded channel files." -ForegroundColor White
Write-Host ""
