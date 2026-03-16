param(
    [switch]$NoRun
)

$ErrorActionPreference = "Stop"

function Assert-Command {
    param([Parameter(Mandatory = $true)][string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $Name"
    }
}

function Invoke-Step {
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][scriptblock]$Action
    )
    Write-Host ""
    Write-Host "==> $Title" -ForegroundColor Cyan
    & $Action
}

function Resolve-NativeDllPath {
    param(
        [Parameter(Mandatory = $true)][string]$BuildDir,
        [Parameter(Mandatory = $true)][string]$Config
    )

    $candidates = @(
        (Join-Path $BuildDir "bin\\sweeteditor.dll"),
        (Join-Path $BuildDir "bin\\$Config\\sweeteditor.dll"),
        (Join-Path $BuildDir "$Config\\sweeteditor.dll"),
        (Join-Path $BuildDir "sweeteditor.dll")
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return (Resolve-Path $candidate).Path
        }
    }

    $found = Get-ChildItem -Path $BuildDir -Recurse -File -Filter "sweeteditor.dll" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($found) {
        return $found.FullName
    }

    return $null
}

Assert-Command -Name "cmake"
Assert-Command -Name "dotnet"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir "..")).Path
Set-Location $repoRoot

$buildDir = Join-Path $repoRoot "cmake-build-debug-visual-studio"
$cmakeCache = Join-Path $buildDir "CMakeCache.txt"
$nativeDllLegacyPath = Join-Path $buildDir "bin\\sweeteditor.dll"
$winFormsSolution = Join-Path $repoRoot "platform\\WinForms\\WinForms.sln"
$demoProject = Join-Path $repoRoot "platform\\WinForms\\Demo\\Demo.csproj"
$cmakeGenerator = "Ninja"
$isMultiConfigGenerator = $false
$buildConfig = "Debug"

Invoke-Step -Title "Configure C++ core (CMake)" -Action {
    if (Test-Path $cmakeCache) {
        $generatorLine = Get-Content $cmakeCache | Where-Object { $_ -like "CMAKE_GENERATOR:INTERNAL=*" } | Select-Object -First 1
        if ($generatorLine) {
            $cmakeGenerator = $generatorLine.Substring("CMAKE_GENERATOR:INTERNAL=".Length)
        }
        if (
            $cmakeGenerator -like "Visual Studio *" -or
            $cmakeGenerator -eq "Xcode" -or
            $cmakeGenerator -eq "Ninja Multi-Config"
        ) {
            $isMultiConfigGenerator = $true
        }

        Write-Host "Reuse existing CMake generator: $cmakeGenerator" -ForegroundColor DarkGray
        & cmake `
            -S $repoRoot `
            -B $buildDir `
            -DBUILD_SHARED_LIB=ON `
            -DBUILD_STATIC_LIB=ON `
            -DBUILD_TESTING=OFF
    } else {
        $cmakeGenerator = "Visual Studio 17 2022"
        $isMultiConfigGenerator = $true
        & cmake `
            -S $repoRoot `
            -B $buildDir `
            -G $cmakeGenerator `
            -A x64 `
            -DBUILD_SHARED_LIB=ON `
            -DBUILD_STATIC_LIB=ON `
            -DBUILD_TESTING=OFF
    }
    if ($LASTEXITCODE -ne 0) {
        throw "CMake configure failed."
    }
}

Invoke-Step -Title "Build C++ DLL (sweeteditor.dll)" -Action {
    $buildArgs = @("--build", $buildDir, "--target", "sweeteditor")
    if ($isMultiConfigGenerator) {
        $buildArgs += @("--config", $buildConfig)
    }
    & cmake @buildArgs
    if ($LASTEXITCODE -ne 0) {
        throw "C++ DLL build failed."
    }

    $nativeDll = Resolve-NativeDllPath -BuildDir $buildDir -Config $buildConfig
    if (-not $nativeDll) {
        throw "C++ DLL not found under build dir: $buildDir"
    }

    $resolvedNativeDll = [System.IO.Path]::GetFullPath($nativeDll)
    $resolvedLegacyDll = [System.IO.Path]::GetFullPath($nativeDllLegacyPath)
    if ([string]::Compare($resolvedNativeDll, $resolvedLegacyDll, $true) -ne 0) {
        $legacyDir = Split-Path -Parent $nativeDllLegacyPath
        if (-not (Test-Path $legacyDir)) {
            New-Item -ItemType Directory -Path $legacyDir | Out-Null
        }
        Copy-Item -Path $nativeDll -Destination $nativeDllLegacyPath -Force
        Write-Host "Synced native DLL to expected path: $nativeDllLegacyPath" -ForegroundColor DarkGray
    }

    Write-Host "Native DLL ready: $nativeDll" -ForegroundColor Green
}

Invoke-Step -Title "Build WinForms solution" -Action {
    & dotnet build $winFormsSolution -c Debug -nologo
    if ($LASTEXITCODE -ne 0) {
        throw "WinForms build failed."
    }
}

if ($NoRun) {
    Write-Host ""
    Write-Host "Build complete. Skipped preview run because -NoRun is set." -ForegroundColor Yellow
    exit 0
}

Invoke-Step -Title "Run WinForms preview (Demo)" -Action {
    & dotnet run --project $demoProject -c Debug --no-build
    if ($LASTEXITCODE -ne 0) {
        throw "WinForms preview failed to start."
    }
}
