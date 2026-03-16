package com.qiplat.sweeteditor.core;

import java.lang.foreign.Arena;

/**
 * Document object, encapsulating the native document handle from the C++ layer.
 */
public class Document implements AutoCloseable {
    final long nativeHandle;
    private final Arena arena;

    public Document(String text) {
        this.arena = Arena.ofConfined();
        this.nativeHandle = EditorNative.createDocument(arena, text);
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

    @Override
    public void close() {
        EditorNative.freeDocument(nativeHandle);
        arena.close();
    }
}
