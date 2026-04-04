package com.qiplat.sweeteditor.core;

import java.lang.foreign.Arena;
import java.lang.ref.Cleaner;
import java.io.File;
import java.nio.file.Path;
import java.util.Objects;

/**
 * Document object, encapsulating the native document handle from the C++ layer.
 */
public class Document {
    private static final Cleaner CLEANER = Cleaner.create();

    final long nativeHandle;
    private final Arena arena;
    private final Cleaner.Cleanable cleanable;

    private static final class CleanupAction implements Runnable {
        private final long nativeHandle;
        private final Arena arena;
        private boolean cleaned;

        private CleanupAction(long nativeHandle, Arena arena) {
            this.nativeHandle = nativeHandle;
            this.arena = arena;
        }

        @Override
        public synchronized void run() {
            if (cleaned) return;
            cleaned = true;
            EditorNative.freeDocument(nativeHandle);
            arena.close();
        }
    }

    public Document(String text) {
        this.arena = Arena.ofConfined();
        this.nativeHandle = EditorNative.createDocument(arena, text);
        this.cleanable = CLEANER.register(this, new CleanupAction(nativeHandle, arena));
    }

    public Document(Path path) {
        this.arena = Arena.ofConfined();
        this.nativeHandle = EditorNative.createDocumentFromFile(arena, Objects.requireNonNull(path, "path").toString());
        this.cleanable = CLEANER.register(this, new CleanupAction(nativeHandle, arena));
    }

    public Document(File file) {
        this(Objects.requireNonNull(file, "file").toPath());
    }

    public long getHandle() {
        return nativeHandle;
    }

    /**
     * Get the text content of the specified line.
     * @param line line number (0-based)
     * @return the line text, returns empty string if the handle is invalid
     */
    public String getLineText(int line) {
        if (nativeHandle == 0) return "";
        String text = EditorNative.getDocumentLineText(nativeHandle, line);
        return text != null ? text : "";
    }

    /**
     * Get the total number of lines in the document.
     */
    public int getLineCount() {
        if (nativeHandle == 0) return 0;
        return EditorNative.getDocumentLineCount(nativeHandle);
    }

    /**
     * Get the full text content of the document.
     * @return the complete document text, or empty string if the handle is invalid
     */
    public String getText() {
        if (nativeHandle == 0) return "";
        int lineCount = getLineCount();
        if (lineCount == 0) return "";
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < lineCount; i++) {
            if (i > 0) sb.append('\n');
            sb.append(getLineText(i));
        }
        return sb.toString();
    }

}
