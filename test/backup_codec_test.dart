import 'package:bills_o9_time/sync/backup_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sample = {
    'v': 1,
    't': {
      'bills': {
        'c': ['id', 'name', 'amount'],
        'r': [
          [1, 'Rent', 46000.0],
          [2, 'Electricity', 15000.0],
        ],
      },
    },
  };

  test('round-trips with the right passphrase', () async {
    final bytes = await BackupCodec.encode(sample, 'correct horse');
    expect(BackupCodec.looksLikeBackup(bytes), isTrue);
    final back = await BackupCodec.decode(bytes, 'correct horse');
    expect(back['t']['bills']['r'][0][1], 'Rent');
  });

  test('wrong passphrase is rejected', () async {
    final bytes = await BackupCodec.encode(sample, 'correct horse');
    expect(() => BackupCodec.decode(bytes, 'wrong'),
        throwsA(isA<WrongPassphrase>()));
  });

  test('other files are rejected', () async {
    expect(() => BackupCodec.decode(List.filled(100, 7), 'x'),
        throwsA(isA<NotABackup>()));
  });
}
