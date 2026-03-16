package com.qiplat.sweeteditor.newline;

import androidx.annotation.Nullable;

/**
 * Smart newline provider interface.
 * Implement this interface to customize newline behavior (e.g., smart indent, line continuation comment, bracket expansion, etc.).
 * Return null to indicate the current provider does not handle this, pass to the next provider in the chain.
 */
public interface NewLineActionProvider {
    /**
     * Calculate newline action based on context.
     *
     * @param context newline context
     * @return newline action; return null to not handle
     */
    @Nullable
    NewLineAction provideNewLineAction(@Nullable NewLineContext context);
}
