#requires -Version 5.1
<#
.SYNOPSIS
  Fetch (or update) an up-to-date Omarchy checkout into ./omarchy.

.DESCRIPTION
  omarchy-wsl builds its WSL images from the real upstream Omarchy sources. That
  checkout is intentionally NOT vendored in this repo (it is large and changes
  fast); this script provides the "easy way to set it up".

  It clones https://github.com/basecamp/omarchy.git into ./omarchy on first run,
  and fast-forwards it to the latest upstream commit on subsequent runs. The
  Containerfile relies on the checkout keeping its .git directory (it regenerates
  the working tree from git blobs to fix Windows CRLF/exec-bit issues, and
  `omarchy update` uses it inside the distro), so a full clone is used.

.PARAMETER Repo
  Git URL to clone from. Default: https://github.com/basecamp/omarchy.git

.PARAMETER Ref
  Branch, tag, or commit to check out. Default: v4.0.0 ("Quattro") — the
  release matching the directory layout omarchy-wsl-install.sh expects.
  Re-verify the installer before pinning to a newer -Ref.

.PARAMETER Force
  Delete any existing ./omarchy checkout and clone it fresh.

.EXAMPLE
  ./setup-omarchy.ps1                 # clone or update to the pinned v4.0.0

.EXAMPLE
  ./setup-omarchy.ps1 -Ref v3.4.2     # pin to a different tag

.EXAMPLE
  ./setup-omarchy.ps1 -Force          # nuke and re-clone
#>
[CmdletBinding()]
param(
  [string]$Repo = "https://github.com/basecamp/omarchy.git",
  [string]$Ref = "v4.0.0",
  [switch]$Force
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$dest = Join-Path $root "omarchy"

function Invoke-Git {
  param([Parameter(ValueFromRemainingArguments = $true)]$GitArgs)
  & git @GitArgs
  if ($LASTEXITCODE -ne 0) { throw "git $($GitArgs -join ' ') failed (exit $LASTEXITCODE)" }
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  throw "git is required but was not found on PATH."
}

if ($Force -and (Test-Path $dest)) {
  Write-Host "Removing existing checkout at '$dest'..." -ForegroundColor Yellow
  Remove-Item -Recurse -Force $dest
}

if (Test-Path (Join-Path $dest ".git")) {
  Write-Host "Updating existing Omarchy checkout in '$dest'..." -ForegroundColor Cyan
  Invoke-Git -C $dest fetch --tags --prune origin
  if (-not $Ref) {
    # Resolve the remote's default branch (e.g. origin/dev -> dev).
    $Ref = (& git -C $dest symbolic-ref --short refs/remotes/origin/HEAD) -replace '^origin/', ''
    if ($LASTEXITCODE -ne 0 -or -not $Ref) { $Ref = "HEAD" }
  }
  Invoke-Git -C $dest checkout $Ref
  # Fast-forward only if we are on a branch (a detached tag/commit can't pull).
  & git -C $dest symbolic-ref -q HEAD *> $null
  if ($LASTEXITCODE -eq 0) { Invoke-Git -C $dest pull --ff-only origin $Ref }
} else {
  Write-Host "Cloning Omarchy ($Repo) into '$dest'..." -ForegroundColor Cyan
  if ($Ref) { Invoke-Git clone --branch $Ref $Repo $dest }
  else { Invoke-Git clone $Repo $dest }
}

if (-not (Test-Path (Join-Path $dest "install"))) {
  throw "Checkout completed but '$dest\install' is missing — is '$Repo' the Omarchy repo?"
}

$commit = (& git -C $dest rev-parse --short HEAD).Trim()
$branch = (& git -C $dest rev-parse --abbrev-ref HEAD).Trim()
$version = if (Test-Path (Join-Path $dest "version")) { (Get-Content (Join-Path $dest "version") -Raw).Trim() } else { "unknown" }

Write-Host "`nOmarchy ready at '$dest'" -ForegroundColor Green
Write-Host "  branch/ref : $branch" -ForegroundColor Green
Write-Host "  commit     : $commit" -ForegroundColor Green
Write-Host "  version    : $version" -ForegroundColor Green
Write-Host "`nNext: ./build-omarchy.ps1        (builds Omarchy-Basic.wsl)" -ForegroundColor Green
Write-Host "      ./build-omarchy-wslg.ps1   (builds Omarchy-WSLg.wsl)" -ForegroundColor Green
