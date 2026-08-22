import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/app_state.dart';

/// Persistence is one JSON document. At roughly 500 records a semester there is
/// no reason to pay for SQLite, and it means the on-disk format *is* the backup
/// format — export and import are the same code path as save and load.
class Store {
  static const fileName = 'proxymate.json';

  /// The save file. Overridable so tests can exercise the write path against a
  /// temp directory — `getApplicationDocumentsDirectory` needs a platform
  /// channel that `flutter test` does not provide.
  @visibleForTesting
  Future<File> resolveFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }

  Future<AppState?> load() async {
    try {
      final f = await resolveFile();
      if (!await f.exists()) return null;
      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return null;
      return AppState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // A corrupt save must not brick the app. Returning null drops the user
      // into setup with their old file still on disk for manual recovery.
      return null;
    }
  }

  /// Only ever one write in flight, and only ever the newest state.
  ///
  /// Callers are fire-and-forget, so rapid marking used to overlap several
  /// writes onto one fixed temp path; interleaved writes could rename a
  /// half-written document into place, defeating the very guard below.
  /// Coalescing is correct here because each save is the whole document —
  /// an older one has nothing the newer lacks.
  AppState? _pending;
  Future<void>? _inFlight;

  Future<void> save(AppState state) {
    _pending = state;
    return _inFlight ??= _drain();
  }

  Future<void> _drain() async {
    try {
      while (_pending != null) {
        final next = _pending!;
        _pending = null;
        await _writeAtomically(next);
      }
    } finally {
      _inFlight = null;
      // A save queued while the finally block ran would otherwise sit forever.
      if (_pending != null) _inFlight = _drain();
    }
  }

  /// Written to a temp file and renamed, so a crash mid-write cannot leave a
  /// half-serialized document where the term's records used to be.
  ///
  /// Failures are swallowed deliberately: callers are fire-and-forget, so an
  /// uncaught error here would take down the zone rather than lose one write,
  /// and the next save rewrites the whole document anyway.
  Future<void> _writeAtomically(AppState state) async {
    try {
      final f = await resolveFile();
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(encode(state), flush: true);
      await tmp.rename(f.path);
    } catch (e) {
      debugPrint('ProxyMate: could not save state: $e');
    }
  }

  Future<File> writeExport(AppState state) async {
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().split('T').first;
    final f = File(
      '${dir.path}${Platform.pathSeparator}proxymate-backup-$stamp.json',
    );
    await f.writeAsString(encode(state), flush: true);
    return f;
  }

  static String encode(AppState state) =>
      const JsonEncoder.withIndent('  ').convert(state.toJson());

  static AppState decode(String raw) =>
      AppState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
