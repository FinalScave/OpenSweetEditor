package com.qiplat.sweeteditor.decoration;

import androidx.annotation.NonNull;

import java.util.EnumSet;

public interface DecorationProvider {
    @NonNull
    EnumSet<DecorationType> getCapabilities();

    void provideDecorations(@NonNull DecorationContext context, @NonNull DecorationReceiver receiver);
}
