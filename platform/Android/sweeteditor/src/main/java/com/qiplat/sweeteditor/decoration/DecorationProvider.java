package com.qiplat.sweeteditor.decoration;

import androidx.annotation.NonNull;
import androidx.annotation.MainThread;

import java.util.EnumSet;

public interface DecorationProvider {
    @NonNull
    EnumSet<DecorationType> getCapabilities();

    /**
     * Called on the main/UI thread. Providers MAY offload heavy computation
     * to background threads and later submit results via {@code receiver.accept()}.
     */
    @MainThread
    void provideDecorations(@NonNull DecorationContext context, @NonNull DecorationReceiver receiver);
}
