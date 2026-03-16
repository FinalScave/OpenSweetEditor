package com.qiplat.sweeteditor.decoration;

import java.util.EnumSet;

public interface DecorationProvider {
    EnumSet<DecorationType> getCapabilities();

    void provideDecorations(DecorationContext context, DecorationReceiver receiver);
}
