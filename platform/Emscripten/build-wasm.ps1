param(
  [string]$BuildType = "Release",
  [string]$BuildDir = "build/wasm"
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "../..")
$buildPath = Join-Path $repoRoot $BuildDir

if (-not $env:EMSDK_PYTHON) {
  $candidate = Join-Path $env:USERPROFILE "emsdk/python/3.13.3_64bit/python.exe"
  if (Test-Path $candidate) {
    $env:EMSDK_PYTHON = $candidate
  }
}

$emcmake = Get-Command emcmake.bat -ErrorAction SilentlyContinue
if (-not $emcmake) {
  $emcmake = Get-Command emcmake -ErrorAction SilentlyContinue
}
if (-not $emcmake) {
  throw "emcmake not found. Please ensure emsdk is activated."
}

cmake -E make_directory $buildPath
if ($LASTEXITCODE -ne 0) {
  throw "Failed to create build directory: $buildPath"
}

& $emcmake.Source cmake -S $repoRoot -B $buildPath -G Ninja "-DCMAKE_BUILD_TYPE=$BuildType"
if ($LASTEXITCODE -ne 0) {
  throw "CMake configure failed for wasm build (BuildType=$BuildType)."
}

cmake --build $buildPath
if ($LASTEXITCODE -ne 0) {
  throw "CMake build failed for wasm target."
}

$wasmJs = Join-Path $buildPath "bin/sweeteditor.js"
$wasmWasm = Join-Path $buildPath "bin/sweeteditor.wasm"
$webDir = Join-Path $repoRoot "platform/Emscripten/web"

if (-not (Test-Path $wasmJs)) {
  throw "Wasm JS output not found: $wasmJs"
}
if (-not (Test-Path $wasmWasm)) {
  throw "Wasm binary output not found: $wasmWasm"
}

Copy-Item -Force $wasmJs (Join-Path $webDir "sweeteditor.js")
Copy-Item -Force $wasmWasm (Join-Path $webDir "sweeteditor.wasm")

Write-Host "Wasm build done: $wasmJs"
Write-Host "Synced wasm artifacts to web directory, ready to package: $webDir"
