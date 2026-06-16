import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';

/// A network image that decodes at a sensible size and auto-retries a couple of
/// times on failure. Product photos come from a single heavy-size host
/// (~300 KB PNGs) and occasionally drop on a cold cache; without a retry the
/// card is stuck on its error placeholder until a manual refresh. [errorBuilder]
/// is shown only after retries are exhausted.
class RetryNetworkImage extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final WidgetBuilder errorBuilder;
  final int? memCacheWidth;

  const RetryNetworkImage({
    super.key,
    required this.url,
    required this.errorBuilder,
    this.fit = BoxFit.cover,
    this.memCacheWidth = 450,
  });

  @override
  State<RetryNetworkImage> createState() => _RetryNetworkImageState();
}

class _RetryNetworkImageState extends State<RetryNetworkImage> {
  int _attempt = 0;
  static const _maxRetries = 2;

  Widget _loading() => Shimmer.fromColors(
        baseColor: AppColors.surfaceVariant,
        highlightColor: AppColors.surface,
        child: Container(color: Colors.white),
      );

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      // New key per attempt forces a fresh load WITHOUT cache-busting the URL,
      // so successful downloads still cache normally.
      key: ValueKey('${widget.url}#$_attempt'),
      imageUrl: widget.url,
      fit: widget.fit,
      memCacheWidth: widget.memCacheWidth,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (_, _) => _loading(),
      errorWidget: (context, _, _) {
        if (_attempt < _maxRetries) {
          Future.delayed(Duration(milliseconds: 600 * (_attempt + 1)), () {
            if (mounted) setState(() => _attempt++);
          });
          return _loading();
        }
        return widget.errorBuilder(context);
      },
    );
  }
}
