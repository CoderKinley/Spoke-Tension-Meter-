param(
    [string]$FlutterSdk = 'C:\flutter',
    [string]$AndroidSdk = "$env:LOCALAPPDATA\Android\Sdk",
    [string]$Avd = 'pixel_7_-_api_35_0'
)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
$flutter = Join-Path $FlutterSdk 'bin/flutter.bat'
$adb = Join-Path $AndroidSdk 'platform-tools/adb.exe'
$emulator = Join-Path $AndroidSdk 'emulator/emulator.exe'
$manager = Join-Path $AndroidSdk 'cmdline-tools/latest/bin/sdkmanager.bat'
foreach ($executable in @($flutter, $adb, $emulator)) {
    if (!(Test-Path -LiteralPath $executable)) { throw "Required tool missing: $executable" }
}
$env:ANDROID_HOME = $AndroidSdk
$env:ANDROID_SDK_ROOT = $AndroidSdk
if (!(Test-Path -LiteralPath (Join-Path $AndroidSdk 'system-images/android-35/google_apis_playstore/x86_64/system.img'))) {
    if (!(Test-Path -LiteralPath $manager)) { throw 'Install Android SDK Command-line Tools in Android Studio SDK Manager.' }
    Write-Host 'Downloading the Android 35 Google Play system image. Review any SDK license prompt.'
    & $manager "--sdk_root=$AndroidSdk" 'system-images;android-35;google_apis_playstore;x86_64'
    if ($LASTEXITCODE -ne 0) { throw 'System image installation failed.' }
}
$devices = & $adb devices
if (!($devices -match '^emulator-5554\s+device')) {
    if ($devices -match '^emulator-5554\s+') { throw 'Emulator port 5554 is already occupied by an unavailable device.' }
    Start-Process -FilePath $emulator -ArgumentList @('-avd', $Avd, '-port', '5554', '-no-snapshot') -WindowStyle Normal
    $deadline = (Get-Date).AddMinutes(3)
    do {
        Start-Sleep -Seconds 3
        $booted = & $adb -s emulator-5554 shell getprop sys.boot_completed 2>$null
    } until (($booted -match '^1') -or (Get-Date) -gt $deadline)
    if (!($booted -match '^1')) { throw 'Emulator did not finish booting within three minutes.' }
}
& $flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'Flutter dependency installation failed.' }
& $flutter run -d emulator-5554
if ($LASTEXITCODE -ne 0) { throw 'App launch failed. Review the Flutter output above.' }
