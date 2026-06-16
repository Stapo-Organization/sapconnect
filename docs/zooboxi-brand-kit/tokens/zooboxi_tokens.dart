// ════════════════════════════════════════════════════════════════════════
// ZOOBOXI · Design Tokens (Dart / Flutter)
// هوية متجر زووبوكسي — المصدر الموحّد للألوان والخطوط للتطبيقات.
// مستخرجة من الشعار الرسمي + ثيم المتجر. الهوية المعتمدة = تركواز + كورال دافئ.
//
// ملاحظة: تطبيق العميل الحالي (pets_customer_app) يستخدم أزرق (#3A71B3) — وهو
// خارج الهوية. هذه الـ tokens هي المرجع لمحاذاة التطبيق مع المتجر لاحقًا.
// ════════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

/// ألوان وقيَم هوية زووبوكسي. استخدمها كمصدر وحيد للحقيقة.
abstract final class ZooboxiTokens {
  // ── Brand · التركواز ──────────────────────────────────────────────
  static const Color teal     = Color(0xFF429D9C); // الأساسي
  static const Color tealDark = Color(0xFF2D7A79);
  static const Color tealDeep = Color(0xFF1F5C5B);
  static const Color tealTint = Color(0xFFDCEFEE);
  static const Color mint     = Color(0xFFE6F2E6);

  // ── Warm · الكورال والبرتقالي ─────────────────────────────────────
  static const Color coral     = Color(0xFFD46856); // الأكشن/الأيقونات
  static const Color coralDark = Color(0xFFB14B3B);
  static const Color orange    = Color(0xFFD48644);
  static const Color amber     = Color(0xFFF4BE2C); // إبراز نادر
  static const Color peach     = Color(0xFFF7DDC7);

  // ── Neutrals · المحايدة ───────────────────────────────────────────
  static const Color ink     = Color(0xFF2C3E2D); // النص
  static const Color inkSoft = Color(0xFF5C6B5C);
  static const Color line    = Color(0xFFE7EBE6);
  static const Color cream   = Color(0xFFFFF7EF); // خلفية
  static const Color paper   = Color(0xFFFFFFFF);

  // ── Semantic · الحالات ────────────────────────────────────────────
  static const Color success = Color(0xFF2FA36B);
  static const Color warning = Color(0xFFE8A33D);
  static const Color error   = Color(0xFFE5484D);
  static const Color info    = teal;

  // ── Gradients · التدرّجات الموقّعة ─────────────────────────────────
  /// تدرّج الشعار: كورال → برتقالي → تركواز
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.centerRight, end: Alignment.centerLeft,
    colors: [coral, orange, teal], stops: [0.0, 0.38, 1.0],
  );
  static const LinearGradient tealGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [teal, tealDark],
  );
  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [amber, orange],
  );
  /// عرض ساخن / تخفيض
  static const LinearGradient hotGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFFFF6B6B), Color(0xFFEE5A24)],
  );

  // ── Typography · الخطوط ───────────────────────────────────────────
  static const String fontDisplay = 'Baloo Bhaijaan 2'; // عناوين مرحة
  static const String fontHead     = 'El Messiri';        // عناوين أنيقة
  static const String fontBody     = 'Tajawal';           // نصوص وأسعار
  static const String fontApp      = 'Cairo';             // بديل

  // ── Radius · الاستدارة ────────────────────────────────────────────
  static const double rSm = 8, rMd = 12, rLg = 16, rXl = 22, rPill = 999;

  // ── Spacing · المسافات (شبكة 4) ──────────────────────────────────
  static const double s1 = 4, s2 = 8, s3 = 12, s4 = 16, s6 = 24, s8 = 32, s12 = 48;

  // ── Shadows · الظلال ──────────────────────────────────────────────
  static const List<BoxShadow> shCard = [
    BoxShadow(color: Color(0x122C3E2D), blurRadius: 3, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> shHover = [
    BoxShadow(color: Color(0x292D7A79), blurRadius: 30, offset: Offset(0, 10)),
  ];
}
