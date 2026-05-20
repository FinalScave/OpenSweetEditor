# Swing Platform API

This document maps to the current Swing implementation:

- Control layer: `platform/Swing/sweeteditor/src/main/java/com/qiplat/sweeteditor/SweetEditor.java`
- Bridge layer: `platform/Swing/sweeteditor/src/main/java/com/qiplat/sweeteditor/core/EditorCore.java`
- FFM layer: `platform/Swing/sweeteditor/src/main/java/com/qiplat/sweeteditor/core/EditorNative.java`
- Document object: `platform/Swing/sweeteditor/src/main/java/com/qiplat/sweeteditor/core/Document.java`

## Architecture Notes

- Swing calls C API through Java FFM.
- `EditorCore` handles upcall measure callbacks and binary payload decoding.
- The current bridge protocol is binary payload.
- `SweetEditor` provides semantic control APIs (enums) and handles Swing input events.

## Quick Start

### Environment Requirements (current repo configuration)

- JDK: `22`
- Gradle Wrapper: `8.10`
- Runtime JVM flag: `--enable-native-access=ALL-UNNAMED`
- The current demo setup enables `--enable-preview` for both compile and run

### Run the Demo in this repository

```bash
cd platform/Swing
./gradlew :demo:run
```

On Windows PowerShell:

```powershell
cd platform/Swing
.\gradlew.bat :demo:run
```

### Integrate into an existing Java Swing project

Recommended: use the Maven Central artifact:

```gradle
repositories {
    mavenCentral()
}

dependencies {
    implementation("com.qiplat:sweeteditor-swing:0.0.1")
}
```

For Maven (`pom.xml`):

```xml
<dependency>
    <groupId>com.qiplat</groupId>
    <artifactId>sweeteditor-swing</artifactId>
    <version>0.0.1</version>
    <scope>compile</scope>
</dependency>
```
> The repository module version is `0.0.1`. If you integrate from Maven Central, replace it with the release version you actually want to consume.

Required JVM flag:

```text
--enable-native-access=ALL-UNNAMED
```

If you use local source-module integration (for local debugging):

```gradle
dependencies {
    implementation(project(":sweeteditor"))
}
```

### Minimal Integration Example

```java
import com.qiplat.sweeteditor.EditorTheme;
import com.qiplat.sweeteditor.SweetEditor;
import com.qiplat.sweeteditor.core.Document;

import javax.swing.JFrame;
import javax.swing.SwingUtilities;

SwingUtilities.invokeLater(() -> {
    JFrame frame = new JFrame("SweetEditor");
    frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);

    SweetEditor editor = new SweetEditor(EditorTheme.dark());
    editor.loadDocument(new Document("Hello, SweetEditor!"));

    frame.setContentPane(editor);
    frame.setSize(1000, 700);
    frame.setLocationRelativeTo(null);
    frame.setVisible(true);
});
```

### Notes

- `EditorNative` loads native library in order: `-Dsweeteditor.lib.path` -> source candidate directories -> native auto-extract from JAR -> `java.library.path`.
- In Maven-release scenarios, you can optionally call `NativeLibraryExtractor.extractToDefaultDir()` before first editor use.

## Public Control Layer: `SweetEditor`

### Constructor and Basics

```java
public SweetEditor()
public SweetEditor(EditorTheme theme)
public void loadDocument(Document document)
public EditorTheme getEditorTheme()
public void applyTheme(EditorTheme theme)
public EditorCore getEditorCore()
public void flush()
```

`flush()` is a force-refresh / compatibility entrypoint. Normal edit, decoration, scroll, and selection paths dispatch `EditorActionResult` through the unified result path, and `needsRedraw` decides whether to refresh the render model and redraw; hosts usually do not need to call it after batched decoration updates.

### Edit / Line Actions / Undo Redo

```java
public EditorCore.EditorActionResult insertText(String text)
public EditorCore.EditorActionResult replaceText(TextRange range, String newText)
public EditorCore.EditorActionResult deleteText(TextRange range)

public EditorCore.EditorActionResult moveLineUp()
public EditorCore.EditorActionResult moveLineDown()
public EditorCore.EditorActionResult copyLineUp()
public EditorCore.EditorActionResult copyLineDown()
public EditorCore.EditorActionResult deleteLine()
public EditorCore.EditorActionResult insertLineAbove()
public EditorCore.EditorActionResult insertLineBelow()

public EditorCore.EditorActionResult undo()
public EditorCore.EditorActionResult redo()
public boolean canUndo()
public boolean canRedo()
```

### Cursor Selection / Navigation / Appearance

```java
public void selectAll()
public String getSelectedText()
public int[] getCursorPosition()
public Document getDocument()
public int[] getWordRangeAtCursor()
public String getWordAtCursor()
public void setReadOnly(boolean readOnly)
public boolean isReadOnly()
public void gotoPosition(int line, int column)
public void setScroll(float scrollX, float scrollY)
public ScrollMetrics getScrollMetrics()
public void setLineSpacing(float add, float mult)

public void setFoldArrowMode(FoldArrowMode mode)
public void setWrapMode(WrapMode mode)
public void setAutoIndentMode(AutoIndentMode mode)
public int getAutoIndentMode()
public CursorRect getPositionRect(int line, int column)
public CursorRect getCursorRect()
```

### Language Config / Metadata / Extension Providers

```java
public void setLanguageConfiguration(LanguageConfiguration config)
public LanguageConfiguration getLanguageConfiguration()
public <T extends EditorMetadata> void setMetadata(T metadata)
public <T extends EditorMetadata> T getMetadata()

public void addNewLineActionProvider(NewLineActionProvider provider)
public void removeNewLineActionProvider(NewLineActionProvider provider)

public void addDecorationProvider(DecorationProvider provider)
public void removeDecorationProvider(DecorationProvider provider)
public void requestDecorationRefresh()

public void addCompletionProvider(CompletionProvider provider)
public void removeCompletionProvider(CompletionProvider provider)
public void triggerCompletion()
public void showCompletionItems(List<CompletionItem> items)
public void dismissCompletion()
public void setCompletionCellRenderer(CompletionCellRenderer renderer)
public void setEditorIconProvider(EditorIconProvider provider)
public EditorIconProvider getEditorIconProvider()
public int[] getVisibleLineRange()
public int getTotalLineCount()
public <T extends EditorEvent> void subscribe(Class<T> eventType, EditorEventListener<T> listener)
public <T extends EditorEvent> void unsubscribe(Class<T> eventType, EditorEventListener<T> listener)
```

### Styles / Decorations / Folding / Linked Editing

```java
public void registerTextStyle(int styleId, int color, int bgColor, int fontStyle)
public void registerTextStyle(int styleId, int color, int fontStyle)
public void registerBatchTextStyles(Map<Integer, ? extends TextStyle> textStyles)
public void setLineSpans(int line, int layer, List<? extends StyleSpan> spans)
public void setBatchLineSpans(int layer, Map<Integer, ? extends List<? extends StyleSpan>> spansByLine)

public void setLineInlayHints(int line, List<? extends InlayHint> hints)
public void setBatchLineInlayHints(Map<Integer, ? extends List<? extends InlayHint>> hintsByLine)
public void setLinePhantomTexts(int line, List<? extends PhantomText> phantoms)
public void setBatchLinePhantomTexts(Map<Integer, ? extends List<? extends PhantomText>> phantomsByLine)
public void setLineCodeLens(int line, List<? extends CodeLensItem> items)
public void setBatchLineCodeLens(Map<Integer, ? extends List<? extends CodeLensItem>> itemsByLine)
public void clearCodeLens()
public void setLineLinks(int line, List<? extends LinkSpan> links)
public void setBatchLineLinks(Map<Integer, ? extends List<? extends LinkSpan>> linksByLine)
public String getLinkTargetAt(int line, int column)
public void clearLinks()

public void setLineDiagnostics(int line, List<? extends DiagnosticItem> items)
public void setBatchLineDiagnostics(Map<Integer, ? extends List<? extends DiagnosticItem>> diagsByLine)
public void clearDiagnostics()

public void setLineGutterIcons(int line, List<? extends GutterIcon> icons)
public void setBatchLineGutterIcons(Map<Integer, ? extends List<? extends GutterIcon>> iconsByLine)
public void setMaxGutterIcons(int count)
public void clearGutterIcons()

public void setIndentGuides(List<? extends IndentGuide> guides)
public void setBracketGuides(List<? extends BracketGuide> guides)
public void setFlowGuides(List<? extends FlowGuide> guides)
public void setSeparatorGuides(List<? extends SeparatorGuide> guides)
public void clearGuides()

public void setFoldRegions(List<? extends FoldRegion> regions)
public boolean toggleFold(int line)
public void foldAll()
public void unfoldAll()

public void clearHighlights()
public void clearHighlights(SpanLayer layer)
public void clearInlayHints()
public void clearPhantomTexts()
public void clearAllDecorations()

public EditorCore.EditorActionResult insertSnippet(String snippetTemplate)
public void startLinkedEditing(LinkedEditingModel model)
public boolean isInLinkedEditing()
public boolean linkedEditingNext()
public boolean linkedEditingPrev()
public void cancelLinkedEditing()
```

`CodeLensClickEvent` and `LinkClickEvent` are emitted through the generic `subscribe(...)` event bus. `getLinkTargetAt(...)` returns an empty string when no link matches the requested position.

## Bridge Layer Notes

- `EditorCore` / `EditorNative` already include bracket highlight support:
  - `setBracketPairs(int[] openChars, int[] closeChars)`
  - `setMatchedBrackets(...)`
  - `clearMatchedBrackets()`
- Control layer usually sends bracket pairs through `setLanguageConfiguration(...)`.
- `Document` currently exposes two read APIs: `getLineText(int)` and `getLineCount()`.

## `Document`

```java
public Document(String text)
public long getHandle()
public String getLineText(int line)
public int getLineCount()
public void close()
```
