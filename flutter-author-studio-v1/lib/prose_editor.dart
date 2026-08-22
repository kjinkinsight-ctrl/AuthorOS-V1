/// The writing surface: a text field that can carry formatting.
///
/// Flutter's [TextEditingController] owns a plain string. This one owns a
/// [ProseMarkup] beside it — the same string, plus where the marks are — and
/// keeps the two in step as the author types. Everything the field itself does
/// still works: selection, undo, IME, autofill, the platform's own text
/// handling. Only the painting and the mark bookkeeping are added.
///
/// Two rules govern this file:
///
/// * It owns no storage. The manuscript store decides where prose lives; this
///   hands it a document and takes one back.
/// * It owns no formatting vocabulary. [ProseMark] and [ProseBlockKind] are
///   the document's, so a mark cannot exist here that the document cannot
///   store.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/prose_document.dart';
import 'core/prose_markup.dart';

/// A text controller that remembers formatting.
class ProseEditingController extends TextEditingController {
  ProseEditingController({ProseMarkup? markup})
      : _markup = markup ?? ProseMarkup.empty,
        super(text: markup?.text ?? '');

  ProseMarkup _markup;

  /// Marks chosen with nothing selected, waiting for the next character.
  Set<ProseMark>? _pending;

  ProseMarkup get markup => _markup;

  /// Replaces both the text and its formatting.
  ///
  /// Used when the author moves to another scene. Assigning [text] alone would
  /// leave the previous scene's marks anchored over the new scene's words.
  set markup(ProseMarkup next) {
    _markup = next;
    _pending = null;
    // Assign through `value` so the selection is reset with the text rather
    // than left pointing into a document that no longer exists.
    value = TextEditingValue(
      text: next.text,
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  /// The document the author is looking at.
  ProseDocument get document => _markup.toDocument();

  set document(ProseDocument next) => markup = ProseMarkup.fromDocument(next);

  /// What the toolbar should show as active.
  ///
  /// Pending marks win: having just pressed bold with no selection, the button
  /// must look pressed even though no character carries it yet.
  Set<ProseMark> get activeMarks {
    if (_pending != null) return _pending!;
    if (!selection.isValid) return const {};
    return _markup.marksIn(selection.start, selection.end);
  }

  @override
  set value(TextEditingValue newValue) {
    if (newValue.text != _markup.text) {
      _markup = _markup.withText(
        newValue.text,
        applyMarks: _pending ?? const {},
      );
      _pending = null;
    } else if (newValue.selection != selection) {
      // Moving the caret abandons a pending choice: bold chosen over there is
      // not still chosen over here.
      _pending = null;
    }
    super.value = newValue;
  }

  /// Adds [mark] to the selection, or removes it when the whole selection has
  /// it already. With nothing selected, arms it for what is typed next.
  void toggleMark(ProseMark mark) {
    if (!selection.isValid) return;

    if (selection.isCollapsed) {
      final next = {...activeMarks};
      if (!next.remove(mark)) next.add(mark);
      _pending = next;
      notifyListeners();
      return;
    }

    _markup = _markup.toggle(mark, selection.start, selection.end);
    _pending = null;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (_markup.ranges.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final children = <TextSpan>[];
    var cursor = 0;
    for (final range in _markup.ranges) {
      if (range.start > cursor) {
        children.add(TextSpan(text: text.substring(cursor, range.start)));
      }
      children.add(
        TextSpan(
          text: text.substring(range.start, range.end),
          style: styleFor(range.marks, style),
        ),
      );
      cursor = range.end;
    }
    if (cursor < text.length) {
      children.add(TextSpan(text: text.substring(cursor)));
    }

    return TextSpan(style: style, children: children);
  }

  /// How a set of marks paints.
  ///
  /// The one place marks become pixels. Underline and strikethrough compose
  /// rather than replace each other, because an author can mean both.
  static TextStyle styleFor(Set<ProseMark> marks, TextStyle? base) {
    final decorations = <TextDecoration>[
      if (marks.contains(ProseMark.underline)) TextDecoration.underline,
      if (marks.contains(ProseMark.strikethrough)) TextDecoration.lineThrough,
    ];
    return (base ?? const TextStyle()).copyWith(
      fontWeight: marks.contains(ProseMark.bold) ? FontWeight.w700 : null,
      fontStyle: marks.contains(ProseMark.italic) ? FontStyle.italic : null,
      decoration:
          decorations.isEmpty ? null : TextDecoration.combine(decorations),
    );
  }
}

/// What each mark is called, and what it is bound to.
class ProseMarkAction {
  const ProseMarkAction({
    required this.mark,
    required this.label,
    required this.icon,
    required this.shortcut,
  });

  final ProseMark mark;
  final String label;
  final IconData icon;
  final SingleActivator shortcut;

  static const actions = <ProseMarkAction>[
    ProseMarkAction(
      mark: ProseMark.bold,
      label: 'Bold',
      icon: Icons.format_bold,
      shortcut: SingleActivator(LogicalKeyboardKey.keyB, control: true),
    ),
    ProseMarkAction(
      mark: ProseMark.italic,
      label: 'Italic',
      icon: Icons.format_italic,
      shortcut: SingleActivator(LogicalKeyboardKey.keyI, control: true),
    ),
    ProseMarkAction(
      mark: ProseMark.underline,
      label: 'Underline',
      icon: Icons.format_underlined,
      shortcut: SingleActivator(LogicalKeyboardKey.keyU, control: true),
    ),
    ProseMarkAction(
      mark: ProseMark.strikethrough,
      label: 'Strikethrough',
      icon: Icons.format_strikethrough,
      shortcut: SingleActivator(
        LogicalKeyboardKey.keyX,
        control: true,
        shift: true,
      ),
    ),
  ];
}

/// The formatting controls above the editor.
///
/// Rebuilds from the controller rather than holding state of its own, so the
/// buttons follow the caret: moving into a bold word lights the bold button
/// without anything having to tell it.
class ProseFormattingToolbar extends StatelessWidget {
  const ProseFormattingToolbar({
    super.key,
    required this.controller,
    this.enabled = true,
  });

  final ProseEditingController controller;

  /// False while the manuscript is Canon and a branch is active, so the
  /// toolbar is visibly unavailable rather than silently inert.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final active = controller.activeMarks;
        final theme = Theme.of(context);
        return Wrap(
          key: const Key('prose-formatting-toolbar'),
          spacing: 4,
          children: [
            for (final action in ProseMarkAction.actions)
              IconButton(
                key: Key('prose-mark-${action.mark.name}'),
                icon: Icon(action.icon),
                iconSize: 18,
                // Deliberately small. This sits directly above the writing
                // surface, where every pixel it takes is one the author does
                // not get to write in -- and in focus mode the field is sized
                // to the window, so a chunky toolbar does not just look wrong,
                // it pushes the editor off the bottom.
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 30,
                  height: 30,
                ),
                isSelected: active.contains(action.mark),
                tooltip: '${action.label} '
                    '(${_shortcutLabel(action.shortcut)})',
                style: IconButton.styleFrom(
                  backgroundColor: active.contains(action.mark)
                      ? theme.colorScheme.secondaryContainer
                      : null,
                ),
                onPressed:
                    enabled ? () => controller.toggleMark(action.mark) : null,
              ),
          ],
        );
      },
    );
  }

  static String _shortcutLabel(SingleActivator shortcut) {
    final keys = <String>[
      if (shortcut.control) 'Ctrl',
      if (shortcut.shift) 'Shift',
      shortcut.trigger.keyLabel,
    ];
    return keys.join('+');
  }
}

/// Wraps [child] so the mark shortcuts work wherever the editor has focus.
///
/// Bound here rather than on the field itself because the shortcuts must also
/// fire from the toolbar, and because focus mode mounts a second field over
/// the same controller.
class ProseFormattingShortcuts extends StatelessWidget {
  const ProseFormattingShortcuts({
    super.key,
    required this.controller,
    required this.child,
    this.enabled = true,
  });

  final ProseEditingController controller;
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return CallbackShortcuts(
      bindings: {
        for (final action in ProseMarkAction.actions)
          action.shortcut: () => controller.toggleMark(action.mark),
      },
      child: child,
    );
  }
}
