package com.qiplat.sweeteditor.completion;

import android.content.Context;
import android.graphics.Color;
import android.graphics.Rect;
import android.graphics.RectF;
import android.graphics.Typeface;
import android.graphics.drawable.ColorDrawable;
import android.graphics.drawable.GradientDrawable;
import android.text.TextUtils;
import android.view.KeyEvent;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.PopupWindow;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.qiplat.sweeteditor.EditorTheme;
import com.qiplat.sweeteditor.ui.PopupAnimator;
import com.qiplat.sweeteditor.ui.PopupPositioner;
import com.qiplat.sweeteditor.ui.UiDimensions;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * Completion popup controller: PopupWindow + RecyclerView.
 * <p>Cursor-following positioning, up/down key navigation, Enter to confirm, Escape to dismiss.</p>
 */
public class CompletionPopupController implements CompletionProviderManager.CompletionUpdateListener {

    public interface CompletionConfirmListener {
        void onCompletionConfirmed(@NonNull CompletionItem item);
    }

    private static final int MAX_VISIBLE_ITEMS = 4;
    private static final int ITEM_HEIGHT_DP = 32;
    private static final int POPUP_WIDTH_DP = 300;
    private static final int PANEL_HORIZONTAL_PADDING_DP = 4;
    private static final int PANEL_VERTICAL_PADDING_DP = 6;
    private static final int POPUP_MIN_WIDTH_DP = 120;
    private static final int POPUP_FRAME_PADDING_DP = 8;
    private static final int GAP_DP = 4;
    private static final List<PopupPositioner.Placement> POPUP_PLACEMENTS = Arrays.asList(
            PopupPositioner.Placement.of(PopupPositioner.PopupSide.BELOW, PopupPositioner.PopupAlign.START),
            PopupPositioner.Placement.of(PopupPositioner.PopupSide.ABOVE, PopupPositioner.PopupAlign.START)
    );

    private final Context context;
    private final View anchorView;
    @Nullable private CompletionConfirmListener confirmListener;
    @Nullable private CompletionItemViewFactory viewFactory;

    private PopupWindow popupWindow;
    private RecyclerView recyclerView;
    private CompletionAdapter adapter;
    private final List<CompletionItem> items = new ArrayList<>();
    private int selectedIndex = 0;

    private int panelBgColor;
    private int panelBorderColor;
    private int selectedBgColor;
    private int labelColor;
    private int detailColor;

    private float cachedCursorX = 0;
    private float cachedCursorY = 0;
    private float cachedCursorHeight = 0;
    @NonNull private PopupPositioner.Placement lastPlacement =
            PopupPositioner.Placement.of(PopupPositioner.PopupSide.BELOW, PopupPositioner.PopupAlign.START);

    public CompletionPopupController(@NonNull Context context, @NonNull View anchorView, @NonNull EditorTheme theme) {
        this.context = context;
        this.anchorView = anchorView;
        panelBgColor = theme.completionBgColor;
        panelBorderColor = theme.completionBorderColor;
        selectedBgColor = theme.completionSelectedBgColor;
        labelColor = theme.completionLabelColor;
        detailColor = theme.completionDetailColor;
        initPopup();
    }

    public void applyTheme(@NonNull EditorTheme theme) {
        panelBgColor = theme.completionBgColor;
        panelBorderColor = theme.completionBorderColor;
        selectedBgColor = theme.completionSelectedBgColor;
        labelColor = theme.completionLabelColor;
        detailColor = theme.completionDetailColor;
        if (recyclerView != null) {
            recyclerView.setBackground(createPanelBackground());
            recyclerView.setClipToOutline(true);
        }
        if (adapter != null) adapter.notifyDataSetChanged();
    }

    public void setConfirmListener(@Nullable CompletionConfirmListener listener) {
        this.confirmListener = listener;
    }

    public void setViewFactory(@Nullable CompletionItemViewFactory factory) {
        this.viewFactory = factory;
        if (adapter != null) adapter.setViewFactory(factory);
    }

    public boolean isShowing() {
        return popupWindow != null && popupWindow.isShowing();
    }

    @Override
    public void onCompletionItemsUpdated(@NonNull List<CompletionItem> newItems) {
        items.clear();
        items.addAll(newItems);
        selectedIndex = 0;
        adapter.notifyDataSetChanged();
        if (items.isEmpty()) {
            dismiss();
        } else {
            show();
        }
    }

    @Override
    public void onCompletionDismissed() {
        dismiss();
    }

    /**
     * Handle Android KeyEvent keyCode for completion panel navigation.
     */
    public boolean handleAndroidKeyCode(int androidKeyCode) {
        if (!isShowing() || items.isEmpty()) return false;
        switch (androidKeyCode) {
            case KeyEvent.KEYCODE_ENTER:
                confirmSelected();
                return true;
            case KeyEvent.KEYCODE_ESCAPE:
                dismiss();
                return true;
            case KeyEvent.KEYCODE_DPAD_UP:
                moveSelection(-1);
                return true;
            case KeyEvent.KEYCODE_DPAD_DOWN:
                moveSelection(1);
                return true;
            default:
                return false;
        }
    }

    /**
     * Update cached cursor screen coordinates (called by SweetEditor every frame in onDraw).
     * If panel is showing, also refresh panel position.
     */
    public void updateCursorPosition(float cursorScreenX, float cursorScreenY, float cursorHeight) {
        cachedCursorX = cursorScreenX;
        cachedCursorY = cursorScreenY;
        cachedCursorHeight = cursorHeight;
        if (isShowing()) {
            applyPosition();
        }
    }

    /**
     * Calculate and apply panel position based on cached cursor coordinates.
     * cachedCursorX/Y are coordinates within anchorView, need to be converted to screen coordinates for PopupWindow positioning.
     */
    private void applyPosition() {
        PopupLayout layout = computePopupLayout();
        if (layout == null) {
            return;
        }
        applyPopupLayout(layout);
    }

    public void dismiss() {
        if (popupWindow != null && popupWindow.isShowing()) {
            PopupAnimator.animateDismiss(recyclerView, lastPlacement, () -> {
                if (popupWindow.isShowing()) {
                    popupWindow.dismiss();
                }
            });
        }
    }

    private void initPopup() {
        recyclerView = new RecyclerView(context);
        recyclerView.setLayoutManager(new LinearLayoutManager(context));

        recyclerView.setBackground(createPanelBackground());
        recyclerView.setClipToOutline(true);
        recyclerView.setPadding(
                PopupPositioner.dpToPx(context, PANEL_HORIZONTAL_PADDING_DP),
                PopupPositioner.dpToPx(context, PANEL_VERTICAL_PADDING_DP),
                PopupPositioner.dpToPx(context, PANEL_HORIZONTAL_PADDING_DP),
                PopupPositioner.dpToPx(context, PANEL_VERTICAL_PADDING_DP));
        recyclerView.setClipToPadding(false);

        adapter = new CompletionAdapter();
        recyclerView.setAdapter(adapter);

        int width = PopupPositioner.dpToPx(context, POPUP_WIDTH_DP);
        popupWindow = new PopupWindow(recyclerView, width, ViewGroup.LayoutParams.WRAP_CONTENT);
        popupWindow.setBackgroundDrawable(new ColorDrawable(Color.TRANSPARENT));
        popupWindow.setFocusable(false);
        popupWindow.setElevation(PopupPositioner.dpToPx(context, 8));
    }

    private void show() {
        PopupLayout layout = computePopupLayout();
        if (layout == null) {
            dismiss();
            return;
        }
        applyPopupSize(layout.popupWidth, layout.popupHeight);
        if (!popupWindow.isShowing()) {
            lastPlacement = layout.position.placement;
            PopupAnimator.prepareForShow(recyclerView, lastPlacement);
            popupWindow.showAtLocation(anchorView, Gravity.NO_GRAVITY,
                    layout.position.screenX, layout.position.screenY);
            applyPopupLayout(layout);
            PopupAnimator.animateShow(recyclerView, lastPlacement);
            return;
        }
        applyPopupLayout(layout);
    }

    @Nullable
    private PopupLayout computePopupLayout() {
        int gap = PopupPositioner.dpToPx(context, GAP_DP);
        int visibleRows = Math.max(1, Math.min(items.size(), MAX_VISIBLE_ITEMS));
        int popupHeight = PopupPositioner.dpToPx(context,
                ITEM_HEIGHT_DP * visibleRows + PANEL_VERTICAL_PADDING_DP * 2);

        Rect availableFrame = PopupPositioner.resolveAvailableFrame(anchorView);
        if (availableFrame.height() < PopupPositioner.dpToPx(context, ITEM_HEIGHT_DP)) {
            return null;
        }

        int desiredPopupWidth = PopupPositioner.dpToPx(context, POPUP_WIDTH_DP);
        int minPopupWidth = PopupPositioner.dpToPx(context, POPUP_MIN_WIDTH_DP);
        int availableWidth = Math.max(1, availableFrame.width() - PopupPositioner.dpToPx(context, POPUP_FRAME_PADDING_DP));
        int popupWidth = Math.min(desiredPopupWidth, Math.max(minPopupWidth, availableWidth));
        if (popupWidth > availableFrame.width()) {
            popupWidth = availableFrame.width();
        }

        int maxPopupHeight = Math.max(
                PopupPositioner.dpToPx(context, ITEM_HEIGHT_DP + PANEL_VERTICAL_PADDING_DP * 2),
                availableFrame.height() - PopupPositioner.dpToPx(context, POPUP_FRAME_PADDING_DP));
        if (popupHeight > maxPopupHeight) {
            popupHeight = maxPopupHeight;
        }

        PopupPositioner.Result position = PopupPositioner.compute(new PopupPositioner.Request(
                anchorView,
                new RectF(cachedCursorX, cachedCursorY, cachedCursorX, cachedCursorY + cachedCursorHeight),
                popupWidth,
                popupHeight,
                gap,
                0,
                POPUP_PLACEMENTS
        ));
        return new PopupLayout(position, popupWidth, popupHeight);
    }

    private void applyPopupSize(int popupWidth, int popupHeight) {
        ViewGroup.LayoutParams layoutParams = recyclerView.getLayoutParams();
        if (layoutParams == null) {
            layoutParams = new ViewGroup.LayoutParams(popupWidth, popupHeight);
        } else {
            layoutParams.width = popupWidth;
            layoutParams.height = popupHeight;
        }
        recyclerView.setLayoutParams(layoutParams);
        popupWindow.setWidth(popupWidth);
        popupWindow.setHeight(popupHeight);
    }

    private void applyPopupLayout(@NonNull PopupLayout layout) {
        lastPlacement = layout.position.placement;
        applyPopupSize(layout.popupWidth, layout.popupHeight);
        popupWindow.update(layout.position.screenX, layout.position.screenY,
                layout.popupWidth, layout.popupHeight);
    }

    @NonNull
    private GradientDrawable createPanelBackground() {
        GradientDrawable panelBg = new GradientDrawable();
        panelBg.setColor(panelBgColor);
        panelBg.setCornerRadius(PopupPositioner.dpToPx(context, 12));
        panelBg.setStroke(PopupPositioner.dpToPx(context, 1), panelBorderColor);
        return panelBg;
    }

    private void moveSelection(int delta) {
        if (items.isEmpty()) return;
        int old = selectedIndex;
        selectedIndex = Math.max(0, Math.min(items.size() - 1, selectedIndex + delta));
        if (old != selectedIndex) {
            adapter.notifyItemChanged(old);
            adapter.notifyItemChanged(selectedIndex);
            recyclerView.scrollToPosition(selectedIndex);
        }
    }

    private void confirmSelected() {
        if (selectedIndex >= 0 && selectedIndex < items.size()) {
            CompletionItem item = items.get(selectedIndex);
            dismiss();
            if (confirmListener != null) {
                confirmListener.onCompletionConfirmed(item);
            }
        }
    }

    private class CompletionAdapter extends RecyclerView.Adapter<RecyclerView.ViewHolder> {

        @Nullable private CompletionItemViewFactory factory;

        void setViewFactory(@Nullable CompletionItemViewFactory factory) {
            this.factory = factory;
        }

        @NonNull @Override
        public RecyclerView.ViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
            if (factory != null) {
                View view = factory.createItemView(parent);
                return new RecyclerView.ViewHolder(view) {};
            }
            return new DefaultViewHolder(parent);
        }

        @Override
        public void onBindViewHolder(@NonNull RecyclerView.ViewHolder holder, int position) {
            CompletionItem item = items.get(holder.getAdapterPosition());
            boolean isSelected = position == selectedIndex;
            if (factory != null) {
                factory.bindItemView(holder.itemView, item, isSelected);
            } else {
                ((DefaultViewHolder) holder).bind(item, isSelected, selectedBgColor, labelColor, detailColor);
            }
            holder.itemView.setOnClickListener(v -> {
                selectedIndex = position;
                confirmSelected();
            });
        }

        @Override
        public int getItemCount() {
            return items.size();
        }
    }

    private static class DefaultViewHolder extends RecyclerView.ViewHolder {
        private final TextView kindBadge;
        private final ImageView iconView;
        private final TextView labelView;
        private final TextView detailView;
        private final GradientDrawable rowBg;
        private final GradientDrawable badgeBg;

        DefaultViewHolder(@NonNull ViewGroup parent) {
            super(createDefaultItemView(parent.getContext()));
            kindBadge = itemView.findViewWithTag("kindBadge");
            iconView = itemView.findViewWithTag("icon");
            labelView = itemView.findViewWithTag("label");
            detailView = itemView.findViewWithTag("detail");

            rowBg = new GradientDrawable();
            rowBg.setCornerRadius(PopupPositioner.dpToPx(parent.getContext(), 6));
            itemView.setBackground(rowBg);

            badgeBg = new GradientDrawable();
            badgeBg.setCornerRadius(PopupPositioner.dpToPx(parent.getContext(), 4));
            kindBadge.setBackground(badgeBg);
        }

        void bind(@NonNull CompletionItem item, boolean isSelected, int selectedColor, int lblColor, int dtlColor) {
            labelView.setText(item.label);
            labelView.setTextColor(lblColor);
            if (item.detail != null && !item.detail.isEmpty()) {
                detailView.setVisibility(View.VISIBLE);
                detailView.setText(item.detail);
                detailView.setTextColor(dtlColor);
            } else {
                detailView.setVisibility(View.GONE);
            }

            rowBg.setColor(isSelected ? selectedColor : Color.TRANSPARENT);

            iconView.setVisibility(View.GONE);
            kindBadge.setVisibility(View.VISIBLE);
            applyKindBadge(kindBadge, item.kind);
        }

        private static void applyKindBadge(TextView badge, int kind) {
            int color;
            String letter;
            switch (kind) {
                case CompletionItem.KIND_KEYWORD:
                    color = 0xFFC678DD; letter = "K"; break;
                case CompletionItem.KIND_FUNCTION:
                    color = 0xFF61AFEF; letter = "F"; break;
                case CompletionItem.KIND_VARIABLE:
                    color = 0xFFE5C07B; letter = "V"; break;
                case CompletionItem.KIND_CLASS:
                    color = 0xFFE06C75; letter = "C"; break;
                case CompletionItem.KIND_INTERFACE:
                    color = 0xFF56B6C2; letter = "I"; break;
                case CompletionItem.KIND_MODULE:
                    color = 0xFFD19A66; letter = "M"; break;
                case CompletionItem.KIND_PROPERTY:
                    color = 0xFF98C379; letter = "P"; break;
                case CompletionItem.KIND_SNIPPET:
                    color = 0xFFBE5046; letter = "S"; break;
                default:
                    color = 0xFF7A8494; letter = "T"; break;
            }
            badge.setText(letter);
            GradientDrawable bg = (GradientDrawable) badge.getBackground();
            bg.setColor(color);
        }

        private static View createDefaultItemView(@NonNull Context context) {
            int hPadding = UiDimensions.dpToPx(context, 8);
            int vPadding = UiDimensions.dpToPx(context, 2);
            int height = UiDimensions.dpToPx(context, ITEM_HEIGHT_DP);

            android.widget.LinearLayout layout = new android.widget.LinearLayout(context);
            layout.setOrientation(android.widget.LinearLayout.HORIZONTAL);
            layout.setGravity(Gravity.CENTER_VERTICAL);
            layout.setPadding(hPadding, vPadding, hPadding, vPadding);
            layout.setLayoutParams(new ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, height));

            TextView kindBadge = new TextView(context);
            int badgeSize = UiDimensions.dpToPx(context, 18);
            android.widget.LinearLayout.LayoutParams badgeLp =
                    new android.widget.LinearLayout.LayoutParams(badgeSize, badgeSize);
            badgeLp.setMarginEnd(UiDimensions.dpToPx(context, 8));
            kindBadge.setLayoutParams(badgeLp);
            kindBadge.setGravity(Gravity.CENTER);
            kindBadge.setTextSize(10);
            kindBadge.setTextColor(0xFFFFFFFF);
            kindBadge.setTypeface(Typeface.DEFAULT_BOLD);
            kindBadge.setTag("kindBadge");
            layout.addView(kindBadge);

            ImageView icon = new ImageView(context);
            int iconSize = UiDimensions.dpToPx(context, 16);
            android.widget.LinearLayout.LayoutParams iconLp =
                    new android.widget.LinearLayout.LayoutParams(iconSize, iconSize);
            iconLp.setMarginEnd(UiDimensions.dpToPx(context, 8));
            icon.setLayoutParams(iconLp);
            icon.setTag("icon");
            icon.setVisibility(View.GONE);
            layout.addView(icon);

            TextView label = new TextView(context);
            label.setTextSize(13);
            label.setTextColor(0xFFD8DEE9);
            label.setSingleLine(true);
            label.setEllipsize(TextUtils.TruncateAt.END);
            label.setTag("label");
            android.widget.LinearLayout.LayoutParams labelLp =
                    new android.widget.LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1);
            label.setLayoutParams(labelLp);
            layout.addView(label);

            TextView detail = new TextView(context);
            detail.setTextSize(11);
            detail.setTextColor(0xFF7A8494);
            detail.setSingleLine(true);
            detail.setEllipsize(TextUtils.TruncateAt.END);
            detail.setTag("detail");
            detail.setVisibility(View.GONE);
            android.widget.LinearLayout.LayoutParams detailLp =
                    new android.widget.LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
            detailLp.setMarginStart(UiDimensions.dpToPx(context, 8));
            detail.setLayoutParams(detailLp);
            layout.addView(detail);

            return layout;
        }
    }

    private static final class PopupLayout {
        @NonNull final PopupPositioner.Result position;
        final int popupWidth;
        final int popupHeight;

        PopupLayout(@NonNull PopupPositioner.Result position, int popupWidth, int popupHeight) {
            this.position = position;
            this.popupWidth = popupWidth;
            this.popupHeight = popupHeight;
        }
    }
}
