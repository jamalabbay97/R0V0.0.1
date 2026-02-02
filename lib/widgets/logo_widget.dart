import 'package:flutter/material.dart';

class OcpLogo extends StatelessWidget {
  final double size;
  const OcpLogo({super.key, this.size = 150});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
