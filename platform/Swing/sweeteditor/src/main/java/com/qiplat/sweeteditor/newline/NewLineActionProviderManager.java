package com.qiplat.sweeteditor.newline;

import java.util.ArrayList;
import java.util.List;

/**
 * Chain-based manager for newline providers, iterates until the first non-null provider takes effect.
 */
public class NewLineActionProviderManager {

    private final List<NewLineActionProvider> providers = new ArrayList<>();

    public void addProvider(NewLineActionProvider provider) {
        providers.add(provider);
    }

    public void removeProvider(NewLineActionProvider provider) {
        providers.remove(provider);
    }

    /**
     * Iterate all providers, return first non-null NewLineAction; return null if all return null.
     */
    public NewLineAction provideNewLineAction(NewLineContext context) {
        for (NewLineActionProvider provider : providers) {
            NewLineAction action = provider.provideNewLineAction(context);
            if (action != null) {
                return action;
            }
        }
        return null;
    }
}
