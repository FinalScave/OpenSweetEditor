import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sweeteditor/core/editor_core.dart' as core;
import 'package:sweeteditor/sweeteditor.dart';

import 'demo_completion_provider.dart';
import 'demo_decoration_provider.dart';
import 'demo_file_metadata.dart';

void main() {
  runApp(const SweetEditorDemoApp());
}

class SweetEditorDemoApp extends StatelessWidget {
  const SweetEditorDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SweetEditor Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      home: const EditorDemoPage(),
    );
  }
}

class EditorDemoPage extends StatefulWidget {
  const EditorDemoPage({super.key});

  @override
  State<EditorDemoPage> createState() => _EditorDemoPageState();
}

class _EditorDemoPageState extends State<EditorDemoPage> {
  static const int _styleColor = EditorTheme.styleUserBase + 1;
  static const List<MapEntry<String, String>> _sampleAssets = [
    MapEntry('example.java', 'assets/demo_shared/files/example.java'),
    MapEntry('example.kt', 'assets/demo_shared/files/example.kt'),
    MapEntry('example.lua', 'assets/demo_shared/files/example.lua'),
    MapEntry('gc.cpp', 'assets/demo_shared/files/gc.cpp'),
  ];

  late final SweetEditorController _controller;
  late final EditorSettings _editorSettings;
  StreamSubscription<TextChangedEvent>? _textChangedSub;
  StreamSubscription<CursorChangedEvent>? _cursorChangedSub;
  StreamSubscription<CodeLensClickEvent>? _codeLensClickSub;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _replaceController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isDarkTheme = true;
  core.WrapMode _wrapMode = core.WrapMode.none;
  String _statusText = 'Ready';
  String _editorText = '';
  EditorMetadata? _editorMetadata;
  int _activeSampleIndex = 0;
  bool _isLoadingSample = false;
  int _loadRequestId = 0;
  Timer? _suggestionTimer;
  bool _searchVisible = false;
  bool _replaceVisible = false;
  bool _searchCaseSensitive = false;
  bool _searchWholeWord = false;
  bool _searchUseRegex = false;
  core.SearchState _searchState = const core.SearchState();

  @override
  void initState() {
    super.initState();
    _controller = SweetEditorController();
    _editorSettings = EditorSettings()
      ..setFoldArrowMode(core.FoldArrowMode.auto)
      ..setCurrentLineRenderMode(core.CurrentLineRenderMode.border)
      ..setMaxGutterIcons(1);
    _controller.whenReady(() {
      unawaited(_setupEditor());
    });
  }

  @override
  void dispose() {
    _suggestionTimer?.cancel();
    _textChangedSub?.cancel();
    _cursorChangedSub?.cancel();
    _codeLensClickSub?.cancel();
    _searchController.dispose();
    _replaceController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _setupEditor() async {
    _controller.addCompletionProvider(DemoCompletionProvider());
    try {
      await DemoDecorationProvider.ensureSweetLineReady();
      _controller.addDecorationProvider(DemoDecorationProvider(_controller));
    } catch (_) {
      _updateStatus('Failed to initialize SweetLine');
    }

    _textChangedSub = _controller.onTextChanged.listen(_onTextChanged);
    _cursorChangedSub = _controller.onCursorChanged.listen(_onCursorChanged);
    _codeLensClickSub = _controller.onCodeLensClick.listen(_onCodeLensClick);

    _controller.setInlineSuggestionListener(
      _DemoSuggestionListener(
        onAccepted: () => _updateStatus('Accepted suggestion'),
        onDismissed: () => _updateStatus('Dismissed suggestion'),
      ),
    );
    await _loadSampleByIndex(_activeSampleIndex);
  }

  void _onTextChanged(TextChangedEvent e) {
    final changeSummary = e.changes
        .map(
          (change) =>
              '${change.range.start.line}:${change.range.start.column}'
              '-${change.range.end.line}:${change.range.end.column}'
              ' ${change.newText}',
        )
        .join(', ');
    _updateStatus('${e.action?.name ?? 'unknown'} [$changeSummary]');
  }

  void _onCursorChanged(CursorChangedEvent e) {
    _scheduleSuggestionIfAtLineEnd(e);
  }

  void _onCodeLensClick(CodeLensClickEvent e) {
    _updateStatus(
      'CodeLens ${_describeCodeLensCommand(e.commandId)} at line ${e.line + 1}',
    );
  }

  void _scheduleSuggestionIfAtLineEnd(CursorChangedEvent event) {
    _suggestionTimer?.cancel();
    _suggestionTimer = null;

    if (_controller.hasSelection) return;

    final line = event.cursorPosition.line;
    final column = event.cursorPosition.column;
    final lineText = _controller.getLineText(line);
    if (lineText.isEmpty ||
        column != lineText.length ||
        lineText.trim().isEmpty) {
      return;
    }

    _suggestionTimer = Timer(const Duration(seconds: 1), () {
      if (_controller.isInlineSuggestionShowing) return;
      const demoText =
          '\nvoid autoGenerated() {\n    std::cout << "hello" << std::endl;\n    return;\n}';
      _controller.showInlineSuggestion(
        InlineSuggestion(line: line, column: column, text: demoText),
      );
    });
  }

  void _toggleTheme() {
    setState(() {
      _isDarkTheme = !_isDarkTheme;
    });
    _updateStatus(_isDarkTheme ? 'Dark theme' : 'Light theme');
  }

  void _cycleWrapMode() {
    final modes = core.WrapMode.values;
    setState(() {
      _wrapMode = modes[(_wrapMode.value + 1) % modes.length];
      _editorSettings.setWrapMode(_wrapMode);
    });
    _updateStatus('WrapMode: ${_wrapMode.name}');
  }

  void _updateStatus(String message) {
    if (mounted) setState(() => _statusText = message);
  }

  String _describeCodeLensCommand(int commandId) {
    switch (commandId) {
      case codeLensRun:
        return '▶ Run';
      case codeLensDebug:
        return '◎ Debug';
      default:
        return 'Command#$commandId';
    }
  }

  Future<void> _loadSampleByIndex(int index) async {
    if (index < 0 || index >= _sampleAssets.length) {
      return;
    }
    final requestId = ++_loadRequestId;
    final sample = _sampleAssets[index];
    _suggestionTimer?.cancel();
    _controller.dismissInlineSuggestion();
    _controller.dismissCompletion();
    _clearSearchState();
    if (mounted) {
      setState(() {
        _activeSampleIndex = index;
        _isLoadingSample = true;
      });
    }

    try {
      final text = await rootBundle.loadString(sample.value);
      if (!mounted || requestId != _loadRequestId) {
        return;
      }
      setState(() {
        _editorMetadata = DemoFileMetadata(sample.key);
        _editorText = text;
      });
      _updateStatus('Loaded: ${sample.key}');
    } catch (e) {
      if (!mounted || requestId != _loadRequestId) {
        return;
      }
      _updateStatus('Failed to load ${sample.key}');
    } finally {
      if (mounted && requestId == _loadRequestId) {
        setState(() {
          _isLoadingSample = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _isDarkTheme;
    final bgColor = Color(isDark ? 0xFF1B1E24 : 0xFFFAFBFD);
    final fgColor = Color(isDark ? 0xFFD7DEE9 : 0xFF1F2937);
    final secondaryColor = Color(isDark ? 0xFF5E6778 : 0xFF8A94A6);

    final theme = _isDarkTheme ? EditorTheme.dark() : EditorTheme.light();
    theme.defineTextStyle(
      _styleColor,
      core.TextStyle(color: isDark ? 0xFFB5CEA8 : 0xFF098658),
    );

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Shortcuts(
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.keyF, control: true):
                _OpenSearchIntent(false),
            SingleActivator(LogicalKeyboardKey.keyF, meta: true):
                _OpenSearchIntent(false),
            SingleActivator(LogicalKeyboardKey.keyH, control: true):
                _OpenSearchIntent(true),
            SingleActivator(LogicalKeyboardKey.keyH, meta: true):
                _OpenSearchIntent(true),
            SingleActivator(LogicalKeyboardKey.escape): _CloseSearchIntent(),
            SingleActivator(LogicalKeyboardKey.enter, shift: true):
                _FindPreviousSearchIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              _OpenSearchIntent: CallbackAction<_OpenSearchIntent>(
                onInvoke: (intent) {
                  _openSearch(replaceMode: intent.replaceMode);
                  return null;
                },
              ),
              _CloseSearchIntent: CallbackAction<_CloseSearchIntent>(
                onInvoke: (_) {
                  if (_searchVisible) {
                    _closeSearch();
                  }
                  return null;
                },
              ),
              _FindPreviousSearchIntent:
                  CallbackAction<_FindPreviousSearchIntent>(
                    onInvoke: (_) {
                      if (_searchVisible) {
                        _findPreviousSearchMatch();
                      }
                      return null;
                    },
                  ),
            },
            child: Focus(
              autofocus: true,
              child: Column(
                children: [
                  _buildToolbar(bgColor, fgColor),
                  _buildSearchPanel(bgColor, fgColor, secondaryColor),
                  Expanded(
                    child: SweetEditorWidget(
                      controller: _controller,
                      text: _editorText,
                      theme: theme,
                      settings: _editorSettings,
                      metadata: _editorMetadata,
                      fontFamily:
                          defaultTargetPlatform == TargetPlatform.iOS ||
                              defaultTargetPlatform == TargetPlatform.macOS
                          ? 'Menlo'
                          : 'monospace',
                      fontSize: 14,
                    ),
                  ),
                  _buildStatusBar(bgColor, secondaryColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar(Color bgColor, Color fgColor) {
    final secondaryColor = Color(_isDarkTheme ? 0xFF5E6778 : 0xFF8A94A6);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: bgColor,
      child: Row(
        children: [
          Expanded(child: _buildSamplePicker(bgColor, fgColor, secondaryColor)),
          _iconButton(Icons.search, fgColor, () {
            _openSearch(replaceMode: false);
          }),
          _iconButton(Icons.find_replace, fgColor, () {
            _openSearch(replaceMode: true);
          }),
          _iconButton(Icons.undo, fgColor, () {
            if (_isLoadingSample) return;
            if (_controller.canUndo) {
              _controller.undo();
              _updateStatus('Undo');
            } else {
              _updateStatus('Nothing to undo');
            }
          }),
          _iconButton(Icons.redo, fgColor, () {
            if (_isLoadingSample) return;
            if (_controller.canRedo) {
              _controller.redo();
              _updateStatus('Redo');
            } else {
              _updateStatus('Nothing to redo');
            }
          }),
          _iconButton(Icons.brightness_6, fgColor, _toggleTheme),
          _iconButton(Icons.wrap_text, fgColor, _cycleWrapMode),
        ],
      ),
    );
  }

  Widget _buildSearchPanel(Color bgColor, Color fgColor, Color secondaryColor) {
    if (!_searchVisible) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      color: bgColor,
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: (_) => _performSearch(),
                    onSubmitted: (_) => _findNextSearchMatch(),
                    style: TextStyle(color: fgColor, fontSize: 13),
                    decoration: _searchFieldDecoration(
                      'Find',
                      fgColor,
                      secondaryColor,
                    ),
                  ),
                ),
              ),
              _iconButton(Icons.subdirectory_arrow_left, fgColor, () {
                _insertNewlineToken(_searchController);
              }),
              SizedBox(
                width: 56,
                child: Text(
                  _searchCounterText(),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: secondaryColor, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _searchToggleButton(
                'Aa',
                _searchCaseSensitive,
                fgColor,
                secondaryColor,
                () {
                  setState(() => _searchCaseSensitive = !_searchCaseSensitive);
                  _performSearch();
                },
              ),
              _searchToggleButton(
                'Word',
                _searchWholeWord,
                fgColor,
                secondaryColor,
                () {
                  setState(() => _searchWholeWord = !_searchWholeWord);
                  _performSearch();
                },
              ),
              _searchToggleButton(
                '.*',
                _searchUseRegex,
                fgColor,
                secondaryColor,
                () {
                  setState(() => _searchUseRegex = !_searchUseRegex);
                  _performSearch();
                },
              ),
              _iconButton(
                Icons.keyboard_arrow_up,
                fgColor,
                _findPreviousSearchMatch,
              ),
              _iconButton(
                Icons.keyboard_arrow_down,
                fgColor,
                _findNextSearchMatch,
              ),
              _iconButton(Icons.close, fgColor, _closeSearch),
            ],
          ),
          if (_replaceVisible) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 34,
                    child: TextField(
                      controller: _replaceController,
                      onSubmitted: (_) => _replaceCurrentSearchMatch(),
                      style: TextStyle(color: fgColor, fontSize: 13),
                      decoration: _searchFieldDecoration(
                        'Replace',
                        fgColor,
                        secondaryColor,
                      ),
                    ),
                  ),
                ),
                _iconButton(Icons.subdirectory_arrow_left, fgColor, () {
                  _insertNewlineToken(_replaceController);
                }),
                TextButton(
                  onPressed: _replaceCurrentSearchMatch,
                  child: Text('Replace', style: TextStyle(color: fgColor)),
                ),
                TextButton(
                  onPressed: _replaceAllSearchMatches,
                  child: Text('All', style: TextStyle(color: fgColor)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _searchFieldDecoration(
    String hint,
    Color fgColor,
    Color secondaryColor,
  ) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: secondaryColor, fontSize: 13),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    filled: true,
    fillColor: secondaryColor.withValues(alpha: 0.10),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: secondaryColor.withValues(alpha: 0.30)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: secondaryColor.withValues(alpha: 0.30)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: fgColor.withValues(alpha: 0.65)),
    ),
  );

  Widget _searchToggleButton(
    String label,
    bool selected,
    Color fgColor,
    Color secondaryColor,
    VoidCallback onPressed,
  ) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(36, 30),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        foregroundColor: selected ? fgColor : secondaryColor,
        backgroundColor: selected
            ? secondaryColor.withValues(alpha: 0.18)
            : null,
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _buildSamplePicker(
    Color bgColor,
    Color fgColor,
    Color secondaryColor,
  ) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.centerLeft,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _activeSampleIndex,
          isExpanded: true,
          dropdownColor: bgColor,
          iconEnabledColor: secondaryColor,
          style: TextStyle(color: fgColor, fontSize: 13),
          onChanged: _isLoadingSample
              ? null
              : (value) {
                  if (value == null || value == _activeSampleIndex) {
                    return;
                  }
                  unawaited(_loadSampleByIndex(value));
                },
          items: [
            for (var i = 0; i < _sampleAssets.length; i++)
              DropdownMenuItem<int>(
                value: i,
                child: Text(
                  _sampleAssets[i].key,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _iconButton(IconData icon, Color color, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, size: 20, color: color),
      onPressed: onPressed,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }

  Widget _buildStatusBar(Color bgColor, Color textColor) {
    final fileName = _sampleAssets[_activeSampleIndex].key;
    final status = _isLoadingSample ? 'Loading $fileName...' : _statusText;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      color: bgColor,
      child: Text(
        '$fileName  |  $status',
        style: TextStyle(color: textColor, fontSize: 11),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  void _openSearch({required bool replaceMode}) {
    setState(() {
      _searchVisible = true;
      _replaceVisible = replaceMode;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchFocusNode.requestFocus();
      _searchController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _searchController.text.length,
      );
    });
    _performSearch();
  }

  void _closeSearch() {
    _clearSearchState();
    setState(() {
      _searchVisible = false;
      _replaceVisible = false;
    });
    _updateStatus('Search closed');
  }

  void _clearSearchState() {
    _controller.clearSearch();
    if (mounted) {
      setState(() => _searchState = const core.SearchState());
    } else {
      _searchState = const core.SearchState();
    }
  }

  void _performSearch() {
    if (!_searchVisible) return;
    final pattern = _decodeNewlineTokens(_searchController.text);
    if (pattern.isEmpty) {
      _clearSearchState();
      return;
    }

    _controller.search(
      core.SearchRequest(
        pattern: pattern,
        options: core.SearchOptions(
          caseSensitive: _searchCaseSensitive,
          wholeWord: _searchWholeWord,
          useRegex: _searchUseRegex,
        ),
      ),
    );
    _refreshSearchState();
    if (_searchState.status == core.SearchStatus.failed) {
      _updateStatus(
        _searchState.errorMessage.isEmpty
            ? 'Search failed'
            : _searchState.errorMessage,
      );
    }
  }

  void _findNextSearchMatch() {
    if (!_searchVisible) {
      _openSearch(replaceMode: false);
      return;
    }
    _controller.findNextSearchMatch();
    _refreshSearchState();
  }

  void _findPreviousSearchMatch() {
    if (!_searchVisible) {
      _openSearch(replaceMode: false);
      return;
    }
    _controller.findPreviousSearchMatch();
    _refreshSearchState();
  }

  void _replaceCurrentSearchMatch() {
    if (!_searchVisible) return;
    final state = _controller.getSearchState();
    if (_searchController.text.isEmpty ||
        state.status == core.SearchStatus.failed ||
        !state.hasCurrentMatch) {
      return;
    }
    _controller.replaceCurrentSearchMatch(
      _decodeNewlineTokens(_replaceController.text),
    );
    _performSearch();
    _updateStatus('Replace');
  }

  void _replaceAllSearchMatches() {
    if (!_searchVisible) return;
    final state = _controller.getSearchState();
    if (_searchController.text.isEmpty ||
        state.status == core.SearchStatus.failed ||
        state.matchCount <= 0) {
      return;
    }
    final count = state.matchCount;
    _controller.replaceAllSearchMatches(
      _decodeNewlineTokens(_replaceController.text),
    );
    _performSearch();
    _updateStatus('Replaced $count matches');
  }

  void _refreshSearchState() {
    if (!mounted) return;
    setState(() => _searchState = _controller.getSearchState());
  }

  String _searchCounterText() {
    if (!_searchVisible || _searchController.text.isEmpty) {
      return '';
    }
    if (_searchState.status == core.SearchStatus.failed) {
      return 'Error';
    }
    if (_searchState.matchCount <= 0) {
      return '0/0';
    }
    final index = _searchState.hasCurrentMatch
        ? _searchState.currentIndex + 1
        : 0;
    return '$index/${_searchState.matchCount}';
  }

  void _insertNewlineToken(TextEditingController controller) {
    final selection = controller.selection;
    var start = selection.start < 0 ? controller.text.length : selection.start;
    var end = selection.end < 0 ? controller.text.length : selection.end;
    start = start.clamp(0, controller.text.length).toInt();
    end = end.clamp(0, controller.text.length).toInt();
    if (end < start) {
      final temp = start;
      start = end;
      end = temp;
    }
    final text = controller.text.replaceRange(start, end, r'\n');
    controller.value = controller.value.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: start + 2),
      composing: TextRange.empty,
    );
    if (identical(controller, _searchController)) {
      _performSearch();
    }
  }

  String _decodeNewlineTokens(String text) {
    final builder = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (ch == '\\' && i + 1 < text.length) {
        final next = text[i + 1];
        if (next == 'n') {
          builder.write('\n');
          i++;
          continue;
        }
        if (next == '\\') {
          builder.write('\\');
          i++;
          continue;
        }
      }
      builder.write(ch);
    }
    return builder.toString();
  }
}

class _OpenSearchIntent extends Intent {
  const _OpenSearchIntent(this.replaceMode);

  final bool replaceMode;
}

class _CloseSearchIntent extends Intent {
  const _CloseSearchIntent();
}

class _FindPreviousSearchIntent extends Intent {
  const _FindPreviousSearchIntent();
}

class _DemoSuggestionListener implements InlineSuggestionListener {
  _DemoSuggestionListener({
    required this.onAccepted,
    required this.onDismissed,
  });

  final VoidCallback onAccepted;
  final VoidCallback onDismissed;

  @override
  void onSuggestionAccepted(InlineSuggestion suggestion) => onAccepted();

  @override
  void onSuggestionDismissed(InlineSuggestion suggestion) => onDismissed();
}
