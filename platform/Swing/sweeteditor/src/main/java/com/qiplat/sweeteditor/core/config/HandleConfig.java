package com.qiplat.sweeteditor.core.config;

public final class HandleConfig {
    public HandleHitArea startHitArea = new HandleHitArea(-32.1f, -8.0f, 8.0f, 32.1f);
    public HandleHitArea endHitArea = new HandleHitArea(-8.0f, -8.0f, 32.1f, 32.1f);

    public HandleConfig() {
    }

    public HandleConfig(HandleHitArea startHitArea, HandleHitArea endHitArea) {
        this.startHitArea = startHitArea;
        this.endHitArea = endHitArea;
    }
}
