#requires -Version 5.1
<#
.SYNOPSIS
  Build the lightweight Omarchy WSLg application distro.

.DESCRIPTION
  Fetches Omarchy, builds the CLI profile plus a curated set of GUI
  applications, and exports Omarchy-WSLg.wsl. Applications run as individual
  Windows-managed WSLg windows; this profile does not include Hyprland or SDDM.

.PARAMETER Tag
  Image tag to produce. Default: omarchy:wslg

.PARAMETER OutFile
  Destination .wsl path. Default: Omarchy-WSLg.wsl in the repo root.

.PARAMETER Ref
  Branch, tag, or commit of Omarchy to check out.

.PARAMETER NoCache
  Build without the layer cache.

.PARAMETER SkipSetup
  Use the existing ./omarchy checkout.
#>
[CmdletBinding()]
param(
  [string]$Tag = "omarchy:wslg",
  [string]$OutFile,
  [string]$Ref,
  [switch]$NoCache,
  [switch]$SkipSetup
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

if (-not $OutFile) { $OutFile = Join-Path $root "Omarchy-WSLg.wsl" }
if (-not [System.IO.Path]::IsPathRooted($OutFile)) { $OutFile = Join-Path $root $OutFile }

if (-not $SkipSetup) {
  Write-Host "=== Step 1/3: Fetching/updating Omarchy checkout ===" -ForegroundColor Cyan
  if ($Ref) { & "$root\setup-omarchy.ps1" -Ref $Ref }
  else { & "$root\setup-omarchy.ps1" }
  if ($LASTEXITCODE -ne 0) { throw "setup-omarchy failed (exit $LASTEXITCODE)." }
} else {
  Write-Host "=== Step 1/3: Skipping Omarchy checkout (-SkipSetup) ===" -ForegroundColor Cyan
}

Write-Host "`n=== Step 2/3: Building WSLg image '$Tag' ===" -ForegroundColor Cyan
& "$root\build.ps1" -Tag $Tag -Arch amd64 -Wslg -NoCache:$NoCache
if ($LASTEXITCODE -ne 0) { throw "WSLg build failed (exit $LASTEXITCODE)." }

Write-Host "`n=== Step 3/3: Exporting '$Tag' -> '$OutFile' ===" -ForegroundColor Cyan
& "$root\export-wsl.ps1" -Image $Tag -OutFile $OutFile
if ($LASTEXITCODE -ne 0) { throw "Export failed (exit $LASTEXITCODE)." }

Write-Host "`nDone. Built Omarchy-WSLg.wsl:" -ForegroundColor Green
Write-Host ("  {0} ({1} GB)" -f $OutFile, [math]::Round((Get-Item $OutFile).Length / 1GB, 2)) -ForegroundColor Green
Write-Host "Install it with: wsl --install --from-file `"$OutFile`"" -ForegroundColor Green
