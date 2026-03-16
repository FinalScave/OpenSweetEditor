package com.qiplat.sweeteditor.core.snippet;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.qiplat.sweeteditor.core.foundation.TextRange;

import java.util.List;

/**
 * Tab Stop group.
 */
public class TabStopGroup {
    /** Group index (0=final cursor position, 1+=editing order) */
    public final int index;
    /** Default placeholder text */
    @Nullable public final String defaultText;
    /** All text ranges in this group */
    @NonNull public final List<TextRange> ranges;

    public TabStopGroup(int index, @Nullable String defaultText, @NonNull List<TextRange> ranges) {
        this.index = index;
        this.defaultText = defaultText;
        this.ranges = ranges;
    }
}
