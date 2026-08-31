#requires -Version 5.1
<#
.SYNOPSIS
  Reproducibly build the Omarchy WSL container image with wslc.

.DESCRIPTION
  Wraps `wslc build`. Run from the repo root (the directory containing the
  Containerfile and the cloned `omarchy/` checkout).

  By default it builds the FULL Omarchy desktop. Desktop options can be turned
  off individually with the switches below (each maps to a Containerfile build arg
  and a packages/groups/<group>.packages list).

.PARAMETER Tag
  Image tag to produce. Default: omarchy:latest

.PARAMETER Arch
  Target architecture: amd64 or arm64. Defaults to the host's architecture.
  amd64 builds FROM archlinux:latest; arm64 builds FROM the Arch Linux ARM
  (ALARM) rootfs, since Arch's own images and the [omarchy] pacman repo are
  x86_64-only. See README.md.

.PARAMETER NoDesktop
  Build a curated CLI-only image (DESKTOP=0): no Hyprland desktop.

.PARAMETER NoApps
  Skip large GUI apps (browser, office, media editors, chat, …). APPS=0

.PARAMETER NoLogin
  Skip the login manager + boot splash (sddm, plymouth). LOGIN=0

.PARAMETER NoPrinting
  Skip the CUPS printing stack. PRINTING=0

.PARAMETER NoInput
  Skip fcitx5 input methods. INPUT=0

.PARAMETER Wslg
  Build the lightweight WSLg application profile. This implies DESKTOP=0,
  adds a curated GUI application set, and names the distro Omarchy-WSLg.
  Currently supported on amd64 only.

.PARAMETER NoCache
  Build without the layer cache.

.EXAMPLE
  ./build.ps1                       # full desktop

.EXAMPLE
  ./build.ps1 -NoApps -NoLogin      # desktop without heavy apps or sddm/plymouth

.EXAMPLE
  ./build.ps1 -NoDesktop -Tag omarchy:cli   # CLI-only image
#>
[CmdletBinding()]
param(
  [string]$Tag = "omarchy:latest",
  [ValidateSet("amd64", "arm64")]
  [string]$Arch,
  [switch]$NoDesktop,
  [switch]$NoApps,
  [switch]$NoLogin,
  [switch]$NoPrinting,
  [switch]$NoInput,
  [switch]$Wslg,
  [switch]$NoCache
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

if (-not (Test-Path (Join-Path $root "omarchy\install"))) {
  throw "Cannot find the Omarchy checkout at '$root\omarchy'. Set it up first: ./setup-omarchy.ps1"
}

# Default to the host's architecture (wslc can't cross-build).
if (-not $Arch) {
  $Arch = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "amd64" }
}
if ($Wslg -and $Arch -ne "amd64") {
  throw "The Omarchy WSLg profile currently supports amd64 only."
}

# Map switches to 0/1 build args (default 1 = enabled).
$toggles = [ordered]@{
  DESKTOP  = if ($NoDesktop -or $Wslg) { 0 } else { 1 }
  APPS     = if ($NoApps -or $Wslg)     { 0 } else { 1 }
  LOGIN    = if ($NoLogin -or $Wslg)    { 0 } else { 1 }
  PRINTING = if ($NoPrinting -or $Wslg) { 0 } else { 1 }
  INPUT    = if ($NoInput -or $Wslg)    { 0 } else { 1 }
  WSLG     = if ($Wslg)       { 1 } else { 0 }
}

$distroName = if ($Wslg) { "Omarchy-WSLg" } else { "Omarchy" }
$wslcArgs = @("build", "-t", $Tag, "--build-arg", "ARCH=$Arch", "--build-arg", "DISTRO_NAME=$distroName")
foreach ($k in $toggles.Keys) { $wslcArgs += "--build-arg", "$k=$($toggles[$k])" }
if ($NoCache) { $wslcArgs += "--no-cache" }
$wslcArgs += "-f", (Join-Path $root "Containerfile"), $root

$summary = ($toggles.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join " "
Write-Host "Building '$Tag' (ARCH=$Arch $summary)..." -ForegroundColor Cyan
Write-Host "wslc $($wslcArgs -join ' ')" -ForegroundColor DarkGray

& wslc.exe @wslcArgs
if ($LASTEXITCODE -ne 0) { throw "wslc build failed with exit code $LASTEXITCODE" }

Write-Host "`nBuilt '$Tag'. Verify it with: ./test.ps1 -Tag $Tag" -ForegroundColor Green
