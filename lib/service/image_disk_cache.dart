import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Persistent on-disk cache for remote images.
///
/// Why hand-rolled?
///   The codebase intentionally doesn't pull in `cached_network_image` (one
///   less moving part to update + audit). Place hero images dominate the
///   network bill on the suggestions feed, and Flutter's built-in
///   [PaintingBinding.imageCache] is in-memory only — every cold start /
///   eviction triggers a full re-download. This service writes the bytes to
///   the OS temp directory so repeat views become a local file read.
///
/// Behaviour:
///   * Cache lives under `<temp>/img_cache/` — the OS reclaims it under
///     memory pressure, so no explicit eviction is needed.
///   * Concurrent calls for the same URL share a single in-flight future
///     ([_inFlight]) so a scroll burst doesn't fan out into N HTTP calls
///     for the same image.
///   * Disk + network failures are silent — callers fall back to placeholder.
///   * Web is unsupported (no temp directory). The widget falls back to
///     `Image.network` automatically.
class ImageDiskCache {
  ImageDiskCache._();
  static final ImageDiskCache instance = ImageDiskCache._();

  static const Duration _networkTimeout = Duration(seconds: 20);
  static const String _subdir = 'img_cache';

  Directory? _dir;
  Future<Directory>? _dirInit;

  final Map<String, Future<File?>> _inFlight = <String, Future<File?>>{};

  /// Returns a cached file for [url], downloading and persisting if needed.
  ///
  /// Returns `null` on web or on any I/O / network failure.
  Future<File?> fileFor(String url) {
    if (kIsWeb || url.isEmpty) return Future.value(null);
    final existing = _inFlight[url];
    if (existing != null) return existing;
    final future = _resolve(url);
    _inFlight[url] = future;
    future.whenComplete(() => _inFlight.remove(url));
    return future;
  }

  /// Synchronous best-effort lookup — used to skip the async hop when the
  /// file is already on disk.
  File? cachedFileSync(String url) {
    if (kIsWeb || url.isEmpty) return null;
    final dir = _dir;
    if (dir == null) return null;
    final file = File('${dir.path}/${_safeName(url)}');
    return file.existsSync() ? file : null;
  }

  Future<void> warmUp() => _ensureDir().then((_) {});

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  Future<Directory> _ensureDir() {
    final existing = _dir;
    if (existing != null) return Future.value(existing);
    return _dirInit ??= _createDir();
  }

  Future<Directory> _createDir() async {
    final base = await getTemporaryDirectory();
    final dir = Directory('${base.path}/$_subdir');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _dir = dir;
    return dir;
  }

  /// FNV-1a hash. Stable, fast, fits in a 32-bit hex string — collisions
  /// are not safety-critical (a collision just means one image gets the
  /// wrong cached file, which would fail validation on read).
  String _safeName(String url) {
    var hash = 0x811C9DC5;
    for (final byte in url.codeUnits) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  Future<File?> _resolve(String url) async {
    try {
      final dir = await _ensureDir();
      final file = File('${dir.path}/${_safeName(url)}');

      // Cache hit — no network round-trip.
      if (await file.exists()) return file;

      // Cache miss — download once, persist, hand back the file.
      final response = await http.get(Uri.parse(url)).timeout(_networkTimeout);
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return null;
      }

      // Write atomically: stream to a temp file, then rename. Prevents
      // partial files from being read by a concurrent scroll burst.
      final tempFile = File('${file.path}.part');
      await tempFile.writeAsBytes(response.bodyBytes, flush: true);
      await tempFile.rename(file.path);
      return file;
    } catch (_) {
      return null;
    }
  }
}
