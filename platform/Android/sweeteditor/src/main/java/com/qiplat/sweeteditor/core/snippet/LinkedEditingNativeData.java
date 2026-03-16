package com.qiplat.sweeteditor.core.snippet;

import androidx.annotation.NonNull;

/**
 * Flat data for JNI transport of the linked editing model.
 */
public class LinkedEditingNativeData {
    @NonNull public final int[] groupIndices;
    @NonNull public final String[] groupDefaultTexts;
    @NonNull public final int[] rangeStartLines;
    @NonNull public final int[] rangeStartColumns;
    @NonNull public final int[] rangeEndLines;
    @NonNull public final int[] rangeEndColumns;
    @NonNull public final int[] rangeGroupIndices;

    public LinkedEditingNativeData(@NonNull int[] groupIndices, @NonNull String[] groupDefaultTexts,
                                   @NonNull int[] rangeStartLines, @NonNull int[] rangeStartColumns,
                                   @NonNull int[] rangeEndLines, @NonNull int[] rangeEndColumns,
                                   @NonNull int[] rangeGroupIndices) {
        this.groupIndices = groupIndices;
        this.groupDefaultTexts = groupDefaultTexts;
        this.rangeStartLines = rangeStartLines;
        this.rangeStartColumns = rangeStartColumns;
        this.rangeEndLines = rangeEndLines;
        this.rangeEndColumns = rangeEndColumns;
        this.rangeGroupIndices = rangeGroupIndices;
    }
}
