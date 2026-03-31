import 'package:flutter/foundation.dart';

class EditorOverlayState<T> {
  const EditorOverlayState.hidden() : data = null;

  const EditorOverlayState.visible(this.data);

  final T? data;

  bool get isVisible => data != null;
}

class EditorOverlayBinding<T> {
  const EditorOverlayBinding({
    required this.show,
    required this.update,
    required this.hide,
  });

  final ValueSetter<T> show;
  final ValueSetter<T> update;
  final VoidCallback hide;
}
