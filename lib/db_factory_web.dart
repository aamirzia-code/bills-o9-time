import 'package:sqflite/sqflite.dart' show DatabaseFactory;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Web / PWA: SQLite compiled to WebAssembly, persisted in the browser's
/// IndexedDB. Requires web/sqlite3.wasm (added by
/// `dart run sqflite_common_ffi_web:setup`).
DatabaseFactory get appDatabaseFactory => databaseFactoryFfiWebNoWebWorker;
