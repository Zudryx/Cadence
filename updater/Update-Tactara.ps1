# Copyright (C) 2026 Zudryx. Part of Tactara, licensed under the GNU GPL v3 only.
# SPDX-License-Identifier: GPL-3.0-only

# Tactara updater for WoW Forever (Windows).
# Double-click "Update Tactara.bat" next to this file.
#
# What it does:
#   1. Finds your World of Warcraft\_forever_\Interface\AddOns folder
#      (remembers it after the first run; asks you if it can't find it).
#   2. Checks GitHub for the newest Tactara release.
#   3. If it's newer than what you have, backs up your current copy
#      (next to this script, in "backup") and installs the new one.
# Your own rotation edits are stored by WoW in WTF\...\SavedVariables,
# not in the addon folder, so updating never touches them.
#
# Before 0.5.0 the addon was called Cadence. If that old folder is still in
# AddOns, the updater moves it to "backup" (so it doesn't load next to
# Tactara) and copies its saved settings over to Tactara's, once.

param(
  [switch]$Force   # reinstall even if you're up to date
)

$ErrorActionPreference = 'Stop'
$Repo = 'Zudryx/Tactara'   # GitHub owner/name
$ConfigPath = Join-Path $PSScriptRoot 'tactara-updater.json'
$Headers = @{ 'User-Agent' = 'Tactara-Updater'; 'Accept' = 'application/vnd.github+json' }

try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

function Find-AddOnsFolder {
  # 1) remembered from last time (or by the updater's old-name copy in this folder)
  foreach ($path in @($ConfigPath, (Join-Path $PSScriptRoot 'cadence-updater.json'))) {
    if (-not (Test-Path $path)) { continue }
    try {
      $cfg = Get-Content $path -Raw | ConvertFrom-Json
      if ($cfg.AddOns -and (Test-Path $cfg.AddOns)) { return $cfg.AddOns }
    } catch {}
  }

  # 2) Battle.net's install location + common places
  $roots = New-Object System.Collections.Generic.List[string]
  foreach ($key in @('HKLM:\SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft',
                     'HKLM:\SOFTWARE\Blizzard Entertainment\World of Warcraft')) {
    try {
      $p = (Get-ItemProperty -Path $key -ErrorAction Stop).InstallPath
      if ($p) {
        $p = $p.TrimEnd('\')
        $roots.Add($p)
        $roots.Add((Split-Path $p -Parent))   # InstallPath usually points at ...\_retail_
      }
    } catch {}
  }
  foreach ($drive in @('C', 'D', 'E', 'F')) {
    foreach ($sub in @('Program Files (x86)\World of Warcraft', 'Program Files\World of Warcraft',
                       'World of Warcraft', 'Games\World of Warcraft', 'Battle.net\World of Warcraft')) {
      $roots.Add("${drive}:\$sub")
    }
  }
  foreach ($root in ($roots | Select-Object -Unique)) {
    foreach ($flavor in @('_forever_', 'forever')) {
      $game = Join-Path $root $flavor
      if (Test-Path $game) {
        $addons = Join-Path $game 'Interface\AddOns'
        New-Item -ItemType Directory -Force -Path $addons | Out-Null
        return $addons
      }
    }
  }

  # 3) ask
  Write-Host "Couldn't find WoW Forever automatically. Please pick your World of Warcraft\_forever_ folder."
  Add-Type -AssemblyName System.Windows.Forms
  $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
  $dialog.Description = 'Select your World of Warcraft\_forever_ folder'
  if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { throw 'No folder selected.' }
  $picked = $dialog.SelectedPath
  if ((Split-Path $picked -Leaf) -ieq 'AddOns') { return $picked }
  if ((Split-Path $picked -Leaf) -ieq 'Interface') { $addons = Join-Path $picked 'AddOns' }
  else { $addons = Join-Path $picked 'Interface\AddOns' }
  New-Item -ItemType Directory -Force -Path $addons | Out-Null
  return $addons
}

function Get-InstalledVersion($addons) {
  $toc = Join-Path $addons 'Tactara\Tactara.toc'
  if (-not (Test-Path $toc)) { return $null }
  $m = Select-String -Path $toc -Pattern '^## Version:\s*([\d\.]+)' | Select-Object -First 1
  if ($m) { return $m.Matches[0].Groups[1].Value }
  return $null
}

#---------------------------------------------------------------------------
# One-time move from the old name (Cadence, before 0.5.0)
#---------------------------------------------------------------------------

# Only touch a Cadence folder that is this addon's earlier version.
function Test-OldInstall($addons) {
  $dir = Join-Path $addons 'Cadence'
  $toc = Join-Path $dir 'Cadence.toc'
  if (-not (Test-Path $toc)) { return $false }
  if (-not (Test-Path (Join-Path $dir 'Rotations\Warrior.lua'))) { return $false }
  return [bool](Select-String -Path $toc -Pattern 'CadenceCharDB' -SimpleMatch -Quiet)
}

function Test-WoWRunning {
  return [bool](Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'Wow*' })
}

# Copy each old SavedVariables file to Tactara.lua with the variables renamed.
# Skips any character that already has Tactara settings.
function Copy-OldSettings($addons) {
  $game = Split-Path (Split-Path $addons -Parent) -Parent   # AddOns -> Interface -> _forever_
  $accounts = Join-Path $game 'WTF\Account'
  if (-not (Test-Path $accounts)) { return 0 }
  $utf8 = New-Object System.Text.UTF8Encoding($false)   # no BOM
  $copied = 0
  $files = Get-ChildItem -Path $accounts -Recurse -File -Filter 'Cadence.lua' -ErrorAction SilentlyContinue |
    Where-Object { $_.Directory.Name -ieq 'SavedVariables' }
  foreach ($file in $files) {
    $target = Join-Path $file.DirectoryName 'Tactara.lua'
    if (Test-Path $target) { continue }
    $text = [System.IO.File]::ReadAllText($file.FullName)
    $account = ($text -match '(?m)^CadenceDB\s*=') -and ($text -match '\["hideErrors"\]')
    $char = ($text -match '(?m)^CadenceCharDB\s*=') -and ($text -match '\["active"\]')
    if (-not ($account -or $char)) { continue }
    $text = $text -replace '(?m)^CadenceDB(\s*=)', 'TactaraDB$1' -replace '(?m)^CadenceCharDB(\s*=)', 'TactaraCharDB$1'
    [System.IO.File]::WriteAllText($target, $text, $utf8)
    $copied++
  }
  return $copied
}

# Move the old folder out of AddOns (into backup) so WoW doesn't load both.
function Move-OldInstall($addons) {
  $old = Join-Path $addons 'Cadence'
  $backupRoot = Join-Path $PSScriptRoot 'backup'
  New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
  $dest = Join-Path $backupRoot ('Cadence-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
  Copy-Item -Path $old -Destination $dest -Recurse
  Remove-Item -Path $old -Recurse -Force
  return $dest
}

function Test-Newer($latest, $installed) {
  if (-not $installed) { return $true }
  try { return ([version]$latest) -gt ([version]$installed) } catch { return $latest -ne $installed }
}

try {
  Write-Host ''
  Write-Host '  Tactara updater' -ForegroundColor Cyan
  Write-Host '  ---------------'

  $addons = Find-AddOnsFolder
  @{ AddOns = $addons } | ConvertTo-Json | Set-Content -Path $ConfigPath -Encoding UTF8
  Write-Host "  AddOns folder: $addons"

  $installed = Get-InstalledVersion $addons
  $hasOld = Test-OldInstall $addons
  if ($hasOld -and (Test-WoWRunning)) {
    throw 'Cadence is now called Tactara. Close WoW completely, then run this again so your settings come along.'
  }
  if ($hasOld -or -not $installed) {
    $copied = Copy-OldSettings $addons
    if ($copied -gt 0) { Write-Host "  Carried your settings over to Tactara ($copied file(s))." -ForegroundColor Green }
  }
  $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -Headers $Headers
  $latest = $release.tag_name.TrimStart('v')
  $shown = if ($installed) { $installed } else { 'not installed' }
  Write-Host "  Installed: $shown    Latest: $latest"

  if (-not $Force -and -not (Test-Newer $latest $installed)) {
    Write-Host ''
    Write-Host '  You already have the latest Tactara.' -ForegroundColor Green
    if ($hasOld) { Write-Host "  Moved the old Cadence folder out of AddOns: $(Move-OldInstall $addons)" }
    return
  }

  $asset = $release.assets | Where-Object { $_.name -like 'Tactara-*.zip' } | Select-Object -First 1   # the addon, not TactaraUpdater.zip
  if (-not $asset) { throw "Release $latest has no Tactara zip attached." }

  $tmp = Join-Path $env:TEMP ('tactara-update-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $tmp | Out-Null
  $zip = Join-Path $tmp $asset.name
  Write-Host "  Downloading $($asset.name) ..."
  Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip -Headers $Headers -UseBasicParsing
  Expand-Archive -Path $zip -DestinationPath $tmp -Force
  $new = Join-Path $tmp 'Tactara'
  if (-not (Test-Path (Join-Path $new 'Tactara.toc'))) { throw 'The download looks wrong (no Tactara.toc inside).' }

  $dest = Join-Path $addons 'Tactara'
  $backup = $null
  if (Test-Path $dest) {
    # keep a copy outside the AddOns folder so WoW doesn't try to load it
    $backupRoot = Join-Path $PSScriptRoot 'backup'
    $label = if ($installed) { $installed } else { 'unknown' }
    $backup = Join-Path $backupRoot ("Tactara-$label-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
    Copy-Item -Path $dest -Destination $backup -Recurse
    Remove-Item -Path $dest -Recurse -Force
    Write-Host "  Old version backed up to: $backup"
  }
  try {
    Copy-Item -Path $new -Destination $dest -Recurse
  } catch {
    # put the old version back so the addon keeps working
    if ($backup -and (Test-Path $backup)) {
      if (Test-Path $dest) { Remove-Item -Path $dest -Recurse -Force -ErrorAction SilentlyContinue }
      Copy-Item -Path $backup -Destination $dest -Recurse
      Write-Host '  Install failed - your previous version was restored.' -ForegroundColor Yellow
    }
    throw
  }
  Remove-Item -Path $tmp -Recurse -Force -ErrorAction SilentlyContinue
  # only now that Tactara is in place, so a failed download never leaves you with neither
  if ($hasOld) { Write-Host "  Moved the old Cadence folder out of AddOns: $(Move-OldInstall $addons)" }

  Write-Host ''
  Write-Host "  Tactara $latest installed." -ForegroundColor Green
  Write-Host '  If WoW is running, type /reload in game.'
  if ($release.body) {
    Write-Host ''
    Write-Host '  What changed:' -ForegroundColor Cyan
    $release.body -split "`n" | ForEach-Object { Write-Host "    $_" }
  }
}
catch {
  Write-Host ''
  Write-Host "  Update failed: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host '  If WoW is open, close the game or the AddOns window and try again.'
  exit 1
}
