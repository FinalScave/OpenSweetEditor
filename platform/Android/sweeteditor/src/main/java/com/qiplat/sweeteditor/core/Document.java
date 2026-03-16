package com.qiplat.sweeteditor.core;

import com.qiplat.sweeteditor.core.foundation.TextPosition;

import java.io.File;

import dalvik.annotation.optimization.CriticalNative;
import dalvik.annotation.optimization.FastNative;

/**
 * Document model, encapsulating the JNI bridge to the C++ layer's text buffer.
 * <p>
 * Supports creating documents from strings or files, providing line text queries,
 * character index and position conversion, and other functionalities.
 */
public class Document {
    protected long mNativeHandle;

    protected Document(long nativeHandle) {
        this.mNativeHandle = nativeHandle;
    }

    public Document(String content) {
        mNativeHandle = nativeMakeStringDocument(content);
    }

    public Document(File file) {
        mNativeHandle = nativeMakeFileDocument(file.getAbsolutePath());
    }

    public String getText() {
        if (mNativeHandle == 0) {
            return "";
        }
        return nativeGetText(mNativeHandle);
    }

    public int getLineCount() {
        if (mNativeHandle == 0) {
            return 0;
        }
        return nativeGetLineCount(mNativeHandle);
    }

    public String getLineText(int line) {
        if (mNativeHandle == 0) {
            return "";
        }
        return nativeGetLineText(mNativeHandle, line);
    }

    public TextPosition getPositionFromCharIndex(int index) {
        if (mNativeHandle == 0) {
            return TextPosition.NONE;
        }
        long value = nativePositionOfCharIndex(mNativeHandle, index);
        int line = (int) (value >> 32);
        int column = (int) (value & 0XFFFFFFFFL);
        return new TextPosition(line, column);
    }

    public int getCharIndexFromPosition(TextPosition position) {
        if (mNativeHandle == 0) {
            return 0;
        }
        long value = ((long) position.line << 32) | (position.column & 0XFFFFFFFFL);
        return nativeCharIndexOfPosition(mNativeHandle, value);
    }

    @Override
    protected void finalize() throws Throwable {
        super.finalize();
        if (mNativeHandle == 0) {
            return;
        }
        nativeFinalizeDocument(mNativeHandle);
        mNativeHandle = 0;
    }

    @FastNative
    private static native long nativeMakeStringDocument(String content);

    @FastNative
    private static native long nativeMakeFileDocument(String path);

    @CriticalNative
    private static native void nativeFinalizeDocument(long handle);

    @FastNative
    private static native String nativeGetText(long handle);

    @CriticalNative
    private static native int nativeGetLineCount(long handle);

    @FastNative
    private static native String nativeGetLineText(long handle, int line);

    @CriticalNative
    private static native int nativeCharIndexOfPosition(long handle, long position);

    @CriticalNative
    private static native long nativePositionOfCharIndex(long handle, int charIndex);
}
