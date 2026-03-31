import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'completion/completion_types.dart';
import 'copilot/inline_suggestion_bar_widget.dart';
import 'copilot/inline_suggestion_types.dart';
import 'decoration/decoration_types.dart';
import 'editor_core.dart' as core;
import 'editor_settings.dart';
import 'editor_types.dart';
import 'event/editor_event.dart';
import 'event/editor_event_bus.dart';
import 'newline/newline_action_provider_manager.dart';
import 'newline/newline_types.dart';
import 'selection/selection_menu_controller.dart';
import 'selection/selection_menu_widget.dart';
import 'selection/selection_types.dart';
import 'widget/editor_canvas_painter.dart';
import 'widget/editor_overlay.dart';
import 'widget/editor_text_measurer.dart';

export 'completion/completion_types.dart';
export 'copilot/inline_suggestion_types.dart';
export 'decoration/decoration_types.dart';
export 'editor_settings.dart';
export 'editor_types.dart';
export 'event/editor_event.dart';
export 'newline/newline_types.dart';
export 'selection/selection_types.dart';

part 'widget/sweet_editor_controller.dart';
part 'completion/completion_provider_manager.dart';
part 'completion/completion_popup_controller.dart';
part 'completion/completion_popup_widget.dart';
part 'copilot/inline_suggestion_controller.dart';
part 'decoration/decoration_provider_manager.dart';
part 'widget/editor_session.dart';
part 'widget/editor_interaction_controller.dart';
part 'widget/editor_overlay_coordinator.dart';
part 'widget/sweet_editor_widget.dart';
