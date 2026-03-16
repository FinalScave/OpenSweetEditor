package com.qiplat.sweeteditor.completion;

import android.content.Context;
import android.graphics.Color;
import android.graphics.drawable.ColorDrawable;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.PopupWindow;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import java.util.ArrayList;
import java.util.List;

/**
 * Completion popup controller: PopupWindow + RecyclerView.
 * <p>Cursor-following positioning, up/down key navigation, Enter to confirm, Escape to dismiss.</p>
 */
public class CompletionPopupController implements CompletionProviderManager.CompletionUpdateListener {

    public interface CompletionConfirmListener {
        void onCompletionConfirmed(@NonNull CompletionItem item);
    }

    private static final int MAX_VISIBLE_ITEMS = 6;
    private static final int ITEM_HEIGHT_DP = 32;
    private static final int POPUP_WIDTH_DP = 280;
    private static final int GAP_DP = 4;

    private final Context context;
    private final View anchorView;
    @Nullable private CompletionConfirmListener confirmListener;
    @Nullable private CompletionItemViewFactory viewFactory;

    private PopupWindow popupWindow;
    private RecyclerView recyclerView;
    private CompletionAdapter adapter;
    private final List<CompletionItem> items = new ArrayList<>();
    private int selectedIndex = 0;

    // Cached cursor screen coordinates (updated by external every frame)
    private float cachedCursorX = 0;
    private float cachedCursorY = 0;
    private float cachedCursorHeight = 0;

    public CompletionPopupController(@NonNull Context context, @NonNull View anchorView) {
        this.context = context;
        this.anchorView = anchorView;
        initPopup();
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

    // ==================== CompletionUpdateListener ====================

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

    // ==================== Keyboard Navigation ====================

    public boolean handleKeyDown(int keyCode) {
        if (!isShowing() || items.isEmpty()) return false;

        // Enter = 13 (KEYCODE_ENTER = 66, but here receives the mapped native keyCode)
        if (keyCode == 13) {
            confirmSelected();
            return true;
        }
        // Escape = 27
        if (keyCode == 27) {
            dismiss();
            return true;
        }
        // Up = 38
        if (keyCode == 38) {
            moveSelection(-1);
            return true;
        }
        // Down = 40
        if (keyCode == 40) {
            moveSelection(1);
            return true;
        }
        return false;
    }

    /**
     * Handle Android KeyEvent keyCode (KEYCODE_ENTER=66, etc.).
     */
    public boolean handleAndroidKeyCode(int androidKeyCode) {
        if (!isShowing() || items.isEmpty()) return false;
        switch (androidKeyCode) {
            case 66: // KEYCODE_ENTER
                confirmSelected();
                return true;
            case 111: // KEYCODE_ESCAPE
                dismiss();
                return true;
            case 19: // KEYCODE_DPAD_UP
                moveSelection(-1);
                return true;
            case 20: // KEYCODE_DPAD_DOWN
                moveSelection(1);
                return true;
            default:
                return false;
        }
    }

    // ==================== Panel Positioning ====================

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
        int gap = dpToPx(GAP_DP);
        int popupHeight = popupWindow.getHeight();
        if (popupHeight <= 0) popupHeight = dpToPx(ITEM_HEIGHT_DP * Math.min(items.size(), MAX_VISIBLE_ITEMS));
        int popupWidth = dpToPx(POPUP_WIDTH_DP);

        // Convert View-relative coordinates to screen coordinates
        int[] anchorLocation = new int[2];
        anchorView.getLocationOnScreen(anchorLocation);

        int screenX = anchorLocation[0] + (int) cachedCursorX;
        // Default: display below cursor (cursor bottom + gap)
        int screenY = anchorLocation[1] + (int) (cachedCursorY + cachedCursorHeight + gap);

        // Get screen height for boundary detection
        int screenHeight = anchorView.getResources().getDisplayMetrics().heightPixels;
        int screenWidth = anchorView.getResources().getDisplayMetrics().widthPixels;

        // Flip to above cursor if not enough space below
        if (screenY + popupHeight > screenHeight) {
            screenY = anchorLocation[1] + (int) cachedCursorY - popupHeight - gap;
        }

        // Right edge overflow
        if (screenX + popupWidth > screenWidth) {
            screenX = screenWidth - popupWidth;
        }
        if (screenX < 0) screenX = 0;
        // Fallback if top also overflows
        if (screenY < 0) screenY = 0;

        popupWindow.update(screenX, screenY, popupWidth, popupHeight);
    }

    public void dismiss() {
        if (popupWindow != null && popupWindow.isShowing()) {
            popupWindow.dismiss();
        }
    }

    // ==================== Internal Implementation ====================

    private void initPopup() {
        recyclerView = new RecyclerView(context);
        recyclerView.setLayoutManager(new LinearLayoutManager(context));
        recyclerView.setBackgroundColor(0xFFF5F5F5);
        adapter = new CompletionAdapter();
        recyclerView.setAdapter(adapter);

        int width = dpToPx(POPUP_WIDTH_DP);
        popupWindow = new PopupWindow(recyclerView, width, ViewGroup.LayoutParams.WRAP_CONTENT);
        popupWindow.setBackgroundDrawable(new ColorDrawable(Color.TRANSPARENT));
        popupWindow.setOutsideTouchable(true);
        popupWindow.setFocusable(false);
        popupWindow.setElevation(dpToPx(4));
    }

    private void show() {
        int maxHeight = dpToPx(ITEM_HEIGHT_DP * Math.min(items.size(), MAX_VISIBLE_ITEMS));
        popupWindow.setHeight(maxHeight);
        if (!popupWindow.isShowing()) {
            popupWindow.showAtLocation(anchorView, Gravity.NO_GRAVITY, 0, 0);
        }
        // Position near cursor immediately using cached cursor coordinates
        applyPosition();
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

    private int dpToPx(int dp) {
        return (int) (dp * context.getResources().getDisplayMetrics().density + 0.5f);
    }

    // ==================== RecyclerView Adapter ====================

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
            CompletionItem item = items.get(position);
            boolean isSelected = position == selectedIndex;
            if (factory != null) {
                factory.bindItemView(holder.itemView, item, isSelected);
            } else {
                ((DefaultViewHolder) holder).bind(item, isSelected);
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

    // ==================== Default ViewHolder ====================

    private static class DefaultViewHolder extends RecyclerView.ViewHolder {
        private final ImageView iconView;
        private final TextView labelView;
        private final TextView detailView;

        DefaultViewHolder(@NonNull ViewGroup parent) {
            super(createDefaultItemView(parent.getContext()));
            iconView = itemView.findViewWithTag("icon");
            labelView = itemView.findViewWithTag("label");
            detailView = itemView.findViewWithTag("detail");
        }

        void bind(@NonNull CompletionItem item, boolean isSelected) {
            labelView.setText(item.getLabel());
            if (item.getDetail() != null) {
                detailView.setVisibility(View.VISIBLE);
                detailView.setText(item.getDetail());
            } else {
                detailView.setVisibility(View.GONE);
            }
            itemView.setBackgroundColor(isSelected ? 0xFFD0E8FF : 0xFFF5F5F5);
            if (item.getIconId() != 0) {
                iconView.setVisibility(View.VISIBLE);
                iconView.setImageResource(item.getIconId());
            } else {
                iconView.setVisibility(View.GONE);
            }
        }

        private static View createDefaultItemView(@NonNull Context context) {
            float density = context.getResources().getDisplayMetrics().density;
            int padding = (int) (6 * density);
            int height = (int) (32 * density);

            android.widget.LinearLayout layout = new android.widget.LinearLayout(context);
            layout.setOrientation(android.widget.LinearLayout.HORIZONTAL);
            layout.setGravity(Gravity.CENTER_VERTICAL);
            layout.setPadding(padding, 0, padding, 0);
            layout.setLayoutParams(new ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, height));

            ImageView icon = new ImageView(context);
            int iconSize = (int) (16 * density);
            android.widget.LinearLayout.LayoutParams iconLp =
                    new android.widget.LinearLayout.LayoutParams(iconSize, iconSize);
            iconLp.setMarginEnd((int) (4 * density));
            icon.setLayoutParams(iconLp);
            icon.setTag("icon");
            icon.setVisibility(View.GONE);
            layout.addView(icon);

            TextView label = new TextView(context);
            label.setTextSize(13);
            label.setTextColor(0xFF333333);
            label.setSingleLine(true);
            label.setTag("label");
            android.widget.LinearLayout.LayoutParams labelLp =
                    new android.widget.LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1);
            label.setLayoutParams(labelLp);
            layout.addView(label);

            TextView detail = new TextView(context);
            detail.setTextSize(11);
            detail.setTextColor(0xFF999999);
            detail.setSingleLine(true);
            detail.setTag("detail");
            detail.setVisibility(View.GONE);
            android.widget.LinearLayout.LayoutParams detailLp =
                    new android.widget.LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
            detailLp.setMarginStart((int) (8 * density));
            detail.setLayoutParams(detailLp);
            layout.addView(detail);

            return layout;
        }
    }
}
