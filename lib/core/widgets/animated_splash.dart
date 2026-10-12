import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/core/widgets/finly_logo.dart';
import 'package:flutter/material.dart';

/// True while the opening animation is on screen. The lock screen waits for
/// it to end before asking for the fingerprint, so the two never collide.
final splashShowing = ValueNotifier<bool>(false);

/// How long the opening animation takes.
const splashDuration = Duration(milliseconds: 2300);

/// The part of [t] (0 to 1) between [from] and [to], eased, as 0 to 1.
double splashStep(double t, double from, double to) {
  if (t <= from) return 0;
  if (t >= to) return 1;
  return Curves.easeInOut.transform((t - from) / (to - from));
}

/// The opening of the app: the shield drawn line by line (the arrows, then
/// the gold part, like a check), filled with color, a small pulse, and the
/// name rising with a shine. It plays once; [onFinished] is called at the end.
/// With "remove animations" on, it shows the finished logo at once.
class AnimatedSplash extends StatefulWidget {
  final VoidCallback? onFinished;

  /// The time it takes; tests pass a short one.
  final Duration duration;

  const AnimatedSplash({super.key, this.onFinished, this.duration = splashDuration});

  @override
  State<AnimatedSplash> createState() => _AnimatedSplashState();
}

class _AnimatedSplashState extends State<AnimatedSplash> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.duration)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed && !_jumped) widget.onFinished?.call();
    });

  bool _started = false;

  /// Set when it jumps to the end ("remove animations"): then the end is
  /// told once, after the frame, not by the jump itself (it happens while
  /// building, too early to change the screens above).
  bool _jumped = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      _jumped = true;
      _controller.value = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onFinished?.call());
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A Material gives the texts their style (without it Flutter draws them
    // with yellow lines and a fallback font).
    return Material(
      color: AppColors.white,
      child: Center(
        // Its own layer: what changes under it does not repaint it, and the
        // other way round.
        child: RepaintBoundary(
          child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            final fill = splashStep(t, 0.48, 0.66);
            final pulse = t < 0.66 || t > 0.82
                ? 1.0
                : 1 + 0.06 * Curves.easeOut.transform(1 - ((t - 0.74).abs() / 0.08).clamp(0.0, 1.0));
            final name = splashStep(t, 0.66, 0.82);
            final shine = splashStep(t, 0.76, 1.0);
            final slogan = splashStep(t, 0.78, 0.94);

            return Semantics(
              label: 'Finly, inteligência financeira',
              excludeSemantics: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: pulse,
                    child: CustomPaint(
                      size: const Size(176, 190),
                      painter: FinlyLogoPainter(
                        upper: splashStep(t, 0.02, 0.36),
                        lower: splashStep(t, 0.10, 0.42),
                        goldLine: splashStep(t, 0.24, 0.52),
                        fill: fill,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Opacity(
                    opacity: name,
                    child: Transform.translate(
                      offset: Offset(0, 8 * (1 - name)),
                      child: ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (bounds) {
                          final x = -0.4 + 1.8 * (1 - shine);
                          return LinearGradient(
                            colors: const [AppColors.midnight, AppColors.techBlueOnDark, AppColors.midnight],
                            stops: [(x - 0.12).clamp(0.0, 1.0), x.clamp(0.0, 1.0), (x + 0.12).clamp(0.0, 1.0)],
                          ).createShader(bounds);
                        },
                        child: const Text(
                          'FINLY',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w700,
                            fontSize: 34,
                            letterSpacing: 3,
                            color: AppColors.midnight,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Opacity(
                    opacity: slogan,
                    child: const Text(
                      'INTELIGÊNCIA FINANCEIRA',
                      style: TextStyle(fontSize: 12, letterSpacing: 2, color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
            );
          },
          ),
        ),
      ),
    );
  }
}

/// Plays the splash once over [child] when the app opens, then fades it out.
/// It sits above everything, the lock screen included.
/// The app under it keeps starting (restoring the session) meanwhile, so the
/// splash never makes the app slower to open than it already is.
class StartupSplash extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const StartupSplash({super.key, required this.child, this.duration = splashDuration});

  @override
  State<StartupSplash> createState() => _StartupSplashState();
}

class _StartupSplashState extends State<StartupSplash> {
  bool _finished = false;
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    splashShowing.value = true;
  }

  @override
  void dispose() {
    splashShowing.value = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The app starts under it (the session, the data), but its own
        // animations (spinners) wait: fewer things moving at once keeps the
        // splash smooth.
        Positioned.fill(child: TickerMode(enabled: _finished, child: widget.child)),
        if (!_gone)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: _finished,
              child: AnimatedOpacity(
                opacity: _finished ? 0 : 1,
                duration: const Duration(milliseconds: 280),
                onEnd: () {
                  // Fully gone only now (after the fade): the lock may ask
                  // for the fingerprint.
                  splashShowing.value = false;
                  setState(() => _gone = true);
                },
                child: AnimatedSplash(
                  duration: widget.duration,
                  onFinished: () {
                    if (mounted) setState(() => _finished = true);
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}
