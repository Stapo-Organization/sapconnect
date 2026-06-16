import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Opens [url] full-screen on a black backdrop with pinch-to-zoom / pan.
/// Single tap (or the close button / back) dismisses.
Future<void> showFullScreenImage(BuildContext context, String url) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, _, _) => _FullScreenImageViewer(url: url),
      transitionsBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
    ),
  );
}

class _FullScreenImageViewer extends StatelessWidget {
  const _FullScreenImageViewer({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.contain,
                    placeholder: (c, u) => const Center(
                      child: CircularProgressIndicator(color: Colors.white70),
                    ),
                    errorWidget: (_, _, _) =>
                        const Icon(Icons.broken_image_outlined, color: Colors.white38, size: 48),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: Material(
              color: Colors.black45,
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
