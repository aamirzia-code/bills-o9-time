import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../skins.dart';
import '../utils.dart';

/// Shown once, on a fresh install: name, currency, payday, look, and the
/// usual monthly bills. Everything can be changed later in Settings.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static bool needed(AppState s) =>
      !s.pref<bool>('onboarded', false) && s.bills.isEmpty && s.txns.isEmpty;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _CommonBill {
  final String name, category, icon;
  const _CommonBill(this.name, this.category, this.icon);
}

const _common = [
  _CommonBill('Electricity', 'Electricity', 'bolt'),
  _CommonBill('Gas', 'Gas', 'gas'),
  _CommonBill('Water', 'Water', 'water'),
  _CommonBill('Internet', 'Internet', 'wifi'),
  _CommonBill('Mobile package', 'Mobile', 'phone'),
  _CommonBill('House rent', 'Rent', 'home'),
  _CommonBill('School fee', 'Education', 'school'),
  _CommonBill('Credit card', 'Credit Card', 'card'),
  _CommonBill('Car / bike loan', 'Loan / EMI', 'loan'),
  _CommonBill('Netflix / streaming', 'Subscriptions', 'tv'),
  _CommonBill('Maid / driver', 'Family', 'cleaning'),
  _CommonBill('Milkman', 'Groceries', 'milk'),
];

class _Pick {
  final _CommonBill b;
  final amount = TextEditingController();
  int day = 10;
  _Pick(this.b);
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _page = PageController();
  int _i = 0;
  final _name = TextEditingController();
  late String _currency;
  late int _payday;
  late String _skin;
  final Map<String, _Pick> _picks = {};

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    _name.text = s.userName;
    _currency = s.currency;
    _payday = s.monthStart;
    _skin = s.skinId;
  }

  @override
  void dispose() {
    _page.dispose();
    _name.dispose();
    for (final p in _picks.values) {
      p.amount.dispose();
    }
    super.dispose();
  }

  Future<void> _finish() async {
    final s = context.read<AppState>();
    if (_name.text.trim().isNotEmpty) await s.setUserName(_name.text.trim());
    await s.setCurrency(_currency);
    await s.setPref('monthStart', _payday);
    await s.setSkin(_skin);
    final now = DateTime.now();
    for (final p in _picks.values) {
      final catId = s.categories
          .where((c) => c.name == p.b.category && c.type == TxType.expense)
          .map((c) => c.id)
          .firstOrNull;
      await s.saveBill(Bill(
        name: p.b.name,
        amount: double.tryParse(p.amount.text) ?? 0,
        categoryId: catId,
        dueDate: nextOccurrenceOfDay(p.day, now),
        repeat: Repeat.monthly,
        dueDay: p.day,
      ));
    }
    await s.setPref('onboarded', true);
  }

  void _next() {
    if (_i == 3) {
      _finish();
      return;
    }
    FocusScope.of(context).unfocus();
    _page.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    Widget page({required IconData icon, required String title, required String sub, required Widget child}) =>
        ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: cs.primary, size: 32),
            ),
            const SizedBox(height: 20),
            Text(title, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(sub, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15, height: 1.4)),
            const SizedBox(height: 24),
            child,
          ],
        );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  for (var k = 0; k < 4; k++)
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: k <= _i ? cs.primary : cs.outlineVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  TextButton(
                    onPressed: () => context.read<AppState>().setPref('onboarded', true),
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _page,
                onPageChanged: (v) => setState(() => _i = v),
                children: [
                  page(
                    icon: Icons.waving_hand_rounded,
                    title: 'Welcome to Bills O9 Time',
                    sub: 'Bills, spending, budgets and everyday money tools. Everything stays on this phone — no account, no server.',
                    child: TextField(
                      controller: _name,
                      autofocus: false,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _next(),
                      decoration: const InputDecoration(
                        labelText: 'What should we call you?',
                        prefixIcon: Icon(Icons.person_rounded),
                      ),
                    ),
                  ),
                  page(
                    icon: Icons.payments_rounded,
                    title: 'Money basics',
                    sub: 'Pick your currency and the day your month really starts — usually payday.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final c in const ['Rs', 'PKR', 'AED', 'SAR', 'QAR', '\$', '£', '€', '₹'])
                              ChoiceChip(
                                label: Text(c),
                                selected: _currency == c,
                                onSelected: (_) => setState(() => _currency = c),
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        DropdownButtonFormField<int>(
                          value: _payday,
                          decoration: const InputDecoration(
                            labelText: 'My month starts on',
                            prefixIcon: Icon(Icons.event_rounded),
                          ),
                          items: [
                            for (var d = 1; d <= 28; d++)
                              DropdownMenuItem(
                                  value: d, child: Text(d == 1 ? '1st (calendar month)' : '${ordinal(d)} (payday)')),
                          ],
                          onChanged: (v) => setState(() => _payday = v ?? 1),
                        ),
                      ],
                    ),
                  ),
                  page(
                    icon: Icons.palette_rounded,
                    title: 'Choose a look',
                    sub: 'You can switch any time in Settings → Theme.',
                    child: GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.72,
                      children: [
                        for (final k in kSkins)
                          GestureDetector(
                            onTap: () {
                              setState(() => _skin = k.id);
                              context.read<AppState>().setSkin(k.id);
                            },
                            child: Column(
                              children: [
                                Expanded(
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(13),
                                      border: Border.all(
                                          color: _skin == k.id ? cs.primary : Colors.transparent, width: 2.5),
                                    ),
                                    child: SkinPreview(k),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(k.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: _skin == k.id ? FontWeight.w800 : FontWeight.w500)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  page(
                    icon: Icons.receipt_long_rounded,
                    title: 'Your monthly bills',
                    sub: 'Tap the ones you pay. Add a rough amount and due day — you\'ll be reminded before each one.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final b in _common)
                              FilterChip(
                                avatar: Icon(iconFor(b.icon), size: 17),
                                label: Text(b.name),
                                selected: _picks.containsKey(b.name),
                                onSelected: (v) => setState(() {
                                  if (v) {
                                    _picks[b.name] = _Pick(b);
                                  } else {
                                    _picks.remove(b.name)?.amount.dispose();
                                  }
                                }),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        for (final p in _picks.values)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Icon(iconFor(p.b.icon), color: cs.primary),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: p.amount,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      labelText: p.b.name,
                                      prefixText: '$_currency ',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<int>(
                                    value: p.day,
                                    isDense: true,
                                    decoration: const InputDecoration(isDense: true, labelText: 'Due on'),
                                    items: [
                                      for (var d = 1; d <= 28; d++)
                                        DropdownMenuItem(value: d, child: Text(ordinal(d))),
                                      const DropdownMenuItem(value: kLastDay, child: Text('Last day')),
                                    ],
                                    onChanged: (v) => setState(() => p.day = v ?? 10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                children: [
                  if (_i > 0)
                    TextButton(
                      onPressed: () => _page.previousPage(
                          duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic),
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  FilledButton(
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15)),
                    onPressed: _next,
                    child: Text(_i == 3 ? (_picks.isEmpty ? 'Start' : 'Add ${_picks.length} & start') : 'Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
