package com.qiplat.sweeteditor.core.interaction;

public final class HitTarget {
    public HitTargetType type = HitTargetType.NONE;
    public int line = 0;
    public int column = 0;
    public int iconId = 0;
    public int colorValue = 0;

    public HitTarget() {
    }

    public HitTarget(HitTargetType type, int line, int column, int iconId, int colorValue) {
        this.type = type;
        this.line = line;
        this.column = column;
        this.iconId = iconId;
        this.colorValue = colorValue;
    }
}
