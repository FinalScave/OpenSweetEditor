package com.qiplat.sweeteditor.ui;

import android.content.Context;
import android.graphics.Rect;
import android.graphics.RectF;
import android.os.Build;
import android.view.View;
import android.view.WindowInsets;

import androidx.annotation.NonNull;

import java.util.List;

/**
 * Shared popup positioning helper for Android overlay components.
 */
public final class PopupPositioner {

    public enum PopupSide {
        ABOVE,
        BELOW,
        LEFT,
        RIGHT
    }

    public enum PopupAlign {
        START,
        CENTER,
        END
    }

    public static final class Placement {
        @NonNull public final PopupSide side;
        @NonNull public final PopupAlign align;

        public Placement(@NonNull PopupSide side, @NonNull PopupAlign align) {
            this.side = side;
            this.align = align;
        }

        @NonNull
        public static Placement of(@NonNull PopupSide side, @NonNull PopupAlign align) {
            return new Placement(side, align);
        }
    }

    public static final class Request {
        @NonNull public final View anchorView;
        @NonNull public final RectF anchorRectInView;
        public final int popupWidth;
        public final int popupHeight;
        public final int gapPx;
        public final int clearancePx;
        @NonNull public final List<Placement> preferredPlacements;

        public Request(@NonNull View anchorView,
                       @NonNull RectF anchorRectInView,
                       int popupWidth,
                       int popupHeight,
                       int gapPx,
                       int clearancePx,
                       @NonNull List<Placement> preferredPlacements) {
            this.anchorView = anchorView;
            this.anchorRectInView = anchorRectInView;
            this.popupWidth = popupWidth;
            this.popupHeight = popupHeight;
            this.gapPx = gapPx;
            this.clearancePx = clearancePx;
            this.preferredPlacements = preferredPlacements;
        }
    }

    public static final class Result {
        public final int screenX;
        public final int screenY;
        @NonNull public final Placement placement;
        @NonNull public final Rect availableFrame;

        public Result(int screenX, int screenY,
                      @NonNull Placement placement,
                      @NonNull Rect availableFrame) {
            this.screenX = screenX;
            this.screenY = screenY;
            this.placement = placement;
            this.availableFrame = availableFrame;
        }
    }

    private static final int KEYBOARD_FALLBACK_THRESHOLD_DP = 80;
    private static final Placement DEFAULT_PLACEMENT = Placement.of(PopupSide.BELOW, PopupAlign.CENTER);

    private PopupPositioner() {
    }

    public static int dpToPx(@NonNull Context context, int dp) {
        return UiDimensions.dpToPx(context, dp);
    }

    @NonNull
    public static Rect resolveVisibleFrame(@NonNull View anchorView) {
        Rect visibleFrame = new Rect();
        anchorView.getWindowVisibleDisplayFrame(visibleFrame);
        if (visibleFrame.width() <= 0 || visibleFrame.height() <= 0) {
            int screenWidth = anchorView.getResources().getDisplayMetrics().widthPixels;
            int screenHeight = anchorView.getResources().getDisplayMetrics().heightPixels;
            visibleFrame.set(0, 0, screenWidth, screenHeight);
        }

        int imeBottom = 0;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            WindowInsets rootInsets = anchorView.getRootWindowInsets();
            if (rootInsets != null) {
                imeBottom = rootInsets.getInsets(WindowInsets.Type.ime()).bottom;
            }
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            WindowInsets rootInsets = anchorView.getRootWindowInsets();
            if (rootInsets != null) {
                int systemBottom = rootInsets.getSystemWindowInsetBottom();
                int stableBottom = rootInsets.getStableInsetBottom();
                imeBottom = Math.max(0, systemBottom - stableBottom);
            }
        }

        if (imeBottom > 0) {
            View rootView = anchorView.getRootView();
            int rootHeight = rootView != null ? rootView.getHeight() : 0;
            if (rootView != null && rootHeight > 0) {
                int[] rootLocation = new int[2];
                rootView.getLocationOnScreen(rootLocation);
                int imeTop = rootLocation[1] + rootHeight - imeBottom;
                if (imeTop > visibleFrame.top && imeTop < visibleFrame.bottom) {
                    visibleFrame.bottom = imeTop;
                }
            } else if (imeBottom < visibleFrame.height()) {
                visibleFrame.bottom = visibleFrame.bottom - imeBottom;
            }
        }

        if (imeBottom <= 0) {
            View rootView = anchorView.getRootView();
            if (rootView != null) {
                Rect rootVisible = new Rect();
                rootView.getWindowVisibleDisplayFrame(rootVisible);
                int keyboardHeight = rootView.getHeight() - rootVisible.height();
                int keyboardThreshold = dpToPx(anchorView.getContext(), KEYBOARD_FALLBACK_THRESHOLD_DP);
                if (keyboardHeight > keyboardThreshold) {
                    int[] rootLocation = new int[2];
                    rootView.getLocationOnScreen(rootLocation);
                    int imeTop = rootLocation[1] + rootVisible.bottom;
                    if (imeTop > visibleFrame.top && imeTop < visibleFrame.bottom) {
                        visibleFrame.bottom = imeTop;
                    }
                }
            }
        }

        return visibleFrame;
    }

    @NonNull
    public static Rect resolveAvailableFrame(@NonNull View anchorView) {
        Rect visibleFrame = resolveVisibleFrame(anchorView);
        int[] anchorLocation = new int[2];
        anchorView.getLocationOnScreen(anchorLocation);
        Rect anchorFrame = new Rect(
                anchorLocation[0],
                anchorLocation[1],
                anchorLocation[0] + anchorView.getWidth(),
                anchorLocation[1] + anchorView.getHeight());
        Rect availableFrame = new Rect(visibleFrame);
        if (!availableFrame.intersect(anchorFrame)) {
            if (anchorFrame.width() > 0 && anchorFrame.height() > 0) {
                return anchorFrame;
            }
            return visibleFrame;
        }
        return availableFrame;
    }

    @NonNull
    public static Result compute(@NonNull Request request) {
        Rect availableFrame = resolveAvailableFrame(request.anchorView);
        int[] anchorLocation = new int[2];
        request.anchorView.getLocationOnScreen(anchorLocation);

        RectF anchorRect = new RectF(request.anchorRectInView);
        anchorRect.offset(anchorLocation[0], anchorLocation[1]);

        int popupWidth = Math.max(1, request.popupWidth);
        int popupHeight = Math.max(1, request.popupHeight);
        boolean isRtl = request.anchorView.getLayoutDirection() == View.LAYOUT_DIRECTION_RTL;

        Candidate bestCandidate = null;
        List<Placement> placements = request.preferredPlacements;
        if (placements.isEmpty()) {
            placements = java.util.Collections.singletonList(DEFAULT_PLACEMENT);
        }
        for (Placement placement : placements) {
            Candidate candidate = buildCandidate(anchorRect, popupWidth, popupHeight, request.gapPx,
                    request.clearancePx, placement, isRtl, availableFrame);
            if (candidate.overflowPx == 0) {
                return buildResult(candidate, availableFrame, popupWidth, popupHeight);
            }
            if (bestCandidate == null || candidate.overflowPx < bestCandidate.overflowPx) {
                bestCandidate = candidate;
            }
        }

        if (bestCandidate == null) {
            bestCandidate = buildCandidate(anchorRect, popupWidth, popupHeight, request.gapPx,
                    request.clearancePx, DEFAULT_PLACEMENT, isRtl, availableFrame);
        }
        return buildResult(bestCandidate, availableFrame, popupWidth, popupHeight);
    }

    @NonNull
    private static Result buildResult(@NonNull Candidate candidate,
                                      @NonNull Rect availableFrame,
                                      int popupWidth,
                                      int popupHeight) {
        int minX = availableFrame.left;
        int maxX = availableFrame.left + Math.max(0, availableFrame.width() - popupWidth);
        int minY = availableFrame.top;
        int maxY = availableFrame.top + Math.max(0, availableFrame.height() - popupHeight);
        int clampedX = clamp(candidate.x, minX, maxX);
        int clampedY = clamp(candidate.y, minY, maxY);
        return new Result(clampedX, clampedY, candidate.placement, new Rect(availableFrame));
    }

    @NonNull
    private static Candidate buildCandidate(@NonNull RectF anchorRect,
                                            int popupWidth,
                                            int popupHeight,
                                            int gapPx,
                                            int clearancePx,
                                            @NonNull Placement placement,
                                            boolean isRtl,
                                            @NonNull Rect availableFrame) {
        float x;
        float y;
        switch (placement.side) {
            case ABOVE:
                x = resolveHorizontalAlignedX(anchorRect, popupWidth, placement.align, isRtl);
                y = anchorRect.top - popupHeight - gapPx;
                break;
            case BELOW:
                x = resolveHorizontalAlignedX(anchorRect, popupWidth, placement.align, isRtl);
                y = anchorRect.bottom + gapPx + clearancePx;
                break;
            case LEFT:
                x = anchorRect.left - popupWidth - gapPx;
                y = resolveVerticalAlignedY(anchorRect, popupHeight, placement.align);
                break;
            case RIGHT:
            default:
                x = anchorRect.right + gapPx + clearancePx;
                y = resolveVerticalAlignedY(anchorRect, popupHeight, placement.align);
                break;
        }

        int screenX = Math.round(x);
        int screenY = Math.round(y);
        int overflowLeft = Math.max(0, availableFrame.left - screenX);
        int overflowTop = Math.max(0, availableFrame.top - screenY);
        int overflowRight = Math.max(0, screenX + popupWidth - availableFrame.right);
        int overflowBottom = Math.max(0, screenY + popupHeight - availableFrame.bottom);
        int overflowPx = overflowLeft + overflowTop + overflowRight + overflowBottom;
        return new Candidate(screenX, screenY, placement, overflowPx);
    }

    private static float resolveHorizontalAlignedX(@NonNull RectF anchorRect,
                                                   int popupWidth,
                                                   @NonNull PopupAlign align,
                                                   boolean isRtl) {
        switch (align) {
            case START:
                return isRtl ? anchorRect.right - popupWidth : anchorRect.left;
            case END:
                return isRtl ? anchorRect.left : anchorRect.right - popupWidth;
            case CENTER:
            default:
                return anchorRect.centerX() - popupWidth * 0.5f;
        }
    }

    private static float resolveVerticalAlignedY(@NonNull RectF anchorRect,
                                                 int popupHeight,
                                                 @NonNull PopupAlign align) {
        switch (align) {
            case START:
                return anchorRect.top;
            case END:
                return anchorRect.bottom - popupHeight;
            case CENTER:
            default:
                return anchorRect.centerY() - popupHeight * 0.5f;
        }
    }

    private static int clamp(int value, int min, int max) {
        return Math.max(min, Math.min(max, value));
    }

    private static final class Candidate {
        final int x;
        final int y;
        @NonNull final Placement placement;
        final int overflowPx;

        Candidate(int x, int y, @NonNull Placement placement, int overflowPx) {
            this.x = x;
            this.y = y;
            this.placement = placement;
            this.overflowPx = overflowPx;
        }
    }
}
