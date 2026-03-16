package com.qiplat.sweeteditor.newline;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.util.ArrayList;
import java.util.List;

/**
 * Chain-based manager for newline providers, iterates until the first non-null provider takes effect.
 */
public class NewLineActionProviderManager {

    private final List<NewLineActionProvider> providers = new ArrayList<>();

    public void addProvider(@NonNull NewLineActionProvider provider) {
        providers.add(provider);
    }

    public void removeProvider(@NonNull NewLineActionProvider provider) {
        providers.remove(provider);
    }

    /**
     * Iterate all providers, return first non-null NewLineAction; return null if all return null.
     */
    @Nullable
    public NewLineAction provideNewLineAction(@NonNull NewLineContext context) {
        for (NewLineActionProvider provider : providers) {
            NewLineAction action = provider.provideNewLineAction(context);
            if (action != null) {
                return action;
            }
        }
        return null;
    }
}
