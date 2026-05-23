import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/svg.dart';
import 'package:lottie/lottie.dart';

class AppImage extends StatelessWidget {
  final String path;
  final double? height, width;
  final BoxFit fit;
  final Color? color;

  const AppImage(
    this.path, {
    super.key,
    this.height,
    this.width,
    this.fit = BoxFit.scaleDown,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final targetCacheWidth =
        !kIsWeb && width != null ? (width! * devicePixelRatio).round() : null;
    final targetCacheHeight =
        !kIsWeb && height != null ? (height! * devicePixelRatio).round() : null;

    if (path.endsWith("svg")) {
      return SvgPicture.asset(
        path,
        fit: fit,
        height: height,
        width: width,
        colorFilter:
            color == null ? null : ColorFilter.mode(color!, BlendMode.srcIn),
      );
    } else if (path.endsWith("json")) {
      return Lottie.asset(
        path,
        fit: fit,
        height: height,
        width: width,
      );
    } else if (path.startsWith("http")) {
      return Image.network(
        path,
        fit: fit,
        height: height,
        width: width,
        color: color,
        cacheWidth: targetCacheWidth,
        cacheHeight: targetCacheHeight,
        webHtmlElementStrategy: kIsWeb
            ? WebHtmlElementStrategy.prefer
            : WebHtmlElementStrategy.never,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: height,
            width: width,
            color: Colors.grey[200],
            child: Icon(
              Icons.error_outline,
              color: Colors.grey[400],
              size: 32,
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      (loadingProgress.expectedTotalBytes ?? 1)
                  : null,
            ),
          );
        },
      );
    } else if (path.contains("assets")) {
      return Image.asset(
        path,
        fit: fit,
        height: height,
        width: width,
        color: color,
        cacheWidth: targetCacheWidth,
        cacheHeight: targetCacheHeight,
      );
    } else {
      if (kIsWeb) {
        // Local device file paths are not available on Flutter web.
        return Container(
          height: height,
          width: width,
          color: Colors.grey[200],
          child: Icon(
            Icons.image_not_supported_outlined,
            color: Colors.grey[500],
            size: 28,
          ),
        );
      }
      return Image.file(
        File(path),
        fit: fit,
        height: height,
        width: width,
        color: color,
        cacheWidth: targetCacheWidth,
        cacheHeight: targetCacheHeight,
      );
    }
  }
}
