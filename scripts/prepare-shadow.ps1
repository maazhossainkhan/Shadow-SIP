$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$app = Join-Path $root "upstream\medut-softphone"
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
    $content = [System.IO.File]::ReadAllText($path)
    $updated = $content.Replace("package:medut_phone/", "package:shadow_sip/")
    $updated = [regex]::Replace($updated, '\bMedut\b', 'Shadow-SIP')
    if ($path -eq (Join-Path $app "android\app\build.gradle.kts")) {
        $updated = $updated.Replace('applicationId = "com.medut.generic.phone"', 'applicationId = "com.maaz.shadowsip"')
    }
    if ($path -eq (Join-Path $app "windows\runner\main.cpp")) {
        $updated = $updated.Replace("MEDUT_PHONE_WINDOW", "SHADOW_SIP_PHONE_WINDOW")
        $updated = $updated.Replace('Local\com.medut.generic.phone', 'Local\com.maaz.shadowsip')
    }
    if ($path -eq (Join-Path $app "lib\main.dart")) {
        $updated = $updated.Replace("MEDUT_VERSION", "SHADOW_SIP_VERSION")
    }
    if ($updated -cne $content) {
        [System.IO.File]::WriteAllText($path, $updated, $utf8)
    }
}
Write-Host "Shadow-SIP source prepared in $app"
