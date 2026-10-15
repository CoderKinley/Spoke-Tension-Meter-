param([Parameter(Mandatory=$true)][string]$FlutterSdk)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
$sdk = (Resolve-Path -LiteralPath $FlutterSdk).Path
$engine = Join-Path $sdk 'bin/cache/artifacts/engine/windows-x64'
$runtime = Join-Path $sdk 'bin/cache/dart-sdk/bin/dartaotruntime.exe'
$output = Join-Path (Get-Location) 'artifacts/direct-tests'
$assets = Join-Path $output 'assets'
New-Item -ItemType Directory -Force "$assets/shaders" | Out-Null
if (!(Test-Path .dart_tool/package_config.json)) { throw 'Run flutter pub get first.' }
foreach ($shader in @('ink_sparkle', 'stretch_effect')) {
    & "$engine/impellerc.exe" --sksl --runtime-stage-vulkan --iplr `
        "--sl=$assets/shaders/$shader.frag" "--spirv=$output/$shader.spirv" `
        "--input=$sdk/packages/flutter/lib/src/material/shaders/$shader.frag" `
        --input-type=frag "--include=$engine/shader_lib"
    if ($LASTEXITCODE -ne 0) { throw "Shader compilation failed: $shader" }
}
& $runtime "$engine/frontend_server_aot.dart.snapshot" `
    --sdk-root "$sdk/bin/cache/artifacts/engine/common/flutter_patched_sdk/" `
    --target flutter --track-widget-creation --enable-asserts `
    --no-print-incremental-dependencies --packages .dart_tool/package_config.json `
    --output-dill "$output/tests.dill" tools/direct_test_runner.dart
if ($LASTEXITCODE -ne 0) { throw 'Test compilation failed.' }
$previousTestMode = $env:FLUTTER_TEST
try {
    $env:FLUTTER_TEST = 'true'
    & "$engine/flutter_tester.exe" --disable-vm-service --enable-checked-mode `
        --non-interactive --use-test-fonts --disable-asset-fonts `
        "--flutter-assets-dir=$assets" --packages=.dart_tool/package_config.json `
        "$output/tests.dill" | Tee-Object -FilePath "$output/results.txt"
    if ($LASTEXITCODE -ne 0) { throw 'Tests failed. See artifacts/direct-tests/results.txt.' }
} finally { $env:FLUTTER_TEST = $previousTestMode }
