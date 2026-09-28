<#
.SYNOPSIS
  Performs conflict/safety checks and builds release APKs.

.EXAMPLE
  .\build-apk.ps1 -ValidateOnly

.EXAMPLE
  .\build-apk.ps1

.EXAMPLE
  .\build-apk.ps1 -Mode split

.EXAMPLE
  .\build-apk.ps1 -VersionIncrement patch

.EXAMPLE
  .\build-apk.ps1 -RequireReleaseSigning

.NOTES
  Configure a private release keystore before public distribution.
  By default, debug signing is allowed for local installation or registration
  evidence and produces a visible warning. Use -RequireReleaseSigning for a
  public-distribution build.
#>
[CmdletBinding()]
param(
    [ValidateSet('universal', 'split')]
    [string]$Mode = 'universal',
    [ValidateSet('build', 'patch', 'minor', 'major')]
    [string]$VersionIncrement = 'build',
    [switch]$SkipTests,
    [switch]$ValidateOnly,
    [switch]$RequireReleaseSigning,
    # Kept for compatibility with the first script revision; no longer needed.
    [switch]$AllowDebugSigning,
    [string]$OutputDirectory = 'release\apk'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$utf8Encoding = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8Encoding
[Console]::OutputEncoding = $utf8Encoding
$OutputEncoding = $utf8Encoding
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandArgumentPassing = 'Standard'
}

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$pubspecPath = Join-Path $projectRoot 'pubspec.yaml'
$lockPath = Join-Path $projectRoot 'pubspec.lock'
$gradlePath = Join-Path $projectRoot 'android\app\build.gradle.kts'
$mutex = $null
$buildLock = $null
$mappedDrive = $null
$originalLocation = Get-Location
$originalPubspecContent = $null
$versionChanged = $false
$buildCompleted = $false

function Write-Step([string]$Message) {
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments
    )
    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code $LASTEXITCODE`: $FilePath $($Arguments -join ' ')"
    }
}

function Find-Flutter {
    $candidates = @(
        'D:\download\flutter_windows_3.47.0-stable\flutter\bin\flutter.bat',
        (Get-Command flutter -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue)
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
    if ($candidates.Count -eq 0) {
        throw 'Flutter was not found. Install Flutter or update Find-Flutter in build-apk.ps1.'
    }
    return $candidates[0]
}

function Find-Dart([string]$FlutterPath) {
    $sdkDart = Join-Path (Split-Path -Parent $FlutterPath) 'dart.bat'
    if (Test-Path -LiteralPath $sdkDart) { return $sdkDart }
    $command = Get-Command dart -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    throw 'Dart was not found next to Flutter and is not available on PATH.'
}

function Use-CompatibleJava {
    $homes = @()
    if ($env:JAVA_HOME) { $homes += $env:JAVA_HOME }
    foreach ($root in @('C:\Program Files\Java', 'C:\Program Files\Eclipse Adoptium')) {
        if (Test-Path -LiteralPath $root) {
            $homes += Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
                Select-Object -ExpandProperty FullName
        }
    }
    $androidStudioJbr = 'D:\download\Android Studio\jbr'
    if (Test-Path -LiteralPath $androidStudioJbr) { $homes += $androidStudioJbr }

    foreach ($javaHomeCandidate in @($homes | Select-Object -Unique)) {
        $java = Join-Path $javaHomeCandidate 'bin\java.exe'
        $release = Join-Path $javaHomeCandidate 'release'
        if (-not (Test-Path -LiteralPath $java -PathType Leaf) -or
            -not (Test-Path -LiteralPath $release -PathType Leaf)) {
            continue
        }
        $versionText = Get-Content -LiteralPath $release -Raw
        $match = [regex]::Match($versionText, '(?m)^JAVA_VERSION="(\d+)(?:\.|"|-)')
        if ($match.Success) {
            $major = [int]$match.Groups[1].Value
            if ($major -ge 17 -and $major -le 24) {
                $env:JAVA_HOME = $javaHomeCandidate
                $env:Path = "$(Join-Path $javaHomeCandidate 'bin');$env:Path"
                return $javaHomeCandidate
            }
        }
    }
    throw 'A compatible JDK was not found. Install JDK 21 and set JAVA_HOME.'
}

function Assert-ProjectLayout {
    foreach ($required in @(
        $pubspecPath,
        $lockPath,
        $gradlePath,
        (Join-Path $projectRoot 'lib\main.dart'),
        (Join-Path $projectRoot 'assets\data\word_entries.wvd')
    )) {
        if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
            throw "Required project file is missing: $required"
        }
    }
    if ((Get-Content -LiteralPath $pubspecPath -Raw) -notmatch '(?m)^name:\s*wuwei_dictionary\s*$') {
        throw 'This script must be run from the wuwei_dictionary project.'
    }
}

function Assert-NoMergeConflicts {
    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git) {
        $gitOptions = @(
            '-c', "safe.directory=$projectRoot",
            '-c', 'core.autocrlf=false',
            '-c', 'core.whitespace=cr-at-eol',
            '-C', $projectRoot
        )
        $unmerged = & $git.Source @gitOptions ls-files -u
        if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect Git merge state.' }
        if ($unmerged) { throw 'Git contains unresolved merge entries.' }
        & $git.Source @gitOptions diff --check
        if ($LASTEXITCODE -ne 0) { throw 'Git diff check found whitespace errors or conflict markers.' }
    }

    $sourceRoots = @('lib', 'test', 'tool', 'android', 'ios') |
        ForEach-Object { Join-Path $projectRoot $_ } |
        Where-Object { Test-Path -LiteralPath $_ }
    $extensions = @('.dart', '.yaml', '.yml', '.gradle', '.kts', '.xml', '.properties',
        '.java', '.kt', '.swift', '.m', '.h', '.ps1', '.cmd')
    $markers = '^(' + ('<' * 7) + '|' + ('=' * 7) + '|' + ('>' * 7) + ')( .*)?$'
    $conflicts = Get-ChildItem -LiteralPath $sourceRoots -File -Recurse -ErrorAction Stop |
        Where-Object { $extensions -contains $_.Extension } |
        Select-String -Pattern $markers
    if ($conflicts) {
        $detail = ($conflicts | Select-Object -First 10 |
            ForEach-Object { "$($_.Path):$($_.LineNumber)" }) -join "`n"
        throw "Source files contain merge-conflict markers:`n$detail"
    }
}

function Assert-NoTrackedSecrets {
    $git = Get-Command git -ErrorAction SilentlyContinue
    if (-not $git) { return }
    $gitOptions = @(
        '-c', "safe.directory=$projectRoot",
        '-c', 'core.autocrlf=false',
        '-c', 'core.whitespace=cr-at-eol',
        '-C', $projectRoot
    )
    $tracked = & $git.Source @gitOptions ls-files
    if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect tracked files.' }
    $sensitive = $tracked | Where-Object {
        $_ -match '(^|/)(key\.properties|.*\.(jks|keystore|p12|pfx|pem))$'
    }
    if ($sensitive) {
        throw "Signing secrets must not be committed:`n$($sensitive -join "`n")"
    }
}

function Get-ShortProjectRoot {
    if ($projectRoot -notmatch '[^\x00-\x7F]') {
        return $projectRoot
    }

    foreach ($letter in @('Z', 'Y', 'X', 'W', 'V', 'U', 'T')) {
        $drive = "$letter`:"
        if (-not (Test-Path "$drive\")) {
            Invoke-Checked -FilePath 'subst.exe' $drive $projectRoot
            $script:mappedDrive = $drive
            return "$drive\"
        }
    }
    throw 'No free drive letter is available for the short-path build workspace.'
}

function Get-PackageVersion {
    $content = [System.IO.File]::ReadAllText(
        $pubspecPath,
        [System.Text.Encoding]::UTF8
    )
    $match = [regex]::Match(
        $content,
        '(?m)^version:\s*(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)\+(?<build>\d+)\s*$'
    )
    if (-not $match.Success) {
        throw 'pubspec.yaml version must use the form major.minor.patch+build.'
    }
    return [pscustomobject]@{
        Major = [int]$match.Groups['major'].Value
        Minor = [int]$match.Groups['minor'].Value
        Patch = [int]$match.Groups['patch'].Value
        Build = [int]$match.Groups['build'].Value
    }
}

function Get-NextPackageVersion([object]$Current, [string]$Increment) {
    $major = $Current.Major
    $minor = $Current.Minor
    $patch = $Current.Patch
    switch ($Increment) {
        'patch' { $patch++ }
        'minor' { $minor++; $patch = 0 }
        'major' { $major++; $minor = 0; $patch = 0 }
    }
    $build = $Current.Build + 1
    return [pscustomobject]@{
        Name = "$major.$minor.$patch"
        Build = $build
        Full = "$major.$minor.$patch+$build"
    }
}

function Set-PackageVersion([string]$Version) {
    $content = [System.IO.File]::ReadAllText(
        $pubspecPath,
        [System.Text.Encoding]::UTF8
    )
    $versionPattern = [regex]::new('(?m)^version:\s*[^\s]+\s*$')
    $updated = $versionPattern.Replace($content, "version: $Version", 1)
    if ($updated -eq $content) { throw 'Unable to update pubspec.yaml version.' }
    [System.IO.File]::WriteAllText(
        $pubspecPath,
        $updated,
        [System.Text.UTF8Encoding]::new($false)
    )
}

try {
    Assert-ProjectLayout
    $mutex = New-Object System.Threading.Mutex($false, 'Local\WuweiDictionaryApkReleaseBuild')
    if (-not $mutex.WaitOne(0)) { throw 'Another APK release build is already running.' }

    $lockDirectory = Join-Path $projectRoot '.dart_tool'
    New-Item -ItemType Directory -Path $lockDirectory -Force | Out-Null
    try {
        $buildLock = [System.IO.File]::Open(
            (Join-Path $lockDirectory 'apk-release-build.lock'),
            [System.IO.FileMode]::OpenOrCreate,
            [System.IO.FileAccess]::ReadWrite,
            [System.IO.FileShare]::None
        )
    } catch {
        throw 'The APK build workspace is locked by another process.'
    }

    Write-Step 'Checking source and repository safety'
    Assert-NoMergeConflicts
    Assert-NoTrackedSecrets

    $signingPropertiesPath = Join-Path $projectRoot 'android\key.properties'
    $usesDebugSigning = -not (Test-Path -LiteralPath $signingPropertiesPath -PathType Leaf)
    if (-not $usesDebugSigning) {
        $signingProperties = @{}
        foreach ($line in Get-Content -LiteralPath $signingPropertiesPath) {
            if ($line -match '^\s*([^#!][^=:]*?)\s*[=:]\s*(.*?)\s*$') {
                $signingProperties[$matches[1]] = $matches[2]
            }
        }
        foreach ($requiredKey in @('storeFile', 'storePassword', 'keyAlias', 'keyPassword')) {
            if (-not $signingProperties.ContainsKey($requiredKey) -or
                [string]::IsNullOrWhiteSpace($signingProperties[$requiredKey])) {
                throw "Android signing configuration is missing '$requiredKey'."
            }
        }
        $configuredKeystore = $signingProperties['storeFile']
        if (-not [System.IO.Path]::IsPathRooted($configuredKeystore)) {
            $configuredKeystore = Join-Path (Join-Path $projectRoot 'android') $configuredKeystore
        }
        if (-not (Test-Path -LiteralPath $configuredKeystore -PathType Leaf)) {
            throw "Android release keystore was not found: $configuredKeystore"
        }
    }
    if ($usesDebugSigning -and $RequireReleaseSigning) {
        throw 'A public-distribution build requires a release signing key, but Gradle is currently configured to use the debug key.'
    }
    if ($usesDebugSigning) {
        Write-Warning 'Using the debug signing key. Do not publish this APK to an app store.'
    }

    $flutter = Find-Flutter
    $dart = Find-Dart $flutter
    $compatibleJavaHome = Use-CompatibleJava
    Write-Step "Configuring Flutter to use JDK $compatibleJavaHome"
    Invoke-Checked -FilePath $flutter config --jdk-dir $compatibleJavaHome
    $shortRoot = Get-ShortProjectRoot
    Set-Location $shortRoot

    Write-Step 'Checking locked dependencies'
    Invoke-Checked -FilePath $flutter pub get --enforce-lockfile

    Write-Step 'Formatting Dart sources'
    $formatTargets = @('lib', 'test', 'tool') | Where-Object { Test-Path -LiteralPath $_ }
    Invoke-Checked -FilePath $dart format @formatTargets

    Write-Step 'Running static analysis'
    Invoke-Checked -FilePath $flutter analyze --no-pub

    if (-not $SkipTests) {
        Write-Step 'Running tests'
        Invoke-Checked -FilePath $flutter test --no-pub
    }

    if ($ValidateOnly) {
        Write-Host "`nValidation passed. No APK was built." -ForegroundColor Green
        exit 0
    }

    $originalPubspecContent = [System.IO.File]::ReadAllText(
        $pubspecPath,
        [System.Text.Encoding]::UTF8
    )
    $currentVersion = Get-PackageVersion
    $nextVersion = Get-NextPackageVersion $currentVersion $VersionIncrement
    Write-Step "Incrementing package version to $($nextVersion.Full)"
    Set-PackageVersion $nextVersion.Full
    $versionChanged = $true

    Write-Step 'Building Android release APK'
    $buildArguments = @(
        'build', 'apk', '--release', '--no-pub',
        "--build-name=$($nextVersion.Name)",
        "--build-number=$($nextVersion.Build)"
    )
    if ($Mode -eq 'split') { $buildArguments += '--split-per-abi' }
    Invoke-Checked -FilePath $flutter @buildArguments

    $apkRoot = Join-Path $shortRoot 'build\app\outputs\flutter-apk'
    $apkFiles = @(
        if ($Mode -eq 'split') {
            Get-ChildItem -LiteralPath $apkRoot -Filter 'app-*-release.apk' -File
        } else {
            Get-Item -LiteralPath (Join-Path $apkRoot 'app-release.apk')
        }
    )
    if ($apkFiles.Count -eq 0) { throw 'No APK output was found.' }

    $outputRoot = if ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
        $OutputDirectory
    } else {
        Join-Path $projectRoot $OutputDirectory
    }
    New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
    $version = $nextVersion.Full
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $manifestEntries = @()
    foreach ($apk in $apkFiles) {
        $variant = if ($apk.Name -eq 'app-release.apk') {
            'universal'
        } else {
            $apk.BaseName.Replace('app-', '').Replace('-release', '')
        }
        $targetName = "five-flavor-dictionary-$version-$variant-$timestamp.apk"
        $targetPath = Join-Path $outputRoot $targetName
        Copy-Item -LiteralPath $apk.FullName -Destination $targetPath -Force
        $hash = (Get-FileHash -LiteralPath $targetPath -Algorithm SHA256).Hash.ToLowerInvariant()
        Set-Content -LiteralPath "$targetPath.sha256" -Value "$hash  $targetName" -Encoding ASCII
        $target = Get-Item -LiteralPath $targetPath
        $manifestEntries += [ordered]@{ file = $target.Name; sha256 = $hash; bytes = $target.Length }
    }

    $git = Get-Command git -ErrorAction SilentlyContinue
    $revision = 'not-available'
    $workingTree = 'not-available'
    if ($git) {
        $previousErrorActionPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            $gitOptions = @(
                '-c', "safe.directory=$projectRoot",
                '-c', 'core.autocrlf=false',
                '-c', 'core.whitespace=cr-at-eol',
                '-C', $projectRoot
            )
            $revisionValue = & $git.Source @gitOptions rev-parse --verify HEAD 2>$null
            $revisionExitCode = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }
        if ($revisionExitCode -eq 0) { $revision = $revisionValue.Trim() }
        $workingTree = if (& $git.Source @gitOptions status --porcelain) { 'dirty' } else { 'clean' }
    }
    $manifest = [ordered]@{
        package = 'wuwei_dictionary'
        version = $version
        builtAt = (Get-Date).ToUniversalTime().ToString('o')
        mode = $Mode
        signing = if ($usesDebugSigning) { 'debug' } else { 'release' }
        gitRevision = $revision
        workingTree = $workingTree
        artifacts = $manifestEntries
    }
    $manifestPath = Join-Path $outputRoot "five-flavor-dictionary-$version-$timestamp.build.json"
    $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

    Write-Host "`nAPK build completed: $outputRoot" -ForegroundColor Green
    foreach ($entry in $manifestEntries) {
        Write-Host "  $($entry.file)  SHA256 $($entry.sha256)"
    }
    Write-Host "  Manifest: $(Split-Path -Leaf $manifestPath)"
    $buildCompleted = $true
} finally {
    Set-Location $originalLocation
    if ($versionChanged -and -not $buildCompleted -and $null -ne $originalPubspecContent) {
        [System.IO.File]::WriteAllText(
            $pubspecPath,
            $originalPubspecContent,
            [System.Text.UTF8Encoding]::new($false)
        )
        Write-Warning 'Build did not complete; pubspec.yaml version was restored.'
    }
    if ($buildLock) { $buildLock.Dispose() }
    if ($mappedDrive) { & subst.exe $mappedDrive /D | Out-Null }
    if ($mutex) {
        try { $mutex.ReleaseMutex() } catch { }
        $mutex.Dispose()
    }
}
