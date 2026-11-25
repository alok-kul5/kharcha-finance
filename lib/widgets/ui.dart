import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/money.dart';
import '../theme/app_theme.dart';

/// Space under scrolling content so the floating tab bar never covers it.
double bottomClearance(BuildContext context) => MediaQuery.paddingOf(context).bottom + 104;

/// Icon and colour for each category.
abstract final class CategoryVisuals {
  static const _icons = <String, IconData>{
    'Food & Dining': Icons.ramen_dining_rounded,
    'Groceries': Icons.local_grocery_store_rounded,
    'Transport': Icons.directions_car_filled_rounded,
    'Shopping': Icons.shopping_bag_rounded,
    'Bills & Utilities': Icons.bolt_rounded,
    'Rent': Icons.home_rounded,
    'Entertainment': Icons.movie_rounded,
    'Health': Icons.favorite_rounded,
    'Education': Icons.school_rounded,
    'Travel': Icons.flight_takeoff_rounded,
    'Subscriptions': Icons.autorenew_rounded,
    'Transfers': Icons.swap_horiz_rounded,
    'Income': Icons.south_west_rounded,
    'Other': Icons.category_rounded,
  };
  static const _colors = <String, Color>{
    'Food & Dining': Color(0xffe8790a),
    'Groceries': Color(0xff28a745),
    'Transport': Color(0xff0a9fc6),
    'Shopping': Color(0xffe8335a),
    'Bills & Utilities': Color(0xfff2b200),
    'Rent': Color(0xff8e6e4e),
    'Entertainment': Color(0xffa548d6),
    'Health': Color(0xffff453a),
    'Education': Color(0xff5e5ce6),
    'Travel': Color(0xff14b8a6),
    'Subscriptions': Color(0xff2f6bff),
    'Transfers': Color(0xff8e8e93),
    'Income': Color(0xff248a3d),
    'Other': Color(0xff7c7c85),
  };
  static IconData icon(String c) => _icons[c] ?? Icons.category_rounded;
  static Color color(String c) => _colors[c] ?? const Color(0xff7c7c85);
}

/// Where a row sits in an iOS-style grouped list.
enum GroupPosition {
  single,
  first,
  middle,
  last;

  static GroupPosition of(int index, int count) => count == 1
      ? single
      : index == 0
          ? first
          : index == count - 1
              ? last
              : middle;

  BorderRadius get radius {
    const r = Radius.circular(Radii.card);
    return switch (this) {
      single => const BorderRadius.all(r),
      first => const BorderRadius.vertical(top: r),
      last => const BorderRadius.vertical(bottom: r),
      middle => BorderRadius.zero,
    };
  }

  bool get hasDivider => this == first || this == middle;
}

/// A rounded surface on the grey page: no border, no heavy shadow.
class Surface extends StatelessWidget {
  const Surface({
    super.key,
    required this.child,
    this.onTap,
    this.padding = EdgeInsets.zero,
    this.color,
    this.radius,
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? color;
  final BorderRadius? radius;

  @override
  Widget build(BuildContext context) {
    final surface = Material(
      color: color ?? context.k.surface,
      shape: RoundedRectangleBorder(borderRadius: radius ?? BorderRadius.circular(Radii.card)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
    final body = onTap == null ? surface : Pressable(child: surface);
    return Padding(padding: margin, child: body);
  }
}

/// Shrinks a little while pressed, like iOS buttons and cards. With [onTap]
/// it is the tap target; without, it only adds the press effect.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.scale = 0.97, this.haptic = false});

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final bool haptic;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  Offset? _downAt;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final scaled = AnimatedScale(
      scale: _down && !Motion.reduced(context) ? widget.scale : 1,
      duration: _down ? Motion.press : Motion.medium,
      curve: Motion.signature,
      child: widget.child,
    );
    if (widget.onTap == null) {
      return Listener(
        onPointerDown: (e) {
          _downAt = e.position;
          _set(true);
        },
        onPointerMove: (e) {
          final from = _downAt;
          if (from != null && (e.position - from).distance > kTouchSlop) _set(false);
        },
        onPointerUp: (_) => _set(false),
        onPointerCancel: (_) => _set(false),
        child: scaled,
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      onTap: () {
        if (widget.haptic) HapticFeedback.lightImpact();
        widget.onTap!();
      },
      child: scaled,
    );
  }
}

/// Fades and lifts into place once; rows stagger by [index].
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0});
  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Motion.reducedFade,
        child: child,
        builder: (_, t, c) => Opacity(opacity: t, child: c),
      );
    }
    final wait = Motion.staggerRow * index.clamp(0, Motion.staggerMax);
    final total = wait + Motion.sheet;
    final delay = wait.inMicroseconds / total.inMicroseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(delay, 1, curve: Motion.signature),
      child: child,
      builder: (_, t, c) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: c),
      ),
    );
  }
}

/// "₹12,680.42" with the paise in a fainter colour. One [Text], so screen
/// readers and finders see a single amount.
class MoneyText extends StatelessWidget {
  const MoneyText(this.paise, {super.key, required this.style, this.decimalsColor, this.prefix = '', this.decimals = true});

  final int paise;
  final TextStyle style;
  final Color? decimalsColor;
  final String prefix;
  final bool decimals;

  @override
  Widget build(BuildContext context) {
    final text = '$prefix${formatPaise(paise, decimals: decimals)}';
    final dot = text.lastIndexOf('.');
    final base = style.color ?? context.k.ink;
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: dot < 0 ? text : text.substring(0, dot)),
        if (dot >= 0) TextSpan(text: text.substring(dot), style: TextStyle(color: decimalsColor ?? base.withAlpha(102))),
      ]),
      style: style,
      maxLines: 1,
    );
  }
}

/// An amount that counts to its new value (or just shows it under reduced
/// motion).
class AnimatedAmount extends StatelessWidget {
  const AnimatedAmount(this.paise, {super.key, required this.style, this.decimalsColor});
  final int paise;
  final TextStyle style;
  final Color? decimalsColor;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: paise.toDouble()),
      duration: Motion.reduced(context) ? Duration.zero : Motion.count,
      curve: Motion.signature,
      builder: (_, v, _) => MoneyText(v.round(), style: style, decimalsColor: decimalsColor),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing, this.padding});
  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding ?? const EdgeInsets.fromLTRB(20, 26, 20, 10),
        child: Row(children: [
          Expanded(child: Text(title, style: KText.title(context))),
          ?trailing,
        ]),
      );
}

/// Icon in a tinted rounded square or circle.
class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, required this.color, this.size = 40, this.circle = false});
  final IconData icon;
  final Color color;
  final double size;
  final bool circle;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withAlpha(context.isDark ? 46 : 26),
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: circle ? null : BorderRadius.circular(size * 0.3),
        ),
        child: Icon(icon, size: size * 0.48, color: color),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          IconTile(icon, color: context.k.secondaryLabel, size: 64),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: KText.title(context)),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!, textAlign: TextAlign.center, style: KText.caption(context).copyWith(fontSize: 14)),
          ],
          if (action != null) ...[const SizedBox(height: 20), action!],
        ]),
      );
}

/// The primary action: a blue-to-violet pill with a soft glow.
class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.label, required this.onPressed, this.icon, this.busy = false, this.expand = false});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final child = AnimatedOpacity(
      duration: Motion.fast,
      opacity: enabled ? 1 : 0.55,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          gradient: Brand.gradient,
          borderRadius: BorderRadius.circular(25),
          boxShadow: enabled ? Brand.glow() : null,
        ),
        child: Row(mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
          if (busy)
            const Spinner(size: 18, color: Colors.white)
          else if (icon != null)
            Icon(icon, size: 19, color: Colors.white),
          if (busy || icon != null) const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15.5, letterSpacing: -0.2)),
        ]),
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Pressable(onTap: enabled ? onPressed : null, haptic: true, child: child),
    );
  }
}

/// A quiet secondary button: tinted fill, brand text.
class SoftButton extends StatelessWidget {
  const SoftButton({super.key, required this.label, required this.onPressed, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Pressable(
          onTap: onPressed,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: context.k.brandSoft, borderRadius: BorderRadius.circular(22)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[Icon(icon, size: 18, color: Theme.of(context).colorScheme.onPrimaryContainer), const SizedBox(width: 6)],
              Text(label,
                  style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onPrimaryContainer)),
            ]),
          ),
        ),
      );
}

/// A spinning arc that never shrinks to a dot.
class Spinner extends StatefulWidget {
  const Spinner({super.key, this.size = 20, this.color, this.strokeWidth = 2.5});
  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  State<Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<Spinner> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Loading',
        child: SizedBox.square(
          dimension: widget.size,
          child: CustomPaint(painter: _SpinnerPainter(_c, widget.color ?? Brand.mid, widget.strokeWidth)),
        ),
      );
}

class _SpinnerPainter extends CustomPainter {
  _SpinnerPainter(this.t, this.color, this.strokeWidth) : super(repaint: t);
  final Animation<double> t;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, p..color = color.withAlpha(40));
    canvas.drawArc(rect, t.value * 2 * math.pi, 1.9, false, p..color = color);
  }

  @override
  bool shouldRepaint(_SpinnerPainter old) => old.color != color;
}

/// A rounded progress track; colour follows the budget level.
class ProgressTrack extends StatelessWidget {
  const ProgressTrack({super.key, required this.value, required this.color, this.height = 8, this.background});
  final double value;
  final Color color;
  final double height;
  final Color? background;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: SizedBox(
          height: height,
          child: Stack(children: [
            Positioned.fill(child: ColoredBox(color: background ?? context.k.fill)),
            TweenAnimationBuilder<double>(
              tween: Tween(end: value.clamp(0, 1)),
              duration: Motion.of(context, Motion.count),
              curve: Motion.signature,
              builder: (_, v, _) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: v,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [color.withAlpha(200), color]),
                    borderRadius: BorderRadius.circular(height),
                  ),
                ),
              ),
            ),
          ]),
        ),
      );
}

/// The deep-blue hero backdrop: a navy-to-blue gradient, two soft glows
/// and a faint silk ribbon. It drifts once each time it comes into view,
/// then settles, so a screen left open costs nothing.
class HeroBackground extends StatefulWidget {
  const HeroBackground({super.key, this.child, this.animate = true});
  final Widget? child;
  final bool animate;

  @override
  State<HeroBackground> createState() => _HeroBackgroundState();
}

class _HeroBackgroundState extends State<HeroBackground> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  AnimationController? _c;
  Animation<double>? _eased;
  bool _visible = false;
  Timer? _replay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wanted = widget.animate && !Motion.reduced(context);
    if (wanted && _c == null) {
      _c = AnimationController(vsync: this, duration: Motion.ambient);
      _eased = CurvedAnimation(parent: _c!, curve: Motion.loop);
    } else if (!wanted && _c != null) {
      _c!.dispose();
      _c = null;
      _eased = null;
    }
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible && !_visible) {
      _replay?.cancel();
      _replay = Timer(Motion.sheet, () {
        if (mounted && _visible && _c != null && !_c!.isAnimating) _c!.forward(from: 0);
      });
    }
    _visible = visible;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _visible && _c != null && !_c!.isAnimating) _c!.forward(from: 0);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _replay?.cancel();
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _HeroPainter(_eased),
        child: widget.child == null ? null : RepaintBoundary(child: widget.child),
      );
}

class _HeroPainter extends CustomPainter {
  _HeroPainter(this.drift) : super(repaint: drift);
  final Animation<double>? drift;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Brand.heroTop, Brand.heroMid, Brand.heroBottom],
          stops: [0, 0.55, 1],
        ).createShader(rect),
    );
    final t = (drift?.value ?? 0) * 2 * math.pi;
    final w = size.width, h = size.height;
    void glow(Offset c, double r, Color color) => canvas.drawCircle(
        c, r, Paint()..shader = RadialGradient(colors: [color, color.withAlpha(0)]).createShader(Rect.fromCircle(center: c, radius: r)));
    glow(Offset(w * (0.85 + 0.08 * math.sin(t)), h * (0.95 + 0.04 * math.cos(t))), w * 0.95, const Color(0x704f9bff));
    glow(Offset(w * (0.05 + 0.1 * math.cos(t)), h * (0.15 + 0.05 * math.sin(t))), w * 0.7, const Color(0x382a6cff));
    glow(Offset(w * (0.6 + 0.06 * math.sin(t + 1)), h * (0.35 + 0.05 * math.cos(t))), w * 0.45, const Color(0x267b3ff2));

    final s = 0.05 * math.sin(t);
    canvas.drawPath(
      Path()
        ..moveTo(-w * 0.1, h * (0.52 + s))
        ..cubicTo(w * 0.3, h * (0.3 + s), w * 0.62, h * (0.86 - s), w * 1.1, h * (0.46 - s))
        ..lineTo(w * 1.1, h * (0.6 - s))
        ..cubicTo(w * 0.62, h * (0.98 - s), w * 0.3, h * (0.46 + s), -w * 0.1, h * (0.7 + s))
        ..close(),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withAlpha(0), Colors.white.withAlpha(18), Colors.white.withAlpha(0)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_HeroPainter old) => old.drift != drift;
}

/// A round frosted button for the hero (translucent fill and hairline, no blur).
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({super.key, required this.icon, required this.onTap, required this.tooltip, this.size = 42});
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final double size;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          label: tooltip,
          child: Pressable(
            onTap: onTap,
            scale: 0.9,
            haptic: true,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(30),
                border: Border.all(color: Colors.white.withAlpha(40)),
              ),
              child: Icon(icon, size: size * 0.46, color: Colors.white),
            ),
          ),
        ),
      );
}

class GlassChip extends StatelessWidget {
  const GlassChip({super.key, required this.label, this.icon, this.onTap});
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(26),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withAlpha(30)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: Colors.white.withAlpha(225)), const SizedBox(width: 5)],
        Text(label,
            style: TextStyle(fontSize: 12.5, height: 1.2, color: Colors.white.withAlpha(225), fontWeight: FontWeight.w500)),
      ]),
    );
    return onTap == null ? chip : Pressable(onTap: onTap, scale: 0.94, child: chip);
  }
}

/// Keeps every tab alive but moves between them with a fade-through.
class FadeThroughStack extends StatefulWidget {
  const FadeThroughStack({super.key, required this.index, required this.children});
  final int index;
  final List<Widget> children;

  @override
  State<FadeThroughStack> createState() => _FadeThroughStackState();
}

class _FadeThroughStackState extends State<FadeThroughStack> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: Motion.medium, value: 1);
  late int _previous = widget.index;
  bool _still = false;

  late final Animation<double> _fadeOut =
      ReverseAnimation(CurvedAnimation(parent: _c, curve: const Interval(0, 0.35, curve: Motion.exit)));
  late final Animation<double> _fadeIn = CurvedAnimation(parent: _c, curve: const Interval(0.3, 1, curve: Motion.signature));
  late final Animation<double> _scaleIn = Tween<double>(begin: 0.985, end: 1)
      .animate(CurvedAnimation(parent: _c, curve: const Interval(0.3, 1, curve: Motion.signature)));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = Motion.reduced(context);
    _c.duration = _still ? Motion.reducedFade : Motion.medium;
  }

  @override
  void didUpdateWidget(FadeThroughStack old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _previous = old.index;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Stack(fit: StackFit.expand, children: [
          for (var i = 0; i < widget.children.length; i++) _layer(i, _c.isAnimating),
        ]),
      );

  Widget _layer(int i, bool animating) {
    final current = i == widget.index;
    final leaving = animating && i == _previous && !current;
    final visible = current || leaving;
    return Offstage(
      key: ValueKey(i),
      offstage: !visible,
      child: TickerMode(
        enabled: visible,
        child: IgnorePointer(
          ignoring: !current,
          child: FadeTransition(
            opacity: current ? _fadeIn : (leaving ? _fadeOut : kAlwaysCompleteAnimation),
            child: ScaleTransition(
              scale: current && !_still ? _scaleIn : kAlwaysCompleteAnimation,
              child: RepaintBoundary(child: widget.children[i]),
            ),
          ),
        ),
      ),
    );
  }
}

class GlassTabItem {
  const GlassTabItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// The floating tab bar: a flat navy capsule (the home field's colour) with
/// an amber pill that slides to the selected tab, and an amber add button.
class GlassTabBar extends StatelessWidget {
  const GlassTabBar({super.key, required this.items, required this.selectedIndex, required this.onSelected, this.onAdd});

  final List<GlassTabItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback? onAdd;

  static const _slot = 66.0;
  static const _pad = 6.0;
  static const _slide = Cubic(0.3, 1.2, 0.4, 1);

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final reduce = Motion.reduced(context);
    const capsule = BoxDecoration(color: Brand.navBar);
    final shadow = [BoxShadow(color: Brand.navBar.withAlpha(context.isDark ? 160 : 90), blurRadius: 24, offset: const Offset(0, 10))];
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 12),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        RepaintBoundary(
          child: Container(
            height: 64,
            width: _slot * items.length + _pad * 2 + 2,
            padding: const EdgeInsets.all(_pad),
            decoration: capsule.copyWith(
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withAlpha(22)),
              boxShadow: shadow,
            ),
            child: LayoutBuilder(builder: (context, box) {
              final slot = box.maxWidth / items.length;
              return Stack(children: [
                AnimatedPositioned(
                  duration: reduce ? Duration.zero : Motion.page,
                  curve: _slide,
                  left: slot * selectedIndex,
                  top: 0,
                  bottom: 0,
                  width: slot,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Brand.navAccent, borderRadius: BorderRadius.circular(26), boxShadow: Brand.navGlow()),
                  ),
                ),
                Row(children: [
                  for (var i = 0; i < items.length; i++)
                    _GlassTab(
                      item: items[i],
                      width: slot,
                      selected: i == selectedIndex,
                      onTap: () {
                        if (i != selectedIndex) HapticFeedback.selectionClick();
                        onSelected(i);
                      },
                    ),
                ]),
              ]);
            }),
          ),
        ),
        if (onAdd != null) ...[
          const SizedBox(width: 10),
          Tooltip(
            message: 'Add',
            child: Semantics(
              button: true,
              label: 'Add transaction',
              child: Pressable(
                onTap: onAdd,
                scale: 0.9,
                haptic: true,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Brand.navAccent,
                    border: Border.all(color: Colors.white.withAlpha(60)),
                    boxShadow: [...Brand.navGlow(), ...shadow],
                  ),
                  child: const Icon(Icons.add_rounded, color: Brand.navBar, size: 30),
                ),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

class _GlassTab extends StatelessWidget {
  const _GlassTab({required this.item, required this.width, required this.selected, required this.onTap});
  final GlassTabItem item;
  final double width;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: item.label,
        child: Semantics(
          selected: selected,
          button: true,
          label: item.label,
          excludeSemantics: true,
          child: Pressable(
            onTap: onTap,
            scale: 0.9,
            child: SizedBox(
              width: width,
              height: double.infinity,
              child: TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: selected ? Brand.navBar : Colors.white.withAlpha(150)),
                duration: Motion.medium,
                curve: Motion.signature,
                builder: (context, color, _) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(item.icon, size: 21, color: color),
                  const SizedBox(height: 3),
                  Text(item.label,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: TextStyle(
                          fontSize: 11, height: 1.1, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: color)),
                ]),
              ),
            ),
          ),
        ),
      );
}
