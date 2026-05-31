package com.qiplat.sweeteditor.core.config;

import com.qiplat.sweeteditor.core.foundation.OffsetRect;

public final class HandleConfig {
    public OffsetRect startHitOffset = new OffsetRect(-32.1f, -8.0f, 8.0f, 32.1f);
    public OffsetRect endHitOffset = new OffsetRect(-8.0f, -8.0f, 32.1f, 32.1f);

    public HandleConfig() {
    }

    public HandleConfig(OffsetRect startHitOffset, OffsetRect endHitOffset) {
        this.startHitOffset = startHitOffset;
        this.endHitOffset = endHitOffset;
    }
}
