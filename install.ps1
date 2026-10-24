# Install vex: .\install.ps1 [-Uninstall] [-Version 0.1.0] [-Prefix <dir>]
param(
    [string]$Prefix = (Join-Path $env:LOCALAPPDATA 'vex'),
    [string]$Version = '',
    [switch]$Uninstall
)
$ErrorActionPreference = 'Stop'
$repo = 'TyronCameron/vex'

function Set-UserPath([scriptblock]$Edit) {
    $current = [Environment]::GetEnvironmentVariable('Path', 'User')
    $entries = @($current -split ';' | Where-Object { $_ -and $_ -ne $Prefix })
    [Environment]::SetEnvironmentVariable('Path', ((& $Edit $entries) -join ';'), 'User')
}

if ($Uninstall) {
    if (Test-Path $Prefix) { Remove-Item -Recurse -Force $Prefix }
    Set-UserPath { param($entries) $entries }
    Write-Host "Removed vex from $Prefix"
    return
}

if (-not (Get-Command luajit -ErrorAction SilentlyContinue)) {
    throw 'vex needs LuaJIT: https://luajit.org/'
}

$source = Join-Path $PSScriptRoot 'src'
if (-not (Test-Path (Join-Path $source 'vex.lua'))) {
    if (-not $Version) {
        $latest = Invoke-WebRequest -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue "https://github.com/$repo/releases/latest"
        $Version = ($latest.Headers.Location -split '/')[-1]
    }
    $Version = $Version.TrimStart('v')
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName())
    New-Item -ItemType Directory $tmp | Out-Null
    $zip = Join-Path $tmp 'vex.zip'
    Invoke-WebRequest -UseBasicParsing "https://github.com/$repo/releases/download/v$Version/vex-$Version.zip" -OutFile $zip
    Expand-Archive $zip -DestinationPath $tmp
    $source = Join-Path $tmp "vex-$Version\src"
}

if (Test-Path $Prefix) { Remove-Item -Recurse -Force $Prefix }
New-Item -ItemType Directory $Prefix | Out-Null
Copy-Item -Recurse (Join-Path $source '*') $Prefix
Set-UserPath { param($entries) $entries + $Prefix }

Write-Host "Installed vex $(& (Join-Path $Prefix 'vex.bat') version) to $Prefix"
Write-Host 'Open a new terminal to pick up the PATH change.'
