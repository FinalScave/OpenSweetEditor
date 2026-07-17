package com.qiplat.sweeteditor.contextmenu;

import android.content.Context;
import android.content.res.ColorStateList;
import android.graphics.Color;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.ColorDrawable;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.RippleDrawable;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.PopupWindow;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.qiplat.sweeteditor.ui.PopupAnimator;
import com.qiplat.sweeteditor.ui.PopupPositioner;

import java.util.List;

/**
 * Floating popup used to render context menu sections.
 */
public final class ContextMenuPopup {

    public interface OnMenuItemClickListener {
        void onMenuItemClick(@NonNull ContextMenuItem item);
    }

    private static final int CORNER_RADIUS_DP = 8;
    private static final int CONTAINER_ELEVATION_DP = 6;
    private static final int MIN_WIDTH_DP = 120;
    private static final int ROW_HEIGHT_DP = 36;
    private static final int ROW_HORIZONTAL_PADDING_DP = 10;
    private static final int ROW_ICON_SIZE_DP = 18;
    private static final int ROW_ICON_GAP_DP = 10;
    private static final int ROW_GAP_DP = 8;
    private static final int SECTION_DIVIDER_HEIGHT_DP = 1;
    private static final int SECTION_DIVIDER_MARGIN_H_DP = 10;
    private static final int SECTION_DIVIDER_MARGIN_V_DP = 4;
    private final Context context;
    private final PopupWindow popupWindow;
    private View contentView;

    private int bgColor;
    private int textColor;
    private int dividerColor;
    private int rippleColor;
    private int measuredWidth = -1;
    private int measuredHeight = -1;
    private int popupGeneration;
    @NonNull private PopupPositioner.Placement lastPlacement =
            PopupPositioner.Placement.of(PopupPositioner.PopupSide.BELOW, PopupPositioner.PopupAlign.START);

    @Nullable private OnMenuItemClickListener listener;
    @Nullable private List<ContextMenuSection> currentSections;

    public ContextMenuPopup(@NonNull Context context, int bgColor, int textColor, int dividerColor) {
        this.context = context;
        this.bgColor = bgColor;
        this.textColor = textColor;
        this.dividerColor = resolveDividerColor(bgColor, dividerColor);
        this.rippleColor = deriveOverlayColor(bgColor);

        contentView = new View(context);
        popupWindow = new PopupWindow(contentView,
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        popupWindow.setBackgroundDrawable(new ColorDrawable(Color.TRANSPARENT));
        popupWindow.setClippingEnabled(true);
        popupWindow.setOutsideTouchable(false);
        popupWindow.setFocusable(false);
    }

    public void setOnMenuItemClickListener(@Nullable OnMenuItemClickListener listener) {
        this.listener = listener;
    }

    public void updateTheme(int bgColor, int textColor, int dividerColor) {
        this.bgColor = bgColor;
        this.textColor = textColor;
        this.dividerColor = resolveDividerColor(bgColor, dividerColor);
        this.rippleColor = deriveOverlayColor(bgColor);
        if (currentSections != null) {
            rebuildContent(currentSections);
        }
    }

    public void setSections(@NonNull List<ContextMenuSection> sections) {
        currentSections = sections;
        rebuildContent(sections);
    }

    public void showAt(@NonNull View anchor, int screenX, int screenY,
                       @NonNull PopupPositioner.Placement placement) {
        popupGeneration++;
        if (popupWindow.isShowing()) {
            popupWindow.dismiss();
        }
        ensureMeasured();
        lastPlacement = placement;
        PopupAnimator.prepareForShow(contentView, placement);
        popupWindow.showAtLocation(anchor, Gravity.NO_GRAVITY, screenX, screenY);
        popupWindow.update(screenX, screenY, measuredWidth, measuredHeight);
        PopupAnimator.animateShow(contentView, placement);
    }

    public void dismiss() {
        currentSections = null;
        if (popupWindow.isShowing()) {
            int dismissGeneration = ++popupGeneration;
            PopupAnimator.animateDismiss(contentView, lastPlacement, () -> {
                if (dismissGeneration == popupGeneration && popupWindow.isShowing()) {
                    popupWindow.dismiss();
                }
            });
        }
    }

    public void dismissImmediate() {
        popupGeneration++;
        currentSections = null;
        if (popupWindow.isShowing()) {
            popupWindow.dismiss();
        }
    }

    public boolean isShowing() {
        return popupWindow.isShowing();
    }

    public int getPopupWidth() {
        ensureMeasured();
        return measuredWidth;
    }

    public int getPopupHeight() {
        ensureMeasured();
        return measuredHeight;
    }

    private void rebuildContent(@NonNull List<ContextMenuSection> sections) {
        View newContent = buildContentView(sections);
        popupWindow.setContentView(newContent);
        contentView = newContent;
        invalidateMeasurement();
    }

    private View buildContentView(@NonNull List<ContextMenuSection> sections) {
        LinearLayout container = new LinearLayout(context);
        container.setOrientation(LinearLayout.VERTICAL);
        boolean reserveIconSlot = hasAnyIcons(sections);
        if (MIN_WIDTH_DP > 0) {
            container.setMinimumWidth(PopupPositioner.dpToPx(context, MIN_WIDTH_DP));
        }

        GradientDrawable bg = new GradientDrawable();
        bg.setColor(bgColor);
        bg.setCornerRadius(PopupPositioner.dpToPx(context, CORNER_RADIUS_DP));
        container.setBackground(bg);
        container.setElevation(PopupPositioner.dpToPx(context, CONTAINER_ELEVATION_DP));

        for (int sectionIndex = 0; sectionIndex < sections.size(); sectionIndex++) {
            ContextMenuSection section = sections.get(sectionIndex);
            for (ContextMenuItem item : section.items) {
                if (item != null) {
                    container.addView(createRow(item, reserveIconSlot));
                }
            }
            if (sectionIndex < sections.size() - 1) {
                container.addView(createSectionDivider());
            }
        }
        return container;
    }

    private View createRow(@NonNull ContextMenuItem item, boolean reserveIconSlot) {
        LinearLayout row = new LinearLayout(context);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setMinimumHeight(PopupPositioner.dpToPx(context, ROW_HEIGHT_DP));
        row.setPadding(
                PopupPositioner.dpToPx(context, ROW_HORIZONTAL_PADDING_DP), 0,
                PopupPositioner.dpToPx(context, ROW_HORIZONTAL_PADDING_DP), 0);
        row.setBackground(createRowBackground());

        if (reserveIconSlot) {
            ImageView iconView = new ImageView(context);
            LinearLayout.LayoutParams iconLp = new LinearLayout.LayoutParams(
                    PopupPositioner.dpToPx(context, ROW_ICON_SIZE_DP),
                    PopupPositioner.dpToPx(context, ROW_ICON_SIZE_DP));
            iconLp.rightMargin = PopupPositioner.dpToPx(context, ROW_ICON_GAP_DP);
            iconView.setLayoutParams(iconLp);
            if (item.icon != null) {
                Drawable icon = cloneIcon(item.icon);
                if (icon != null) {
                    int iconColor = item.enabled ? textColor : deriveDisabledTextColor(textColor);
                    icon.setTintList(ColorStateList.valueOf(iconColor));
                    iconView.setImageDrawable(icon);
                } else {
                    iconView.setVisibility(View.INVISIBLE);
                }
            } else {
                iconView.setVisibility(View.INVISIBLE);
            }
            row.addView(iconView);
        }

        TextView labelView = new TextView(context);
        labelView.setText(item.label);
        labelView.setTextSize(12);
        labelView.setSingleLine(true);
        LinearLayout.LayoutParams labelLp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        labelView.setLayoutParams(labelLp);

        boolean hasSecondaryLabel = item.secondaryLabel != null && !item.secondaryLabel.isEmpty();

        if (item.enabled) {
            labelView.setTextColor(textColor);
            row.setOnClickListener(v -> {
                if (listener != null) {
                    listener.onMenuItemClick(item);
                }
            });
        } else {
            int disabledTextColor = deriveDisabledTextColor(textColor);
            labelView.setTextColor(disabledTextColor);
            row.setClickable(false);
        }

        row.addView(labelView);
        if (hasSecondaryLabel) {
            TextView secondaryView = new TextView(context);
            secondaryView.setText(item.secondaryLabel);
            secondaryView.setTextSize(11);
            secondaryView.setSingleLine(true);
            LinearLayout.LayoutParams secondaryLp = new LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
            secondaryLp.leftMargin = PopupPositioner.dpToPx(context, ROW_GAP_DP);
            secondaryView.setLayoutParams(secondaryLp);
            if (item.enabled) {
                secondaryView.setTextColor(deriveSecondaryTextColor(textColor));
            } else {
                secondaryView.setTextColor(Color.argb(72,
                        Color.red(textColor), Color.green(textColor), Color.blue(textColor)));
            }
            row.addView(secondaryView);
        }
        return row;
    }

    private View createSectionDivider() {
        View divider = new View(context);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, PopupPositioner.dpToPx(context, SECTION_DIVIDER_HEIGHT_DP));
        int margin = PopupPositioner.dpToPx(context, SECTION_DIVIDER_MARGIN_V_DP);
        lp.topMargin = margin;
        lp.bottomMargin = margin;
        lp.leftMargin = PopupPositioner.dpToPx(context, SECTION_DIVIDER_MARGIN_H_DP);
        lp.rightMargin = PopupPositioner.dpToPx(context, SECTION_DIVIDER_MARGIN_H_DP);
        divider.setLayoutParams(lp);
        divider.setBackgroundColor(dividerColor);
        return divider;
    }

    private RippleDrawable createRowBackground() {
        GradientDrawable mask = new GradientDrawable();
        mask.setColor(Color.WHITE);
        mask.setCornerRadius(PopupPositioner.dpToPx(context, 4));
        return new RippleDrawable(ColorStateList.valueOf(rippleColor), null, mask);
    }

    private static int deriveOverlayColor(int base) {
        float lum = Color.luminance(base);
        return lum > 0.5f ? Color.argb(30, 0, 0, 0) : Color.argb(40, 255, 255, 255);
    }

    private static int resolveDividerColor(int bgColor, int dividerColor) {
        return dividerColor != 0 ? dividerColor : deriveOverlayColor(bgColor);
    }

    private static int deriveSecondaryTextColor(int textColor) {
        return Color.argb(170,
                Color.red(textColor), Color.green(textColor), Color.blue(textColor));
    }

    private static int deriveDisabledTextColor(int textColor) {
        return Color.argb(96,
                Color.red(textColor), Color.green(textColor), Color.blue(textColor));
    }

    private static boolean hasAnyIcons(@NonNull List<ContextMenuSection> sections) {
        for (ContextMenuSection section : sections) {
            for (ContextMenuItem item : section.items) {
                if (item != null && item.icon != null) {
                    return true;
                }
            }
        }
        return false;
    }

    @Nullable
    private Drawable cloneIcon(@NonNull Drawable source) {
        Drawable.ConstantState state = source.getConstantState();
        Drawable drawable = state != null
                ? state.newDrawable(context.getResources(), context.getTheme())
                : source.mutate();
        return drawable != null ? drawable.mutate() : null;
    }

    private void invalidateMeasurement() {
        measuredWidth = -1;
        measuredHeight = -1;
    }

    private void ensureMeasured() {
        if (measuredWidth >= 0 && measuredHeight >= 0) {
            return;
        }
        contentView.measure(View.MeasureSpec.UNSPECIFIED, View.MeasureSpec.UNSPECIFIED);
        measuredWidth = contentView.getMeasuredWidth();
        measuredHeight = contentView.getMeasuredHeight();
    }
}
