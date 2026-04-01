#ifndef SWEETEDITOR_INTERACTION_H
#define SWEETEDITOR_INTERACTION_H

#include <macro.h>
#include <visual.h>
#include <gesture.h>

namespace NS_SWEETEDITOR {
  class EditorCore;
  class TextLayout;
  struct EditorSettings;
  struct ViewState;
  struct Viewport;

  struct InteractionContext {
    TouchConfig touch_config;
    EditorSettings* settings {nullptr};
    ViewState* view_state {nullptr};
    Viewport* viewport {nullptr};
    TextLayout* text_layout {nullptr};
  };

  class EditorInteraction {
  public:
    struct PendingScaleAnchor {
      bool active {false};
      PointF focus_screen;
      TextPosition anchor_position;
      float offset_x {0};
      float offset_y {0};
    };

    explicit EditorInteraction(const InteractionContext& context);

    GestureResult handleGestureEvent(EditorCore& core, const GestureEvent& event);
    GestureResult tickEdgeScroll(TextPosition& cursor_position);
    GestureResult tickFling(const TextPosition& cursor_position);
    GestureResult tickAnimations(TextPosition& cursor_position);
    void stopFling();

    void setSelection(const TextRange& range);
    void clearSelection();
    const TextRange& selection() const;
    bool hasSelection() const;

    void markScrollbarInteraction();
    void computeScrollbarModels(ScrollbarModel& vertical, ScrollbarModel& horizontal) const;

    PendingScaleAnchor takePendingScaleAnchor();
    void resetScaleState();
    bool isScaleGestureActive() const;

    void clearHandleCache();
    void updateHandleCache(const PointF& start, const PointF& end, float line_height);

  private:
    enum class HandleDragTarget { NONE, START, END };
    enum class ScrollbarDragTarget { NONE, VERTICAL, HORIZONTAL };

    struct EdgeScrollState {
      bool active {false};
      float speed {0};
      PointF last_screen_point;
      bool is_handle_drag {false};
      bool is_mouse {false};
      int64_t last_tick_time {0};
    };

    void fillGestureResult(const TextPosition& cursor_position, GestureResult& result) const;
    PointF resolveScaleFocus(const GestureEvent& event) const;
    bool handleScrollbarGesture(TextPosition& cursor_position, const GestureEvent& event, GestureResult& result);
    HandleDragTarget hitTestHandle(const PointF& screen_point) const;
    void dragHandleTo(TextPosition& cursor_position, HandleDragTarget target, const PointF& screen_point);
    void dragSelectTo(TextPosition& cursor_position, const PointF& screen_point, bool is_mouse = false);
    void updateEdgeScrollState(const PointF& screen_point, bool is_handle_drag, bool is_mouse);

    InteractionContext m_context_;
    UPtr<GestureHandler> m_gesture_handler_;
    UPtr<FlingAnimator> m_fling_;

    int64_t m_scrollbar_last_interaction_ms_ {0};
    int64_t m_scrollbar_cycle_start_ms_ {0};
    ScrollbarDragTarget m_dragging_scrollbar_ {ScrollbarDragTarget::NONE};
    PointF m_scrollbar_drag_start_point_;
    float m_scrollbar_drag_start_scroll_x_ {0};
    float m_scrollbar_drag_start_scroll_y_ {0};
    float m_scrollbar_drag_travel_x_ {0};
    float m_scrollbar_drag_travel_y_ {0};
    float m_scrollbar_drag_max_scroll_x_ {0};
    float m_scrollbar_drag_max_scroll_y_ {0};

    PendingScaleAnchor m_pending_scale_anchor_;
    bool m_scale_gesture_active_ {false};

    HandleDragTarget m_dragging_handle_ {HandleDragTarget::NONE};
    PointF m_cached_start_handle_pos_;
    PointF m_cached_end_handle_pos_;
    float m_cached_handle_height_ {0};
    bool m_cached_handles_valid_ {false};

    EdgeScrollState m_edge_scroll_;
    TextRange m_selection_;
    bool m_has_selection_ {false};
  };
}

#endif //SWEETEDITOR_INTERACTION_H
