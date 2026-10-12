import 'package:flutter/material.dart';

/// How Amora looks: each moment of the app has its face.
enum AmoraMood {
  /// The default: tips, the button.
  happy,

  /// While the AI reads a sentence.
  thinking,

  /// A goal reached, a budget kept.
  celebrating,

  /// A budget over its limit, an invoice about to be due.
  worried,
}

/// The image of Amora's round head for [mood].
String amoraAsset(AmoraMood mood) => switch (mood) {
      AmoraMood.happy => 'assets/mascot/amora_happy.webp',
      AmoraMood.thinking => 'assets/mascot/amora_thinking.webp',
      AmoraMood.celebrating => 'assets/mascot/amora_celebrating.webp',
      AmoraMood.worried => 'assets/mascot/amora_worried.webp',
    };

/// Amora's round head, at [size] (works from 24).
class AmoraAvatar extends StatelessWidget {
  final AmoraMood mood;
  final double size;

  /// A white ring around her (on photos, colors or the blue band).
  final bool ring;

  const AmoraAvatar({super.key, this.mood = AmoraMood.happy, this.size = 48, this.ring = false});

  @override
  Widget build(BuildContext context) {
    final image = ClipOval(
      child: Image.asset(
        amoraAsset(mood),
        width: size,
        height: size,
        fit: BoxFit.cover,
        semanticLabel: 'Amora',
        errorBuilder: (context, error, stack) => SizedBox(
          width: size,
          height: size,
          child: const ColoredBox(color: Color(0xFFE2ECFC)),
        ),
      ),
    );
    if (!ring) return image;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: image,
    );
  }
}
