package com.qiplat.sweeteditor.core;

import java.lang.foreign.Arena;

/**
 * Construction-time immutable options for EditorCore.
 * <p>
 * Fields mirror the C++ {@code EditorOptions} struct.
 * Use {@link ProtocolEncoder#packEditorOptions(EditorOptions, Arena)} to encode into the binary payload
 * expected by the native C API.
 * <p>
 * Binary layout (LE byte order):
 * <pre>
 *   f32  touch_slop
 *   i64  double_tap_timeout
 *   i64  long_press_ms
 *   f32  fling_friction
 *   f32  fling_min_velocity
 *   f32  fling_max_velocity
 *   u64  max_undo_stack_size
 *   i64  key_chord_timeout_ms
 *   u8   reveal_selection_end_on_select_all
 * </pre>
 */
public class EditorOptions {
    /** Threshold to determine if a gesture is a move; below this threshold, it's considered a tap */
    public final float touchSlop;
    /** Double-tap time threshold (milliseconds) */
    public final long doubleTapTimeout;
    /** Long press time threshold (milliseconds) */
    public final long longPressMs;
    /** Fling friction coefficient (higher = faster deceleration) */
    public final float flingFriction;
    /** Minimum fling velocity threshold in pixels/second */
    public final float flingMinVelocity;
    /** Maximum fling velocity cap in pixels/second */
    public final float flingMaxVelocity;
    /** Max undo stack size (0 = unlimited) */
    public final long maxUndoStackSize;
    /** Key chord pending timeout in milliseconds (default 2000). */
    public final long keyChordTimeoutMs;
    /** Whether selectAll() should reveal the selection end after selecting the full document. */
    public final boolean revealSelectionEndOnSelectAll;

    public EditorOptions() {
        this(10f, 300, 500, 2.0f, 30f, 12000f, 512, 2000, false);
    }

    public EditorOptions(float touchSlop, long doubleTapTimeout) {
        this(touchSlop, doubleTapTimeout, 500, 2.0f, 30f, 12000f, 512, 2000, false);
    }

    public EditorOptions(float touchSlop, long doubleTapTimeout, boolean revealSelectionEndOnSelectAll) {
        this(touchSlop, doubleTapTimeout, 500, 2.0f, 30f, 12000f, 512, 2000, revealSelectionEndOnSelectAll);
    }

    public EditorOptions(float touchSlop, long doubleTapTimeout, long longPressMs, long maxUndoStackSize) {
        this(touchSlop, doubleTapTimeout, longPressMs, 2.0f, 30f, 12000f, maxUndoStackSize, 2000, false);
    }

    public EditorOptions(float touchSlop, long doubleTapTimeout, long longPressMs,
                         float flingFriction, float flingMinVelocity, float flingMaxVelocity,
                         long maxUndoStackSize) {
        this(touchSlop, doubleTapTimeout, longPressMs, flingFriction, flingMinVelocity,
                flingMaxVelocity, maxUndoStackSize, 2000, false);
    }

    public EditorOptions(float touchSlop, long doubleTapTimeout, long longPressMs,
                         float flingFriction, float flingMinVelocity, float flingMaxVelocity,
                         long maxUndoStackSize, long keyChordTimeoutMs) {
        this(touchSlop, doubleTapTimeout, longPressMs, flingFriction, flingMinVelocity,
                flingMaxVelocity, maxUndoStackSize, keyChordTimeoutMs, false);
    }

    public EditorOptions(float touchSlop, long doubleTapTimeout, long longPressMs,
                         float flingFriction, float flingMinVelocity, float flingMaxVelocity,
                         long maxUndoStackSize, long keyChordTimeoutMs, boolean revealSelectionEndOnSelectAll) {
        this.touchSlop = touchSlop;
        this.doubleTapTimeout = doubleTapTimeout;
        this.longPressMs = longPressMs;
        this.flingFriction = flingFriction;
        this.flingMinVelocity = flingMinVelocity;
        this.flingMaxVelocity = flingMaxVelocity;
        this.maxUndoStackSize = maxUndoStackSize;
        this.keyChordTimeoutMs = keyChordTimeoutMs;
        this.revealSelectionEndOnSelectAll = revealSelectionEndOnSelectAll;
    }
}
