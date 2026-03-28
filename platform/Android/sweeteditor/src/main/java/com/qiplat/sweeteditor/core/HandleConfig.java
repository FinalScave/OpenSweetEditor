package com.qiplat.sweeteditor.core;

import android.graphics.RectF;

/**
 * Selection handle hit-test configuration.
 * Platform layer owns handle drawing; this only describes the hit areas
 * passed to C++ core for touch detection and drag offset calculation.
 */
public class HandleConfig {
    /** Hit area for start handle, offset from the cursor bottom anchor (handle tip) */
    public final RectF startHitOffset;
    /** Hit area for end handle, offset from the cursor bottom anchor (handle tip) */
    public final RectF endHitOffset;

    public HandleConfig() {
        this(new RectF(-32.1f, -8f, 8f, 32.1f),
             new RectF(-8f, -8f, 32.1f, 32.1f));
    }

    public HandleConfig(RectF startHitOffset, RectF endHitOffset) {
        this.startHitOffset = startHitOffset;
        this.endHitOffset = endHitOffset;
    }
}
