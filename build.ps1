param (
    [string]$SdkDir = "$env:LOCALAPPDATA\Android\Sdk",
    [string]$BuildToolsVer = "34.0.0",
    [string]$PlatformVer = "android-34",
    [string]$KeystorePath = "",
    [string]$KeystorePass = "",
    [string]$KeyAlias = "",
    [string]$KeyPass = ""
)

$ErrorActionPreference = 'Stop'
$HERE = $PSScriptRoot
$TOOLS = Join-Path $HERE 'tools'
$BUILD = Join-Path $HERE 'build'

$BUILD_TOOLS = Join-Path $SdkDir "build-tools\$BuildToolsVer"
$ANDROID_JAR = Join-Path $SdkDir "platforms\$PlatformVer\android.jar"

if (-not (Test-Path $ANDROID_JAR)) {
    $ANDROID_JAR = Join-Path $TOOLS "android-4.1.1.4.jar"
}

if (Test-Path $BUILD) { Remove-Item -Recurse -Force $BUILD }
New-Item -ItemType Directory -Force -Path (Join-Path $BUILD 'classes') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $BUILD 'dex') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $BUILD 'apk_root\META-INF\xposed') | Out-Null

Write-Host "1. Compiling Java sources..."
$javaFiles = Get-ChildItem -Recurse (Join-Path $HERE 'src\main\java') -Filter '*.java' | ForEach-Object { $_.FullName }
& javac -encoding UTF-8 --release 11 -cp "$TOOLS\api-102.jar;$ANDROID_JAR" -d (Join-Path $BUILD 'classes') $javaFiles

Write-Host "2. D8 dexing..."
$classFiles = Get-ChildItem -Recurse (Join-Path $BUILD 'classes') -Filter '*.class' | ForEach-Object { $_.FullName }
& java -cp "$TOOLS\r8-9.5.33.jar" com.android.tools.r8.D8 --min-api 29 --lib $ANDROID_JAR --output (Join-Path $BUILD 'dex') $classFiles

Write-Host "3. AAPT packaging..."
& "$BUILD_TOOLS\aapt.exe" package -f -M (Join-Path $HERE 'AndroidManifest.xml') -S (Join-Path $HERE 'res') -I $ANDROID_JAR -F (Join-Path $BUILD 'base.apk')

Write-Host "4. Adding classes.dex and META-INF/xposed files..."
Copy-Item (Join-Path $BUILD 'dex\classes.dex') (Join-Path $BUILD 'apk_root\classes.dex')
Copy-Item -Recurse -Force (Join-Path $HERE 'src\main\resources\*') (Join-Path $BUILD 'apk_root\')
Push-Location (Join-Path $BUILD 'apk_root')
try {
    & "$BUILD_TOOLS\aapt.exe" add (Join-Path $BUILD 'base.apk') classes.dex META-INF/xposed/module.prop META-INF/xposed/java_init.list META-INF/xposed/scope.list
} finally {
    Pop-Location
}

Write-Host "5. Zipalign..."
$alignedApk = Join-Path $HERE 'HyperTraffic-API102-unsigned.apk'
& "$BUILD_TOOLS\zipalign.exe" -f 4 (Join-Path $BUILD 'base.apk') $alignedApk

if ($KeystorePath -and (Test-Path $KeystorePath)) {
    Write-Host "6. Signing with provided keystore ($KeystorePath)..."
    $signedApk = Join-Path $HERE 'HyperTraffic-API102.apk'
    $keyPassArg = if ($KeyPass) { $KeyPass } else { $KeystorePass }
    & "$BUILD_TOOLS\apksigner.bat" sign --ks $KeystorePath --ks-pass "pass:$KeystorePass" --key-pass "pass:$keyPassArg" --ks-key-alias $KeyAlias --out $signedApk $alignedApk
    Write-Host "=== Build SUCCESS: $signedApk ===" -ForegroundColor Green
} else {
    Write-Host "=== Build SUCCESS (Unsigned): $alignedApk ===" -ForegroundColor Green
    Write-Host "(Please sign with your own keystore or Android Studio)"
}
