package com.qiplat.sweeteditor.ui;

import android.content.Context;

import androidx.annotation.NonNull;

/**
 * Unit conversion helpers for Android UI dimensions.
 */
public final class UiDimensions {
    private UiDimensions() {
    }

    public static float density(@NonNull Context context) {
        return context.getResources().getDisplayMetrics().density;
    }

    public static int dpToPx(@NonNull Context context, float dp) {
        return Math.round(dpToPxFloat(context, dp));
    }

    public static float dpToPxFloat(@NonNull Context context, float dp) {
        return dp * density(context);
    }
}
