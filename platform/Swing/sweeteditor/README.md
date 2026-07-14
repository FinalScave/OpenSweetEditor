# SweetEditor for Swing

SweetEditor for Swing is a Java2D code editor component that calls the shared SweetEditor C API through Java 22 FFM.

## Installation

Consume the Gradle project directly from the source tree:

```gradle
dependencies {
    implementation(project(":sweeteditor"))
}
```

For local JAR integration, build `:sweeteditor:jar`, add `sweeteditor-1.0.0-rc1.jar` from `sweeteditor/build/libs`, and declare Gson 2.11.0 in the consuming project. The generated JAR includes native resources for the supported desktop targets.

## Requirements

- JDK 22
- `--enable-native-access=ALL-UNNAMED` at runtime
- Preview features enabled for the current repository build

## Features

- Java2D rendering and Swing input integration
- Native editing, layout, selection, folding, scrolling, and search
- Completion, decorations, inlay hints, phantom text, diagnostics, and providers
- Native libraries bundled as JAR resources for supported desktop targets

## Quick Start

```java
import com.qiplat.sweeteditor.EditorTheme;
import com.qiplat.sweeteditor.SweetEditor;
import com.qiplat.sweeteditor.core.Document;

import javax.swing.JFrame;
import javax.swing.SwingUtilities;

SwingUtilities.invokeLater(() -> {
    JFrame frame = new JFrame("SweetEditor");
    SweetEditor editor = new SweetEditor(EditorTheme.dark());
    editor.loadDocument(new Document("Hello, SweetEditor!"));
    frame.setContentPane(editor);
    frame.setSize(1000, 700);
    frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
    frame.setVisible(true);
});
```

## Native Loading

Native loading first checks the directory set by `-Dsweeteditor.lib.path`, then extracts a matching bundled JAR resource to `~/.sweeteditor/native`, and finally falls back to `java.library.path` through `System.loadLibrary`.

```text
-Dsweeteditor.lib.path=/path/to/native/library/directory
```

## Build and Run

```powershell
cd platform/Swing
.\gradlew.bat :sweeteditor:build
.\gradlew.bat :demo:run
```

## Links

- [Swing API reference](https://github.com/FinalScave/SweetEditor/blob/main/docs/en/api-platform-swing.md)
- [Changelog](CHANGELOG.md)
- [Repository](https://github.com/FinalScave/SweetEditor)
- [MIT License](../../../LICENSE)
