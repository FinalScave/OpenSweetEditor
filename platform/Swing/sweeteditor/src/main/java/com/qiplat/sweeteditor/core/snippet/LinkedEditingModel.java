package com.qiplat.sweeteditor.core.snippet;

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

    /**
     * Tab Stop group.
     */
    public static class TabStopGroup {
        /** Group index (0=final cursor position, 1+=editing order) */
        public final int index;
        /** Default placeholder text */
        public final String defaultText;
        /** All text ranges of this group */
        public final List<TextRange> ranges;

        TabStopGroup(int index, String defaultText, List<TextRange> ranges) {
            this.index = index;
            this.defaultText = defaultText;
            this.ranges = ranges;
        }
    }

    private final List<TabStopGroup> groups;

    private LinkedEditingModel(List<TabStopGroup> groups) {
        this.groups = groups;
    }

    public List<TabStopGroup> getGroups() {
        return groups;
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
        public GroupBuilder addGroup(int index, String defaultText) {
            GroupBuilder gb = new GroupBuilder(this, index, defaultText);
            groupBuilders.add(gb);
            return gb;
        }

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
        final String defaultText;
        final List<TextRange> ranges = new ArrayList<>();

        GroupBuilder(Builder parent, int index, String defaultText) {
            this.parent = parent;
            this.index = index;
            this.defaultText = defaultText;
        }

        /**
         * Add a linked editing range.
         */
        public GroupBuilder addRange(int startLine, int startColumn, int endLine, int endColumn) {
            ranges.add(new TextRange(
                    new TextPosition(startLine, startColumn),
                    new TextPosition(endLine, endColumn)));
            return this;
        }

        /**
         * Return to the parent Builder to add more groups.
         */
        public Builder and() {
            return parent;
        }

        /**
         * Directly build the model (shortcut method).
         */
        public LinkedEditingModel build() {
            return parent.build();
        }
    }
}
