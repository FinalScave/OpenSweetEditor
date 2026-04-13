# Building .NET Android in Termux (Environment & Toolchain)

Last Updated: 2026-04-01
Target Environment: Termux (aarch64, Android)

## 0. Verified Environment

The following versions are from the current Termux environment (as baseline):

```bash
dotnet --info
# .NET SDK 9.0.115
# Workload: android (35.0.105)

java -version
# openjdk version "21.0.10"

adb version
# Android Debug Bridge 1.0.41 (35.0.2)
```

Verified paths:

```bash
DOTNET_ROOT=/data/data/com.termux/files/usr/lib/dotnet
JAVA_HOME=/data/data/com.termux/files/usr/lib/jvm/java-21-openjdk/
ANDROID_SDK_ROOT=/data/data/com.termux/files/home/android-sdk
AAPT2=/data/data/com.termux/files/usr/bin/aapt2
ZIPALIGN=/data/data/com.termux/files/usr/bin/zipalign
APKSIGNER=/data/data/com.termux/files/usr/bin/apksigner
ADB=/data/data/com.termux/files/usr/bin/adb
```

## 1. Basic Environment Setup

Update repositories and install basic tools:

```bash
pkg update && pkg upgrade -y
pkg install -y git curl wget unzip clang cmake ninja make
pkg install -y android-tools aapt aapt2 apksigner
pkg install -y openjdk-21
pkg install -y dotnet9.0 dotnet-sdk-9.0
```

Optional check:

```bash
which dotnet java adb aapt2 zipalign apksigner
```

## 2. Android SDK Installation & Configuration

If you don't have an SDK directory:

```bash
mkdir -p $HOME/android-sdk
```

Download Android Command-line Tools (check official page for latest link):

```bash
cd $HOME
wget -O cmdline-tools.zip "https://dl.google.com/android/repository/commandlinetools-linux-<VERSION>_latest.zip"
mkdir -p android-sdk/cmdline-tools
unzip -q cmdline-tools.zip -d android-sdk/cmdline-tools
mv android-sdk/cmdline-tools/cmdline-tools android-sdk/cmdline-tools/latest
```

Configure environment variables (add to `~/.bashrc` or `~/.zshrc`):

```bash
export ANDROID_SDK_ROOT=$HOME/android-sdk
export ANDROID_HOME=$ANDROID_SDK_ROOT
export JAVA_HOME=$PREFIX/lib/jvm/java-21-openjdk
export DOTNET_ROOT=$PREFIX/lib/dotnet
export PATH=$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH
```

Apply immediately:

```bash
source ~/.bashrc 2>/dev/null || true
source ~/.zshrc 2>/dev/null || true
```

Install SDK components and accept license:

```bash
yes | sdkmanager --sdk_root=$ANDROID_SDK_ROOT --licenses
sdkmanager --sdk_root=$ANDROID_SDK_ROOT \
  "platform-tools" \
  "platforms;android-34" \
  "build-tools;34.0.0"
```

Note: Termux aapt2 may not support android-35

## 3. Install .NET Android Workload

```bash
dotnet workload install android
dotnet workload list
```

If workload doesn't show android, download official workload manifest and inject manually.

If workload is corrupted, repair:

```bash
dotnet workload repair
```

## 4. Build Commands (Termux Stable Template)

The following commands are stable in Termux. Key points: explicitly specify SDK path and aapt2/zipalign tool paths.

```bash
dotnet build <YOUR_ANDROID_CSPROJ> \
  -c Debug \
  -f net8.0-android \
  -m:1 \
  -p:RuntimeIdentifier=android-arm64 \
  -p:AndroidSdkDirectory=$HOME/android-sdk \
  -p:Aapt2ToolPath=$PREFIX/bin \
  -p:Aapt2ToolExe=aapt2 \
  -p:AndroidBinUtilsDirectory=$PREFIX/bin \
  -p:ZipAlignToolPath=$PREFIX/bin \
  -p:ZipalignToolExe=zipalign \
  -p:RunAOTCompilation=false \
  -p:PublishAot=false \
  -p:AndroidEnableProfiledAot=false \
  -p:AndroidEnableLLVM=false \
  -p:UseInterpreter=true
```

Notes:

- `-m:1`: Reduce parallelism to lower Termux memory pressure
- `UseInterpreter=true`: More stable debug builds, faster compilation
- Explicit `Aapt2ToolPath/ZipAlignToolPath` avoids tool detection failures
- Don't omit `RunAOTCompilation=false` / `PublishAot=false`, otherwise `Release` may trigger `Microsoft.NET.Runtime.MonoAOTCompiler.Task` resolution failure
- Don't rely on implicit SDK path detection; without `AndroidSdkDirectory`, you'll get `XA5300` error

## 5. APK Installation & Debug

Connect device (wireless debugging supported):

```bash
adb devices -l
```

Install APK:

```bash
adb install -r <APK_PATH>
```

Find launch Activity:

```bash
adb shell cmd package resolve-activity --brief <PACKAGE_NAME>
```

Launch app:

```bash
adb shell am start -n <PACKAGE_NAME>/<ACTIVITY_NAME>
```

Check foreground focus:

```bash
adb shell dumpsys activity activities | rg "topResumedActivity|mCurrentFocus|<PACKAGE_NAME>"
```

## 6. Common Issues & Solutions

### 6.1 `Error type 3: Activity class does not exist`

Cause: Wrong Activity name (common with .NET Android generated class names).

Solution:

```bash
adb shell cmd package resolve-activity --brief <PACKAGE_NAME>
```

Use the returned value as the real entry point.

### 6.2 `aapt2` / `zipalign` not found

Symptom: MSBuild can't find packaging tools.

Solution:

- Confirm installation: `pkg install aapt aapt2 apksigner`
- Pass explicit parameters:
  - `-p:Aapt2ToolPath=$PREFIX/bin -p:Aapt2ToolExe=aapt2`
  - `-p:ZipAlignToolPath=$PREFIX/bin -p:ZipalignToolExe=zipalign`

### 6.3 SDK license not accepted

Symptom: Android build reports license error.

Solution:

```bash
yes | sdkmanager --sdk_root=$ANDROID_SDK_ROOT --licenses
```

### 6.4 `adb unauthorized` or no device

Solution:

```bash
adb kill-server
adb start-server
adb devices -l
```

Confirm USB debugging authorization popup on device.

### 6.5 `Could not extract the MVID ... refint/*.dll`

This appears frequently but doesn't block builds; check for `Build succeeded`.

### 6.6 CA1416 Warning (Android API Version)

Usually a warning, not an error. Handle with API level checks or `SupportedOSPlatform` attributes before release.

### 6.7 `Could not resolve SDK "Microsoft.NET.Runtime.MonoAOTCompiler.Task"`

Symptom:

- `dotnet build -c Release` reports `MSB4236` / `Could not resolve SDK "Microsoft.NET.Runtime.MonoAOTCompiler.Task"`

Common triggers:

- Only passing `-c Release` without explicit `RunAOTCompilation=false`
- Not providing `AndroidSdkDirectory`, which then triggers `XA5300`

Recommended fix:

```bash
dotnet workload list
dotnet workload repair

dotnet build <YOUR_ANDROID_CSPROJ> \
  -c Release \
  -f net8.0-android \
  -m:1 \
  -p:RuntimeIdentifier=android-arm64 \
  -p:AndroidSdkDirectory=$HOME/android-sdk \
  -p:Aapt2ToolPath=$PREFIX/bin \
  -p:Aapt2ToolExe=aapt2 \
  -p:AndroidBinUtilsDirectory=$PREFIX/bin \
  -p:ZipAlignToolPath=$PREFIX/bin \
  -p:ZipalignToolExe=zipalign \
  -p:RunAOTCompilation=false \
  -p:PublishAot=false \
  -p:AndroidEnableProfiledAot=false \
  -p:AndroidEnableLLVM=false \
  -p:UseInterpreter=true
```

## 7. Reusable Script Variables

Set before each build to reduce command length and typos:

```bash
export ANDROID_SDK_ROOT=$HOME/android-sdk
export ANDROID_HOME=$ANDROID_SDK_ROOT
export JAVA_HOME=$PREFIX/lib/jvm/java-21-openjdk
export DOTNET_ROOT=$PREFIX/lib/dotnet
export PATH=$ANDROID_SDK_ROOT/platform-tools:$PATH
```

## 8. Termux Notes

- Termux ADB automation on the same phone may have unstable foreground focus and input simulation
- UI gesture issues should be manually tested; ADB is for install, launch, and log capture
- Large projects should use `-m:1` to avoid memory thrashing from parallel compilation

## 9. Quick Checklist

```bash
dotnet --info
java -version
adb version
aapt2 version
ls $HOME/android-sdk/platforms
ls $HOME/android-sdk/build-tools
dotnet workload list
adb devices -l
```

If all above are normal, `.NET Android` build chain in Termux should be functional.
