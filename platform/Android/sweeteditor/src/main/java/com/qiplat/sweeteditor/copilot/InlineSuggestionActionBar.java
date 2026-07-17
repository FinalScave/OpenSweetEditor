package com.qiplat.sweeteditor.copilot;

import android.content.Context;
import android.content.res.ColorStateList;
import android.graphics.Color;
import android.graphics.RectF;
import android.graphics.drawable.ColorDrawable;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.RippleDrawable;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.LinearLayout;
import android.widget.PopupWindow;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.qiplat.sweeteditor.ui.PopupAnimator;
import com.qiplat.sweeteditor.ui.PopupPositioner;

import java.util.Arrays;
import java.util.List;

/**
 * Lightweight floating action bar for inline suggestion Accept / Dismiss interaction.
 * Pure UI component — no business logic, no editor dependency.
 */
public class InlineSuggestionActionBar {

    public interface ActionCallback {
        void onAccept();
        void onDismiss();
    }

    private static final int BAR_HEIGHT_DP = 28;
    private static final int CORNER_RADIUS_DP = 6;
    private static final int HORIZONTAL_PADDING_DP = 4;
    private static final int BUTTON_HORIZONTAL_PADDING_DP = 10;
    private static final int DIVIDER_WIDTH_DP = 1;
    private static final int DIVIDER_VERTICAL_MARGIN_DP = 6;
    private static final int GAP_DP = 2;
    private static final int ELEVATION_DP = 4;
    private static final int POPUP_FALLBACK_WIDTH_DP = 200;
    private static final List<PopupPositioner.Placement> BAR_PLACEMENTS = Arrays.asList(
            PopupPositioner.Placement.of(PopupPositioner.PopupSide.ABOVE, PopupPositioner.PopupAlign.START),
            PopupPositioner.Placement.of(PopupPositioner.PopupSide.BELOW, PopupPositioner.PopupAlign.START)
    );

    private final Context context;
    private final PopupWindow popupWindow;
    private View contentView;
    @Nullable private ActionCallback callback;

    private int bgColor;
    private int acceptTextColor;
    private int dismissTextColor;
    private int dividerColor;
    private int rippleColor;
    private int popupGeneration;
    @NonNull private PopupPositioner.Placement lastPlacement =
            PopupPositioner.Placement.of(PopupPositioner.PopupSide.ABOVE, PopupPositioner.PopupAlign.START);

    public InlineSuggestionActionBar(@NonNull Context context,
                                     int bgColor, int acceptTextColor, int dismissTextColor) {
        this.context = context;
        this.bgColor = bgColor;
        this.acceptTextColor = acceptTextColor;
        this.dismissTextColor = dismissTextColor;
        this.dividerColor = deriveOverlayColor(bgColor);
        this.rippleColor = deriveOverlayColor(bgColor);
        this.contentView = buildContentView();
        this.popupWindow = createPopupWindow(contentView);
    }

    private static int deriveOverlayColor(int bgColor) {
        int r = (bgColor >> 16) & 0xFF;
        int g = (bgColor >> 8) & 0xFF;
        int b = bgColor & 0xFF;
        float luminance = 0.299f * r + 0.587f * g + 0.114f * b;
        return luminance > 128 ? 0x22000000 : 0x22FFFFFF;
    }

    public void setCallback(@Nullable ActionCallback callback) {
        this.callback = callback;
    }

    /**
     * Update theme colors and rebuild internal views.
     * If currently showing, the popup is dismissed first.
     */
    public void applyTheme(int bgColor, int acceptTextColor, int dismissTextColor) {
        boolean wasShowing = isShowing();
        if (wasShowing) dismissImmediately();

        this.bgColor = bgColor;
        this.acceptTextColor = acceptTextColor;
        this.dismissTextColor = dismissTextColor;
        this.dividerColor = deriveOverlayColor(bgColor);
        this.rippleColor = deriveOverlayColor(bgColor);

        View newContent = buildContentView();
        popupWindow.setContentView(newContent);
        contentView = newContent;
    }

    public boolean isShowing() {
        return popupWindow.isShowing();
    }

    public void showAt(@NonNull View anchor, float cursorX, float cursorY, float cursorHeight) {
        PopupLayout layout = computeLayout(anchor, cursorX, cursorY, cursorHeight);
        popupGeneration++;
        if (!popupWindow.isShowing()) {
            lastPlacement = layout.position.placement;
            PopupAnimator.prepareForShow(contentView, lastPlacement);
            popupWindow.showAtLocation(anchor, Gravity.NO_GRAVITY,
                    layout.position.screenX, layout.position.screenY);
            applyPopupLayout(layout);
            PopupAnimator.animateShow(contentView, lastPlacement);
            return;
        }
        applyPopupLayout(layout);
        PopupAnimator.animateShow(contentView, lastPlacement);
    }

    public void updatePosition(@NonNull View anchor, float cursorX, float cursorY, float cursorHeight) {
        if (!popupWindow.isShowing()) return;
        applyPopupLayout(computeLayout(anchor, cursorX, cursorY, cursorHeight));
    }

    public void dismiss() {
        if (!popupWindow.isShowing()) return;
        int dismissGeneration = ++popupGeneration;
        PopupAnimator.animateDismiss(contentView, lastPlacement, () -> {
            if (dismissGeneration == popupGeneration && popupWindow.isShowing()) {
                popupWindow.dismiss();
            }
        });
    }

    public void dismissImmediately() {
        popupGeneration++;
        if (popupWindow.isShowing()) popupWindow.dismiss();
    }

    private View buildContentView() {
        LinearLayout bar = new LinearLayout(context);
        bar.setOrientation(LinearLayout.HORIZONTAL);
        bar.setGravity(Gravity.CENTER_VERTICAL);
        bar.setPadding(
                PopupPositioner.dpToPx(context, HORIZONTAL_PADDING_DP), 0,
                PopupPositioner.dpToPx(context, HORIZONTAL_PADDING_DP), 0);

        GradientDrawable bg = new GradientDrawable();
        bg.setColor(bgColor);
        bg.setCornerRadius(PopupPositioner.dpToPx(context, CORNER_RADIUS_DP));
        bar.setBackground(bg);

        TextView acceptBtn = createButton("Accept", acceptTextColor, true);
        acceptBtn.setOnClickListener(v -> {
            if (callback != null) callback.onAccept();
        });

        View divider = createDivider();

        TextView dismissBtn = createButton("Dismiss", dismissTextColor, false);
        dismissBtn.setOnClickListener(v -> {
            if (callback != null) callback.onDismiss();
        });

        bar.addView(acceptBtn, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.MATCH_PARENT));
        bar.addView(divider);
        bar.addView(dismissBtn, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.MATCH_PARENT));

        return bar;
    }

    private TextView createButton(String text, int textColor, boolean bold) {
        TextView btn = new TextView(context);
        btn.setText(text);
        btn.setTextSize(11);
        btn.setTextColor(textColor);
        if (bold) btn.setTypeface(btn.getTypeface(), android.graphics.Typeface.BOLD);
        btn.setGravity(Gravity.CENTER);
        btn.setPadding(
                PopupPositioner.dpToPx(context, BUTTON_HORIZONTAL_PADDING_DP), 0,
                PopupPositioner.dpToPx(context, BUTTON_HORIZONTAL_PADDING_DP), 0);

        GradientDrawable mask = new GradientDrawable();
        mask.setColor(Color.WHITE);
        mask.setCornerRadius(PopupPositioner.dpToPx(context, CORNER_RADIUS_DP));
        btn.setBackground(new RippleDrawable(
                ColorStateList.valueOf(rippleColor),
                null,
                mask));
        btn.setClickable(true);
        return btn;
    }

    private View createDivider() {
        View divider = new View(context);
        divider.setBackgroundColor(dividerColor);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                PopupPositioner.dpToPx(context, DIVIDER_WIDTH_DP), ViewGroup.LayoutParams.MATCH_PARENT);
        lp.topMargin = PopupPositioner.dpToPx(context, DIVIDER_VERTICAL_MARGIN_DP);
        lp.bottomMargin = PopupPositioner.dpToPx(context, DIVIDER_VERTICAL_MARGIN_DP);
        divider.setLayoutParams(lp);
        return divider;
    }

    private PopupWindow createPopupWindow(View content) {
        PopupWindow pw = new PopupWindow(content,
                ViewGroup.LayoutParams.WRAP_CONTENT, PopupPositioner.dpToPx(context, BAR_HEIGHT_DP));
        pw.setBackgroundDrawable(new ColorDrawable(Color.TRANSPARENT));
        pw.setOutsideTouchable(true);
        pw.setFocusable(false);
        pw.setElevation(PopupPositioner.dpToPx(context, ELEVATION_DP));
        return pw;
    }

    @NonNull
    private PopupLayout computeLayout(@NonNull View anchor,
                                      float cursorX,
                                      float cursorY,
                                      float cursorHeight) {
        int barHeight = PopupPositioner.dpToPx(context, BAR_HEIGHT_DP);
        int gap = PopupPositioner.dpToPx(context, GAP_DP);
        int popupWidth = popupWindow.getWidth();
        if (popupWidth <= 0) {
            contentView.measure(View.MeasureSpec.UNSPECIFIED, View.MeasureSpec.UNSPECIFIED);
            popupWidth = contentView.getMeasuredWidth();
        }
        if (popupWidth <= 0) {
            popupWidth = PopupPositioner.dpToPx(context, POPUP_FALLBACK_WIDTH_DP);
        }
        PopupPositioner.Result position = PopupPositioner.compute(new PopupPositioner.Request(
                anchor,
                new RectF(cursorX, cursorY, cursorX, cursorY + cursorHeight),
                popupWidth,
                barHeight,
                gap,
                0,
                BAR_PLACEMENTS
        ));
        return new PopupLayout(position, popupWidth, barHeight);
    }

    private void applyPopupLayout(@NonNull PopupLayout layout) {
        lastPlacement = layout.position.placement;
        popupWindow.update(layout.position.screenX, layout.position.screenY,
                layout.popupWidth, layout.popupHeight);
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
