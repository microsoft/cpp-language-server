<#
.SYNOPSIS
    Installs the pinned MSBuild extractor from the public cpp_PublicPackages feed.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageId   = 'Microsoft.VisualStudio.Cpp.MSBuildExtractor'
$version     = '1.0.2609.39'
$nupkgSha256 = '9670F13F974FEBD360D7B8F747CF025E1E1CC88394419234ECD9590E7B1805AE' # pragma: allowlist secret

$installDir = Join-Path $env:LOCALAPPDATA "mscppls\msbuild-extractor\public\$packageId.$version"
$exePath    = Join-Path $installDir 'tools\msbuild-extractor-sample.exe'
$feedBase   = 'https://pkgs.dev.azure.com/azure-public/VisualCpp/_packaging/cpp_PublicPackages/nuget/v3/flat2'

function Get-Sha256 ([string]$Path) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $stream = [IO.File]::OpenRead($Path)
        try { [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '') }
        finally { $stream.Dispose() }
    }
    finally { $sha.Dispose() }
}

function Test-Installed ([string]$Root) {
    Test-Path -LiteralPath (Join-Path $Root 'tools\msbuild-extractor-sample.exe') -PathType Leaf
}

function Write-Ready {
    Write-Host "msbuild-extractor $version ready: $exePath"

    $dotnetRoot = if ($env:DOTNET_ROOT) { $env:DOTNET_ROOT } else { Join-Path $env:ProgramFiles 'dotnet' }
    $sharedDir  = Join-Path $dotnetRoot 'shared\Microsoft.NETCore.App'
    $hasNet10   = (Test-Path -LiteralPath $sharedDir) -and
        @(Get-ChildItem -LiteralPath $sharedDir -Directory -Filter '10.*' -ErrorAction SilentlyContinue).Count -gt 0
    if (-not $hasNet10) {
        Write-Warning "A .NET 10 runtime was not detected. Install the .NET 10 SDK from https://dotnet.microsoft.com/download/dotnet/10.0."
    }
}

# Installed copies need no package download or hash check.
if (Test-Installed $installDir) {
    Write-Ready
    return
}

$cacheRoot = Split-Path -Parent $installDir
if (Test-Path -LiteralPath $cacheRoot) {
    Get-ChildItem -LiteralPath $cacheRoot -Directory -Filter "$packageId.*" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne "$packageId.$version" } |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Get-ChildItem -LiteralPath $cacheRoot -Directory -Filter '_staging.*' -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddHours(-1) } |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}

$lowerId  = $packageId.ToLowerInvariant()
$nupkgUrl = "$feedBase/$lowerId/$version/$lowerId.$version.nupkg"
$nupkgTmp = Join-Path ([IO.Path]::GetTempPath()) "$lowerId.$version.$PID.nupkg"
$stageDir = Join-Path $cacheRoot "_staging.$PID"
$retired  = Join-Path $cacheRoot "_staging.retired.$PID"

# Serialize concurrent session starts; publish the staged directory by rename.
$mutex = $null
try { $mutex = New-Object Threading.Mutex($false, 'Global\mscppls-msbuild-extractor-public-install') }
catch [UnauthorizedAccessException] { $mutex = New-Object Threading.Mutex($false, 'Local\mscppls-msbuild-extractor-public-install') }
$held = $false

try {
    try { $held = $mutex.WaitOne([TimeSpan]::FromSeconds(100)) }
    catch [Threading.AbandonedMutexException] { $held = $true }

    if (Test-Installed $installDir) {
        Write-Ready
        return
    }
    if (-not $held) {
        throw "Timed out waiting for another session to finish installing."
    }

    # Windows PowerShell 5.1 needs the ZIP assembly and TLS 1.2 enabled explicitly.
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.ServicePointManager]::SecurityProtocol

    Write-Host "Downloading $packageId $version from cpp_PublicPackages..."
    $progress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    try {
        Invoke-WebRequest -Uri $nupkgUrl -OutFile $nupkgTmp -UseBasicParsing
    }
    finally {
        $ProgressPreference = $progress
    }

    $actual = Get-Sha256 $nupkgTmp
    if ($actual -ne $nupkgSha256) {
        throw "SHA256 mismatch for $lowerId.$version.nupkg. Expected $nupkgSha256, got $actual."
    }

    if (Test-Path -LiteralPath $stageDir) {
        Remove-Item -LiteralPath $stageDir -Recurse -Force
    }
    [IO.Compression.ZipFile]::ExtractToDirectory($nupkgTmp, $stageDir)

    if (-not (Test-Installed $stageDir)) {
        throw "$lowerId.$version.nupkg did not contain tools\msbuild-extractor-sample.exe."
    }

    if (Test-Path -LiteralPath $installDir) {
        [IO.Directory]::Move($installDir, $retired)
    }
    [IO.Directory]::Move($stageDir, $installDir)

    if (-not (Test-Installed $installDir)) {
        throw "msbuild-extractor-sample.exe is missing after publishing to $installDir."
    }
}
catch {
    if ((Test-Path -LiteralPath $installDir) -and -not (Test-Installed $installDir)) {
        Remove-Item -LiteralPath $installDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-Error "Failed to install $packageId $version from cpp_PublicPackages. $($_.Exception.Message)"
    exit 1
}
finally {
    Remove-Item -LiteralPath $nupkgTmp -Force -ErrorAction SilentlyContinue
    foreach ($d in $stageDir, $retired) {
        if (Test-Path -LiteralPath $d) {
            Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    if ($held) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}

Write-Ready
