# Packs the Yandex web export (build/yandex) into a ZIP for the developer console.
# Usage: .\tools\package_yandex.ps1   (after Project > Export > "Yandex Release", Export With Debug OFF)
Set-Location (Join-Path $PSScriptRoot "..")
$src = "build\yandex"
if (-not (Test-Path "$src\index.html")) { Write-Error "Export first: $src\index.html not found"; exit 1 }
$zip = "build\archeoblocks-yandex.zip"
if (Test-Path $zip) { Remove-Item $zip }
Compress-Archive -Path "$src\*" -DestinationPath $zip
$sizeMb = [math]::Round(((Get-ChildItem $src -Recurse | Measure-Object Length -Sum).Sum) / 1MB, 1)
"Created $zip (unpacked size $sizeMb MB, limit 100 MB)"
