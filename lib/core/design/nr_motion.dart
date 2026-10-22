import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'nr_tokens.dart';

/// Duraciones y curvas: cortas, con salida suave. Nada rebota más de lo necesario.
abstract final class NrMotion {
  static const fast = Duration(milliseconds: 160);
  static const base = Duration(milliseconds: 260);
  static const slow = Duration(milliseconds: 420);
  static const count = Duration(milliseconds: 700);
  static const ease = Curves.easeOutCubic;
  static const emphasized = Cubic(0.2, 0.8, 0.2, 1);
}

/// `true` si el usuario pidió reducir movimiento (Accesibilidad) o en pruebas.
bool nrReduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Vibraciones con intención: tocar una tecla, confirmar un cobro, algo que no se puede.
abstract final class NrHaptics {
  static bool enabled = true;

  static Future<void> tap() async {
    if (enabled) await HapticFeedback.selectionClick();
  }

  static Future<void> action() async {
    if (enabled) await HapticFeedback.lightImpact();
  }

  static Future<void> success() async {
    if (!enabled) return;
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (enabled) await HapticFeedback.lightImpact();
  }

  static Future<void> warning() async {
    if (enabled) await HapticFeedback.heavyImpact();
  }
}

/// Se hunde un poco al presionar (0.97, 120 ms), como los botones de iOS. No
/// compite con el gesto del hijo: si el dedo se mueve (scroll) se suelta.
class NrPressable extends StatefulWidget {
  const NrPressable({super.key, required this.child, this.enabled = true, this.scale = 0.97});

  final Widget child;
  final bool enabled;
  final double scale;

  @override
  State<NrPressable> createState() => _NrPressableState();
}

class _NrPressableState extends State<NrPressable> {
  bool _down = false;
  Offset? _origin;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || nrReduceMotion(context)) return widget.child;
    return Listener(
      onPointerDown: (e) {
        _origin = e.position;
        _set(true);
      },
      onPointerMove: (e) {
        if (_origin != null && (e.position - _origin!).distance > kTouchSlop) _set(false);
      },
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(scale: _down ? widget.scale : 1, duration: const Duration(milliseconds: 120), curve: NrMotion.ease, child: widget.child),
    );
  }
}

/// Número que viaja de su valor anterior al nuevo (la primera vez, desde 0).
class NrCountUp extends StatefulWidget {
  const NrCountUp({super.key, required this.value, required this.builder, this.duration = NrMotion.count, this.fromZero = true});

  final double value;
  final Widget Function(BuildContext context, double value) builder;
  final Duration duration;
  final bool fromZero;

  @override
  State<NrCountUp> createState() => _NrCountUpState();
}

class _NrCountUpState extends State<NrCountUp> {
  late double _from = widget.fromZero ? 0 : widget.value;

  @override
  void didUpdateWidget(covariant NrCountUp old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _from = old.value;
  }

  @override
  Widget build(BuildContext context) {
    if (nrReduceMotion(context)) return widget.builder(context, widget.value);
    return TweenAnimationBuilder<double>(
      key: ValueKey(widget.value),
      tween: Tween(begin: _from, end: widget.value),
      duration: widget.duration,
      curve: NrMotion.ease,
      builder: (context, v, _) => widget.builder(context, v),
    );
  }
}

/// Entrada escalonada: aparece [index] × 45 ms después (máximo ~400 ms), sube
/// 14 px y se desvanece. Solo la primera vez que se construye.
class NrEntrance extends StatefulWidget {
  const NrEntrance({super.key, required this.child, this.index = 0, this.offset = 14});

  final Widget child;
  final int index;
  final double offset;

  @override
  State<NrEntrance> createState() => _NrEntranceState();
}

class _NrEntranceState extends State<NrEntrance> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: NrMotion.emphasized);

  @override
  void initState() {
    super.initState();
    final delay = Duration(milliseconds: (widget.index.clamp(0, 9)) * 45);
    Future<void>.delayed(delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (nrReduceMotion(context)) _c.value = 1;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(offset: Offset(0, (1 - _t.value) * widget.offset), child: child),
      ),
    );
  }
}

/// Brillo lento que cruza los esqueletos de carga.
class NrShimmer extends StatefulWidget {
  const NrShimmer({super.key, required this.child});

  final Widget child;

  @override
  State<NrShimmer> createState() => _NrShimmerState();
}

class _NrShimmerState extends State<NrShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (nrReduceMotion(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (nrReduceMotion(context)) return widget.child;
    final hi = Colors.white.withValues(alpha: context.nr.night ? 0.07 : 0.6);
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = _c.value * 2.6 - 0.8;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            colors: [hi.withValues(alpha: 0), hi, hi.withValues(alpha: 0)],
            stops: [(t - 0.3).clamp(0.0, 1.0), t.clamp(0.0, 1.0), (t + 0.3).clamp(0.0, 1.0)],
          ).createShader(rect),
          child: child,
        );
      },
    );
  }
}

/// Punto que late (en vivo, sincronizando).
class NrPulseDot extends StatefulWidget {
  const NrPulseDot({super.key, required this.color, this.size = 8, this.pulse = true});

  final Color color;
  final double size;
  final bool pulse;

  @override
  State<NrPulseDot> createState() => _NrPulseDotState();
}

class _NrPulseDotState extends State<NrPulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant NrPulseDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.pulse && !nrReduceMotion(context)) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s * 2.2,
      height: s * 2.2,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Stack(alignment: Alignment.center, children: [
          if (widget.pulse)
            Container(
              width: s + s * 1.2 * _c.value,
              height: s + s * 1.2 * _c.value,
              decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withValues(alpha: 0.35 * (1 - _c.value))),
            ),
          Container(width: s, height: s, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color)),
        ]),
      ),
    );
  }
}

/// Cambia de hijo con un fundido y un leve desplazamiento vertical.
class NrSwitcher extends StatelessWidget {
  const NrSwitcher({super.key, required this.child, this.duration = NrMotion.base});

  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: nrReduceMotion(context) ? Duration.zero : duration,
        switchInCurve: NrMotion.ease,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: SlideTransition(position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(a), child: child),
        ),
        child: child,
      );
}
