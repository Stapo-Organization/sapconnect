import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:iconsax/iconsax.dart';

class ProductHorizontalCard extends StatefulWidget {
  final String title;
  final String price;
  final String? oldPrice;
  final String unitText;
  final String imageUrl;
  final bool isAvailable;
  final List<String> tags;

  const ProductHorizontalCard({
    super.key,
    required this.title,
    required this.price,
    this.oldPrice,
    required this.unitText,
    required this.imageUrl,
    this.isAvailable = true,
    this.tags = const [],
  });

  @override
  State<ProductHorizontalCard> createState() => _ProductHorizontalCardState();
}

class _ProductHorizontalCardState extends State<ProductHorizontalCard> {
  int _quantity = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140, // Height based on Figma
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0F0F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Right Side: Image Area (RTL orientation)
          Container(
            width: 140,
            decoration: const BoxDecoration(
              color: Color(0xFFFAFAFA),
              borderRadius: BorderRadius.horizontal(right: Radius.circular(12)), // right side is start in RTL
            ),
            child: Stack(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: widget.imageUrl.startsWith('assets/')
                        ? widget.imageUrl.endsWith('svg')
                            ? SvgPicture.asset(widget.imageUrl, fit: BoxFit.contain)
                            : Image.asset(widget.imageUrl, fit: BoxFit.contain)
                        : Image.network(widget.imageUrl, fit: BoxFit.contain),
                  ),
                ),
                if (widget.tags.isNotEmpty)
                  Positioned(
                    top: 8,
                    right: 0, // Align to edge
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: widget.tags.map((tag) {
                        bool isPointsOffer = tag.contains('النقاط');
                        bool isPromo = tag.contains('احصل على');
                        Color bgColor = isPointsOffer ? const Color(0xFF4671AD) : (isPromo ? const Color(0xFFFE3A46) : const Color(0xFF4671AD).withOpacity(0.9));
                        IconData iconData = isPointsOffer ? Iconsax.cup : Iconsax.tag5;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(5),
                              bottomLeft: Radius.circular(100),
                              topLeft: Radius.circular(100),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                tag,
                                style: const TextStyle(
                                  fontFamily: 'Expo Arabic',
                                  fontSize: 9,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(iconData, color: Colors.white, size: 10),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
          
          // Left Side: Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Title
                  Text(
                    widget.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Expo Arabic',
                      fontSize: 14,
                      color: Color(0xFF333333),
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  
                  // Unit & Price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.unitText,
                        style: const TextStyle(
                          fontFamily: 'Expo Arabic',
                          fontSize: 12,
                          color: Color(0xFF757575),
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (widget.oldPrice != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 4.0),
                              child: Text(
                                widget.oldPrice!,
                                style: const TextStyle(
                                  fontFamily: 'Expo Arabic',
                                  fontSize: 12,
                                  color: Color(0xFF9F9F9F),
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ),
                          Text(
                            widget.price,
                            style: const TextStyle(
                              fontFamily: 'Expo Arabic',
                              fontSize: 14,
                              color: Color(0xFFE35446),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  // Action Button
                  SizedBox(
                    height: 44,
                    child: _buildActionButtons(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (!widget.isAvailable) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF3BF45).withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: const Text(
          'المنتج غير متوفر',
          style: TextStyle(
            fontFamily: 'Expo Arabic',
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFFD6A01A),
          ),
        ),
      );
    }

    if (_quantity > 0) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Increase Button (Blue)
          GestureDetector(
            onTap: () {
              setState(() {
                _quantity++;
              });
            },
            child: Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF4671AD),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
          ),
          
          // Quantity Text
          Expanded(
            child: Container(
              height: 44,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFEAEAEA)),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                '$_quantity',
                style: const TextStyle(
                  fontFamily: 'Expo Arabic',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          
          // Decrease/Delete Button (Red)
          GestureDetector(
            onTap: () {
              setState(() {
                _quantity--;
              });
            },
            child: Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFFF4D4F),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
            ),
          ),
        ],
      );
    }

    // Default "Add to Cart" Button (Blue)
    return GestureDetector(
      onTap: () {
        setState(() {
          _quantity = 1;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF4671AD),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: const Text(
          'أضف الي السلة',
          style: TextStyle(
            fontFamily: 'Expo Arabic',
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
