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

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }

  Future<AppState?> load() async {
    try {
      final f = await _file();
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

  /// Written to a temp file and renamed, so a crash mid-write can't leave a
  /// half-serialized document where the semester's records used to be.
  ///
  /// Callers treat this as fire-and-forget — in-memory state is what the UI
  /// renders, and a tap must never block on the disk. That makes swallowing
  /// failures here the right call rather than a lazy one: an uncaught error in
  /// a detached future would take down the zone instead of just losing one
  /// write, and the next commit rewrites the whole document anyway.
  Future<void> save(AppState state) async {
    try {
      final f = await _file();
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
