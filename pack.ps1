# Build ThirstTrap-Classic.zip and ThirstTrap-TBC.zip
# Usage: run from repo root: .\pack.ps1

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$src  = Join-Path $root "ThirstTrap"
$dist = Join-Path $root "dist"
$stage = Join-Path $dist "stage"

if (Test-Path $dist) { Remove-Item -Recurse -Force $dist }
New-Item -ItemType Directory -Path $dist | Out-Null
New-Item -ItemType Directory -Path $stage | Out-Null

function Stage-Copy($name, $postCopy) {
    $dest = Join-Path $stage $name
    $addon = Join-Path $dest "ThirstTrap"
    New-Item -ItemType Directory -Path $dest | Out-Null
    Copy-Item -Path $src -Destination $addon -Recurse -Force
    if ($postCopy) { & $postCopy $addon }
}

# Classic: keep Classic TOC, remove TBC TOC
Stage-Copy "Classic" ([ScriptBlock]::Create(@'
param($addon)
$classicToc = Join-Path $addon "ThirstTrap.toc"
$tbcToc     = Join-Path $addon "ThirstTrap-TBC.toc"
if (Test-Path $tbcToc) { Remove-Item -Force $tbcToc }
'@))

# TBC: remove Classic TOC, rename TBC TOC to ThirstTrap.toc
Stage-Copy "TBC" ([ScriptBlock]::Create(@'
param($addon)
$classicToc = Join-Path $addon "ThirstTrap.toc"
$tbcToc     = Join-Path $addon "ThirstTrap-TBC.toc"
if (Test-Path $classicToc) { Remove-Item -Force $classicToc }
if (Test-Path $tbcToc) { Rename-Item -Path $tbcToc -NewName "ThirstTrap.toc" }
'@))

# Zip packages
$classicZip = Join-Path $dist "ThirstTrap-Classic.zip"
$tbcZip     = Join-Path $dist "ThirstTrap-TBC.zip"

Compress-Archive -Path (Join-Path $stage "Classic\ThirstTrap") -DestinationPath $classicZip -Force
Compress-Archive -Path (Join-Path $stage "TBC\ThirstTrap") -DestinationPath $tbcZip -Force

# Clean stage
Remove-Item -Recurse -Force $stage

Write-Host "Built:" -ForegroundColor Green
Write-Host "  $classicZip"
Write-Host "  $tbcZip"
