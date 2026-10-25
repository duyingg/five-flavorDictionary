<#
.SYNOPSIS
  Move reusable corpora and caches to the shared dependency folder.
.NOTES
  No package restore, tests, compilation, download or global environment change.
  Directory junctions and same-volume hard links preserve existing tool paths.
#>
[CmdletBinding()]
param(
    [string]$DependencyRoot = 'D:\ChatGPT\dependence',
    [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$dependencyRootPath = [IO.Path]::GetFullPath($DependencyRoot).TrimEnd('\', '/')
$layout = @(
    @{ Source = 'Aatime\ACP-RAG-main'; Target = 'corpora\ACP-RAG-main'; Kind = 'Junction' },
    @{ Source = 'Aatime\chinese-ancient-poetry-translation-master\data'; Target = 'corpora\chinese-ancient-poetry-translation-master\data'; Kind = 'Junction' },
    @{ Source = 'Aatime\chinese-ancient-poetry-translation-master\output.csv'; Target = 'corpora\chinese-ancient-poetry-translation-master\output.csv'; Kind = 'HardLink' },
    @{ Source = 'Aatime\chinese-classical-corpus-main\docs'; Target = 'corpora\chinese-classical-corpus-main\docs'; Kind = 'Junction' },
    @{ Source = 'Aatime\chinese-classical-corpus-main\output'; Target = 'corpora\chinese-classical-corpus-main\output'; Kind = 'Junction' },
    @{ Source = 'Aatime\chinese-classical-corpus-main\scripts'; Target = 'corpora\chinese-classical-corpus-main\scripts'; Kind = 'Junction' },
    @{ Source = 'Aatime\chinese-classical-corpus-main\training'; Target = 'corpora\chinese-classical-corpus-main\training'; Kind = 'Junction' },
    @{ Source = 'Aatime\Classical-Modern-data\双语数据'; Target = 'corpora\Classical-Modern-data\双语数据'; Kind = 'Junction' },
    @{ Source = 'Aatime\Classical-Modern-main.zip'; Target = 'downloads\Classical-Modern-main.zip'; Kind = 'HardLink' },
    @{ Source = 'Aatime\rime-wubi\wubi86.dict.yaml'; Target = 'corpora\rime-wubi\wubi86.dict.yaml'; Kind = 'HardLink' },
    @{ Source = 'tool\source_cache'; Target = 'cache\web\chinese-literature'; Kind = 'Junction' },
    @{ Source = '.dart_tool\flutter_build'; Target = 'cache\projects\wuwei_dictionary\flutter_build'; Kind = 'Junction' },
    @{ Source = 'android\.gradle'; Target = 'cache\projects\wuwei_dictionary\gradle'; Kind = 'Junction' }
)

function Assert-ContainedPath([string]$Path, [string]$Root) {
    $prefix = $Root.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if (-not $Path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path escapes its permitted root: $Path"
    }
}

function Connect-Dependency([string]$Source, [string]$Target, [string]$Kind) {
    Assert-ContainedPath $Source $projectRoot
    Assert-ContainedPath $Target $dependencyRootPath
    $sourceItem = Get-Item -LiteralPath $Source -Force -ErrorAction SilentlyContinue
    $targetExists = Test-Path -LiteralPath $Target
    if ($sourceItem -and $sourceItem.LinkType) {
        $actual = ''
        if ($sourceItem.LinkType -eq 'HardLink' -and $Kind -eq 'HardLink' -and $targetExists) {
            # PowerShell does not populate Target for NTFS hard links.
            $links = & (Join-Path $env:SystemRoot 'System32\fsutil.exe') hardlink list $Source
            if ($LASTEXITCODE -ne 0) { throw "Cannot inspect hard links: $Source" }
            $volume = [IO.Path]::GetPathRoot($Source).TrimEnd('\')
            foreach ($link in $links) {
                if (($volume + $link.Trim()) -eq $Target) { $actual = $Target; break }
            }
        } else {
            $targets = @($sourceItem.Target | Where-Object { $_ })
            if ($targets.Count) { $actual = [IO.Path]::GetFullPath($targets[0]) }
        }
        if ($sourceItem.LinkType -eq $Kind -and $actual -eq $Target -and $targetExists) {
            return 'AlreadyLinked'
        }
        throw "Existing link does not match the configured dependency: $Source"
    }
    if (-not $sourceItem -and -not $targetExists) { return 'NotPresent' }
    if ($sourceItem -and $targetExists) {
        throw "Both paths exist; refusing to overwrite or merge: $Source -> $Target"
    }
    if ($Kind -eq 'HardLink' -and
        [IO.Path]::GetPathRoot($Source) -ne [IO.Path]::GetPathRoot($Target)) {
        throw "Hard links require source and target on the same volume: $Source"
    }
    if (-not $Apply) {
        return $(if ($sourceItem) { 'WouldMoveAndLink' } else { 'WouldLinkSharedDependency' })
    }
    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $Target) -Force
    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $Source) -Force
    $moved = $false
    try {
        if ($sourceItem) {
            # Both resolved absolute paths were checked before the directory move.
            Move-Item -LiteralPath $Source -Destination $Target
            $moved = $true
        }
        $null = New-Item -ItemType $Kind -Path $Source -Target $Target
    } catch {
        if ($moved -and -not (Test-Path -LiteralPath $Source)) {
            Assert-ContainedPath $Target $dependencyRootPath
            Assert-ContainedPath $Source $projectRoot
            Move-Item -LiteralPath $Target -Destination $Source
        }
        throw
    }
    return $(if ($moved) { 'MovedAndLinked' } else { 'LinkedSharedDependency' })
}

$results = [Collections.Generic.List[object]]::new()
foreach ($entry in $layout) {
    $source = [IO.Path]::GetFullPath((Join-Path $projectRoot $entry.Source))
    $target = [IO.Path]::GetFullPath((Join-Path $dependencyRootPath $entry.Target))
    $status = Connect-Dependency $source $target $entry.Kind
    $results.Add([pscustomobject]@{ Source = $source; Target = $target; Kind = $entry.Kind; Status = $status })
    Write-Host "$status : $($entry.Source)"
}

if ($Apply) {
    # Retain provenance beside shared corpora without removing repository notices.
    foreach ($name in @('chinese-ancient-poetry-translation-master', 'chinese-classical-corpus-main', 'Classical-Modern-data', 'rime-wubi')) {
        $license = Join-Path $projectRoot "Aatime\$name\LICENSE"
        $destination = Join-Path $dependencyRootPath "corpora\$name\LICENSE"
        Assert-ContainedPath $destination $dependencyRootPath
        if ((Test-Path -LiteralPath $license) -and -not (Test-Path -LiteralPath $destination)) {
            Copy-Item -LiteralPath $license -Destination $destination
        }
    }
    $manifestDirectory = Join-Path $dependencyRootPath 'manifests'
    $null = New-Item -ItemType Directory -Path $manifestDirectory -Force
    [pscustomobject]@{
        ProjectRoot = $projectRoot
        DependencyRoot = $dependencyRootPath
        UpdatedAt = [DateTimeOffset]::Now.ToString('o')
        Entries = $results.ToArray()
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $manifestDirectory 'wuwei_dictionary.json') -Encoding UTF8
}
$results
