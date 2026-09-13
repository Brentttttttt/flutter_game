$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot
try {
    flutter build apk --release
    if ($LASTEXITCODE -ne 0) { throw 'Flutter release build failed.' }
    $apkOutput = Join-Path $projectRoot 'build/app/outputs/flutter-apk'
    Copy-Item -LiteralPath (Join-Path $apkOutput 'app-release.apk') -Destination (Join-Path $apkOutput 'witch_kitty.apk')
    Write-Output (Join-Path $apkOutput 'witch_kitty.apk')
} finally {
    Pop-Location
}
