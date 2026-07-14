# SweetEditor for Android

SweetEditor for Android provides a native Android code editor view backed by the shared SweetEditor C++ core and a Java/JNI bridge.

## Installation

```gradle
repositories {
    mavenCentral()
    google()
}

dependencies {
    implementation("com.qiplat:sweeteditor:1.0.0-rc1")
}
```

## Requirements

- Android API 21 or newer
- `compileSdk 34`
- NDK `28.2.13676358` when building from source
- `arm64-v8a` or `x86_64`

## Features

- Native text editing, layout, selection, scrolling, folding, and undo/redo
- Syntax and semantic spans, diagnostics, inlay hints, phantom text, and gutter icons
- Completion, snippets, linked editing, search/replace, and provider extensions
- Android IME, clipboard, gestures, selection handles, and popup integration
- Runtime settings for wrapping, whitespace, line breaks, gutter behavior, and read-only mode

## Quick Start

Add the editor to a layout:

```xml
<com.qiplat.sweeteditor.SweetEditor
    android:id="@+id/editor"
    android:layout_width="match_parent"
    android:layout_height="match_parent" />
```

Initialize it from Java:

```java
import com.qiplat.sweeteditor.EditorTheme;
import com.qiplat.sweeteditor.SweetEditor;
import com.qiplat.sweeteditor.core.Document;

SweetEditor editor = findViewById(R.id.editor);
editor.applyTheme(EditorTheme.dark());
editor.loadDocument(new Document("Hello, SweetEditor!"));
```

Creating `SweetEditor` initializes `EditorCore`, which loads the native library automatically. The standalone `Document` constructors call JNI directly and do not load the library themselves; if a `Document` is created before any `SweetEditor` or `EditorCore` instance, call `System.loadLibrary("sweeteditor")` first.

## Build and Demo

```powershell
cd platform/Android
.\gradlew.bat :sweeteditor:assembleRelease
.\gradlew.bat :app:assembleDebug
```

The Gradle library build includes the JNI bridge. The repository release scripts build separate no-JNI native libraries for cross-platform FFI consumers.

## Links

- [Android API reference](https://github.com/FinalScave/SweetEditor/blob/main/docs/en/api-platform-android.md)
- [Changelog](CHANGELOG.md)
- [Repository](https://github.com/FinalScave/SweetEditor)
- [MIT License](../../../LICENSE)
