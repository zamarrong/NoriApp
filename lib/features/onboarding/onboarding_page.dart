import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/providers.dart';
import '../../core/widgets/nori_logo.dart';
import '../auth/auth_pages.dart';
import 'onboarding_art.dart';

/// Whether this device already went through the onboarding (finished or skipped).
/// A device that already signed in before the onboarding existed counts as seen.
class OnboardingSeenNotifier extends Notifier<bool> {
  static const key = 'nori.onboarding_seen';

  @override
  bool build() {
    final prefs = ref.read(prefsProvider);
    return prefs.getBool(key) ?? (prefs.getString(AuthController.lastUserKey) ?? '').isNotEmpty;
  }

  Future<void> markSeen() async {
    state = true;
    await ref.read(prefsProvider).setBool(key, true);
  }
}

final onboardingSeenProvider = NotifierProvider<OnboardingSeenNotifier, bool>(OnboardingSeenNotifier.new);

class _Slide {
  const _Slide(this.scene, this.title, this.text);

  final OnboardingScene scene;
  final String title;
  final String text;
}

/// First launch only: the app's top features in four pages, skippable. When it ends
/// (or is skipped) the flag is saved and the router takes the user to sign in.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  static const slides = [
    _Slide(OnboardingScene.sell, 'Vende en ruta\no en mostrador', 'Captura tus ventas aunque no tengas señal. Se envían solas cuando vuelve la conexión.'),
    _Slide(OnboardingScene.collect, 'Cobra e imprime\nel ticket', 'Registra el pago y saca el ticket en tu impresora Bluetooth.'),
    _Slide(OnboardingScene.invoice, 'Factura CFDI\ndesde la venta', 'Haz la factura ahí mismo e imprímela o mándasela a tu cliente.'),
    _Slide(OnboardingScene.day, 'Tu día y\ntus clientes', 'Revisa tu ruta y lo que llevas vendido, y checa el precio de cualquier producto.'),
  ];

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _pages = PageController();
  int _index = 0;

  bool get _last => _index == OnboardingPage.slides.length - 1;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _finish() => ref.read(onboardingSeenProvider.notifier).markSeen();

  void _next() {
    if (_last) return _finish();
    final to = _index + 1;
    if (nrReduceMotion(context)) {
      _pages.jumpToPage(to);
    } else {
      _pages.animateToPage(to, duration: NrMotion.slow, curve: NrMotion.emphasized);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    final reduce = nrReduceMotion(context);
    return Scaffold(
      backgroundColor: authBackground(nr),
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(NrSpace.xxl, NrSpace.md, NrSpace.md, 0),
            child: SizedBox(
              height: NrTouch.min,
              child: Row(children: [
                const NoriMark(size: 34),
                const Spacer(),
                AnimatedOpacity(
                  opacity: _last ? 0 : 1,
                  duration: reduce ? Duration.zero : NrMotion.fast,
                  child: IgnorePointer(
                    ignoring: _last,
                    child: TextButton(
                      onPressed: _finish,
                      style: TextButton.styleFrom(foregroundColor: nr.secondary),
                      child: const Text('Saltar'),
                    ),
                  ),
                ),
              ]),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: OnboardingPage.slides.length,
              onPageChanged: (i) {
                NrHaptics.tap();
                setState(() => _index = i);
              },
              itemBuilder: (context, i) => _SlideView(
                slide: OnboardingPage.slides[i],
                index: i,
                controller: _pages,
                playing: i == _index,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(NrSpace.xxl, NrSpace.xxxl, NrSpace.xxl, NrSpace.lg),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Semantics(
                label: 'Página ${_index + 1} de ${OnboardingPage.slides.length}',
                child: Row(children: [
                  for (var i = 0; i < OnboardingPage.slides.length; i++)
                    AnimatedContainer(
                      duration: reduce ? Duration.zero : NrMotion.base,
                      curve: NrMotion.emphasized,
                      margin: const EdgeInsets.only(right: 6),
                      width: i == _index ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _index ? nr.accent : nr.borderStrong,
                        borderRadius: BorderRadius.circular(NrRadius.pill),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: NrSpace.xxl),
              NrButton(
                label: _last ? 'Empezar' : 'Siguiente',
                trailing: Icon(Icons.arrow_forward_rounded, size: 20, color: nr.onAccent),
                onPressed: _next,
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// One page: the art moves a little slower than the text while swiping (parallax).
class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide, required this.index, required this.controller, required this.playing});

  final _Slide slide;
  final int index;
  final PageController controller;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    final reduce = nrReduceMotion(context);
    return LayoutBuilder(builder: (context, box) {
      return AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final page = controller.hasClients && controller.position.haveDimensions ? controller.page ?? index.toDouble() : index.toDouble();
          final delta = (index - page).clamp(-1.0, 1.0);
          final shift = reduce ? 0.0 : delta * box.maxWidth * 0.35;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Center(
                child: Transform.translate(
                  offset: Offset(shift, 0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: NrSpace.sm),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: ExcludeSemantics(child: OnboardingArt(slide.scene, playing: playing)),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(NrSpace.xxl, NrSpace.lg, NrSpace.xxl, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Semantics(header: true, child: Text(slide.title, style: NrText.display(context).copyWith(fontSize: 32, height: 1.08))),
                const SizedBox(height: NrSpace.md),
                Text(slide.text, style: NrText.body(context).copyWith(fontSize: 16, height: 1.45, color: nr.secondary)),
              ]),
            ),
          ]);
        },
      );
    });
  }
}
