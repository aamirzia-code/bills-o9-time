import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models.dart';
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
    return Material(
      color: color ?? Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
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

  const MoneyField(
      {super.key,
      required this.controller,
      this.label = 'Amount',
      this.autofocus = false});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
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
