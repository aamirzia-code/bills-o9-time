import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../sync/backup_codec.dart';
import '../sync/cloud_providers.dart';
import '../sync/sync_service.dart';
import '../utils.dart';
import '../widgets.dart';

const _green = Color(0xFF22C55E);
const _red = Color(0xFFEF4444);

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();
    final cs = Theme.of(context).colorScheme;
    final connected = sync.kind != CloudKind.none;

    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Sync')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          _StatusCard(sync: sync),
          if (sync.choiceNeeded) ...[
            const SizedBox(height: 12),
            _ChoiceCard(sync: sync),
          ],
          if (sync.error != null) ...[
            const SizedBox(height: 12),
            AppCard(
              color: _red.withOpacity(0.12),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: _red),
                  const SizedBox(width: 10),
                  Expanded(child: Text(sync.error!)),
                ],
              ),
            ),
          ],
          const SectionTitle('1 · Encryption'),
          AppCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(
                  sync.hasPassphrase
                      ? Icons.lock_rounded
                      : Icons.lock_open_rounded,
                  color: sync.hasPassphrase ? _green : cs.onSurfaceVariant),
              title: const Text('Backup passphrase'),
              subtitle: Text(sync.hasPassphrase
                  ? 'Set · your backup is AES-256 encrypted'
                  : 'Required before your first backup'),
              trailing: Text(sync.hasPassphrase ? 'Change' : 'Set',
                  style: const TextStyle(
                      color: kBlue, fontWeight: FontWeight.w700)),
              onTap: () => askNewPassphrase(context),
            ),
          ),
          const SectionTitle('2 · Cloud storage (automatic)'),
          if (!SyncService.cloudAvailable)
            AppCard(
              child: Text(
                'Automatic cloud sync runs in the web app (Home Screen version). '
                'In this app, use "Save backup file" below to keep a copy in iCloud Drive, Google Drive or any storage.',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            )
          else
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final k in const [CloudKind.google, CloudKind.dropbox])
                    _ProviderTile(sync: sync, k: k),
                ],
              ),
            ),
          if (connected) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: sync.busy || !sync.hasPassphrase
                        ? null
                        : () async {
                            final ok = await sync.sync();
                            if (context.mounted && ok) {
                              toast(context, 'Synced with ${cloudName(sync.kind)}');
                            }
                          },
                    icon: const Icon(Icons.sync_rounded),
                    label: const Text('Sync now'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: sync.busy
                        ? null
                        : () async {
                            if (await confirm(
                                context,
                                'Restore from ${cloudName(sync.kind)}?',
                                'This replaces everything on this device with the backup in your ${cloudName(sync.kind)}.',
                                ok: 'Restore')) {
                              await sync.resolveChoice(useCloud: true);
                              if (context.mounted && sync.error == null) {
                                toast(context, 'Restored from backup');
                              }
                            }
                          },
                    icon: const Icon(Icons.cloud_download_outlined),
                    label: const Text('Restore'),
                  ),
                ),
              ],
            ),
          ],
          const SectionTitle('3 · Backup file (any storage)'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.save_alt_rounded),
                  title: const Text('Save backup file'),
                  subtitle: const Text(
                      'Save to Files, iCloud Drive, Google Drive, OneDrive, email…'),
                  onTap: () => _saveFile(context, sync),
                ),
                Divider(height: 1, color: cs.outlineVariant),
                ListTile(
                  leading: const Icon(Icons.restore_rounded),
                  title: const Text('Restore from file'),
                  subtitle: const Text('Open a .b9 backup file'),
                  onTap: () => _restoreFile(context, sync),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 15, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'One file (${BackupCodec.fileName}), compressed and encrypted on this device — usually just a few KB. '
                  'It is updated 15 seconds after you make changes and checked once a day when you open the app. '
                  'Only you can read it: without the passphrase the file is useless, and the passphrase can\'t be recovered.',
                  style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveFile(BuildContext context, SyncService sync) async {
    if (!sync.hasPassphrase) {
      final ok = await askNewPassphrase(context);
      if (!ok) return;
    }
    try {
      final (name, bytes) = await sync.exportFile();
      await Share.shareXFiles(
        [XFile.fromData(bytes, name: name, mimeType: 'application/octet-stream')],
        fileNameOverrides: [name],
        subject: 'Bills O9 Time backup',
      );
    } catch (e) {
      if (context.mounted) toast(context, 'Could not save: $e');
    }
  }

  Future<void> _restoreFile(BuildContext context, SyncService sync) async {
    final res = await FilePicker.platform
        .pickFiles(withData: true, type: FileType.any);
    final bytes = res?.files.single.bytes;
    if (bytes == null || !context.mounted) return;
    if (!BackupCodec.looksLikeBackup(bytes)) {
      toast(context, 'That file isn\'t a Bills O9 backup.');
      return;
    }
    final pass = await askPassphrase(context,
        title: 'Backup passphrase',
        hint: 'The passphrase used when this backup was made');
    if (pass == null || !context.mounted) return;
    if (!await confirm(context, 'Replace all data?',
        'Everything on this device will be replaced with the backup.',
        ok: 'Restore')) {
      return;
    }
    try {
      await sync.importFile(bytes, pass);
      if (!sync.hasPassphrase) await sync.setPassphrase(pass);
      if (context.mounted) toast(context, 'Backup restored');
    } catch (e) {
      if (context.mounted) toast(context, '$e');
    }
  }
}

class _StatusCard extends StatelessWidget {
  final SyncService sync;
  const _StatusCard({required this.sync});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final connected = sync.kind != CloudKind.none;
    final ok = connected && !sync.needsSignIn && sync.error == null;
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: (ok ? _green : cs.onSurfaceVariant).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: sync.busy
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: CircularProgressIndicator(strokeWidth: 2.5))
                : Icon(
                    connected
                        ? (sync.needsSignIn
                            ? Icons.cloud_off_rounded
                            : Icons.cloud_done_rounded)
                        : Icons.cloud_outlined,
                    color: ok ? _green : cs.onSurfaceVariant,
                    size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connected ? cloudName(sync.kind) : 'Not backed up to the cloud',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16),
                ),
                if (sync.email != null && connected)
                  Text(sync.email!,
                      style: TextStyle(
                          fontSize: 12.5, color: cs.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(
                  sync.busy
                      ? 'Syncing…'
                      : sync.needsSignIn
                          ? 'Sign-in expired — tap Reconnect'
                          : connected
                              ? sync.describeLastSync()
                              : 'Connect a storage below to sync daily',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: sync.needsSignIn
                          ? const Color(0xFFF59E0B)
                          : ok
                              ? _green
                              : cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (sync.needsSignIn)
            TextButton(
                onPressed: () => sync.reconnect(),
                child: const Text('Reconnect')),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final SyncService sync;
  const _ChoiceCard({required this.sync});

  @override
  Widget build(BuildContext context) {
    final when = sync.remoteSavedAt == null
        ? ''
        : ' (saved ${Fmt.date(sync.remoteSavedAt!.toLocal())})';
    return AppCard(
      color: kBlue.withOpacity(0.12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('A backup already exists',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
              'Your ${cloudName(sync.kind)} already has a Bills O9 backup$when. '
              'Restore it to this device, or replace it with this device\'s data?'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: sync.busy
                      ? null
                      : () async {
                          if (!sync.hasPassphrase || sync.error != null) {
                            final p = await askPassphrase(context,
                                title: 'Backup passphrase',
                                hint: 'The passphrase used on your other device');
                            if (p == null) return;
                            await sync.setPassphrase(p);
                          }
                          await sync.resolveChoice(useCloud: true);
                        },
                  child: const Text('Restore backup'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: sync.busy
                      ? null
                      : () async {
                          if (await confirm(
                              context,
                              'Replace the cloud backup?',
                              'The backup in ${cloudName(sync.kind)} will be overwritten with this device\'s data.',
                              ok: 'Replace')) {
                            if (!sync.hasPassphrase &&
                                !(await askNewPassphrase(context))) {
                              return;
                            }
                            await sync.resolveChoice(useCloud: false);
                          }
                        },
                  child: const Text('Use this device'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProviderTile extends StatelessWidget {
  final SyncService sync;
  final CloudKind k;
  const _ProviderTile({required this.sync, required this.k});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isThis = sync.kind == k;
    final ready = SyncService.providerReady(k);
    final otherConnected = sync.kind != CloudKind.none && !isThis;
    final color = k == CloudKind.google
        ? const Color(0xFF34A853)
        : const Color(0xFF0061FE);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.15),
        child: Icon(
            k == CloudKind.google
                ? Icons.add_to_drive_rounded
                : Icons.inventory_2_rounded,
            color: color),
      ),
      title: Text(cloudName(k)),
      subtitle: Text(
        isThis
            ? 'Connected${sync.email == null ? '' : ' · ${sync.email}'}'
            : !ready
                ? 'Not set up yet'
                : k == CloudKind.google
                    ? 'Hidden app folder in your Drive'
                    : 'Apps/Bills O9 Time folder',
        style: TextStyle(color: isThis ? _green : cs.onSurfaceVariant),
      ),
      trailing: isThis
          ? TextButton(
              onPressed: () async {
                if (await confirm(context, 'Disconnect ${cloudName(k)}?',
                    'Your data stays on this device and the backup file stays in your ${cloudName(k)}.',
                    ok: 'Disconnect')) {
                  await sync.disconnect();
                }
              },
              child: const Text('Disconnect'))
          : FilledButton.tonal(
              onPressed: !ready || otherConnected || sync.busy
                  ? null
                  : () async {
                      if (!sync.hasPassphrase &&
                          !(await askNewPassphrase(context))) {
                        return;
                      }
                      await sync.connect(k);
                    },
              child: const Text('Connect'),
            ),
    );
  }
}

/// Asks for a new passphrase (twice). Returns true when saved.
Future<bool> askNewPassphrase(BuildContext context) async {
  final sync = context.read<SyncService>();
  final a = TextEditingController();
  final b = TextEditingController();
  final key = GlobalKey<FormState>();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Backup passphrase'),
      content: Form(
        key: key,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Encrypts your backup. You\'ll need it to restore on a new phone. Write it down — it can\'t be recovered.'),
            const SizedBox(height: 12),
            TextFormField(
              controller: a,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Passphrase'),
              validator: (v) => (v ?? '').length < 6
                  ? 'Use at least 6 characters'
                  : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: b,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Repeat passphrase'),
              validator: (v) => v != a.text ? 'Doesn\'t match' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () {
              if (key.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Save')),
      ],
    ),
  );
  if (ok != true) return false;
  await sync.setPassphrase(a.text);
  return true;
}

/// Asks for an existing passphrase.
Future<String?> askPassphrase(BuildContext context,
    {required String title, required String hint}) async {
  final c = TextEditingController();
  final r = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        obscureText: true,
        autofocus: true,
        decoration: InputDecoration(labelText: 'Passphrase', helperText: hint),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text),
            child: const Text('OK')),
      ],
    ),
  );
  return (r == null || r.isEmpty) ? null : r;
}
