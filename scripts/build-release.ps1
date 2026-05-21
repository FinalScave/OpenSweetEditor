param(
    [string]$Build = "",
    [string]$Output = "",
    [string]$Src = "",
    [ValidateSet("all", "windows", "android", "ohos", "wasm", "linux")]
    [string]$Platform = "all",
    [string]$AndroidNdk = $env:ANDROID_NDK,
    [string]$OhosToolchain = $env:OHOS_TOOLCHAIN,
    [switch]$UseWsl,
    [string]$WslDistro = ""
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = if ($Src) {
    [System.IO.Path]::GetFullPath($Src)
} else {
    [System.IO.Path]::GetFullPath((Join-Path $ScriptDir ".."))
}
$BuildDir = if ($Build) {
    [System.IO.Path]::GetFullPath($Build)
} else {
    Join-Path $ProjectDir "build"
}
$OutputDir = if ($Output) {
    [System.IO.Path]::GetFullPath($Output)
} else {
    Join-Path $ProjectDir "prebuilt"
}

$TargetName = "sweeteditor"
$WasmTargetNames = @("sweeteditor_wasm_c_abi", "sweeteditor_wasm_embind")

function Write-Section {
    param([Parameter(Mandatory = $true)][string]$Title)
    Write-Host ""
    Write-Host "============================= $Title ============================="
}

function Invoke-External {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        $joined = ($Arguments | ForEach-Object {
            if ($_ -match '\s') { '"{0}"' -f $_ } else { $_ }
        }) -join ' '
        throw "Command failed: $FilePath $joined"
    }
}

function Ensure-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Resolve-CommandPath {
    param([Parameter(Mandatory = $true)][string]$Name)
    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $command) {
        throw "Required command not found: $Name"
    }
    return $command.Source
}

function Get-WslDistros {
    param([Parameter(Mandatory = $true)][string]$WslPath)

    $rawLines = & $WslPath -l -q
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to list installed WSL distributions."
    }

    $distros = @()
    foreach ($line in $rawLines) {
        $clean = ($line -replace "`0", "").Trim()
        if ($clean) {
            $distros += $clean
        }
    }

    return $distros
}

function Resolve-WslDistroName {
    param(
        [Parameter(Mandatory = $true)][string]$WslPath,
        [Parameter(Mandatory = $true)][string]$RequestedName
    )

    $distros = @(Get-WslDistros -WslPath $WslPath)
    if ($distros.Count -eq 0) {
        throw "No WSL distributions are installed."
    }

    $exactMatches = @($distros | Where-Object { $_ -ieq $RequestedName })
    if ($exactMatches.Count -eq 1) {
        return $exactMatches[0]
    }

    $prefixMatches = @($distros | Where-Object {
        $_.StartsWith($RequestedName, [System.StringComparison]::OrdinalIgnoreCase)
    })
    if ($prefixMatches.Count -eq 1) {
        return $prefixMatches[0]
    }

    $installed = $distros -join ", "
    if ($prefixMatches.Count -gt 1) {
        throw "WSL distribution '$RequestedName' is ambiguous. Installed distros: $installed"
    }

    throw "WSL distribution '$RequestedName' was not found. Installed distros: $installed"
}

function Resolve-WslBuildDistroName {
    param(
        [Parameter(Mandatory = $true)][string]$WslPath,
        [string]$RequestedName = ""
    )

    if ($RequestedName) {
        return Resolve-WslDistroName -WslPath $WslPath -RequestedName $RequestedName
    }

    $distros = @(Get-WslDistros -WslPath $WslPath)
    if ($distros.Count -eq 0) {
        throw "No WSL distributions are installed."
    }

    $preferred = @($distros | Where-Object { $_ -notmatch '^docker-desktop(?:-data)?$' })
    if ($preferred.Count -eq 0) {
        $installed = $distros -join ", "
        throw "No usable WSL build distribution found. Installed distros: $installed"
    }

    return $preferred[0]
}

function Convert-ToWslPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if ($fullPath -match '^([A-Za-z]):\\?(.*)$') {
        $drive = $matches[1].ToLowerInvariant()
        $rest = $matches[2] -replace '\\', '/'
        if ([string]::IsNullOrEmpty($rest)) {
            return "/mnt/$drive"
        }
        return "/mnt/$drive/$rest"
    }

    throw "Unsupported Windows path for WSL conversion: $fullPath"
}

function Resolve-AndroidStripTool {
    param([Parameter(Mandatory = $true)][string]$NdkPath)

    $hostTags = @(
        "windows-x86_64",
        "linux-x86_64",
        "darwin-x86_64",
        "darwin-arm64"
    )

    foreach ($tag in $hostTags) {
        $candidate = Join-Path $NdkPath "toolchains\llvm\prebuilt\$tag\bin\llvm-strip.exe"
        if (Test-Path $candidate) {
            return $candidate
        }

        $candidate = Join-Path $NdkPath "toolchains\llvm\prebuilt\$tag\bin\llvm-strip"
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    return $null
}

function Strip-AndroidOutputs {
    param(
        [Parameter(Mandatory = $true)][string]$TargetDir,
        [Parameter(Mandatory = $true)][string]$StripTool
    )

    if (-not (Test-Path $TargetDir)) {
        return
    }

    Get-ChildItem -Path $TargetDir -Recurse -File -Filter *.so -ErrorAction SilentlyContinue |
        ForEach-Object {
            Invoke-External -FilePath $StripTool -Arguments @("--strip-unneeded", $_.FullName)
        }
}

function Copy-BuiltLibraries {
    param(
        [Parameter(Mandatory = $true)][string]$SourceDir,
        [Parameter(Mandatory = $true)][string]$DestinationDir
    )

    Ensure-Directory -Path $DestinationDir

    if (-not (Test-Path $SourceDir)) {
        return
    }

    $patterns = @("*.dll", "*.so", "*.dylib", "*.wasm", "*.js")
    foreach ($pattern in $patterns) {
        Get-ChildItem -Path $SourceDir -Recurse -File -Filter $pattern -ErrorAction SilentlyContinue |
            ForEach-Object {
                Copy-Item -Path $_.FullName -Destination (Join-Path $DestinationDir $_.Name) -Force
            }
    }
}

function Build-WindowsMsvc {
    Write-Section "Windows X64"
    $windowsBuildDir = Join-Path $BuildDir "windows"
    $windowsPrebuiltDir = Join-Path $OutputDir "windows\x64"

    Invoke-External -FilePath "cmake" -Arguments @(
        $ProjectDir,
        "-B", $windowsBuildDir,
        "-G", "Visual Studio 17 2022",
        "-DCMAKE_BUILD_TYPE=Release",
        "-DCMAKE_CXX_STANDARD=17",
        "-DCMAKE_CXX_STANDARD_REQUIRED=ON",
        "-DCMAKE_CXX_FLAGS=/std:c++17 /EHsc /utf-8",
        "-DSWEETEDITOR_BUILD_STATIC=OFF",
        "-DSWEETEDITOR_BUILD_TESTS=OFF"
    )

    Invoke-External -FilePath "cmake" -Arguments @(
        "--build", $windowsBuildDir,
        "--target", $TargetName,
        "--config", "Release",
        "-j", "24"
    )

    Copy-BuiltLibraries -SourceDir (Join-Path $windowsBuildDir "bin") -DestinationDir $windowsPrebuiltDir
}

function Build-Emscripten {
    Write-Section "WebAssembly"
    $wasmBuildDir = Join-Path $BuildDir "emscripten"
    $wasmPrebuiltDir = Join-Path $OutputDir "wasm"
    $emcmake = Resolve-CommandPath -Name "emcmake.bat"

    Invoke-External -FilePath $emcmake -Arguments @(
        "cmake",
        $ProjectDir,
        "-B", $wasmBuildDir,
        "-G", "Ninja",
        "-DCMAKE_CXX_FLAGS=-std=c++17",
        "-DCMAKE_BUILD_TYPE=Release",
        "-DSWEETEDITOR_BUILD_STATIC=OFF",
        "-DSWEETEDITOR_BUILD_TESTS=OFF"
    )

    $wasmBuildArgs = @(
        "--build", $wasmBuildDir,
        "--target"
    ) + $WasmTargetNames + @(
        "-j", "24"
    )
    Invoke-External -FilePath "cmake" -Arguments $wasmBuildArgs

    Copy-BuiltLibraries -SourceDir (Join-Path $wasmBuildDir "bin") -DestinationDir $wasmPrebuiltDir
}

function Build-Android {
    param([Parameter(Mandatory = $true)][string]$Arch)

    if (-not $AndroidNdk) {
        throw "ANDROID_NDK is not set. Use -AndroidNdk or set ANDROID_NDK."
    }

    Write-Section "Android $Arch"
    Write-Host "NDK: $AndroidNdk"

    $androidBuildDir = Join-Path $BuildDir "android\$Arch"
    $androidPrebuiltDir = Join-Path $OutputDir "android\$Arch"
    $toolchainFile = Join-Path $AndroidNdk "build\cmake\android.toolchain.cmake"

    Invoke-External -FilePath "cmake" -Arguments @(
        $ProjectDir,
        "-B", $androidBuildDir,
        "-G", "Ninja",
        "-DANDROID_ABI=$Arch",
        "-DCMAKE_ANDROID_ARCH_ABI=$Arch",
        "-DANDROID_NDK=$AndroidNdk",
        "-DCMAKE_ANDROID_NDK=$AndroidNdk",
        "-DCMAKE_BUILD_TYPE=Release",
        "-DCMAKE_TOOLCHAIN_FILE=$toolchainFile",
        "-DANDROID_PLATFORM=android-21",
        "-DCMAKE_CXX_FLAGS=-std=c++17",
        "-DSWEETEDITOR_BUILD_STATIC=OFF",
        "-DSWEETEDITOR_BUILD_TESTS=OFF"
    )

    Invoke-External -FilePath "cmake" -Arguments @(
        "--build", $androidBuildDir,
        "--target", $TargetName,
        "-j", "24"
    )

    $stripTool = Resolve-AndroidStripTool -NdkPath $AndroidNdk
    if (-not $stripTool) {
        throw "llvm-strip not found under ANDROID_NDK=$AndroidNdk"
    }

    Write-Section "Stripping Android .so ($Arch)"
    Write-Host "Strip Tool: $stripTool"
    Strip-AndroidOutputs -TargetDir $androidBuildDir -StripTool $stripTool
    Copy-BuiltLibraries -SourceDir $androidBuildDir -DestinationDir $androidPrebuiltDir
}

function Build-Ohos {
    param([Parameter(Mandatory = $true)][string]$Arch)

    if (-not $OhosToolchain) {
        throw "OHOS_TOOLCHAIN is not set. Use -OhosToolchain or set OHOS_TOOLCHAIN."
    }

    Write-Section "OHOS $Arch"
    Write-Host "Toolchain: $OhosToolchain"

    $ohosBuildDir = Join-Path $BuildDir "ohos\$Arch"
    $ohosPrebuiltDir = Join-Path $OutputDir "ohos\$Arch"

    Invoke-External -FilePath "cmake" -Arguments @(
        $ProjectDir,
        "-B", $ohosBuildDir,
        "-G", "Ninja",
        "-DOHOS_PLATFORM=OHOS",
        "-DOHOS_ARCH=$Arch",
        "-DCMAKE_BUILD_TYPE=Release",
        "-DCMAKE_TOOLCHAIN_FILE=$OhosToolchain",
        "-DCMAKE_CXX_FLAGS=-std=c++17",
        "-DSWEETEDITOR_BUILD_STATIC=OFF",
        "-DSWEETEDITOR_BUILD_TESTS=OFF"
    )

    Invoke-External -FilePath "cmake" -Arguments @(
        "--build", $ohosBuildDir,
        "--target", $TargetName,
        "-j", "24"
    )

    Copy-BuiltLibraries -SourceDir (Join-Path $ohosBuildDir "lib") -DestinationDir $ohosPrebuiltDir
}

function Build-LinuxWsl {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("x86_64", "aarch64")]
        [string]$Arch
    )

    if (-not $UseWsl) {
        throw "Linux builds require -UseWsl."
    }

    $wsl = Resolve-CommandPath -Name "wsl.exe"
    $linuxBuildDir = Join-Path $BuildDir "linux\$Arch"
    $linuxPrebuiltDir = Join-Path $OutputDir "linux\$Arch"

    Ensure-Directory -Path $linuxPrebuiltDir

    $projectDirWsl = Convert-ToWslPath -Path $ProjectDir
    $linuxBuildDirWsl = Convert-ToWslPath -Path $linuxBuildDir
    $linuxPrebuiltDirWsl = Convert-ToWslPath -Path $linuxPrebuiltDir
    $linuxToolchainFileWsl = Convert-ToWslPath -Path (Join-Path $ProjectDir "cmake\linux-aarch64-toolchain.cmake")

    Write-Section "Linux $Arch (WSL)"
    $resolvedWslDistro = Resolve-WslBuildDistroName -WslPath $wsl -RequestedName $WslDistro
    if ($WslDistro) {
        if ($resolvedWslDistro -ieq $WslDistro) {
            Write-Host "Distro: $resolvedWslDistro"
        } else {
            Write-Host "Distro: $resolvedWslDistro (resolved from $WslDistro)"
        }
    } else {
        Write-Host "Distro: $resolvedWslDistro (auto-selected)"
    }

    $cmakeConfigureCommand = "cmake '$projectDirWsl' -B '$linuxBuildDirWsl' -G 'Ninja' -DCMAKE_CXX_FLAGS='-std=c++17 -fPIC' -DCMAKE_BUILD_TYPE=Release -DSWEETEDITOR_BUILD_STATIC=OFF -DSWEETEDITOR_BUILD_TESTS=OFF"
    if ($Arch -eq "aarch64") {
        $cmakeConfigureCommand += " -DCMAKE_TOOLCHAIN_FILE='$linuxToolchainFileWsl'"
    }

    $bashLines = @(
        'set -euo pipefail'
        "mkdir -p '$linuxPrebuiltDirWsl'"
        if ($Arch -eq "aarch64") { "command -v aarch64-linux-gnu-gcc >/dev/null 2>&1 || { echo 'Missing aarch64-linux-gnu-gcc. Install gcc-aarch64-linux-gnu.' >&2; exit 1; }" } else { $null }
        if ($Arch -eq "aarch64") { "command -v aarch64-linux-gnu-g++ >/dev/null 2>&1 || { echo 'Missing aarch64-linux-gnu-g++. Install g++-aarch64-linux-gnu.' >&2; exit 1; }" } else { $null }
        $cmakeConfigureCommand
        "cmake --build '$linuxBuildDirWsl' --target '$TargetName' -j 12"
        "find '$linuxBuildDirWsl/lib' -type f \( -name '*.dll' -o -name '*.so' -o -name '*.dylib' -o -name '*.wasm' -o -name '*.js' \) -exec cp -f {} '$linuxPrebuiltDirWsl/' \;"
    ) | Where-Object { $_ }
    $bashCommand = $bashLines -join "`n"

    $arguments = @()
    $arguments += @("-d", $resolvedWslDistro)
    $arguments += @("--", "bash", "-lc", $bashCommand)

    Invoke-External -FilePath $wsl -Arguments $arguments
}

Write-Section "Start building: $Platform"

switch ($Platform) {
    "all" {
        Build-WindowsMsvc
        Build-Android -Arch "arm64-v8a"
        Build-Android -Arch "x86_64"
        Build-Ohos -Arch "arm64-v8a"
        Build-Ohos -Arch "x86_64"
        Build-Emscripten
        if ($UseWsl) {
            Build-LinuxWsl -Arch "x86_64"
            Build-LinuxWsl -Arch "aarch64"
        }
    }
    "windows" {
        Build-WindowsMsvc
    }
    "android" {
        Build-Android -Arch "arm64-v8a"
        Build-Android -Arch "x86_64"
    }
    "ohos" {
        Build-Ohos -Arch "arm64-v8a"
        Build-Ohos -Arch "x86_64"
    }
    "wasm" {
        Build-Emscripten
    }
    "linux" {
        Build-LinuxWsl -Arch "x86_64"
        Build-LinuxWsl -Arch "aarch64"
    }
}
