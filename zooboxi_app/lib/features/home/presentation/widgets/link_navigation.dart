import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../catalog/data/catalog_models.dart';

/// The in-app location of a brand's boutique page.
///
/// Spelled once, because three places link to a brand — the strip, a hero
/// slide, and any server-declared `{type: brand}` link — and a route rename
/// that only fixes two of them is a bug nobody notices until a customer taps
/// the third.
String brandLocation(String slug, {String? title}) => (title ?? '').isEmpty
    ? Uri(path: '/brand/$slug').toString()
    : Uri(path: '/brand/$slug', queryParameters: {'title': title}).toString();

/// Follows a merchandising link.
///
/// The server describes destinations declaratively (`{type, value}`) so it can
/// point a banner at a new category without an app release. An unknown type is
/// ignored rather than guessed at — a banner that does nothing is better than
/// one that opens the wrong screen.
Future<void> followLink(BuildContext context, ZbLink? link, {String? title}) async {
  if (link == null) return;

  switch (link.type) {
    case 'product':
      unawaited(context.push('/product/${link.value}'));
    case 'category':
      unawaited(context.push(Uri(
        path: '/listing',
        queryParameters: {'category': link.value, 'title': ?title},
      ).toString()));
    // A brand has a page of its own — its stage, its story, its departments.
    // Sending it to a filtered listing was throwing all of that away.
    case 'brand':
      unawaited(context.push(brandLocation(link.value, title: title)));
    case 'search':
      unawaited(context.push(Uri(
        path: '/listing',
        queryParameters: {'q': link.value, 'title': link.value},
      ).toString()));
    case 'url':
      await _openExternal(context, link.value);
  }
}

/// External links open in a custom tab styled to the app, so a promo page
/// still feels like part of the store and the customer comes back with one tap.
Future<void> _openExternal(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return;
  final cs = context.cs;
  try {
    await launchUrl(
      uri,
      customTabsOptions: CustomTabsOptions(
        colorSchemes: CustomTabsColorSchemes.defaults(toolbarColor: cs.surface),
        showTitle: true,
      ),
      safariVCOptions: SafariViewControllerOptions(
        preferredBarTintColor: cs.surface,
        preferredControlTintColor: cs.primary,
        barCollapsingEnabled: true,
      ),
    );
  } catch (_) {
    // No browser available — nothing useful to say, so stay silent.
  }
}
