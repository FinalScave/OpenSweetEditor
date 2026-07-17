[CmdletBinding()]
param(
    [ValidateSet("menu", "status", "package", "publish", "resume")]
    [string]$Action = "menu",

    [ValidateSet("native", "android", "swing", "winforms", "flutter", "ohos")]
    [string[]]$Targets = @(),

    [string[]]$VersionOverride = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = [System.IO.Path]::GetFullPath((Join-Path $ScriptDir ".."))
$ReleaseDir = Join-Path $ProjectDir "build\release"
$StatePath = Join-Path $ReleaseDir "release-state.json"
$TargetOrder = @("native", "android", "swing", "winforms", "flutter", "ohos")
$VersionOverrides = @{}

foreach ($item in $VersionOverride) {
    if ($item -notmatch '^([^=]+)=(.+)$') {
        throw "Invalid version override '$item'. Use target=version."
    }
    $VersionOverrides[$Matches[1].Trim().ToLowerInvariant()] = $Matches[2].Trim()
}

function Ensure-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Assert-Command {
    param([Parameter(Mandatory = $true)][string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command is unavailable: $Name"
    }
}

function Invoke-External {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [AllowEmptyCollection()][string[]]$Arguments = @(),
        [Parameter(Mandatory = $true)][string]$WorkingDirectory,
        [switch]$HideArguments
    )

    $displayArguments = if ($HideArguments) { "[arguments hidden]" } else { $Arguments -join ' ' }
    Write-Host "`n> $FilePath $displayArguments" -ForegroundColor DarkGray
    Push-Location $WorkingDirectory
    try {
        $global:LASTEXITCODE = 0
        & $FilePath @Arguments
        if ($LASTEXITCODE -ne 0) {
            throw "Command failed with exit code ${LASTEXITCODE}: $FilePath"
        }
    } finally {
        Pop-Location
    }
}

function Get-RegexValue {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [Parameter(Mandatory = $true)][string]$Description
    )

    $content = [System.IO.File]::ReadAllText($Path)
    $match = [regex]::Match($content, $Pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
    if (-not $match.Success) {
        throw "Unable to read $Description from $Path"
    }
    return $match.Groups[1].Value
}

function Get-GradleVersion {
    param([Parameter(Mandatory = $true)][string]$Path)

    return Get-RegexValue -Path $Path -Pattern '^\s*version\s*=\s*["'']([^"'']+)["'']' -Description "Gradle version"
}

function Get-NuGetVersion {
    param([Parameter(Mandatory = $true)][string]$Path)

    [xml]$project = Get-Content -LiteralPath $Path -Raw
    $version = @($project.Project.PropertyGroup.Version | Where-Object { $_ }) | Select-Object -First 1
    if (-not $version) {
        throw "Unable to read NuGet version from $Path"
    }
    return [string]$version
}

function Get-PubVersion {
    param([Parameter(Mandatory = $true)][string]$Path)

    return Get-RegexValue -Path $Path -Pattern '^version:\s*([^\s]+)\s*$' -Description "pub version"
}

function Get-Json5Version {
    param([Parameter(Mandatory = $true)][string]$Path)

    return Get-RegexValue -Path $Path -Pattern '"version"\s*:\s*"([^"]+)"' -Description "OHPM version"
}

function Assert-Version {
    param(
        [Parameter(Mandatory = $true)][string]$Target,
        [Parameter(Mandatory = $true)][string]$Version
    )

    if ($Version -notmatch '^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$') {
        throw "Invalid version for ${Target}: $Version"
    }
}

function Get-TargetDefinitions {
    return @(
        [pscustomobject]@{ Key = "native"; Label = "Native / GitHub Release"; Registry = "GitHub"; PackageId = "FinalScave/SweetEditor"; Version = $null; Path = $ProjectDir; Repository = "FinalScave/SweetEditor" },
        [pscustomobject]@{ Key = "android"; Label = "Android"; Registry = "Maven Central"; PackageId = "com.qiplat:sweeteditor"; Version = Get-GradleVersion (Join-Path $ProjectDir "platform\Android\sweeteditor\build.gradle"); Path = Join-Path $ProjectDir "platform\Android"; Repository = $null },
        [pscustomobject]@{ Key = "swing"; Label = "Swing"; Registry = "Maven Central"; PackageId = "com.qiplat:sweeteditor-swing"; Version = Get-GradleVersion (Join-Path $ProjectDir "platform\Swing\sweeteditor\build.gradle"); Path = Join-Path $ProjectDir "platform\Swing"; Repository = $null },
        [pscustomobject]@{ Key = "winforms"; Label = "WinForms / NuGet"; Registry = "NuGet.org"; PackageId = "SweetEditor"; Version = Get-NuGetVersion (Join-Path $ProjectDir "platform\WinForms\SweetEditor\SweetEditor.csproj"); Path = Join-Path $ProjectDir "platform\WinForms\SweetEditor"; Repository = $null },
        [pscustomobject]@{ Key = "flutter"; Label = "Flutter / Dart"; Registry = "pub.dev"; PackageId = "sweeteditor"; Version = Get-PubVersion (Join-Path $ProjectDir "platform\Flutter\sweeteditor\pubspec.yaml"); Path = Join-Path $ProjectDir "platform\Flutter\sweeteditor"; Repository = $null },
        [pscustomobject]@{ Key = "ohos"; Label = "OHOS"; Registry = "OHPM"; PackageId = "@qiplat/sweeteditor"; Version = Get-Json5Version (Join-Path $ProjectDir "platform\OHOS\sweeteditor\oh-package.json5"); Path = Join-Path $ProjectDir "platform\OHOS"; Repository = $null }
    )
}

function Get-TargetDefinition {
    param([Parameter(Mandatory = $true)][string]$Key)

    $definition = Get-TargetDefinitions | Where-Object Key -EQ $Key | Select-Object -First 1
    if (-not $definition) {
        throw "Unknown release target: $Key"
    }
    return $definition
}

function Get-VersionEditSpecs {
    param([Parameter(Mandatory = $true)][string]$TargetKey)

    switch ($TargetKey) {
        "android" {
            return @(
                [pscustomobject]@{ Path = Join-Path $ProjectDir "platform\Android\sweeteditor\build.gradle"; Pattern = '(?m)^(\s*version\s*=\s*["''])([^"'']+)(["'']\s*)$' },
                [pscustomobject]@{ Path = Join-Path $ProjectDir "platform\Android\sweeteditor\README.md"; Pattern = '(?m)^(\s*implementation\(["'']com\.qiplat:sweeteditor:)([^"'']+)(["'']\)\s*)$' }
            )
        }
        "swing" {
            return @(
                [pscustomobject]@{ Path = Join-Path $ProjectDir "platform\Swing\sweeteditor\build.gradle"; Pattern = '(?m)^(\s*version\s*=\s*["''])([^"'']+)(["'']\s*)$' },
                [pscustomobject]@{ Path = Join-Path $ProjectDir "platform\Swing\sweeteditor\README.md"; Pattern = '(?m)^(\s*<version>)([^<]+)(</version>\s*)$' },
                [pscustomobject]@{ Path = Join-Path $ProjectDir "platform\Swing\sweeteditor\README.md"; Pattern = '(?m)^(\s*implementation\s+["'']com\.qiplat:sweeteditor-swing:)([^"'']+)(["'']\s*)$' },
                [pscustomobject]@{ Path = Join-Path $ProjectDir "platform\Swing\sweeteditor\README.md"; Pattern = '(?m)(sweeteditor-swing-)(\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?)(\.jar)' }
            )
        }
        "winforms" {
            return @(
                [pscustomobject]@{ Path = Join-Path $ProjectDir "platform\WinForms\SweetEditor\SweetEditor.csproj"; Pattern = '(?m)^(\s*<Version>)([^<]+)(</Version>\s*)$' },
                [pscustomobject]@{ Path = Join-Path $ProjectDir "platform\WinForms\SweetEditor\README.md"; Pattern = '(?m)^(\s*dotnet add package SweetEditor --version\s+)([^\s]+)(\s*)$' }
            )
        }
        "flutter" {
            return @(
                [pscustomobject]@{ Path = Join-Path $ProjectDir "platform\Flutter\sweeteditor\pubspec.yaml"; Pattern = '(?m)^(\s*version:\s*)([^\s#]+)(\s*)$' },
                [pscustomobject]@{ Path = Join-Path $ProjectDir "platform\Flutter\sweeteditor\README.md"; Pattern = '(?m)^(\s*sweeteditor:\s*\^?)([^\s]+)(\s*)$' }
            )
        }
        "ohos" {
            return @(
                [pscustomobject]@{ Path = Join-Path $ProjectDir "platform\OHOS\sweeteditor\oh-package.json5"; Pattern = '(?m)^(\s*"version"\s*:\s*")([^"]+)(".*)$' },
                [pscustomobject]@{ Path = Join-Path $ProjectDir "platform\OHOS\sweeteditor\BuildProfile.ets"; Pattern = "(?m)^(\s*export const HAR_VERSION\s*=\s*')([^']+)(';.*)$" },
                [pscustomobject]@{ Path = Join-Path $ProjectDir "platform\OHOS\sweeteditor\src\main\cpp\types\libsweeteditor\oh-package.json5"; Pattern = '(?m)^(\s*"version"\s*:\s*")([^"]+)(".*)$' },
                [pscustomobject]@{ Path = Join-Path $ProjectDir "platform\OHOS\sweeteditor\oh-package-lock.json5"; Pattern = '(?ms)("name"\s*:\s*"libsweeteditor\.so",\s*"version"\s*:\s*")([^"]+)(")' },
                [pscustomobject]@{ Path = Join-Path $ProjectDir "platform\OHOS\sweeteditor\README.md"; Pattern = '(?m)^(\s*ohpm install @qiplat/sweeteditor@)([^\s]+)(\s*)$' }
            )
        }
        default { throw "$TargetKey does not have a persistent package version file." }
    }
}

function New-VersionFileUpdate {
    param(
        [Parameter(Mandatory = $true)][object[]]$Specs,
        [Parameter(Mandatory = $true)][string]$CurrentVersion,
        [Parameter(Mandatory = $true)][string]$NewVersion
    )

    $path = $Specs[0].Path
    if (@($Specs | Where-Object Path -NE $path).Count -gt 0) {
        throw "Version update specs must reference the same file."
    }

    $bytes = [System.IO.File]::ReadAllBytes($path)
    $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $offset = if ($hasBom) { 3 } else { 0 }
    $content = [System.Text.Encoding]::UTF8.GetString($bytes, $offset, $bytes.Length - $offset)
    $updatedContent = $content
    foreach ($spec in $Specs) {
        $matches = [regex]::Matches($updatedContent, $spec.Pattern)
        if ($matches.Count -ne 1) {
            throw "Expected one version field in $path, found $($matches.Count)."
        }
        $match = $matches[0]
        if ($match.Groups[2].Value -ne $CurrentVersion) {
            throw "Version mismatch in ${path}: expected $CurrentVersion, found $($match.Groups[2].Value)."
        }
        $replacement = $match.Groups[1].Value + $NewVersion + $match.Groups[3].Value
        $updatedContent = $updatedContent.Remove($match.Index, $match.Length).Insert($match.Index, $replacement)
    }

    return [pscustomobject]@{
        Path = $path
        OriginalBytes = $bytes
        Content = $updatedContent
        Encoding = [System.Text.UTF8Encoding]::new($hasBom)
    }
}

function Set-PlatformVersion {
    param(
        [Parameter(Mandatory = $true)][string]$TargetKey,
        [Parameter(Mandatory = $true)][string]$NewVersion
    )

    $target = Get-TargetDefinition $TargetKey
    Assert-Version -Target $TargetKey -Version $NewVersion
    if ($target.Version -eq $NewVersion) {
        Write-Host "$($target.Label) is already at version $NewVersion." -ForegroundColor Green
        return
    }

    $updates = @(Get-VersionEditSpecs $TargetKey | Group-Object Path | ForEach-Object {
        New-VersionFileUpdate -Specs @($_.Group) -CurrentVersion $target.Version -NewVersion $NewVersion
    })
    $written = New-Object System.Collections.Generic.List[object]
    try {
        foreach ($update in $updates) {
            [System.IO.File]::WriteAllText($update.Path, $update.Content, $update.Encoding)
            $written.Add($update)
        }
    } catch {
        foreach ($update in $written) {
            [System.IO.File]::WriteAllBytes($update.Path, $update.OriginalBytes)
        }
        throw
    }

    Write-Host "`n$($target.Label): $($target.Version) -> $NewVersion" -ForegroundColor Green
    foreach ($update in $updates) {
        $relative = $update.Path.Substring($ProjectDir.TrimEnd('\', '/').Length).TrimStart('\', '/')
        Write-Host "  $relative"
    }
}

function Resolve-ReleaseItems {
    param(
        [Parameter(Mandatory = $true)][string[]]$SelectedTargets,
        [switch]$AllowPrompt
    )

    $items = New-Object System.Collections.Generic.List[object]
    foreach ($key in $SelectedTargets) {
        $definition = Get-TargetDefinition $key
        $version = if ($VersionOverrides.ContainsKey($key)) { $VersionOverrides[$key] } else { $definition.Version }
        if (-not $version -and $AllowPrompt) {
            $version = (Read-Host "Enter the version for $($definition.Label)").Trim()
            if ($version) {
                $VersionOverrides[$key] = $version
            }
        }
        if (-not $version) {
            throw "$($definition.Label) has no readable version. Pass -VersionOverride ${key}=x.y.z."
        }
        Assert-Version -Target $key -Version $version
        $items.Add([pscustomobject]@{ Target = $definition; Version = $version })
    }

    return @($items | Sort-Object { [array]::IndexOf($TargetOrder, $_.Target.Key) })
}

function Test-MavenPackage {
    param(
        [Parameter(Mandatory = $true)][string]$PackageId,
        [Parameter(Mandatory = $true)][string]$Version
    )

    $parts = $PackageId.Split(':')
    $groupPath = $parts[0].Replace('.', '/')
    $artifact = $parts[1]
    $url = "https://repo.maven.apache.org/maven2/$groupPath/$artifact/maven-metadata.xml"
    try {
        [xml]$metadata = (Invoke-WebRequest -Uri $url -UseBasicParsing).Content
        return $Version -in @($metadata.metadata.versioning.versions.version)
    } catch {
        if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 404) {
            return $false
        }
        throw
    }
}

function Test-NuGetPackage {
    param(
        [Parameter(Mandatory = $true)][string]$PackageId,
        [Parameter(Mandatory = $true)][string]$Version
    )

    $id = $PackageId.ToLowerInvariant()
    try {
        $data = Invoke-RestMethod -Uri "https://api.nuget.org/v3-flatcontainer/$id/index.json"
        return $Version -in @($data.versions)
    } catch {
        if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 404) {
            return $false
        }
        throw
    }
}

function Test-PubPackage {
    param(
        [Parameter(Mandatory = $true)][string]$PackageId,
        [Parameter(Mandatory = $true)][string]$Version
    )

    try {
        $data = Invoke-RestMethod -Uri "https://pub.dev/api/packages/$PackageId"
        return $Version -in @($data.versions.version)
    } catch {
        if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 404) {
            return $false
        }
        throw
    }
}

function Test-OhpmPackage {
    param(
        [Parameter(Mandatory = $true)][string]$PackageId,
        [Parameter(Mandatory = $true)][string]$Version
    )

    Assert-Command "ohpm"
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & ohpm info "$PackageId@$Version" --log_level error 2>&1
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    $ansiPattern = [string][char]27 + '\[[0-9;?]*[ -/]*[@-~]'
    $text = ($output | Out-String) -replace $ansiPattern, ""
    if ($exitCode -eq 0) {
        return $text -match [regex]::Escape("$PackageId@$Version")
    }
    if ($text -match 'NOTFOUND|not found') {
        return $false
    }
    throw "OHPM registry query failed for $PackageId@$Version"
}

function Test-GitHubRelease {
    param(
        [Parameter(Mandatory = $true)][string]$Repository,
        [Parameter(Mandatory = $true)][string]$Tag
    )

    try {
        Invoke-RestMethod -Uri "https://api.github.com/repos/$Repository/releases/tags/$Tag" -Headers @{ "User-Agent" = "SweetEditor release tool" } | Out-Null
        return $true
    } catch {
        if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 404) {
            return $false
        }
        throw
    }
}

function Get-RegistryStatus {
    param(
        [Parameter(Mandatory = $true)]$Target,
        [AllowNull()][string]$Version
    )

    if (-not $Version) {
        return "Version required"
    }

    try {
        $published = switch ($Target.Registry) {
            "Maven Central" { Test-MavenPackage -PackageId $Target.PackageId -Version $Version }
            "NuGet.org" { Test-NuGetPackage -PackageId $Target.PackageId -Version $Version }
            "pub.dev" { Test-PubPackage -PackageId $Target.PackageId -Version $Version }
            "OHPM" { Test-OhpmPackage -PackageId $Target.PackageId -Version $Version }
            "GitHub" {
                Test-GitHubRelease -Repository $Target.Repository -Tag "native-v$Version"
            }
            default { throw "Unsupported registry: $($Target.Registry)" }
        }
        return $(if ($published) { "Published" } else { "Pending" })
    } catch {
        return "Query failed"
    }
}

function Show-ReleaseStatus {
    param([Parameter(Mandatory = $true)][string]$TargetKey)

    $target = Get-TargetDefinition $TargetKey
    $version = if ($VersionOverrides.ContainsKey($target.Key)) { $VersionOverrides[$target.Key] } else { $target.Version }
    $row = [pscustomobject]@{
        Target = $target.Key
        Version = $(if ($version) { $version } else { "-" })
        Registry = $target.Registry
        Status = Get-RegistryStatus -Target $target -Version $version
    }
    Write-Host ""
    $row | Format-Table -AutoSize | Out-Host
    return $row
}

function Get-ExpectedNativeSymbols {
    $headerPath = Join-Path $ProjectDir "include\sweeteditor\c_api.h"
    $content = [System.IO.File]::ReadAllText($headerPath)
    $pattern = '\bEDITOR_API\s+(?:const\s+)?[A-Za-z_][A-Za-z0-9_:<>]*\s*\*?\s*([A-Za-z_][A-Za-z0-9_]*)\s*\('
    return @([regex]::Matches($content, $pattern) |
        ForEach-Object { $_.Groups[1].Value } |
        Where-Object { $_ -match '^[a-z][a-z0-9_]*_[a-z0-9_]+$' } |
        Sort-Object -Unique)
}

function Get-NativeExports {
    param([Parameter(Mandatory = $true)][System.IO.FileInfo]$File)

    $exports = New-Object System.Collections.Generic.HashSet[string]
    if ($File.Extension -eq ".dll") {
        Assert-Command "llvm-readobj"
        $output = & llvm-readobj --coff-exports $File.FullName 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to inspect native exports: $($File.FullName)"
        }
        foreach ($line in $output) {
            if ($line -match 'Name:\s+([A-Za-z_][A-Za-z0-9_]*)') {
                $exports.Add($Matches[1]) | Out-Null
            }
        }
    } else {
        Assert-Command "llvm-nm"
        $arguments = if ($File.Extension -eq ".so") { @("-D", "--defined-only", $File.FullName) } else { @("--defined-only", $File.FullName) }
        $output = & llvm-nm @arguments 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to inspect native exports: $($File.FullName)"
        }
        foreach ($line in $output) {
            if ($line -match '(?:^|\s)_?([A-Za-z_][A-Za-z0-9_]*)$') {
                $exports.Add($Matches[1]) | Out-Null
            }
        }
    }
    return $exports
}

function Test-NativeAbi {
    param([Parameter(Mandatory = $true)][string[]]$TargetKeys)

    $expected = Get-ExpectedNativeSymbols
    $platforms = New-Object System.Collections.Generic.HashSet[string]
    if ($TargetKeys -contains "native") {
        @("android", "ios", "linux", "macos", "ohos", "windows") | ForEach-Object { $platforms.Add($_) | Out-Null }
    } else {
        foreach ($targetKey in $TargetKeys) {
            switch ($targetKey) {
                "swing" { @("linux", "macos", "windows") | ForEach-Object { $platforms.Add($_) | Out-Null } }
                "winforms" { $platforms.Add("windows") | Out-Null }
                "flutter" { @("android", "ios", "linux", "macos", "windows") | ForEach-Object { $platforms.Add($_) | Out-Null } }
            }
        }
    }

    $nativeFiles = foreach ($platform in $platforms) {
        $platformDir = Join-Path $ProjectDir "prebuilt\$platform"
        if (Test-Path -LiteralPath $platformDir) {
            Get-ChildItem -LiteralPath $platformDir -Recurse -File | Where-Object { $_.Extension -in @(".dll", ".so", ".dylib") }
        }
    }
    $nativeFiles = @($nativeFiles)
    if ($nativeFiles.Count -eq 0) {
        throw "No prebuilt native libraries were found."
    }
    if ($expected.Count -eq 0) {
        throw "No exported C API declarations were found."
    }

    $failures = New-Object System.Collections.Generic.List[string]
    foreach ($file in $nativeFiles) {
        $exports = Get-NativeExports $file
        $expectedForFile = if ($file.Extension -eq ".dll") {
            $expected
        } else {
            @($expected | Where-Object { $_ -ne "init_unhandled_exception_handler" })
        }
        $missing = @($expectedForFile | Where-Object { -not $exports.Contains($_) })
        if ($missing.Count -gt 0) {
            $relative = $file.FullName.Substring($ProjectDir.TrimEnd('\', '/').Length).TrimStart('\', '/')
            $failures.Add("${relative}: $($missing -join ', ')")
        }
    }

    if ($failures.Count -gt 0) {
        throw "Native ABI validation failed:`n$($failures -join "`n")"
    }
    Write-Host "Native ABI validation passed." -ForegroundColor Green
}

function Test-NuGetPackageContents {
    param([Parameter(Mandatory = $true)][string]$PackagePath)

    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($PackagePath)
    try {
        $entries = @($archive.Entries.FullName | ForEach-Object { $_.Replace('\', '/') })
        $requiredEntries = @(
            "runtimes/win-x64/native/sweeteditor.dll"
        )
        $missing = @($requiredEntries | Where-Object { $_ -notin $entries })
        if ($missing.Count -gt 0) {
            throw "NuGet package is missing required entries: $($missing -join ', ')"
        }
    } finally {
        $archive.Dispose()
    }
}

function Invoke-PackageTarget {
    param(
        [Parameter(Mandatory = $true)]$Target,
        [Parameter(Mandatory = $true)][string]$Version
    )

    Write-Host "`nPackaging $($Target.Label) $Version" -ForegroundColor Cyan
    switch ($Target.Key) {
        "native" {
            $outputDir = Join-Path $ReleaseDir "native"
            Ensure-Directory $outputDir
            Invoke-External -FilePath (Join-Path $ScriptDir "package-artifacts.ps1") -Arguments @("-Version", $Version, "-OutputDir", $outputDir, "-Force") -WorkingDirectory $ProjectDir
        }
        "android" {
            Invoke-External -FilePath (Join-Path $Target.Path "gradlew.bat") -Arguments @(":sweeteditor:assembleRelease", ":sweeteditor:generateBundle", "--console=plain") -WorkingDirectory $Target.Path
        }
        "swing" {
            Invoke-External -FilePath (Join-Path $Target.Path "gradlew.bat") -Arguments @(":sweeteditor:generateBundle", "--console=plain") -WorkingDirectory $Target.Path
        }
        "winforms" {
            $outputDir = Join-Path $ReleaseDir "winforms"
            Ensure-Directory $outputDir
            Invoke-External -FilePath "dotnet" -Arguments @("pack", (Join-Path $Target.Path "SweetEditor.csproj"), "-c", "Release", "-o", $outputDir, "/p:PackageVersion=$Version") -WorkingDirectory $ProjectDir
            Test-NuGetPackageContents -PackagePath (Join-Path $outputDir "SweetEditor.$Version.nupkg")
        }
        "flutter" {
            Invoke-External -FilePath "dart" -Arguments @("tool/sync_native_binaries.dart") -WorkingDirectory $Target.Path
            Invoke-External -FilePath "dart" -Arguments @("analyze") -WorkingDirectory $Target.Path
            Invoke-External -FilePath "dart" -Arguments @("pub", "publish", "--dry-run") -WorkingDirectory $Target.Path
        }
        "ohos" {
            $buildProfilePath = Join-Path $Target.Path "sweeteditor\BuildProfile.ets"
            $buildProfileBytes = [System.IO.File]::ReadAllBytes($buildProfilePath)
            try {
                Invoke-External -FilePath "hvigorw" -Arguments @("assembleHar", "--mode", "module", "-p", "module=sweeteditor@default", "-p", "product=default", "-p", "buildMode=release", "--no-daemon") -WorkingDirectory $Target.Path
            } finally {
                [System.IO.File]::WriteAllBytes($buildProfilePath, $buildProfileBytes)
            }
            $sourceHar = Join-Path $Target.Path "sweeteditor\build\default\outputs\default\sweeteditor.har"
            if (-not (Test-Path -LiteralPath $sourceHar)) {
                throw "OHOS HAR was not generated: $sourceHar"
            }
            $outputDir = Join-Path $ReleaseDir "ohos"
            Ensure-Directory $outputDir
            $releaseHar = Join-Path $outputDir "sweeteditor-$Version.har"
            Copy-Item -LiteralPath $sourceHar -Destination $releaseHar -Force
            Invoke-External -FilePath "ohpm" -Arguments @("prepublish", $releaseHar) -WorkingDirectory $Target.Path
        }
        default { throw "Unsupported package target: $($Target.Key)" }
    }
}

function Assert-GitHubAuthentication {
    Assert-Command "gh"
    Invoke-External -FilePath "gh" -Arguments @("auth", "status") -WorkingDirectory $ProjectDir
}

function Assert-PublishWorkspace {
    $changes = @(git -C $ProjectDir status --porcelain)
    if ($changes.Count -gt 0) {
        throw "Publishing requires a clean working tree."
    }
    $head = (git -C $ProjectDir rev-parse HEAD).Trim()
    $upstream = (git -C $ProjectDir rev-parse '@{u}').Trim()
    if ($head -ne $upstream) {
        throw "Publishing requires HEAD to match its upstream branch."
    }
}

function Assert-PublishRequirements {
    param([Parameter(Mandatory = $true)][object[]]$Items)

    foreach ($item in $Items) {
        switch ($item.Target.Key) {
            "native" { Assert-GitHubAuthentication }
            "winforms" {
                if (-not $env:NUGET_API_KEY) {
                    throw "NUGET_API_KEY is required to publish NuGet packages."
                }
            }
            { $_ -in @("android", "swing") } { Assert-Command "gpg" }
        }
    }
}

function Invoke-PublishTarget {
    param(
        [Parameter(Mandatory = $true)]$Target,
        [Parameter(Mandatory = $true)][string]$Version
    )

    Write-Host "`nPublishing $($Target.Label) $Version" -ForegroundColor Yellow
    switch ($Target.Key) {
        "native" {
            $outputDir = Join-Path $ReleaseDir "native"
            $assets = @(Get-ChildItem -LiteralPath $outputDir -File | Select-Object -ExpandProperty FullName)
            if ($assets.Count -eq 0) {
                throw "No native release assets were found in $outputDir"
            }
            $notesPath = Join-Path $outputDir "release-notes-v$Version.md"
            $arguments = @("release", "create", "native-v$Version") + $assets + @("--repo", $Target.Repository, "--title", "SweetEditor Native v$Version", "--target", (git -C $ProjectDir rev-parse HEAD).Trim())
            if (Test-Path -LiteralPath $notesPath) {
                $arguments += @("--notes-file", $notesPath)
            } else {
                $arguments += "--generate-notes"
            }
            Invoke-External -FilePath "gh" -Arguments $arguments -WorkingDirectory $ProjectDir
        }
        "android" {
            Invoke-External -FilePath (Join-Path $Target.Path "gradlew.bat") -Arguments @(":sweeteditor:publishToCentralPortal", "--console=plain") -WorkingDirectory $Target.Path
        }
        "swing" {
            Invoke-External -FilePath (Join-Path $Target.Path "gradlew.bat") -Arguments @(":sweeteditor:publishToCentralPortal", "--console=plain") -WorkingDirectory $Target.Path
        }
        "winforms" {
            $packagePath = Join-Path $ReleaseDir "winforms\SweetEditor.$Version.nupkg"
            if (-not (Test-Path -LiteralPath $packagePath)) {
                throw "NuGet package was not found: $packagePath"
            }
            Invoke-External -FilePath "dotnet" -Arguments @("nuget", "push", $packagePath, "--api-key", $env:NUGET_API_KEY, "--source", "https://api.nuget.org/v3/index.json", "--skip-duplicate") -WorkingDirectory $ProjectDir -HideArguments
        }
        "flutter" {
            Invoke-External -FilePath "dart" -Arguments @("pub", "publish", "--force") -WorkingDirectory $Target.Path
        }
        "ohos" {
            $packagePath = Join-Path $ReleaseDir "ohos\sweeteditor-$Version.har"
            if (-not (Test-Path -LiteralPath $packagePath)) {
                throw "OHOS package was not found: $packagePath"
            }
            Invoke-External -FilePath "ohpm" -Arguments @("publish", $packagePath) -WorkingDirectory $Target.Path
        }
        default { throw "Unsupported publish target: $($Target.Key)" }
    }
}

function New-ReleaseState {
    param(
        [Parameter(Mandatory = $true)][string]$Mode,
        [Parameter(Mandatory = $true)][object[]]$Items
    )

    return [ordered]@{
        runId = [System.Guid]::NewGuid().ToString("N")
        mode = $Mode
        startedAt = [DateTimeOffset]::Now.ToString("o")
        entries = @($Items | ForEach-Object {
            [ordered]@{
                target = $_.Target.Key
                version = $_.Version
                status = "Planned"
                message = ""
                updatedAt = [DateTimeOffset]::Now.ToString("o")
            }
        })
    }
}

function Save-ReleaseState {
    param([Parameter(Mandatory = $true)]$State)

    Ensure-Directory $ReleaseDir
    $json = $State | ConvertTo-Json -Depth 6
    [System.IO.File]::WriteAllText($StatePath, $json, [System.Text.UTF8Encoding]::new($false))
}

function Set-ReleaseStateEntry {
    param(
        [Parameter(Mandatory = $true)]$State,
        [Parameter(Mandatory = $true)][string]$Target,
        [Parameter(Mandatory = $true)][string]$Status,
        [string]$Message = ""
    )

    $entry = @($State.entries | Where-Object { $_.target -eq $Target })[0]
    $entry.status = $Status
    $entry.message = $Message
    $entry.updatedAt = [DateTimeOffset]::Now.ToString("o")
    Save-ReleaseState $State
}

function Show-ReleasePlan {
    param(
        [Parameter(Mandatory = $true)][object[]]$Items,
        [hashtable]$Statuses = @{}
    )

    Write-Host "`nRelease plan" -ForegroundColor Cyan
    $Items | ForEach-Object {
        [pscustomobject]@{
            Target = $_.Target.Key
            Version = $_.Version
            Registry = $_.Target.Registry
            Status = $(if ($Statuses.ContainsKey($_.Target.Key)) { $Statuses[$_.Target.Key] } else { Get-RegistryStatus -Target $_.Target -Version $_.Version })
        }
    } | Format-Table -AutoSize
}

function Invoke-PackageItems {
    param([Parameter(Mandatory = $true)][object[]]$Items)

    if ($Items.Target.Key | Where-Object { $_ -in @("native", "swing", "winforms", "flutter") }) {
        Test-NativeAbi -TargetKeys @($Items.Target.Key)
    }

    $results = New-Object System.Collections.Generic.List[object]
    foreach ($item in $Items) {
        try {
            Invoke-PackageTarget -Target $item.Target -Version $item.Version
            $results.Add([pscustomobject]@{ Target = $item.Target.Key; Version = $item.Version; Status = "Succeeded"; Message = "" })
        } catch {
            $results.Add([pscustomobject]@{ Target = $item.Target.Key; Version = $item.Version; Status = "Failed"; Message = $_.Exception.Message })
        }
    }
    Write-Host "`nPackage summary" -ForegroundColor Cyan
    $results | Format-Table -AutoSize -Wrap
    if ($results.Status -contains "Failed") {
        throw "One or more packages failed validation."
    }
}

function Invoke-PublishItems {
    param(
        [Parameter(Mandatory = $true)][object[]]$Items,
        [string]$Mode = "publish"
    )

    $Items = @($Items | Sort-Object { [array]::IndexOf($TargetOrder, $_.Target.Key) })
    $pending = New-Object System.Collections.Generic.List[object]
    $statuses = @{}
    foreach ($item in $Items) {
        $status = Get-RegistryStatus -Target $item.Target -Version $item.Version
        $statuses[$item.Target.Key] = $status
        if ($status -eq "Published") {
            continue
        }
        if ($status -ne "Pending") {
            throw "Unable to safely publish $($item.Target.Key): $status"
        }
        $pending.Add($item)
    }

    Show-ReleasePlan -Items $Items -Statuses $statuses
    if ($pending.Count -eq 0) {
        Write-Host "All selected versions are already published." -ForegroundColor Green
        return
    }

    Assert-PublishWorkspace
    Assert-PublishRequirements -Items $pending
    $state = New-ReleaseState -Mode $Mode -Items $Items
    Save-ReleaseState $state
    foreach ($item in $Items) {
        if ($statuses[$item.Target.Key] -eq "Published") {
            Set-ReleaseStateEntry -State $state -Target $item.Target.Key -Status "Skipped" -Message "Version already exists."
        }
    }
    if ($pending.Target.Key | Where-Object { $_ -in @("native", "swing", "winforms", "flutter") }) {
        Test-NativeAbi -TargetKeys @($pending.Target.Key)
    }

    foreach ($item in $pending) {
        try {
            Invoke-PackageTarget -Target $item.Target -Version $item.Version
            Set-ReleaseStateEntry -State $state -Target $item.Target.Key -Status "PackageReady"
        } catch {
            Set-ReleaseStateEntry -State $state -Target $item.Target.Key -Status "Failed" -Message $_.Exception.Message
            throw "Packaging failed. Nothing has been published. $($_.Exception.Message)"
        }
    }

    foreach ($item in $pending) {
        try {
            Invoke-PublishTarget -Target $item.Target -Version $item.Version
            Set-ReleaseStateEntry -State $state -Target $item.Target.Key -Status "Published"
        } catch {
            Set-ReleaseStateEntry -State $state -Target $item.Target.Key -Status "Failed" -Message $_.Exception.Message
            throw "Publishing stopped at $($item.Target.Key). Use the resume action after resolving the problem."
        }
    }

    Write-Host "`nPublish summary" -ForegroundColor Cyan
    $state.entries | Format-Table target, version, status, message -AutoSize -Wrap
}

function Invoke-ResumeRelease {
    if (-not (Test-Path -LiteralPath $StatePath)) {
        throw "No release state was found: $StatePath"
    }
    $state = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
    $retryEntries = @($state.entries | Where-Object { $_.status -in @("Failed", "PackageReady", "Planned") })
    if ($retryEntries.Count -eq 0) {
        Write-Host "The previous release has no unfinished targets." -ForegroundColor Green
        return
    }

    $items = foreach ($entry in $retryEntries) {
        $target = Get-TargetDefinition $entry.target
        $currentVersion = if ($VersionOverrides.ContainsKey($target.Key)) { $VersionOverrides[$target.Key] } else { $target.Version }
        if ($target.Key -eq "native") {
            $currentVersion = $entry.version
        }
        if ($currentVersion -ne $entry.version) {
            throw "$($target.Key) changed from $($entry.version) to $currentVersion after the failed release."
        }
        [pscustomobject]@{ Target = $target; Version = [string]$entry.version }
    }
    Invoke-PublishItems -Items @($items) -Mode "resume"
}

function Read-SingleTargetSelection {
    param(
        [string[]]$AllowedTargets = $TargetOrder,
        [string]$Prompt = "Select a target"
    )

    $definitions = @(Get-TargetDefinitions | Where-Object { $_.Key -in $AllowedTargets })
    Write-Host ""
    for ($index = 0; $index -lt $definitions.Count; $index++) {
        $target = $definitions[$index]
        $version = if ($VersionOverrides.ContainsKey($target.Key)) { $VersionOverrides[$target.Key] } else { $target.Version }
        Write-Host ("{0,2}. {1,-28} {2}" -f ($index + 1), $target.Label, $(if ($version) { $version } else { "Enter during release" }))
    }
    Write-Host " 0. Cancel"
    $selection = (Read-Host $Prompt).Trim()
    if ($selection -eq "0" -or -not $selection) {
        return $null
    }

    $number = 0
    if (-not [int]::TryParse($selection, [ref]$number) -or $number -lt 1 -or $number -gt $definitions.Count) {
        throw "Invalid target selection: $selection"
    }
    return $definitions[$number - 1].Key
}

function Read-TargetSelection {
    $definitions = Get-TargetDefinitions
    Write-Host ""
    for ($index = 0; $index -lt $definitions.Count; $index++) {
        $target = $definitions[$index]
        $version = if ($VersionOverrides.ContainsKey($target.Key)) { $VersionOverrides[$target.Key] } else { $target.Version }
        Write-Host ("{0,2}. {1,-28} {2}" -f ($index + 1), $target.Label, $(if ($version) { $version } else { "Enter during release" }))
    }
    Write-Host " 0. Cancel"
    $selection = (Read-Host "Select targets, separated by commas, or enter all").Trim()
    if ($selection -eq "0" -or -not $selection) {
        return @()
    }
    if ($selection -ieq "all") {
        return @($definitions.Key)
    }

    $selected = New-Object System.Collections.Generic.List[string]
    foreach ($part in $selection.Split(',')) {
        $number = 0
        if (-not [int]::TryParse($part.Trim(), [ref]$number) -or $number -lt 1 -or $number -gt $definitions.Count) {
            throw "Invalid target selection: $part"
        }
        $key = $definitions[$number - 1].Key
        if (-not $selected.Contains($key)) {
            $selected.Add($key)
        }
    }
    return @($selected)
}

function Show-MainMenu {
    while ($true) {
        Write-Host "`nSweetEditor release tool" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "1. Show target status"
        Write-Host "2. Update target version"
        Write-Host "3. Validate and package"
        Write-Host "4. Publish selected targets"
        Write-Host "5. Resume the previous release"
        Write-Host "0. Exit"
        $choice = (Read-Host "Select an action").Trim()

        try {
            switch ($choice) {
                "1" {
                    $selected = Read-SingleTargetSelection -Prompt "Select the target to inspect"
                    if ($selected) {
                        Show-ReleaseStatus -TargetKey $selected | Out-Null
                    }
                }
                "2" {
                    $editableTargets = @("android", "swing", "winforms", "flutter", "ohos")
                    $selected = Read-SingleTargetSelection -AllowedTargets $editableTargets -Prompt "Select the target to update"
                    if ($selected) {
                        $target = Get-TargetDefinition $selected
                        $newVersion = (Read-Host "Current version is $($target.Version). Enter the new version").Trim()
                        if ($newVersion) {
                            Set-PlatformVersion -TargetKey $selected -NewVersion $newVersion
                        }
                    }
                }
                "3" {
                    $selected = @(Read-TargetSelection)
                    if ($selected.Count -gt 0) {
                        $items = Resolve-ReleaseItems -SelectedTargets $selected -AllowPrompt
                        Invoke-PackageItems -Items $items
                    }
                }
                "4" {
                    $selected = @(Read-TargetSelection)
                    if ($selected.Count -gt 0) {
                        $items = Resolve-ReleaseItems -SelectedTargets $selected -AllowPrompt
                        Invoke-PublishItems -Items $items
                    }
                }
                "5" { Invoke-ResumeRelease }
                "0" { return }
                default { Write-Warning "Invalid selection." }
            }
        } catch {
            Write-Host "`n$($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

function Invoke-RequestedAction {
    switch ($Action) {
        "menu" { Show-MainMenu }
        "status" {
            if ($Targets.Count -ne 1) {
                throw "The status action requires exactly one target."
            }
            Show-ReleaseStatus -TargetKey $Targets[0] | Out-Null
        }
        "package" {
            $selected = if ($Targets.Count -gt 0) { $Targets } else { $TargetOrder }
            Invoke-PackageItems -Items (Resolve-ReleaseItems -SelectedTargets $selected)
        }
        "publish" {
            if ($Targets.Count -eq 0) {
                throw "The publish action requires -Targets."
            }
            Invoke-PublishItems -Items (Resolve-ReleaseItems -SelectedTargets $Targets)
        }
        "resume" { Invoke-ResumeRelease }
    }
}

Invoke-RequestedAction
