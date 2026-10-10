import 'dart:io';

import 'package:finly/core/offline/cached_response.dart';

/// Where the copies of the reads are kept. One folder for each user, so that two
/// people who use the same phone never see each other's data.
/// Which copies to remove when they use more than [maxBytes]: the oldest first,
/// until the rest uses 80% of the limit. Nothing when they fit.
List<String> copiesToRemove(
  List<({String path, int size, DateTime modified})> copies,
  int maxBytes,
) {
  var total = copies.fold<int>(0, (sum, copy) => sum + copy.size);
  if (total <= maxBytes) return const [];

  final target = (maxBytes * 0.8).floor();
  final oldestFirst = [...copies]..sort((a, b) => a.modified.compareTo(b.modified));

  final remove = <String>[];
  for (final copy in oldestFirst) {
    if (total <= target) break;
    remove.add(copy.path);
    total -= copy.size;
  }
  return remove;
}

abstract class CacheStore {
  /// Whether copies are made and used. On unless the person turned it off.
  Future<bool> isEnabled();

  Future<void> setEnabled(bool value);

  Future<CachedResponse?> read(String userId, String key);

  Future<void> write(String userId, String key, CachedResponse response);

  /// How much space the copies use, in bytes.
  Future<int> sizeBytes();

  /// Erases every copy of every user (the choice of turning it off is kept).
  Future<void> clear();
}

class FileCacheStore implements CacheStore {
  /// The most the copies may use: 30 MB.
  static const defaultMaxBytes = 30 * 1024 * 1024;

  static const _enabledFile = '_disabled';

  final Future<Directory> Function() _directory;
  final int _maxBytes;
  final int _checkEveryBytes;
  int _bytesSinceCheck = 0;
  bool? _enabled;

  /// [directory] says where the copies go; it is asked only when needed. The
  /// size is checked each time [checkEveryBytes] were written.
  FileCacheStore({
    required Future<Directory> Function() directory,
    int maxBytes = defaultMaxBytes,
    int checkEveryBytes = 1024 * 1024,
  })  : _directory = directory,
        _maxBytes = maxBytes,
        _checkEveryBytes = checkEveryBytes;

  Future<Directory> _root() async {
    final root = await _directory();
    if (!await root.exists()) await root.create(recursive: true);
    return root;
  }

  /// A user id as a safe name of a folder.
  static String _folderOf(String userId) => userId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  @override
  Future<bool> isEnabled() async {
    // Read from the disk once; after that the answer is kept in memory, because
    // every request asks.
    final known = _enabled;
    if (known != null) return known;

    final root = await _root();
    return _enabled = !await File('${root.path}/$_enabledFile').exists();
  }

  @override
  Future<void> setEnabled(bool value) async {
    final root = await _root();
    final marker = File('${root.path}/$_enabledFile');

    if (value) {
      if (await marker.exists()) await marker.delete();
    } else {
      await marker.writeAsString('off');
    }
    _enabled = value;
  }

  @override
  Future<CachedResponse?> read(String userId, String key) async {
    final file = File('${(await _root()).path}/${_folderOf(userId)}/$key.json');
    if (!await file.exists()) return null;

    try {
      return CachedResponse.fromJson(await file.readAsString());
    } catch (_) {
      // A copy that cannot be read (cut short, or from another version) is
      // worth nothing: it is removed and treated as if it had never been made.
      try {
        await file.delete();
      } catch (_) {}
      return null;
    }
  }

  @override
  Future<void> write(String userId, String key, CachedResponse response) async {
    final folder = Directory('${(await _root()).path}/${_folderOf(userId)}');
    if (!await folder.exists()) await folder.create(recursive: true);

    // Written to a temporary file first, so that a copy is never half written.
    final text = response.toJson();
    final temporary = File('${folder.path}/$key.tmp');
    await temporary.writeAsString(text, flush: true);
    await temporary.rename('${folder.path}/$key.json');

    _bytesSinceCheck += text.length;
    if (_bytesSinceCheck > _checkEveryBytes) {
      _bytesSinceCheck = 0;
      await _makeRoom();
    }
  }

  /// Removes the oldest copies until the rest uses 80% of the limit.
  Future<void> _makeRoom() async {
    final copies = await _copies();
    final remove = copiesToRemove(
      [
        for (final copy in copies)
          (path: copy.file.path, size: copy.stat.size, modified: copy.stat.modified),
      ],
      _maxBytes,
    );

    for (final path in remove) {
      await _delete(File(path));
    }
  }

  /// A copy can be locked for a moment (on Windows, by an antivirus that is
  /// reading what was just written), so a removal that fails is tried again.
  static Future<void> _delete(File file) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await file.delete();
        return;
      } on PathNotFoundException {
        return;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  Future<List<({File file, FileStat stat})>> _copies() async {
    final root = await _root();
    final copies = <({File file, FileStat stat})>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.endsWith('.json')) {
        copies.add((file: entity, stat: await entity.stat()));
      }
    }
    return copies;
  }

  @override
  Future<int> sizeBytes() async {
    var total = 0;
    for (final copy in await _copies()) {
      total += copy.stat.size;
    }
    return total;
  }

  @override
  Future<void> clear() async {
    final root = await _root();
    await for (final entity in root.list(followLinks: false)) {
      if (entity is Directory) {
        try {
          await entity.delete(recursive: true);
        } catch (_) {}
      }
    }
  }
}
