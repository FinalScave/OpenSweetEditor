package com.qiplat.sweeteditor.core.snippet;

import com.qiplat.sweeteditor.core.foundation.TextRange;
import java.util.List;

public final class TabStopGroup {
    public int index = 0;
    public java.util.List<TextRange> ranges = new java.util.ArrayList<>();
    public String defaultText = "";

    public TabStopGroup() {
    }

    public TabStopGroup(int index, java.util.List<TextRange> ranges, String defaultText) {
        this.index = index;
        this.ranges = ranges;
        this.defaultText = defaultText;
    }
}
