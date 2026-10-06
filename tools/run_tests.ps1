# Runs every tests/*_test.gd headlessly and prints one line per test.
# Usage (PowerShell, from the project folder):
#   .\tools\run_tests.ps1 -Godot "C:\path\to\Godot_v4.7-stable_win64_console.exe"
#   .\tools\run_tests.ps1 -Godot "..." -Filter turn_race
param(
    [Parameter(Mandatory = $true)][string]$Godot,
    [string]$Filter = ""
)
Set-Location (Join-Path $PSScriptRoot "..")
New-Item -ItemType Directory -Force -Path ".test_logs" | Out-Null
# Refresh the script class cache and imports first, so new scripts/assets are known.
& $Godot --headless --editor --quit --path . *> ".test_logs\_import.log"
$pass = 0; $fail = 0
Get-ChildItem tests -Filter "*_test.gd" | Sort-Object Name | ForEach-Object {
    $name = $_.BaseName
    if ($Filter -and ($name -notlike "*$Filter*")) { return }
    $log = ".test_logs\$name.log"
    $sw = [Diagnostics.Stopwatch]::StartNew()
    & $Godot --headless --path . -s "res://tests/$($_.Name)" *> $log
    $code = $LASTEXITCODE
    $secs = [int]$sw.Elapsed.TotalSeconds
    if ($code -eq 0) { $pass++; "PASS {0,-45} {1,4}s" -f $name, $secs }
    else {
        $fail++; "FAIL {0,-45} {1,4}s (exit {2})" -f $name, $secs, $code
        Select-String -Path $log -Pattern "ERROR|SCRIPT ERROR|Parse Error" |
            Where-Object { $_.Line -notmatch "root certificate" } |
            Select-Object -First 5 | ForEach-Object { "     " + $_.Line }
    }
}
"TOTAL pass=$pass fail=$fail"
if ($fail -gt 0) { exit 1 }
