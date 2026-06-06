import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:rafiq_app/service/image_disk_cache.dart';

/// Drop-in replacement for `Image.network` that:
///   1. Reads from the persistent [ImageDiskCache] first (no re-download
///      on subsequent app launches).
///   2. Falls back to a one-shot network download if the cache is empty.
///   3. Decodes at the *display* resolution (`cacheWidth` / `cacheHeight`)
///      so a 4K JPEG doesn't sit in `imageCache` as 32 MB of decoded RGBA.
///
/// On web (where `dart:io` and `path_provider` don't apply) the widget
/// transparently degrades to `Image.network`.
class CachedNetworkImage extends StatefulWidget {
  const CachedNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final WidgetBuilder? placeholder;
  final WidgetBuilder? errorWidget;

  @override
  State<CachedNetworkImage> createState() => _CachedNetworkImageState();
}

class _CachedNetworkImageState extends State<CachedNetworkImage> {
  File? _cachedFile;
  bool _resolving = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant CachedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _cachedFile = null;
      _failed = false;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    if (kIsWeb) return; // web falls back to network in build()
    if (widget.url.isEmpty) {
      setState(() => _failed = true);
      return;
    }

    // Synchronous fast-path — avoids an async hop and a frame of placeholder
    // for images already on disk.
    final hit = ImageDiskCache.instance.cachedFileSync(widget.url);
    if (hit != null) {
      _cachedFile = hit;
      return;
    }

    setState(() => _resolving = true);
    final file = await ImageDiskCache.instance.fileFor(widget.url);
    if (!mounted) return;
    setState(() {
      _resolving = false;
      _cachedFile = file;
      _failed = file == null;
    });
  }

  // Cap decode resolution at 2× the displayed pixel size — high-DPR retina
  // sharp, no waste. Falls back to the screen width for full-bleed heroes.
  int? _cacheDimension(double? logical, double dpr) {
    if (logical == null || !logical.isFinite || logical <= 0) return null;
    return (logical * dpr).round();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return widget.errorWidget?.call(context) ?? const _DefaultError();
    }

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final displayWidth = widget.width;
    final decodeWidth = displayWidth != null && displayWidth.isFinite
        ? displayWidth
        : MediaQuery.sizeOf(context).width;
    final cacheW = _cacheDimension(decodeWidth, dpr);
    final cacheH = _cacheDimension(widget.height, dpr);

    if (kIsWeb) {
      return Image.network(
        widget.url,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        cacheWidth: cacheW,
        cacheHeight: cacheH,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) =>
            widget.errorWidget?.call(context) ?? const _DefaultError(),
      );
    }

    if (_cachedFile != null) {
      return Image.file(
        _cachedFile!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        cacheWidth: cacheW,
        cacheHeight: cacheH,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) =>
            widget.errorWidget?.call(context) ?? const _DefaultError(),
      );
    }

    if (_resolving) {
      return widget.placeholder?.call(context) ?? const _DefaultPlaceholder();
    }

    // Pre-resolve hasn't returned yet (initState ran but micro-task pending).
    return widget.placeholder?.call(context) ?? const _DefaultPlaceholder();
  }
}

class _DefaultPlaceholder extends StatelessWidget {
  const _DefaultPlaceholder();

  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: Color(0xFFF0EEE9), // neutral100
      );
}

class _DefaultError extends StatelessWidget {
  const _DefaultError();

  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: Color(0xFFF0EEE9),
        child: Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: Color(0xFF6F6F6F), // neutral600
          ),
        ),
      );
}
