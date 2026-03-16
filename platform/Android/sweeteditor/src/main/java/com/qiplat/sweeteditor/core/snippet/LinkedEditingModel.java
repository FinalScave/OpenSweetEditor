package com.qiplat.sweeteditor.core.snippet;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.qiplat.sweeteditor.core.foundation.TextPosition;
import com.qiplat.sweeteditor.core.foundation.TextRange;

import java.util.ArrayList;
import java.util.List;

/**
 * Linked editing model (pure data structure).
 * <p>
 * Built using Builder and passed to {@code EditorCore.startLinkedEditing()} to start linked editing mode.
 * This model is suitable for scenarios like Snippet expansion, Rename Symbol, Postfix Completion, etc.
 * </p>
 */
public class LinkedEditingModel {

    @NonNull
    private final List<TabStopGroup> groups;

    private LinkedEditingModel(@NonNull List<TabStopGroup> groups) {
        this.groups = groups;
    }

    @NonNull
    public List<TabStopGroup> getGroups() {
        return groups;
    }

    /**
     * Serialize to flat array structure for JNI transport.
     */
    @NonNull
    public LinkedEditingNativeData toNativeData() {
        int groupCount = groups.size();
        int totalRanges = 0;
        for (TabStopGroup g : groups) {
            totalRanges += g.ranges.size();
        }

        int[] groupIndices = new int[groupCount];
        String[] groupDefaultTexts = new String[groupCount];
        int[] rangeStartLines = new int[totalRanges];
        int[] rangeStartColumns = new int[totalRanges];
        int[] rangeEndLines = new int[totalRanges];
        int[] rangeEndColumns = new int[totalRanges];
        int[] rangeGroupIndices = new int[totalRanges];

        int ri = 0;
        for (int gi = 0; gi < groupCount; gi++) {
            TabStopGroup g = groups.get(gi);
            groupIndices[gi] = g.index;
            groupDefaultTexts[gi] = g.defaultText;
            for (TextRange r : g.ranges) {
                rangeStartLines[ri] = r.start.line;
                rangeStartColumns[ri] = r.start.column;
                rangeEndLines[ri] = r.end.line;
                rangeEndColumns[ri] = r.end.column;
                rangeGroupIndices[ri] = gi;
                ri++;
            }
        }
        return new LinkedEditingNativeData(groupIndices, groupDefaultTexts,
                rangeStartLines, rangeStartColumns, rangeEndLines, rangeEndColumns, rangeGroupIndices);
    }

    // ==================== Builder ====================

    public static class Builder {
        private final List<GroupBuilder> groupBuilders = new ArrayList<>();

        /**
         * Add a tab stop group.
         *
         * @param index       group index (0=final cursor position, 1+=editing order)
         * @param defaultText default placeholder text (can be null)
         * @return GroupBuilder, can chain-add ranges
         */
        @NonNull
        public GroupBuilder addGroup(int index, @Nullable String defaultText) {
            GroupBuilder gb = new GroupBuilder(this, index, defaultText);
            groupBuilders.add(gb);
            return gb;
        }

        @NonNull
        public LinkedEditingModel build() {
            List<TabStopGroup> groups = new ArrayList<>(groupBuilders.size());
            for (GroupBuilder gb : groupBuilders) {
                groups.add(new TabStopGroup(gb.index, gb.defaultText, gb.ranges));
            }
            return new LinkedEditingModel(groups);
        }
    }

    public static class GroupBuilder {
        private final Builder parent;
        final int index;
        @Nullable final String defaultText;
        final List<TextRange> ranges = new ArrayList<>();

        GroupBuilder(Builder parent, int index, @Nullable String defaultText) {
            this.parent = parent;
            this.index = index;
            this.defaultText = defaultText;
        }

        /**
         * Add a linked editing range.
         */
        @NonNull
        public GroupBuilder addRange(int startLine, int startColumn, int endLine, int endColumn) {
            ranges.add(new TextRange(
                    new TextPosition(startLine, startColumn),
                    new TextPosition(endLine, endColumn)));
            return this;
        }

        /**
         * Return to the parent Builder to add more groups.
         */
        @NonNull
        public Builder and() {
            return parent;
        }

        /**
         * Directly build the model (shortcut method).
         */
        @NonNull
        public LinkedEditingModel build() {
            return parent.build();
        }
    }
}
