import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Snapshot of the profile picture loaded into memory.
///
/// At most one of [file] or [bytes] is non-null:
///   * mobile/desktop → [file] points to a persisted profile image
///   * web            → [bytes] holds the decoded image bytes
@immutable
class ProfileImageState {
  const ProfileImageState({this.file, this.bytes});
  const ProfileImageState.empty() : this(file: null, bytes: null);

  final File? file;
  final Uint8List? bytes;

  bool get hasImage => file != null || bytes != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProfileImageState &&
          other.file?.path == file?.path &&
          identical(other.bytes, bytes));

  @override
  int get hashCode => Object.hash(file?.path, identityHashCode(bytes));
}

/// Single source of truth for the user's profile picture.
///
/// Replaces the three independent SharedPreferences + File + base64Decode
/// pipelines previously living in `profile_page.dart`,
/// `suggestions_screen.dart`, and `details_page.dart`. Each of those screens
/// used to perform redundant disk I/O on every mount; this store loads once
/// and broadcasts via [ValueNotifier].
///
/// PERFORMANCE:
///   * Disk + prefs read happens once (or on explicit [refresh]).
///   * Web base64 decode is offloaded to an isolate via [compute] so the UI
///     thread stays free during the ~30–50ms decode of a 1 MB profile pic.
///   * Notifiers diff via [ProfileImageState.==] — listeners only rebuild when
///     the underlying image actually changes.
class ProfileImageStore extends ValueNotifier<ProfileImageState> {
  ProfileImageStore._() : super(const ProfileImageState.empty());

  /// App-wide singleton.
  static final ProfileImageStore instance = ProfileImageStore._();

  static const String _prefsKeyMobile = 'profile_image';
  static const String _prefsKeyWeb = 'profile_image_base64';

  Future<void>? _loadInFlight;
  bool _loaded = false;

  /// Load the profile image from disk / prefs if not already cached.
  ///
  /// Concurrent callers share the same in-flight future, so 3 screens
  /// mounting back-to-back trigger only one disk read.
  Future<void> ensureLoaded() {
    if (_loaded) return Future.value();
    final inFlight = _loadInFlight;
    if (inFlight != null) return inFlight;
    final future = _loadFromDisk();
    _loadInFlight = future;
    return future;
  }

  /// Force a re-read from disk (e.g. after the user picks a new picture
  /// in [ProfilePage] and the suggestions screen returns from `Navigator.pop`).
  Future<void> refresh() => _loadFromDisk();

  /// Persist a freshly-picked image and update the in-memory snapshot.
  Future<void> setMobileImage(File file) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyMobile, file.path);
    await prefs.remove(_prefsKeyWeb);
    _publish(ProfileImageState(file: file));
  }

  /// Web variant — stores raw bytes and a base64 mirror in prefs.
  Future<void> setWebBytes(Uint8List bytes) async {
    final prefs = await SharedPreferences.getInstance();
    // Encoding on the UI thread is cheap relative to the decode; only the
    // decode path is offloaded.
    await prefs.setString(_prefsKeyWeb, base64Encode(bytes));
    await prefs.remove(_prefsKeyMobile);
    _publish(ProfileImageState(bytes: bytes));
  }

  /// Clear the cached image and the persisted prefs entries.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKeyMobile);
    await prefs.remove(_prefsKeyWeb);
    _publish(const ProfileImageState.empty());
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  Future<void> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (kIsWeb) {
        final base64Str = prefs.getString(_prefsKeyWeb);
        if (base64Str == null || base64Str.isEmpty) {
          _publish(const ProfileImageState.empty());
          return;
        }
        try {
          // Offload the (potentially expensive) decode so we don't drop a
          // frame on the UI thread.
          final bytes = await compute<String, Uint8List>(
            _decodeBase64,
            base64Str,
          );
          _publish(ProfileImageState(bytes: bytes));
        } catch (_) {
          await prefs.remove(_prefsKeyWeb);
          _publish(const ProfileImageState.empty());
        }
        return;
      }

      final path = prefs.getString(_prefsKeyMobile);
      if (path == null || path.isEmpty) {
        _publish(const ProfileImageState.empty());
        return;
      }
      final file = File(path);
      if (await file.exists()) {
        _publish(ProfileImageState(file: file));
      } else {
        await prefs.remove(_prefsKeyMobile);
        _publish(const ProfileImageState.empty());
      }
    } finally {
      _loaded = true;
      _loadInFlight = null;
    }
  }

  void _publish(ProfileImageState next) {
    if (value == next) return; // skip identical emits (no listener wake-up)
    value = next;
  }
}

/// Top-level so it can be used with `compute()`.
Uint8List _decodeBase64(String src) => base64Decode(src);
