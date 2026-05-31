// ignore_for_file: unused_element

part of 'editor_core.dart';

class LinkedEditingModel {
  const LinkedEditingModel({
    this.groups = const [],
  });

  final List<TabStopGroup> groups;
}

class TabStopGroup {
  const TabStopGroup({
    this.index = 0,
    this.ranges = const [],
    this.defaultText = '',
  });

  final int index;
  final List<TextRange> ranges;
  final String defaultText;
}
