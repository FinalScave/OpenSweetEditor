param(
    [Parameter(Mandatory = $true)]
    [Alias("v")]
    [string]$Version,

    [string]$PrebuiltSourceDir = "",
    [string]$HeadersSourceDir = "",

    [Alias("o")]
    [string]$OutputDir = "",

    [string]$PrebuiltNamePrefix = "sweeteditor-prebuilt",
    [string]$HeadersNamePrefix = "sweeteditor-headers",

    [ValidateSet("android", "ios", "linux", "ohos", "osx", "wasm", "windows")]
    [string[]]$Platform = @(),

    [string]$Commit = "",

    [switch]$SkipPrebuilt,
    [switch]$SkipHeaders,
    [string]$ReleaseNotesTemplate = "",
    [switch]$SkipReleaseNotes,
    [switch]$NoPrebuiltReadme,
    [switch]$NoChecksums,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = [System.IO.Path]::GetFullPath((Join-Path $ScriptDir ".."))
$ResolvedPrebuiltSourceDir = if ($PrebuiltSourceDir) {
    [System.IO.Path]::GetFullPath($PrebuiltSourceDir)
} else {
    Join-Path $ProjectDir "prebuilt"
}
$ResolvedHeadersSourceDir = if ($HeadersSourceDir) {
    [System.IO.Path]::GetFullPath($HeadersSourceDir)
} else {
    Join-Path (Join-Path $ProjectDir "src") "include"
}
$ResolvedReleaseNotesTemplate = if ($ReleaseNotesTemplate) {
    [System.IO.Path]::GetFullPath($ReleaseNotesTemplate)
} else {
    Join-Path $ScriptDir "RELEASE_NOTES.md"
}
$ResolvedOutputDir = if ($OutputDir) {
    [System.IO.Path]::GetFullPath($OutputDir)
} else {
    Join-Path (Join-Path $ProjectDir "build") "artifacts"
}

function Ensure-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Remove-PathIfExists {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
}

function Get-RelativePathNormalized {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$TargetPath
    )

    $baseFullPath = [System.IO.Path]::GetFullPath($BasePath).TrimEnd('\', '/')
    $targetFullPath = [System.IO.Path]::GetFullPath($TargetPath)

    $basePathWithSeparator = if ($baseFullPath.EndsWith('\') -or $baseFullPath.EndsWith('/')) {
        $baseFullPath
    } else {
        $baseFullPath + [System.IO.Path]::DirectorySeparatorChar
    }
    $baseUri = [System.Uri]$basePathWithSeparator
    $targetUri = [System.Uri]$targetFullPath
    $relativeUri = $baseUri.MakeRelativeUri($targetUri)
    return [System.Uri]::UnescapeDataString($relativeUri.ToString()) -replace '\\', '/'
}

function Copy-DirectoryContents {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    Ensure-Directory -Path $Destination
    Get-ChildItem -LiteralPath $Source -Force |
        Where-Object { $_.Name -ne ".gitkeep" } |
        ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination $Destination -Recurse -Force
        }
}

function Get-PlatformDirectories {
    param(
        [Parameter(Mandatory = $true)][string]$RootDir,
        [AllowEmptyCollection()][string[]]$RequestedPlatforms = @()
    )

    $existing = Get-ChildItem -LiteralPath $RootDir -Directory | Select-Object -ExpandProperty Name
    if ($RequestedPlatforms.Count -eq 0) {
        return $existing | Sort-Object
    }

    $missing = @($RequestedPlatforms | Where-Object { $_ -notin $existing })
    if ($missing.Count -gt 0) {
        throw "Requested platform directories are missing under ${RootDir}: $($missing -join ', ')"
    }

    return $RequestedPlatforms
}

function Write-PrebuiltReadmeFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$VersionText,
        [Parameter(Mandatory = $true)][string[]]$Platforms,
        [string]$CommitText = ""
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("OpenSweetEditor Prebuilt Package")
    $lines.Add("================================")
    $lines.Add("")
    $lines.Add("Version: $VersionText")
    if ($CommitText) {
        $lines.Add("Commit: $CommitText")
    }
    $lines.Add("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')")
    $lines.Add("")
    $lines.Add("Included platform directories:")
    foreach ($platformName in $Platforms) {
        $lines.Add("- $platformName")
    }
    $lines.Add("")
    $lines.Add("The zip keeps each platform directory at the archive root.")
    $lines.Add("For example:")
    $lines.Add("- windows/x64/sweeteditor.dll")
    $lines.Add("- wasm/libsweeteditor.js")
    $lines.Add("- android/arm64-v8a/libsweeteditor.so")
    $lines.Add("- ios/SweetEditorCoreIOS.xcframework.zip")
    $lines.Add("- osx/SweetEditorCoreOSX.xcframework.zip")

    [System.IO.File]::WriteAllLines($Path, $lines, [System.Text.UTF8Encoding]::new($false))
}

function Write-ChecksumsFile {
    param([Parameter(Mandatory = $true)][string]$StageDir)

    $checksumPath = Join-Path $StageDir "SHA256SUMS.txt"
    $lines = New-Object System.Collections.Generic.List[string]

    $files = Get-ChildItem -LiteralPath $StageDir -Recurse -File |
        Where-Object { $_.Name -notin @("SHA256SUMS.txt") } |
        Sort-Object FullName

    foreach ($file in $files) {
        $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        $relativePath = Get-RelativePathNormalized -BasePath $StageDir -TargetPath $file.FullName
        $lines.Add("$hash  $relativePath")
    }

    [System.IO.File]::WriteAllLines($checksumPath, $lines, [System.Text.UTF8Encoding]::new($false))
}

function New-ZipFromDirectoryContents {
    param(
        [Parameter(Mandatory = $true)][string]$SourceDir,
        [Parameter(Mandatory = $true)][string]$ZipPath
    )

    if (Test-Path -LiteralPath $ZipPath) {
        Remove-Item -LiteralPath $ZipPath -Force
    }

    $zip = [System.IO.Compression.ZipFile]::Open($ZipPath, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        $sourceFullPath = [System.IO.Path]::GetFullPath($SourceDir)

        Get-ChildItem -LiteralPath $sourceFullPath -Recurse -File | ForEach-Object {
            $relativePath = Get-RelativePathNormalized -BasePath $sourceFullPath -TargetPath $_.FullName
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $zip,
                $_.FullName,
                $relativePath,
                [System.IO.Compression.CompressionLevel]::Optimal
            ) | Out-Null
        }
    } finally {
        $zip.Dispose()
    }
}

function Get-ResolvedCommit {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [string]$OverrideCommit = ""
    )

    if ($OverrideCommit) {
        return $OverrideCommit
    }

    try {
        return (git -C $ProjectRoot rev-parse HEAD).Trim()
    } catch {
        return ""
    }
}

function Write-ReleaseNotesFile {
    param(
        [Parameter(Mandatory = $true)][string]$TemplatePath,
        [Parameter(Mandatory = $true)][string]$OutputDir,
        [Parameter(Mandatory = $true)][string]$VersionText,
        [Parameter(Mandatory = $true)][string]$PrebuiltAssetName,
        [Parameter(Mandatory = $true)][string]$HeadersAssetName,
        [string]$CommitText = ""
    )

    if (-not (Test-Path -LiteralPath $TemplatePath)) {
        throw "Release notes template does not exist: $TemplatePath"
    }

    $content = [System.IO.File]::ReadAllText($TemplatePath, [System.Text.Encoding]::UTF8)
    $replacements = @{
        "{{VERSION}}" = $VersionText
        "{{COMMIT}}" = $CommitText
        "{{PREBUILT_ASSET_NAME}}" = $PrebuiltAssetName
        "{{HEADERS_ASSET_NAME}}" = $HeadersAssetName
    }

    foreach ($entry in $replacements.GetEnumerator()) {
        $content = $content.Replace($entry.Key, $entry.Value)
    }

    $outputPath = Join-Path $OutputDir "release-notes-v$VersionText.md"
    [System.IO.File]::WriteAllText($outputPath, $content, [System.Text.UTF8Encoding]::new($false))
    Write-Host "Created release notes: $outputPath"
}

function Package-PrebuiltArtifacts {
    param(
        [Parameter(Mandatory = $true)][string]$SourceDir,
        [Parameter(Mandatory = $true)][string]$OutputDir,
        [Parameter(Mandatory = $true)][string]$VersionText,
        [Parameter(Mandatory = $true)][string]$ArchivePrefix,
        [Parameter(Mandatory = $true)][string[]]$Platforms,
        [string]$CommitText = "",
        [switch]$IncludeReadme,
        [switch]$IncludeChecksums,
        [switch]$Overwrite
    )

    if (-not (Test-Path -LiteralPath $SourceDir)) {
        throw "Prebuilt source directory does not exist: $SourceDir"
    }

    $archiveName = "$ArchivePrefix-v$VersionText.zip"
    $archivePath = Join-Path $OutputDir $archiveName
    if ((Test-Path -LiteralPath $archivePath) -and -not $Overwrite) {
        throw "Archive already exists: $archivePath. Use -Force to overwrite it."
    }

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sweeteditor-prebuilt-" + [System.Guid]::NewGuid().ToString("N"))
    $stageDir = Join-Path $tempRoot "stage"
    Ensure-Directory -Path $stageDir

    try {
        foreach ($platformName in $Platforms) {
            $sourcePlatformDir = Join-Path $SourceDir $platformName
            $stagePlatformDir = Join-Path $stageDir $platformName
            Copy-DirectoryContents -Source $sourcePlatformDir -Destination $stagePlatformDir
        }

        if ($IncludeReadme) {
            Write-PrebuiltReadmeFile -Path (Join-Path $stageDir "README.txt") -VersionText $VersionText -Platforms $Platforms -CommitText $CommitText
        }

        if ($IncludeChecksums) {
            Write-ChecksumsFile -StageDir $stageDir
        }

        New-ZipFromDirectoryContents -SourceDir $stageDir -ZipPath $archivePath
        Write-Host "Created prebuilt archive: $archivePath"
    } finally {
        Remove-PathIfExists -Path $tempRoot
    }
}

function Package-HeadersArtifacts {
    param(
        [Parameter(Mandatory = $true)][string]$SourceDir,
        [Parameter(Mandatory = $true)][string]$OutputDir,
        [Parameter(Mandatory = $true)][string]$VersionText,
        [Parameter(Mandatory = $true)][string]$ArchivePrefix,
        [switch]$IncludeChecksums,
        [switch]$Overwrite
    )

    if (-not (Test-Path -LiteralPath $SourceDir)) {
        throw "Headers source directory does not exist: $SourceDir"
    }

    $headerFiles = Get-ChildItem -LiteralPath $SourceDir -Recurse -File |
        Where-Object { $_.Extension -in @(".h", ".hpp") }
    if ($headerFiles.Count -eq 0) {
        throw "No header files were found under $SourceDir"
    }

    $archiveName = "$ArchivePrefix-v$VersionText.zip"
    $archivePath = Join-Path $OutputDir $archiveName
    if ((Test-Path -LiteralPath $archivePath) -and -not $Overwrite) {
        throw "Archive already exists: $archivePath. Use -Force to overwrite it."
    }

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sweeteditor-headers-" + [System.Guid]::NewGuid().ToString("N"))
    $stageDir = Join-Path $tempRoot "stage"
    $stageIncludeDir = Join-Path (Join-Path $stageDir "include") "sweeteditor"
    Ensure-Directory -Path $stageIncludeDir

    try {
        foreach ($file in $headerFiles) {
            $relativePath = Get-RelativePathNormalized -BasePath $SourceDir -TargetPath $file.FullName
            $destinationPath = Join-Path $stageIncludeDir $relativePath
            $destinationDir = Split-Path -Parent $destinationPath
            Ensure-Directory -Path $destinationDir
            Copy-Item -LiteralPath $file.FullName -Destination $destinationPath -Force
        }

        if ($IncludeChecksums) {
            Write-ChecksumsFile -StageDir $stageDir
        }

        New-ZipFromDirectoryContents -SourceDir $stageDir -ZipPath $archivePath
        Write-Host "Created headers archive: $archivePath"
    } finally {
        Remove-PathIfExists -Path $tempRoot
    }
}

if ($SkipPrebuilt -and $SkipHeaders) {
    throw "Nothing to package. Remove -SkipPrebuilt or -SkipHeaders."
}

Ensure-Directory -Path $ResolvedOutputDir
$resolvedCommit = Get-ResolvedCommit -ProjectRoot $ProjectDir -OverrideCommit $Commit
$prebuiltArchiveName = "$PrebuiltNamePrefix-v$Version.zip"
$headersArchiveName = "$HeadersNamePrefix-v$Version.zip"

if (-not $SkipPrebuilt) {
    $selectedPlatforms = @(Get-PlatformDirectories -RootDir $ResolvedPrebuiltSourceDir -RequestedPlatforms $Platform)
    if ($selectedPlatforms.Count -eq 0) {
        throw "No platform directories were found under $ResolvedPrebuiltSourceDir"
    }

    Package-PrebuiltArtifacts `
        -SourceDir $ResolvedPrebuiltSourceDir `
        -OutputDir $ResolvedOutputDir `
        -VersionText $Version `
        -ArchivePrefix $PrebuiltNamePrefix `
        -Platforms $selectedPlatforms `
        -CommitText $resolvedCommit `
        -IncludeReadme:(-not $NoPrebuiltReadme) `
        -IncludeChecksums:(-not $NoChecksums) `
        -Overwrite:$Force
}

if (-not $SkipHeaders) {
    Package-HeadersArtifacts `
        -SourceDir $ResolvedHeadersSourceDir `
        -OutputDir $ResolvedOutputDir `
        -VersionText $Version `
        -ArchivePrefix $HeadersNamePrefix `
        -IncludeChecksums:(-not $NoChecksums) `
        -Overwrite:$Force
}

if (-not $SkipReleaseNotes) {
    Write-ReleaseNotesFile `
        -TemplatePath $ResolvedReleaseNotesTemplate `
        -OutputDir $ResolvedOutputDir `
        -VersionText $Version `
        -PrebuiltAssetName $prebuiltArchiveName `
        -HeadersAssetName $headersArchiveName `
        -CommitText $resolvedCommit
}
