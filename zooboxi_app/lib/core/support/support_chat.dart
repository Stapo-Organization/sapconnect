import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/meta/data/meta_repository.dart';
import '../../l10n/app_localizations.dart';

/// The store's WhatsApp number, or null while it has none. Read from `/meta`
/// so setting it in the store's settings page turns the buttons on in every
/// installed app, with no release.
final supportWhatsappProvider = Provider<String?>((ref) {
  final number = ref.watch(metaProvider).value?.supportWhatsapp;
  return (number == null || number.isEmpty) ? null : number;
});

/// Opens a WhatsApp chat with the store, the first line already written.
///
/// With [orderNumber] the message names the order, so whoever answers can
/// open it without asking «رقم طلبك؟» — the first question that makes a
/// waiting customer feel like a ticket.
Future<bool> openSupportChat(
  BuildContext context, {
  required String number,
  String? orderNumber,
}) {
  final l = L.of(context);
  final text = orderNumber == null || orderNumber.isEmpty
      ? l.supportChatHello
      : l.supportChatAboutOrder(orderNumber);
  final uri = Uri.https('wa.me', '/$number', {'text': text});
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
