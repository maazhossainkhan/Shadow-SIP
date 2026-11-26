$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$app = Join-Path $root "upstream/medut-softphone"
if (-not (Test-Path (Join-Path $app "pubspec.yaml"))) {
    throw "Medut Softphone submodule missing. Clone with: git clone --recurse-submodules ..."
}

$utf8 = [System.Text.UTF8Encoding]::new($false)
$pubspecPath = Join-Path $app "pubspec.yaml"
$pubspec = [System.IO.File]::ReadAllText($pubspecPath)
$pubspec = $pubspec -replace '(?m)^name:\s*medut_phone\s*$', 'name: shadow_sip'
$pubspec = $pubspec -replace '(?m)^description:.*$', 'description: "Shadow-SIP — Windows and Android SIP softphone."'
$pubspec = $pubspec -replace '(?m)^version:.*$', 'version: 0.2.0+7'
[System.IO.File]::WriteAllText($pubspecPath, $pubspec, $utf8)

$extensions = @(".dart", ".kt", ".json", ".kts", ".xml", ".cpp", ".h", ".iss", ".properties")
Get-ChildItem -Path $app -Recurse -File | Where-Object { $extensions -contains $_.Extension.ToLowerInvariant() } | ForEach-Object {
    $path = $_.FullName
    $relative = [System.IO.Path]::GetRelativePath($app, $path).Replace('\', '/')
    $content = [System.IO.File]::ReadAllText($path)
    $updated = $content.Replace("package:medut_phone/", "package:shadow_sip/")

    if ($relative.StartsWith("assets/translations/") -and $relative.EndsWith(".json")) {
        $updated = [regex]::Replace($updated, '(?<![A-Za-z0-9_])Medut(?![-A-Za-z0-9_])', 'Shadow-SIP')
    }
    if ($relative -eq "lib/app.dart") {
        $updated = $updated.Replace("title: 'Medut'", "title: 'Shadow-SIP'")
    }
    if ($relative -eq "android/app/build.gradle.kts") {
        $updated = $updated.Replace('applicationId = "com.medut.generic.phone"', 'applicationId = "com.maaz.shadowsip"')
        $updated = $updated.Replace('resValue("string", "app_name", "Medut")', 'resValue("string", "app_name", "Shadow-SIP")')
    }
    if ($relative -eq "windows/runner/main.cpp") {
        $updated = $updated.Replace("MEDUT_PHONE_WINDOW", "SHADOW_SIP_PHONE_WINDOW")
        $updated = $updated.Replace('Local\\com.medut.generic.phone', 'Local\\com.maaz.shadowsip')
        $updated = $updated.Replace('L"Medut"', 'L"Shadow-SIP"')
    }
    if ($relative -eq "windows/CMakeLists.txt") {
        $updated = $updated.Replace('set(BINARY_NAME "medut")', 'set(BINARY_NAME "shadow_sip")')
    }
    if ($relative -eq "windows/installer.iss") {
        $updated = [regex]::Replace($updated, '(?<![A-Za-z0-9_])Medut(?![-A-Za-z0-9_])', 'Shadow-SIP')
        $updated = $updated.Replace('"Shadow-SIP.CallLink"', '"ShadowSIP.CallLink"')
        $updated = $updated.Replace('"medut.exe"', '"shadow_sip.exe"')
        $updated = $updated.Replace('6B9A2E4C-3F1D-4C55-9E2A-6D0B7C1F8A31', 'A7D8B381-DC3C-4F0C-95EC-DF31DAA6E651')
        $updated = $updated.Replace('https://github.com/Ibrahimgamal99/medut-softphone', 'https://github.com/maazhossainkhan/Shadow-SIP')
    }
    $updated = $updated.Replace("Recordings/Medut", "Recordings/Shadow-SIP")
    $updated = $updated.Replace("Recordings\Medut", "Recordings\Shadow-SIP")
    if ($relative -eq "test/core_test.dart") {
        $updated = $updated.Replace("RegExp(r'```json\n", "RegExp(r'```json\r?\n")
        $updated = $updated.Replace("RegExp(r'```text\n", "RegExp(r'```text\r?\n")
    }
    if ($relative -eq "lib/main.dart") {
        $updated = $updated.Replace("MEDUT_VERSION", "SHADOW_SIP_VERSION")
    }
    if ($updated -cne $content) {
        [System.IO.File]::WriteAllText($path, $updated, $utf8)
    }
}
Write-Host "Shadow-SIP source prepared in $app"
