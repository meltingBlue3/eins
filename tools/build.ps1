# Runs tests, exports the Windows build, and zips it as builds/eins-v<version>-windows.zip.
# Usage (PowerShell, repo root):  ./tools/build.ps1
# Uses godot_console.exe so PowerShell waits for each step and sees its output and exit code.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$godot = (Get-Command godot_console -ErrorAction SilentlyContinue).Source
if (-not $godot) { throw 'godot_console.exe (Godot 4.7.2) must be on PATH.' }

$version = (Select-String -Path project.godot -Pattern '^config/version="(.+)"').Matches[0].Groups[1].Value
Write-Host "eins v$version"

& $godot --headless --path . --import | Out-Null
& $godot --headless --path . -s res://tests/test_battle.gd
if ($LASTEXITCODE -ne 0) { throw 'Tests failed; not exporting.' }

New-Item -ItemType Directory -Force builds/windows | Out-Null
Remove-Item builds/windows/eins.exe -ErrorAction SilentlyContinue
& $godot --headless --path . --export-release "Windows Desktop" builds/windows/eins.exe | Out-Null
if (-not (Test-Path builds/windows/eins.exe)) { throw 'Export did not produce builds/windows/eins.exe.' }

$zip = "builds/eins-v$version-windows.zip"
Compress-Archive -Path builds/windows/eins.exe -DestinationPath $zip -Force
Write-Host "Built $zip"
