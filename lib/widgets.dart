import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models.dart';
import 'skins.dart';
import 'utils.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final sk = context.skin;
    final r = BorderRadius.circular(sk.radius);
    final card = Material(
      color: color ?? Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: r,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
    if (sk.cardBorder == null && !sk.cardShadow) return card;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        border: sk.cardBorder == null ? null : Border.all(color: sk.cardBorder!),
        boxShadow: sk.cardShadow
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 3,
                  offset: const Offset(1, 2),
                ),
              ]
            : null,
      ),
      child: card,
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const SectionTitle(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

class CategoryAvatar extends StatelessWidget {
  final TxCategory? category;
  final double size;
  final IconData? fallback;

  const CategoryAvatar(this.category,
      {super.key, this.size = 42, this.fallback});

  @override
  Widget build(BuildContext context) {
    final color = Color(category?.color ?? 0xFF475569);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(
        category != null ? iconFor(category!.icon) : (fallback ?? Icons.category),
        color: color,
        size: size * 0.52,
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const EmptyState(
      {super.key,
      required this.icon,
      required this.title,
      required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: cs.primaryContainer, shape: BoxShape.circle),
            child: Icon(icon, size: 36, color: cs.onPrimaryContainer),
          ),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class ProgressLine extends StatelessWidget {
  final double value; // 0..1+
  final Color color;
  final double height;

  const ProgressLine(
      {super.key, required this.value, required this.color, this.height = 8});

  @override
  Widget build(BuildContext context) {
    final over = value > 1;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: color.withOpacity(0.14),
        valueColor: AlwaysStoppedAnimation(
            over ? const Color(0xFFDC2626) : color),
      ),
    );
  }
}

class MoneyField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  const MoneyField(
      {super.key,
      required this.controller,
      this.label = 'Amount',
      this.autofocus = false,
      this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      onChanged: onChanged,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        prefixText: '${Fmt.symbol} ',
      ),
      validator: (v) {
        final d = double.tryParse(v ?? '');
        if (d == null || d <= 0) return 'Enter a valid amount';
        return null;
      },
    );
  }
}

/// Tappable field that opens a date picker.
class DateField extends StatelessWidget {
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  const DateField(
      {super.key,
      required this.label,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (d != null) onChanged(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_month_rounded),
        ),
        child: Text(Fmt.date(value)),
      ),
    );
  }
}

class CategoryPicker extends StatelessWidget {
  final List<TxCategory> categories;
  final int? selected;
  final ValueChanged<int> onSelected;

  const CategoryPicker(
      {super.key,
      required this.categories,
      required this.selected,
      required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in categories)
          ChoiceChip(
            avatar: Icon(iconFor(c.icon),
                size: 18,
                color: selected == c.id ? cs.onPrimary : Color(c.color)),
            label: Text(c.name),
            selected: selected == c.id,
            showCheckmark: false,
            selectedColor: cs.primary,
            labelStyle: TextStyle(
                color: selected == c.id ? cs.onPrimary : cs.onSurface,
                fontWeight: FontWeight.w600),
            onSelected: (_) => onSelected(c.id!),
          ),
      ],
    );
  }
}

Future<bool> confirm(BuildContext context, String title, String message,
    {String ok = 'Delete'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true), child: Text(ok)),
      ],
    ),
  );
  return r ?? false;
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
        content: Text(msg), behavior: SnackBarBehavior.floating));
}


/// Small rounded label like "Increased by Rs9,300".
class ChangeBadge extends StatelessWidget {
  final double change; // positive = increased
  const ChangeBadge(this.change, {super.key});

  @override
  Widget build(BuildContext context) {
    final up = change > 0;
    final color = up ? const Color(0xFFEF4444) : const Color(0xFF22C55E);
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.8)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(up ? Icons.north_east_rounded : Icons.south_east_rounded,
              size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            '${up ? 'Increased' : 'Reduced'} by ${Fmt.money(change.abs())}',
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface),
          ),
        ],
      ),
    );
  }
}

/// Month header row: "This month ........ Rs152,000".
class GroupHeader extends StatelessWidget {
  final String title;
  final double? total;
  const GroupHeader(this.title, {super.key, this.total});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            if (total != null)
              Text(Fmt.money(total!),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

/// Rounded search field used on list screens.
class SearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const SearchField({super.key, required this.onChanged});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 42,
        child: TextField(
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: 'Search...',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            contentPadding: EdgeInsets.zero,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHigh,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      );
}

/// Paste from the clipboard. On iPhone Safari this shows the small "Paste"
/// bubble the user taps once.
Future<String> readClipboard() async {
  try {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    return d?.text ?? '';
  } catch (_) {
    return '';
  }
}

/// An ordered list of names, edited one line at a time (multi-line text
/// boxes are unreliable on iPhone browsers). Drag to reorder, tap to rename,
/// paste a whole list from WhatsApp in one go.
class NameListEditor extends StatefulWidget {
  final List<String> names;
  final ValueChanged<List<String>> onChanged;
  final List<String> suggestions;
  final String hint;
  const NameListEditor({
    super.key,
    required this.names,
    required this.onChanged,
    this.suggestions = const [],
    this.hint = 'Add a name',
  });

  @override
  State<NameListEditor> createState() => _NameListEditorState();
}

class _NameListEditorState extends State<NameListEditor> {
  final _add = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _add.dispose();
    _focus.dispose();
    super.dispose();
  }

  static List<String> splitNames(String text) => text
      .split(RegExp(r'[\n,;]+'))
      .map((e) => e.replaceAll(RegExp(r'^\s*(\d+[.)\-:]|[-•*])\s*'), '').trim())
      .where((e) => e.isNotEmpty)
      .toList();

  void _addText(String text, {bool keepFocus = true}) {
    final add = splitNames(text);
    if (add.isEmpty) return;
    widget.onChanged([...widget.names, ...add]);
    _add.clear();
    if (keepFocus) _focus.requestFocus();
  }

  Future<void> _paste() async {
    final t = await readClipboard();
    if (!mounted) return;
    if (splitNames(t).isEmpty) {
      toast(context, 'Clipboard is empty — copy the names first');
      return;
    }
    _addText(t, keepFocus: false);
    toast(context, 'Added ${splitNames(t).length} from clipboard');
  }

  Future<void> _rename(int i) async {
    final c = TextEditingController(text: widget.names[i]);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (v == null || v.isEmpty) return;
    final next = [...widget.names];
    next[i] = v;
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final names = widget.names;
    final sugg = widget.suggestions.where((s) => !names.contains(s)).take(8).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (names.isNotEmpty)
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: names.length,
              onReorder: (a, b) {
                final next = [...names];
                if (b > a) b--;
                next.insert(b, next.removeAt(a));
                widget.onChanged(next);
              },
              itemBuilder: (context, i) => ListTile(
                key: ValueKey('n$i-${names[i]}'),
                dense: true,
                contentPadding: const EdgeInsets.only(left: 12, right: 4),
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: cs.primary.withOpacity(0.14),
                  child: Text('${i + 1}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: cs.primary)),
                ),
                title: Text(names[i], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                onTap: () => _rename(i),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Remove',
                      icon: Icon(Icons.close_rounded, size: 20, color: cs.onSurfaceVariant),
                      onPressed: () => widget.onChanged([...names]..removeAt(i)),
                    ),
                    ReorderableDragStartListener(
                      index: i,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(Icons.drag_indicator_rounded, color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _add,
                focusNode: _focus,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (v) => _addText(v),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  prefixIcon: const Icon(Icons.person_add_alt_rounded),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: () => _addText(_add.text), icon: const Icon(Icons.add_rounded)),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.content_paste_rounded, size: 17),
              label: const Text('Paste list'),
              onPressed: _paste,
            ),
            for (final s in sugg)
              ActionChip(
                avatar: const Icon(Icons.add_rounded, size: 17),
                label: Text(s),
                onPressed: () => widget.onChanged([...names, s]),
              ),
          ],
        ),
      ],
    );
  }
}
