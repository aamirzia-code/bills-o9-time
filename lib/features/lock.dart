import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../i18n.dart';
import '../sync/cloud_providers.dart' show SyncStore;
import '../widgets.dart';
import 'passkey_stub.dart' if (dart.library.js_interop) 'passkey_web.dart';

/// App lock: PIN plus optional Face ID / fingerprint (passkey on the web).
/// Settings are kept on this device only (never in backups).
class AppLock extends ChangeNotifier {
  final _store = SyncStore();
  bool enabled = false;
  bool locked = false;
  String? passkeyId;
  int lockAfterSeconds = 60;
  DateTime? _hiddenAt;

  bool get hasPasskey => passkeyId != null;

  Future<void> init() async {
    enabled = (await _store.getNonEmpty('lock_pin')) != null;
    passkeyId = await _store.getNonEmpty('lock_passkey');
    lockAfterSeconds = int.tryParse(await _store.get('lock_after') ?? '') ?? 60;
    locked = enabled;
    notifyListeners();
  }

  String _hash(String salt, String pin) =>
      crypto.sha256.convert(utf8.encode('$salt:$pin')).toString();

  Future<void> setPin(String pin) async {
    final r = Random.secure();
    final salt = base64Url.encode(List.generate(12, (_) => r.nextInt(256)));
    await _store.set('lock_salt', salt);
    await _store.set('lock_pin', _hash(salt, pin));
    enabled = true;
    notifyListeners();
  }

  Future<bool> checkPin(String pin) async {
    final salt = await _store.get('lock_salt') ?? '';
    final ok = _hash(salt, pin) == await _store.get('lock_pin');
    if (ok) unlock();
    return ok;
  }

  Future<void> disable() async {
    for (final k in ['lock_pin', 'lock_salt', 'lock_passkey']) {
      await _store.set(k, null);
    }
    enabled = false;
    locked = false;
    passkeyId = null;
    notifyListeners();
  }

  Future<bool> passkeySupported() => kIsWeb ? passkeyAvailable() : Future.value(false);

  Future<bool> enablePasskey() async {
    final id = await passkeyRegister();
    if (id == null) return false;
    passkeyId = id;
    await _store.set('lock_passkey', id);
    notifyListeners();
    return true;
  }

  Future<void> disablePasskey() async {
    passkeyId = null;
    await _store.set('lock_passkey', null);
    notifyListeners();
  }

  Future<bool> unlockWithPasskey() async {
    if (passkeyId == null) return false;
    final ok = await passkeyVerify(passkeyId!);
    if (ok) unlock();
    return ok;
  }

  Future<void> setLockAfter(int seconds) async {
    lockAfterSeconds = seconds;
    await _store.set('lock_after', '$seconds');
    notifyListeners();
  }

  void unlock() {
    locked = false;
    notifyListeners();
  }

  void onHidden() => _hiddenAt ??= DateTime.now();

  void onResumed() {
    final at = _hiddenAt;
    _hiddenAt = null;
    if (!enabled || at == null || locked) return;
    if (DateTime.now().difference(at).inSeconds >= lockAfterSeconds) {
      locked = true;
      notifyListeners();
    }
  }
}

/// Covers the app while it is locked.
class LockGate extends StatelessWidget {
  final Widget child;
  const LockGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final lock = context.watch<AppLock>();
    return Stack(
      children: [
        child,
        if (lock.locked) const Positioned.fill(child: LockScreen()),
      ],
    );
  }
}

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _pin = '';
  bool _wrong = false;

  Future<void> _tap(String d) async {
    if (_pin.length >= 6) return;
    setState(() {
      _pin += d;
      _wrong = false;
    });
    if (_pin.length >= 4) {
      final ok = await context.read<AppLock>().checkPin(_pin);
      if (!ok && _pin.length >= 6) {
        setState(() {
          _wrong = true;
          _pin = '';
        });
      } else if (ok) {
        _pin = '';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lock = context.watch<AppLock>();
    Widget key(String label, {VoidCallback? onTap, Widget? child}) => SizedBox(
          width: 76,
          height: 76,
          child: Material(
            color: cs.surfaceContainerHigh,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap ?? () => _tap(label),
              child: Center(
                child: child ??
                    Text(label,
                        style: const TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w500)),
              ),
            ),
          ),
        );
    return Material(
      color: cs.surface,
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Icon(Icons.lock_rounded, size: 40, color: cs.primary),
            const SizedBox(height: 12),
            const Text('Bills O9 Time',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(_wrong ? 'Wrong PIN, try again' : 'Enter your PIN',
                style: TextStyle(
                    color: _wrong ? const Color(0xFFEF4444) : cs.onSurfaceVariant)),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 6; i++)
                  Container(
                    width: 13,
                    height: 13,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < _pin.length ? cs.primary : Colors.transparent,
                      border: Border.all(
                          color: i < 4 ? cs.onSurfaceVariant : cs.outlineVariant),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            for (final row in const [
              ['1', '2', '3'],
              ['4', '5', '6'],
              ['7', '8', '9'],
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [for (final d in row) key(d)],
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  lock.hasPasskey
                      ? key('',
                          onTap: () async {
                            final ok = await lock.unlockWithPasskey();
                            if (!ok && context.mounted) {
                              toast(context, 'Face ID / fingerprint failed — use your PIN');
                            }
                          },
                          child: const Icon(Icons.face_rounded, size: 30))
                      : const SizedBox(width: 76),
                  key('0'),
                  key('',
                      onTap: () => setState(() {
                            if (_pin.isNotEmpty) {
                              _pin = _pin.substring(0, _pin.length - 1);
                            }
                          }),
                      child: const Icon(Icons.backspace_outlined)),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

/// Settings → Privacy & lock.
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool? _passkeyOk;

  @override
  void initState() {
    super.initState();
    context.read<AppLock>().passkeySupported().then((v) {
      if (mounted) setState(() => _passkeyOk = v);
    });
  }

  Future<String?> _askNewPin() async {
    final a = TextEditingController();
    final b = TextEditingController();
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set a PIN'),
        content: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: a,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(labelText: '4–6 digits'),
                validator: (v) => RegExp(r'^\d{4,6}$').hasMatch(v ?? '')
                    ? null
                    : 'Use 4 to 6 digits',
              ),
              TextFormField(
                controller: b,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(labelText: 'Repeat PIN'),
                validator: (v) => v != a.text ? 'Doesn\'t match' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancel'))),
          FilledButton(
              onPressed: () {
                if (key.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: Text(tr('Save'))),
        ],
      ),
    );
    return ok == true ? a.text : null;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final lock = context.watch<AppLock>();
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Privacy & lock'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          AppCard(
            padding: EdgeInsets.zero,
            child: SwitchListTile(
              secondary: const Icon(Icons.visibility_off_outlined),
              title: const Text('Hide amounts'),
              subtitle: const Text(
                  'Show •••• instead of money. Quick toggle: the eye on Home.'),
              value: s.pref<bool>('hideAmounts', false),
              onChanged: (v) => s.setPref('hideAmounts', v),
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.lock_outline_rounded),
                  title: const Text('App lock'),
                  subtitle: const Text('Ask for a PIN when the app opens'),
                  value: lock.enabled,
                  onChanged: (v) async {
                    if (v) {
                      final pin = await _askNewPin();
                      if (pin != null) await lock.setPin(pin);
                    } else {
                      await lock.disable();
                    }
                  },
                ),
                if (lock.enabled) ...[
                  Divider(height: 1, color: cs.outlineVariant),
                  ListTile(
                    leading: const Icon(Icons.pin_outlined),
                    title: const Text('Change PIN'),
                    onTap: () async {
                      final pin = await _askNewPin();
                      if (pin != null) {
                        await lock.setPin(pin);
                        if (context.mounted) toast(context, 'PIN changed');
                      }
                    },
                  ),
                  Divider(height: 1, color: cs.outlineVariant),
                  SwitchListTile(
                    secondary: const Icon(Icons.face_rounded),
                    title: const Text('Face ID / fingerprint'),
                    subtitle: Text(_passkeyOk == false
                        ? 'Not available in this browser'
                        : 'Unlock with your phone\'s biometrics'),
                    value: lock.hasPasskey,
                    onChanged: _passkeyOk != true
                        ? null
                        : (v) async {
                            if (v) {
                              final ok = await lock.enablePasskey();
                              if (!ok && context.mounted) {
                                toast(context, 'Could not set up Face ID / fingerprint');
                              }
                            } else {
                              await lock.disablePasskey();
                            }
                          },
                  ),
                  Divider(height: 1, color: cs.outlineVariant),
                  ListTile(
                    leading: const Icon(Icons.timer_outlined),
                    title: const Text('Lock after'),
                    trailing: DropdownButton<int>(
                      value: [0, 60, 300, 900].contains(lock.lockAfterSeconds)
                          ? lock.lockAfterSeconds
                          : 60,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('Immediately')),
                        DropdownMenuItem(value: 60, child: Text('1 minute')),
                        DropdownMenuItem(value: 300, child: Text('5 minutes')),
                        DropdownMenuItem(value: 900, child: Text('15 minutes')),
                      ],
                      onChanged: (v) => lock.setLockAfter(v ?? 60),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'The lock keeps others from opening the app on your phone. Your data never leaves the device unless you turn on Backup & Sync, which is encrypted.',
            style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
