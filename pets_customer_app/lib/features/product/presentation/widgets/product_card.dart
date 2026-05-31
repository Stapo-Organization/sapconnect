import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:iconsax/iconsax.dart';

class ProductCard extends StatefulWidget {
  final String title;
  final String price;
  final String? oldPrice;
  final String unitText;
  final String imageUrl;
  final bool isAvailable;
  final List<String> tags; // E.g., ['خصم 20%', 'جديد']

  const ProductCard({
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
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  int _quantity = 0;

  @override
  Widget build(BuildContext context) {
    bool isPoints = widget.price.contains('نقطة');
    
    return Container(
      width: 175,
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
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Area
              Container(
                height: 120,
                padding: const EdgeInsets.all(12.0),
                decoration: const BoxDecoration(
                  color: Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Center(
                  child: widget.imageUrl.startsWith('assets/')
                      ? widget.imageUrl.endsWith('svg')
                          ? SvgPicture.asset(widget.imageUrl, fit: BoxFit.contain)
                          : Image.asset(widget.imageUrl, fit: BoxFit.contain)
                      : Image.network(widget.imageUrl, fit: BoxFit.contain),
                ),
              ),
              
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Expanded(
                        child: Text(
                          widget.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Expo Arabic',
                            fontSize: 12,
                            color: Color(0xFF333333),
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                      ),
                      
                      // Price & Old Price Row
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.oldPrice != null)
                            Text(
                              widget.oldPrice!,
                              style: const TextStyle(
                                fontFamily: 'Expo Arabic',
                                fontSize: 10,
                                color: Color(0xFF9E9E9E),
                                height: 1.0,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Flexible(
                                child: Text(
                                  widget.price,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Expo Arabic',
                                    fontSize: isPoints ? 13 : 14,
                                    height: 1.0,
                                    color: isPoints ? const Color(0xFF4671AD) : const Color(0xFFE35446),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (!isPoints)
                                Text(
                                  widget.unitText,
                                  style: const TextStyle(
                                    fontFamily: 'Expo Arabic',
                                    fontSize: 9,
                                    height: 1.0,
                                    color: Color(0xFF757575),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              // Action Button Area (Dashed top border)
              Container(
                height: 44,
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFF0F0F0), width: 1, style: BorderStyle.none)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: _buildActionButtons(),
                ),
              ),
            ],
          ),
          
          // Tags Overlay
          if (widget.tags.isNotEmpty)
            Positioned(
              top: 8,
              right: 0, // Align to corner
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
            fontSize: 11,
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
          GestureDetector(
            onTap: () {
              setState(() {
                _quantity++;
              });
            },
            child: Container(
              height: 36,
              width: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF4671AD),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 18),
            ),
          ),
          Container(
            height: 36,
            width: 44,
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
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _quantity--;
              });
            },
            child: Container(
              height: 36,
              width: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFFF4D4F),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.delete_outline, color: Colors.white, size: 18),
            ),
          ),
        ],
      );
    }

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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text(
              'أضف الي السلة',
              style: TextStyle(
                fontFamily: 'Expo Arabic',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
