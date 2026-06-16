import 'package:flutter/material.dart';

import 'pages/product_detail_page.dart';

/// Open the shared product-detail screen (stock across every warehouse &
/// showroom) for any product reference anywhere in the app — the same page the
/// search results open. Pass [myWarehouses] to light up the "معارضي" filter.
Future<void> openProductDetail(
  BuildContext context,
  String itemCode, {
  String? name,
  List<String> myWarehouses = const [],
}) {
  if (itemCode.isEmpty) return Future.value();
  return Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => ProductDetailPage(
      itemCode: itemCode,
      fallbackName: name,
      myWarehouses: myWarehouses,
    ),
  ));
}
