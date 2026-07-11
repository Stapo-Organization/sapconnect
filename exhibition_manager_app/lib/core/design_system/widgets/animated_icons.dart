import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens/radius.dart';

/// ─── نظام الأيقونات الحيّة ───────────────────────────────────────────────
/// أساسيات حركة صغيرة قابلة للتركيب تُستخدم في كامل التطبيق كي تقرأ الأيقونات
/// كعناصر حيّة لا رموز جامدة:
///
///   • [PopIn]        — دخول نابض (scale + fade بارتداد) مع تأخير للتتابع.
///   • [FloatingIcon] — طفو عمودي هادئ مستمر (أبطال الحالات الفارغة).
///   • [BreathingIcon]— تنفّس (تكبير/تصغير خفيف) للمؤشرات «الحيّة».
///   • [WiggleIcon]   — اهتزاز تنبيهي متضائل يعمل مرة عند الظهور (الأخطاء).
///   • [GlowIconChip] — شارة الأيقونة القياسية: سكويركل متدرّج بتوهّج ملوّن.
///   • [AnimatedNavIcon] — نبضة زنبركية لأيقونة التبويب عند اختياره.
///
/// كل الحلقات المستمرة تحترم [MediaQuery.disableAnimations] وتغلَّف بـ
/// [RepaintBoundary]. القاعدة: الحلقات المستمرة لعنصر بطل واحد في الشاشة،
/// لا لصفوف القوائم — صفوف القوائم تكتفي بدخول [PopIn] المتتابع.

bool _reduceMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

/// دخول نابض: يكبر من 55٪ مع شفافية، بمنحنى ارتدادي — أعطِ كل عنصر في القائمة
/// `delay: Duration(milliseconds: i * 60)` فيدخلون كموجة.
class PopIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;

  const PopIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 420),
  });

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion(context)) return widget.child;
    final scale = CurvedAnimation(parent: _c, curve: Curves.easeOutBack);
    final fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    return FadeTransition(
      opacity: fade,
      child: ScaleTransition(
        scale: Tween(begin: 0.55, end: 1.0).animate(scale),
        child: widget.child,
      ),
    );
  }
}

/// طفو عمودي هادئ مستمر — لأيقونة بطلة واحدة (حالة فارغة، سفينة الشحن).
class FloatingIcon extends StatefulWidget {
  final Widget child;
  final double amplitude;
  final Duration period;

  const FloatingIcon({
    super.key,
    required this.child,
    this.amplitude = 5,
    this.period = const Duration(milliseconds: 2600),
  });

  @override
  State<FloatingIcon> createState() => _FloatingIconState();
}

class _FloatingIconState extends State<FloatingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.period)..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion(context)) return widget.child;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, math.sin(_c.value * 2 * math.pi) * widget.amplitude),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// تنفّس خفيف مستمر (١ ↔ [maxScale]) — للمؤشرات الحيّة كنبض المعرض.
class BreathingIcon extends StatefulWidget {
  final Widget child;
  final double maxScale;
  final Duration period;

  const BreathingIcon({
    super.key,
    required this.child,
    this.maxScale = 1.07,
    this.period = const Duration(milliseconds: 1600),
  });

  @override
  State<BreathingIcon> createState() => _BreathingIconState();
}

class _BreathingIconState extends State<BreathingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.period)
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion(context)) return widget.child;
    return RepaintBoundary(
      child: ScaleTransition(
        scale: Tween(begin: 1.0, end: widget.maxScale).animate(
          CurvedAnimation(parent: _c, curve: Curves.easeInOut),
        ),
        child: widget.child,
      ),
    );
  }
}

/// اهتزاز تنبيهي متضائل يعمل مرة واحدة عند الظهور — لأيقونات الخطأ/التنبيه.
class WiggleIcon extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const WiggleIcon({super.key, required this.child, this.delay = Duration.zero});

  @override
  State<WiggleIcon> createState() => _WiggleIconState();
}

class _WiggleIconState extends State<WiggleIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion(context)) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t = _c.value;
        // موجة جيبية تتضاءل: ثلاث هزّات ثم سكون.
        final angle = math.sin(t * math.pi * 6) * (1 - t) * 0.10;
        return Transform.rotate(angle: angle, child: child);
      },
      child: widget.child,
    );
  }
}

/// شارة الأيقونة القياسية: سكويركل متدرّج بلون الهوية + توهّج ملوّن ناعم
/// وأيقونة بيضاء — بديل الشارات المسطّحة (لون شفاف + أيقونة ملوّنة).
/// `pulseGlow` يجعل التوهّج يتنفس (للعناصر التي تستحق لفت النظر فقط).
class GlowIconChip extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size; // ضلع المربع
  final double iconSize;
  final BorderRadiusGeometry? borderRadius;
  final bool pulseGlow;

  const GlowIconChip({
    super.key,
    required this.icon,
    required this.color,
    this.size = 44,
    this.iconSize = 22,
    this.borderRadius,
    this.pulseGlow = false,
  });

  @override
  State<GlowIconChip> createState() => _GlowIconChipState();
}

class _GlowIconChipState extends State<GlowIconChip>
    with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void initState() {
    super.initState();
    if (widget.pulseGlow) {
      _c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1800),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animate = widget.pulseGlow && !_reduceMotion(context) && _c != null;
    Widget chip(double glow) => Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(widget.color, Colors.white, 0.14)!,
                widget.color,
                Color.lerp(widget.color, Colors.black, 0.20)!,
              ],
            ),
            borderRadius: widget.borderRadius ?? AppRadius.borderLg,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: glow),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(widget.icon, size: widget.iconSize, color: Colors.white),
        );

    if (!animate) return chip(0.32);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c!,
        builder: (_, _) => chip(0.22 + 0.24 * _c!.value),
      ),
    );
  }
}

/// نبضة زنبركية لأيقونة التبويب لحظة اختياره (تكبر ثم تستقر بارتداد).
/// تُستخدم كـ `selectedIcon` في شريط التنقل — تعيد التشغيل كلما اختير التبويب.
class AnimatedNavIcon extends StatefulWidget {
  final IconData icon;

  const AnimatedNavIcon({super.key, required this.icon});

  @override
  State<AnimatedNavIcon> createState() => _AnimatedNavIconState();
}

class _AnimatedNavIconState extends State<AnimatedNavIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion(context)) return Icon(widget.icon);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t = Curves.easeOutBack.transform(_c.value);
        // تبدأ مضغوطة قليلاً وتستقر على ١ بارتداد + ميل خاطف يذوب سريعاً.
        final scale = 0.8 + 0.2 * t;
        final tilt = math.sin(_c.value * math.pi) * 0.09;
        return Transform.rotate(
          angle: tilt,
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: Icon(widget.icon),
    );
  }
}
