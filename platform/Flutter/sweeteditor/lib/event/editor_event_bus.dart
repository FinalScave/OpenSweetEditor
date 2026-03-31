import 'dart:async';

import 'editor_event.dart';

/// Generic editor event bus backed by a Dart broadcast stream.
class EditorEventBus {
  final StreamController<EditorEvent> _controller =
      StreamController<EditorEvent>.broadcast();

  Stream<T> on<T extends EditorEvent>() {
    return _controller.stream.where((event) => event is T).cast<T>();
  }

  void publish(EditorEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  Future<void> close() {
    return _controller.close();
  }
}
