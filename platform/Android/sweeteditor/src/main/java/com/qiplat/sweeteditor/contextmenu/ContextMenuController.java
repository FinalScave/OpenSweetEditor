package com.qiplat.sweeteditor.contextmenu;

import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.graphics.PointF;
import android.graphics.RectF;
import android.graphics.drawable.Drawable;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.qiplat.sweeteditor.EditorTheme;
import com.qiplat.sweeteditor.R;
import com.qiplat.sweeteditor.SweetEditor;
import com.qiplat.sweeteditor.core.EditorCore;
import com.qiplat.sweeteditor.core.foundation.TextPosition;
import com.qiplat.sweeteditor.core.foundation.TextRange;
import com.qiplat.sweeteditor.event.ContextMenuItemClickEvent;
import com.qiplat.sweeteditor.event.EditorEventBus;
import com.qiplat.sweeteditor.event.LinkClickEvent;
import com.qiplat.sweeteditor.ui.PopupPositioner;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;

/**
 * Controls context menu lifecycle, default actions, and custom item callbacks.
 */
public final class ContextMenuController {
    private static final int MENU_OFFSET_X_DP = 2;
    private static final int MENU_OFFSET_Y_DP = 4;
    private static final List<PopupPositioner.Placement> MENU_PLACEMENTS = Arrays.asList(
            PopupPositioner.Placement.of(PopupPositioner.PopupSide.BELOW, PopupPositioner.PopupAlign.START),
            PopupPositioner.Placement.of(PopupPositioner.PopupSide.ABOVE, PopupPositioner.PopupAlign.START)
    );

    private final SweetEditor editor;
    private final EditorEventBus eventBus;
    private final ContextMenuPopup popup;

    @Nullable private ContextMenuItemProvider itemProvider;
    @Nullable private ContextMenuRequest currentRequest;

    public ContextMenuController(@NonNull SweetEditor editor,
                                 @NonNull EditorEventBus eventBus,
                                 @NonNull EditorTheme theme) {
        this.editor = editor;
        this.eventBus = eventBus;
        this.popup = new ContextMenuPopup(editor.getContext(),
                theme.contextMenuBgColor,
                theme.contextMenuTextColor,
                theme.contextMenuDividerColor);
        this.popup.setOnMenuItemClickListener(this::onItemClicked);
    }

    public void setItemProvider(@Nullable ContextMenuItemProvider provider) {
        this.itemProvider = provider;
    }

    public void applyTheme(@NonNull EditorTheme theme) {
        popup.updateTheme(
                theme.contextMenuBgColor,
                theme.contextMenuTextColor,
                theme.contextMenuDividerColor);
    }

    public void onEditorActionResult(@NonNull EditorCore.EditorActionResult result, @NonNull PointF locationInEditor) {
        switch (result.gestureType) {
            case LONG_PRESS:
                showMenu(buildRequest(ContextMenuTriggerKind.LONG_PRESS, result, locationInEditor));
                break;
            case CONTEXT_MENU:
                showMenu(buildRequest(ContextMenuTriggerKind.RIGHT_CLICK, result, locationInEditor));
                break;
            case TAP:
            case DOUBLE_TAP:
            case SCROLL:
            case FAST_SCROLL:
            case SCALE:
            case DRAG_SELECT:
                dismissImmediate();
                break;
            default:
                break;
        }
    }

    public void onTextChanged() {
        dismissImmediate();
    }

    public void dismiss() {
        popup.dismiss();
        currentRequest = null;
    }

    public boolean isShowing() {
        return popup.isShowing();
    }

    private void dismissImmediate() {
        popup.dismissImmediate();
        currentRequest = null;
    }

    @NonNull
    private ContextMenuRequest buildRequest(@NonNull ContextMenuTriggerKind triggerKind,
                                            @NonNull EditorCore.EditorActionResult result,
                                            @NonNull PointF locationInEditor) {
        EditorCore.HitTarget hitTarget = result.hitTarget != null ? result.hitTarget : EditorCore.HitTarget.NONE;
        String linkTarget = "";
        if (hitTarget.type == EditorCore.HitTargetType.LINK) {
            linkTarget = editor.getLinkTargetAt(hitTarget.line, hitTarget.column);
        }
        return new ContextMenuRequest(
                triggerKind,
                copyPosition(result.cursorAfter),
                new PointF(locationInEditor.x, locationInEditor.y),
                result.hasSelectionAfter,
                result.hasSelectionAfter ? copyRange(result.selectionAfter) : null,
                hitTarget,
                linkTarget
        );
    }

    private void showMenu(@NonNull ContextMenuRequest request) {
        List<ContextMenuSection> sections = buildSections(request);
        if (sections.isEmpty()) {
            dismissImmediate();
            return;
        }
        currentRequest = request;
        popup.setSections(sections);
        int offsetX = PopupPositioner.dpToPx(editor.getContext(), MENU_OFFSET_X_DP);
        int offsetY = PopupPositioner.dpToPx(editor.getContext(), MENU_OFFSET_Y_DP);
        PopupPositioner.Result position = PopupPositioner.compute(new PopupPositioner.Request(
                editor,
                new RectF(
                        request.locationInEditor.x + offsetX,
                        request.locationInEditor.y + offsetY,
                        request.locationInEditor.x + offsetX,
                        request.locationInEditor.y + offsetY
                ),
                Math.max(1, popup.getPopupWidth()),
                Math.max(1, popup.getPopupHeight()),
                0,
                0,
                MENU_PLACEMENTS
        ));
        popup.showAt(editor, position.screenX, position.screenY, position.placement);
    }

    @NonNull
    private List<ContextMenuSection> buildSections(@NonNull ContextMenuRequest request) {
        if (itemProvider != null) {
            return sanitizeSections(itemProvider.provideMenuItems(editor, request));
        }
        return buildDefaultSections(request);
    }

    @NonNull
    private List<ContextMenuSection> sanitizeSections(@Nullable List<ContextMenuSection> sections) {
        if (sections == null || sections.isEmpty()) {
            return Collections.emptyList();
        }
        List<ContextMenuSection> normalized = new ArrayList<>();
        for (ContextMenuSection section : sections) {
            if (section == null || section.items.isEmpty()) {
                continue;
            }
            List<ContextMenuItem> items = new ArrayList<>();
            for (ContextMenuItem item : section.items) {
                if (item != null) {
                    items.add(item);
                }
            }
            if (!items.isEmpty()) {
                normalized.add(new ContextMenuSection(items));
            }
        }
        return normalized;
    }

    @NonNull
    private List<ContextMenuSection> buildDefaultSections(@NonNull ContextMenuRequest request) {
        List<ContextMenuSection> sections = new ArrayList<>(3);
        appendLinkSection(sections, request);
        appendEditSection(sections, request);
        appendGeneralSection(sections);
        return sections;
    }

    private void appendLinkSection(@NonNull List<ContextMenuSection> out,
                                   @NonNull ContextMenuRequest request) {
        if (request.hitTarget.type != EditorCore.HitTargetType.LINK || request.linkTarget.isEmpty()) {
            return;
        }
        List<ContextMenuItem> items = new ArrayList<>(2);
        items.add(new ContextMenuItem(ContextMenuItem.ACTION_OPEN_LINK,
                "Open Link",
                loadIcon(R.drawable.ic_context_menu_open_link)));
        items.add(new ContextMenuItem(ContextMenuItem.ACTION_COPY_LINK,
                "Copy Link",
                loadIcon(R.drawable.ic_context_menu_copy_link)));
        out.add(new ContextMenuSection(items));
    }

    private void appendEditSection(@NonNull List<ContextMenuSection> out,
                                   @NonNull ContextMenuRequest request) {
        if (!request.hasSelection) {
            return;
        }
        List<ContextMenuItem> items = new ArrayList<>(2);
        items.add(new ContextMenuItem(ContextMenuItem.ACTION_CUT,
                "Cut",
                loadIcon(R.drawable.ic_context_menu_cut)));
        items.add(new ContextMenuItem(ContextMenuItem.ACTION_COPY,
                "Copy",
                loadIcon(R.drawable.ic_context_menu_copy)));
        out.add(new ContextMenuSection(items));
    }

    private void appendGeneralSection(@NonNull List<ContextMenuSection> out) {
        List<ContextMenuItem> items = new ArrayList<>(2);
        items.add(new ContextMenuItem(ContextMenuItem.ACTION_PASTE,
                "Paste",
                loadIcon(R.drawable.ic_context_menu_paste)));
        items.add(new ContextMenuItem(ContextMenuItem.ACTION_SELECT_ALL,
                "Select All",
                loadIcon(R.drawable.ic_context_menu_select_all)));
        out.add(new ContextMenuSection(items));
    }

    private void onItemClicked(@NonNull ContextMenuItem item) {
        ContextMenuRequest request = currentRequest;
        if (request == null) {
            dismissImmediate();
            return;
        }

        switch (item.id) {
            case ContextMenuItem.ACTION_OPEN_LINK:
                if (!request.linkTarget.isEmpty()) {
                    eventBus.publish(new LinkClickEvent(
                            request.hitTarget.line,
                            request.hitTarget.column,
                            request.linkTarget,
                            new PointF(request.locationInEditor.x, request.locationInEditor.y)));
                }
                dismissImmediate();
                break;
            case ContextMenuItem.ACTION_COPY_LINK:
                if (!request.linkTarget.isEmpty()) {
                    copyPlainText(request.linkTarget);
                }
                dismissImmediate();
                break;
            case ContextMenuItem.ACTION_CUT:
                if (editor.cutToClipboard()) {
                    dismissImmediate();
                }
                break;
            case ContextMenuItem.ACTION_COPY:
                if (editor.copyToClipboard()) {
                    dismissImmediate();
                }
                break;
            case ContextMenuItem.ACTION_PASTE:
                editor.pasteFromClipboard();
                dismissImmediate();
                break;
            case ContextMenuItem.ACTION_SELECT_ALL:
                editor.selectAll();
                dismissImmediate();
                break;
            default:
                eventBus.publish(new ContextMenuItemClickEvent(item, request));
                dismissImmediate();
                break;
        }
    }

    private void copyPlainText(@NonNull String text) {
        ClipboardManager clipboard = (ClipboardManager) editor.getContext()
                .getSystemService(Context.CLIPBOARD_SERVICE);
        if (clipboard != null) {
            clipboard.setPrimaryClip(ClipData.newPlainText("SweetEditor", text));
        }
    }

    @NonNull
    private static TextPosition copyPosition(@NonNull TextPosition position) {
        return new TextPosition(position.line, position.column);
    }

    @Nullable
    private static TextRange copyRange(@Nullable TextRange range) {
        if (range == null) {
            return null;
        }
        return new TextRange(copyPosition(range.start), copyPosition(range.end));
    }

    @Nullable
    private Drawable loadIcon(int resId) {
        return editor.getContext().getDrawable(resId);
    }
}
