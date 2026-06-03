package com.qiplat.sweeteditor.core.visual;

import com.qiplat.sweeteditor.core.config.RangeEffectStyle;
import com.qiplat.sweeteditor.core.foundation.Rect;

public final class RangeEffectRenderItem {
    public Rect rect = new Rect();
    public RangeEffectKind kind = RangeEffectKind.SELECTION;
    public RangeEffectStyle style = new RangeEffectStyle();

    public RangeEffectRenderItem() {
    }

    public RangeEffectRenderItem(Rect rect, RangeEffectKind kind, RangeEffectStyle style) {
        this.rect = rect;
        this.kind = kind;
        this.style = style;
    }
}
