$ErrorActionPreference = 'Stop'

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $ProjectRoot

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw 'Flutter was not found. Install Flutter 3.44+ and add flutter/bin to PATH, then run this script again.'
}

$tempRoot = if ($env:TEMP) { $env:TEMP } else { [System.IO.Path]::GetTempPath() }
$backup = Join-Path $tempRoot ('shadow_sip-backup-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $backup | Out-Null
Copy-Item (Join-Path $ProjectRoot 'lib') (Join-Path $backup 'lib') -Recurse
Copy-Item (Join-Path $ProjectRoot 'pubspec.yaml') (Join-Path $backup 'pubspec.yaml')
Copy-Item (Join-Path $ProjectRoot 'README.md') (Join-Path $backup 'README.md')
Copy-Item (Join-Path $ProjectRoot 'test') (Join-Path $backup 'test') -Recurse

Write-Host 'Generating Android and Windows Flutter platform projects...' -ForegroundColor Cyan
flutter create --platforms=android,windows --org com.shadow --project-name shadow_sip --overwrite .

# Restore the application source and dependency manifest after Flutter creates native runners.
Remove-Item (Join-Path $ProjectRoot 'lib') -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item (Join-Path $backup 'lib') (Join-Path $ProjectRoot 'lib') -Recurse
Copy-Item (Join-Path $backup 'pubspec.yaml') (Join-Path $ProjectRoot 'pubspec.yaml') -Force
Copy-Item (Join-Path $backup 'README.md') (Join-Path $ProjectRoot 'README.md') -Force
Remove-Item (Join-Path $ProjectRoot 'test') -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item (Join-Path $backup 'test') (Join-Path $ProjectRoot 'test') -Recurse

# The Medut Android plugin requires Android API 24 or later.
$gradleKts = Join-Path $ProjectRoot 'android/app/build.gradle.kts'
$gradleGroovy = Join-Path $ProjectRoot 'android/app/build.gradle'
if (Test-Path $gradleKts) {
    $gradle = Get-Content $gradleKts -Raw
    $gradle = $gradle -replace 'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 24'
    Set-Content -Path $gradleKts -Value $gradle -Encoding UTF8
} elseif (Test-Path $gradleGroovy) {
    $gradle = Get-Content $gradleGroovy -Raw
    $gradle = $gradle -replace 'minSdkVersion\s+flutter\.minSdkVersion', 'minSdkVersion 24'
    Set-Content -Path $gradleGroovy -Value $gradle -Encoding UTF8
} else {
    throw 'Could not find android/app/build.gradle(.kts). Check the generated Android project.'
}

$manifestPath = Join-Path $ProjectRoot 'android/app/src/main/AndroidManifest.xml'
$manifest = Get-Content $manifestPath -Raw
$manifest = [regex]::Replace(
    $manifest,
    '(<application\b[^>]*?)android:name="[^"]*"',
    '$1android:name=".ShadowSipApplication"',
    1
)
if ($manifest -notmatch '<application[^>]*android:name=') {
    $manifest = $manifest -replace '<application\b', '<application android:name=".ShadowSipApplication"'
}
$manifest = [regex]::Replace($manifest, '(<application\b[^>]*?)android:label="[^"]*"', '$1android:label="Shadow-SIP"', 1)
Set-Content -Path $manifestPath -Value $manifest -Encoding UTF8

$kotlinDir = Join-Path $ProjectRoot 'android/app/src/main/kotlin/com/shadow/shadow_sip'
New-Item -ItemType Directory -Path $kotlinDir -Force | Out-Null
@'
package com.shadow.shadow_sip

import android.app.Application
import android.util.Log
import dev.medut.MedutConfig
import dev.medut.OpusConfig
import dev.medut.AecMode
import dev.medut.JitterBufferType
import dev.medut.android.AndroidOptions
import dev.medut.android.MedutAndroid
import dev.medut.android.telecom.TelecomOptions

/** Starts the native SIP stack early so Android's call framework can attach to it. */
class ShadowSipApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        try {
            MedutAndroid.start(
                this,
                MedutConfig(
                    userAgent = "Shadow-SIP/0.1.0",
                    statsIntervalMs = 2000,
                    mediaStallMs = 3000,
                    mosAlertThreshold = 3.5f,
                    lossAlertThreshold = 5.0f,
                    jitterAlertThreshold = 40.0f,
                    jitterBufferType = JitterBufferType.ADAPTIVE,
                    jitterBufferMinMs = 40,
                    jitterBufferMaxMs = 400,
                    adaptiveBitrate = true,
                    opusExpectedLossPct = 0,
                    opus = OpusConfig(bitrate = 32000, complexity = 9, forwardErrorCorrection = true, discontinuousTransmission = true),
                    aecMode = AecMode.SUPPRESSOR,
                    noiseSuppression = true,
                    autoGainControl = true,
                    keepaliveIntervalMs = 30000,
                    keepaliveReregister = true,
                    regRetryInitialMs = 2000,
                    regRetryMaxMs = 60000,
                    regRetryBackoff = 2.0f,
                    regRetryJitter = 0.2f,
                    sipTimerBMs = 10000,
                ),
                AndroidOptions(telecom = TelecomOptions())
            )
        } catch (error: Throwable) {
            Log.e("Shadow-SIP", "Could not start native SIP engine", error)
        }
    }
}
'@ | Set-Content -Path (Join-Path $kotlinDir 'ShadowSipApplication.kt') -Encoding UTF8

Write-Host ''
Write-Host 'Platform runners generated and Android native SIP startup hook added.' -ForegroundColor Green
Write-Host 'Next run: flutter pub get ; flutter analyze ; flutter run -d windows' -ForegroundColor Yellow
Write-Host 'For Android: connect a phone with USB debugging and run flutter run.' -ForegroundColor Yellow
Remove-Item $backup -Recurse -Force
