import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The Nori logo, the same files as nori-web (public/images/marca): dark letters on a light
/// theme, white letters on a dark one; the cloud keeps the brand blue.
class NoriLogo extends StatelessWidget {
  const NoriLogo({super.key, this.height = 32});

  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SvgPicture.asset(
      dark ? 'assets/brand/nori-logo-oscuro.svg' : 'assets/brand/nori-logo-claro.svg',
      height: height,
      semanticsLabel: 'Nori',
    );
  }
}
