param(
    [int]$Port = 4173,
    [switch]$SkipBuild,
    [switch]$NoOpen
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$flutterCandidates = @(
    'D:\ChatGPT\dependence\flutter\bin\flutter.bat',
    'D:\ChatGPT\dependence\sdks\flutter\bin\flutter.bat',
    'D:\download\flutter_windows_3.47.0-stable\flutter\bin\flutter.bat',
    (Get-Command flutter -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue)
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

if ($flutterCandidates.Count -eq 0) {
    throw 'Flutter was not found. Update the SDK path in preview.ps1.'
}

$flutterPath = $flutterCandidates[0]
$previewUrl = "http://localhost:$Port/"

if (-not $SkipBuild) {
    Write-Host 'Building Flutter Web preview...' -ForegroundColor Cyan
    & $flutterPath build web --no-wasm-dry-run
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter Web build failed with exit code $LASTEXITCODE."
    }
}

$serverScript = Join-Path $projectRoot 'preview-server.ps1'
& $serverScript -Port $Port

Write-Host "Preview ready: $previewUrl" -ForegroundColor Green
if (-not $NoOpen) {
    Start-Process $previewUrl
}
