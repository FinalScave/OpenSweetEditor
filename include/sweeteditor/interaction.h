#ifndef SWEETEDITOR_INTERACTION_H
#define SWEETEDITOR_INTERACTION_H

#include <sweeteditor/macro.h>
#include <sweeteditor/editor_types.h>
#include <sweeteditor/visual.h>
#include <sweeteditor/gesture.h>

namespace NS_SWEETEDITOR {
  class TextLayout;

  struct InteractionContext {
    TouchConfig touch_config;
    EditorSettings* settings{nullptr};
    ViewState* view_state{nullptr};
    Size* viewport{nullptr};
    TextLayout* text_layout{nullptr};
    CaretState* caret{nullptr};
  };

  struct GestureIntent {
    bool place_cursor{false};
    bool select_word{false};
    bool toggle_fold{false};
    size_t fold_line{0};
    bool cancel_linked_editing{false};
  };

  struct InteractionResult {
    GestureResult gesture;
    GestureIntent intent;
    bool handled{false};
    bool needs_redraw{false};
  };

  struct InteractionAnimationState {
    uint32_t flags{0};
    uint32_t next_tick_delay_ms{0};
    bool needs_redraw{false};
  };

  class EditorInteraction {
  public:
    struct PendingScaleAnchor {
      bool active{false};
      PointF focus_screen;
      TextPosition anchor_position;
      float offset_x{0};
      float offset_y{0};
    };

    explicit EditorInteraction(const InteractionContext& context);

    InteractionResult handleGestureEvent(const GestureEvent& event);
    InteractionResult tickAnimations();
    InteractionAnimationState resolveAnimationState();
    uint32_t resolveInteractionFlags() const;
    void stopFling();
    void onViewportChanged();
    void onScrollbarConfigChanged();
    void resetForDocumentLoad();

    void markScrollbarInteraction();
    void computeScrollbarModels(ScrollbarModel& vertical, ScrollbarModel& horizontal) const;
    bool isPointInScrollbar(const PointF& point) const;

    PendingScaleAnchor takePendingScaleAnchor();
    void resetScaleState();
    bool isScaleGestureActive() const;

    void clearHandleCache();
    void updateHandleCache(const PointF& start, const PointF& end, float line_height);

  private:
    enum class PointerInteractionOwner {
      NONE,
      HANDLE_START,
      HANDLE_END,
      SCROLLBAR_VERTICAL,
      SCROLLBAR_HORIZONTAL,
    };

    struct PointerInteractionState {
      PointerInteractionOwner owner{PointerInteractionOwner::NONE};
      PointF start_point;
      float start_scroll_x{0};
      float start_scroll_y{0};
      float travel_x{0};
      float travel_y{0};
      float max_scroll_x{0};
      float max_scroll_y{0};

      void reset() {
        *this = {};
      }
    };

    struct EdgeScrollState {
      bool active{false};
      float speed{0};
      PointF last_screen_point;
      bool selection_drag{false};
      bool is_mouse{false};
      int64_t last_tick_time{0};
    };

    struct TransientScrollbarTimeline {
      int64_t fade_in_start_ms{0};
      int64_t last_interaction_ms{0};
      bool running{false};

      bool active() const {
        return running;
      }

      void reset() {
        fade_in_start_ms = 0;
        last_interaction_ms = 0;
        running = false;
      }
    };

    struct InteractionLifecycleState {
      bool primary_pointer_active{false};
      bool selection_drag_active{false};
      bool pointer_viewport_gesture_active{false};
      uint32_t direct_viewport_gesture_depth{0};

      void resetPointer() {
        primary_pointer_active = false;
        selection_drag_active = false;
        pointer_viewport_gesture_active = false;
      }

      void reset() {
        *this = {};
      }
    };

    PointF resolveScaleFocus(const GestureEvent& event) const;
    bool handleScrollbarGesture(const GestureEvent& event, InteractionResult& result);
    bool handleSelectionHandleGesture(const GestureEvent& event, InteractionResult& result);
    bool canShowTransientScrollbar() const;
    void markScrollbarControlInteraction();
    PointerInteractionOwner hitTestHandle(const PointF& screen_point) const;
    bool shouldPlaceCursorOnLongPress(const PointF& screen_point) const;
    void dragHandleTo(PointerInteractionOwner target, const PointF& screen_point);
    void dragSelectTo(const PointF& screen_point, bool is_mouse = false);
    void updateEdgeScrollState(const PointF& screen_point, bool selection_drag, bool is_mouse);
    void resetPointerMechanics();
    void resetPointerState();
    void resetKineticMotion();
    void resetAllInteractionState();
    GestureResult tickEdgeScroll();
    GestureResult tickFling();

    InteractionContext m_context_;
    UniquePtr<GestureHandler> m_gesture_handler_;
    UniquePtr<FlingAnimator> m_fling_;

    TransientScrollbarTimeline m_transient_scrollbar_timeline_;
    PointerInteractionState m_pointer_interaction_;
    InteractionLifecycleState m_interaction_lifecycle_;

    PendingScaleAnchor m_pending_scale_anchor_;
    bool m_scale_gesture_active_{false};

    PointF m_cached_start_handle_pos_;
    PointF m_cached_end_handle_pos_;
    float m_cached_handle_height_{0};
    bool m_cached_handles_valid_{false};

    EdgeScrollState m_edge_scroll_;
  };
}

#endif //SWEETEDITOR_INTERACTION_H
