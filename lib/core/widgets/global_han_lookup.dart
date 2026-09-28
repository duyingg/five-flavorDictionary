import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../features/dictionary/single_han_validator.dart';

/// Adds character lookup to ordinary rendered text without rebuilding every
/// [Text] as hundreds of gesture widgets.
///
/// Existing controls and [GlobalHanLookupBlocker] regions always win. A drag
/// is treated as scrolling, so releasing a list does not accidentally open a
/// character page.
class GlobalHanLookupRegion extends StatefulWidget {
  const GlobalHanLookupRegion({
    required this.enabled,
    required this.onCharacter,
    required this.child,
    super.key,
  });

  final bool enabled;
  final ValueChanged<String> onCharacter;
  final Widget child;

  @override
  State<GlobalHanLookupRegion> createState() => _GlobalHanLookupRegionState();
}

class _GlobalHanLookupRegionState extends State<GlobalHanLookupRegion> {
  static const _validator = SingleHanValidator();
  final Map<int, Offset> _pointerOrigins = {};
  final Map<int, Timer> _longPressTimers = {};
  final Set<int> _longPressedPointers = {};
  final Set<int> _draggedPointers = {};

  @override
  void dispose() {
    for (final timer in _longPressTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          if (!widget.enabled) return;
          _pointerOrigins[event.pointer] = event.position;
          _longPressTimers[event.pointer] = Timer(
            const Duration(milliseconds: 450),
            () => _longPressedPointers.add(event.pointer),
          );
        },
        onPointerMove: (event) {
          final origin = _pointerOrigins[event.pointer];
          if (origin != null &&
              (event.position - origin).distance > kTouchSlop) {
            _draggedPointers.add(event.pointer);
          }
        },
        onPointerCancel: (event) => _clearPointer(event.pointer),
        onPointerUp: (event) {
          final tracked = _pointerOrigins.containsKey(event.pointer);
          final dragged = _draggedPointers.contains(event.pointer);
          final wasLongPress = _longPressedPointers.contains(event.pointer);
          _clearPointer(event.pointer);
          if (!widget.enabled || !tracked || dragged || wasLongPress) return;
          final character = _characterAt(event.position, event.viewId);
          if (character != null) widget.onCharacter(character);
        },
        child: widget.child,
      );

  void _clearPointer(int pointer) {
    _pointerOrigins.remove(pointer);
    _longPressTimers.remove(pointer)?.cancel();
    _longPressedPointers.remove(pointer);
    _draggedPointers.remove(pointer);
  }

  String? _characterAt(Offset globalPosition, int viewId) {
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, globalPosition, viewId);

    for (final entry in result.path) {
      final target = entry.target;
      if (target is _RenderGlobalHanLookupBlocker || target is RenderEditable) {
        return null;
      }
      if (target is RenderObject) {
        final semantics = SemanticsConfiguration();
        // Hit-test inspection is intentionally read-only and lets ordinary
        // controls retain priority over the global text shortcut.
        // ignore: invalid_use_of_protected_member
        target.describeSemanticsConfiguration(semantics);
        final scrollable = semantics
                    .getActionHandler(SemanticsAction.scrollUp) !=
                null ||
            semantics.getActionHandler(SemanticsAction.scrollDown) != null ||
            semantics.getActionHandler(SemanticsAction.scrollLeft) != null ||
            semantics.getActionHandler(SemanticsAction.scrollRight) != null;
        if (semantics.isTextField ||
            (!scrollable &&
                (semantics.getActionHandler(SemanticsAction.tap) != null ||
                    semantics.getActionHandler(SemanticsAction.longPress) !=
                        null))) {
          return null;
        }
      }
    }

    RenderParagraph? paragraph;
    for (final entry in result.path) {
      if (entry.target case final RenderParagraph candidate) {
        paragraph = candidate;
        break;
      }
    }
    if (paragraph == null) {
      for (final entry in result.path) {
        final target = entry.target;
        if (target is! RenderObject) continue;
        paragraph = _descendantParagraphAt(target, globalPosition);
        if (paragraph != null) break;
      }
    }
    if (paragraph == null) return null;

    final localPosition = paragraph.globalToLocal(globalPosition);
    final text = paragraph.text.toPlainText(includeSemanticsLabels: false);
    if (text.isEmpty) return null;
    final caret = paragraph.getPositionForOffset(localPosition).offset;
    for (final range in _candidateRuneRanges(text, caret)) {
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: range.start, extentOffset: range.end),
      );
      if (!boxes
          .any((box) => box.toRect().inflate(1).contains(localPosition))) {
        continue;
      }
      final value = text.substring(range.start, range.end);
      final validation = _validator.validate(value);
      if (validation is ValidHan) return validation.value;
    }
    return null;
  }

  RenderParagraph? _descendantParagraphAt(
    RenderObject root,
    Offset globalPosition,
  ) {
    RenderParagraph? match;

    void visit(RenderObject object) {
      if (match != null) return;
      if (object is RenderBox) {
        final localPosition = object.globalToLocal(globalPosition);
        if (!object.paintBounds.inflate(1).contains(localPosition)) return;
        if (object is RenderParagraph) {
          match = object;
          return;
        }
      }
      object.visitChildren(visit);
    }

    visit(root);
    return match;
  }

  Iterable<({int start, int end})> _candidateRuneRanges(
    String text,
    int caret,
  ) sync* {
    // getPositionForOffset returns a UTF-16 caret boundary. Only the rune on
    // either side can own that pixel, so scanning and sorting the full
    // paragraph on every tap is unnecessary.
    final previous = _runeRangeAt(text, caret - 1);
    if (previous != null) yield previous;
    final next = _runeRangeAt(text, caret);
    if (next != null && next.start != previous?.start) yield next;
  }

  ({int start, int end})? _runeRangeAt(String text, int offset) {
    if (offset < 0 || offset >= text.length) return null;
    var start = offset;
    final unit = text.codeUnitAt(start);
    if (_isLowSurrogate(unit) &&
        start > 0 &&
        _isHighSurrogate(text.codeUnitAt(start - 1))) {
      start--;
    }
    final first = text.codeUnitAt(start);
    final isPair = _isHighSurrogate(first) &&
        start + 1 < text.length &&
        _isLowSurrogate(text.codeUnitAt(start + 1));
    return (start: start, end: start + (isPair ? 2 : 1));
  }

  bool _isHighSurrogate(int value) => value >= 0xD800 && value <= 0xDBFF;

  bool _isLowSurrogate(int value) => value >= 0xDC00 && value <= 0xDFFF;
}

/// Marks a subtree where global character lookup must never run.
class GlobalHanLookupBlocker extends SingleChildRenderObjectWidget {
  const GlobalHanLookupBlocker({required super.child, super.key});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderGlobalHanLookupBlocker();
}

class _RenderGlobalHanLookupBlocker extends RenderProxyBox {}
