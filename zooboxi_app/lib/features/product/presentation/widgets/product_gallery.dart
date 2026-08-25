import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/widgets/zb_image.dart';

/// The image gallery: swipeable pages, page dots, and pinch-to-zoom.
///
/// Zoom matters here more than in most catalogues — pet-food buyers check
/// ingredient panels and weights off the pack photo, and the alternative is
/// them leaving to search the brand's own site.
class ProductGallery extends StatefulWidget {
  const ProductGallery({super.key, required this.images, this.heroImage});

  final List<String> images;

  /// The selected variant's image, if it has its own — shown ahead of the
  /// gallery so choosing a flavour visibly changes the pack.
  final String? heroImage;

  @override
  State<ProductGallery> createState() => _ProductGalleryState();
}

class _ProductGalleryState extends State<ProductGallery> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<String> get _images {
    final hero = widget.heroImage;
    if (hero == null || hero.isEmpty) return widget.images;
    return [hero, ...widget.images.where((e) => e != hero)];
  }

  @override
  Widget build(BuildContext context) {
    final images = _images;
    final size = MediaQuery.sizeOf(context).width;
    final cs = context.cs;

    if (images.isEmpty) {
      return SizedBox(
        height: size * 0.86,
        child: const ZbImage(url: null),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: size * 0.86,
          child: PageView.builder(
            controller: _controller,
            itemCount: images.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) => InteractiveViewer(
              minScale: 1,
              maxScale: 3.6,
              clipBehavior: Clip.none,
              child: ZbImage(
                url: images[index],
                padding: const EdgeInsets.all(20),
                backgroundColor: Colors.transparent,
              ),
            ),
          ),
        ),
        if (images.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(images.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: Motion.select,
                  curve: Motion.decelerate,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? cs.primary : cs.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}
