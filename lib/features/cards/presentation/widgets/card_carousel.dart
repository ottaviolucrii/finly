import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/features/cards/domain/entities/credit_card_entity.dart';
import 'package:finly/features/cards/presentation/widgets/card_art.dart';
import 'package:flutter/material.dart';

/// The cards side by side: swipe to change card; the next one peeks in from
/// the side. The last place is "Adicionar cartão". Dots under them show where
/// the person is.
class CardCarousel extends StatelessWidget {
  final List<CreditCardEntity> cards;
  final PageController controller;

  /// The place in front (cards.length is "Adicionar cartão").
  final int index;
  final ValueChanged<int> onChanged;
  final VoidCallback onAdd;

  const CardCarousel({
    super.key,
    required this.cards,
    required this.controller,
    required this.index,
    required this.onChanged,
    required this.onAdd,
  });

  /// How much of the screen width one card takes (the rest shows the next).
  static const viewportFraction = 0.86;

  @override
  Widget build(BuildContext context) {
    final count = cards.length + 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth * viewportFraction - 12;
        final height = cardWidth / CardArt.aspectRatio + 24;

        return Column(
          children: [
            SizedBox(
              height: height,
              child: PageView.builder(
                controller: controller,
                itemCount: count,
                onPageChanged: onChanged,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.fromLTRB(6, 4, 6, 20),
                  child: Semantics(
                    label: i < cards.length ? 'Cartão ${i + 1} de ${cards.length}' : null,
                    child: i < cards.length
                        ? CardArt(
                            card: cards[i],
                            // A tap on a card at the side brings it to the front.
                            onTap: i == index
                                ? null
                                : () => controller.animateToPage(
                                      i,
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeOutCubic,
                                    ),
                          )
                        : AddCardTile(onTap: onAdd),
                  ),
                ),
              ),
            ),
            if (count > 1) PageDots(count: count, index: index),
          ],
        );
      },
    );
  }
}

/// Small dots: the one in front is a longer pill.
class PageDots extends StatelessWidget {
  final int count;
  final int index;

  const PageDots({super.key, required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              key: ValueKey('dot-$i'),
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == index ? 20 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == index ? scheme.primary : scheme.outline,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}

/// The place after the last card: a dashed outline with "Adicionar cartão".
class AddCardTile extends StatelessWidget {
  final VoidCallback onTap;

  const AddCardTile({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: 'Adicionar cartão',
      excludeSemantics: true,
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: CardArt.aspectRatio,
        child: CustomPaint(
          painter: _DashedBorder(color: scheme.outline, radius: 22),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline, size: 36, color: scheme.primary),
                  const SizedBox(height: 8),
                  Text(
                    'Adicionar cartão',
                    style: TextStyle(fontWeight: FontWeight.w600, color: scheme.primary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  final Color color;
  final double radius;

  const _DashedBorder({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 8), paint);
        distance += 14;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

/// Shown under the carousel when "Adicionar cartão" is in front: what a card
/// is good for here, and the button to add one.
class AddCardHint extends StatelessWidget {
  /// True when there is no card yet (the first one).
  final bool first;
  final VoidCallback onAdd;

  const AddCardHint({super.key, required this.first, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: dark ? AppColors.blueTintDark : AppColors.blueTint,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.credit_card, color: scheme.primary, size: 28),
            ),
            const SizedBox(height: 14),
            Semantics(
              container: true,
              header: true,
              child: Text(
                first ? 'Adicione o seu primeiro cartão' : 'Mais um cartão?',
                textAlign: TextAlign.center,
                style: text.titleLarge?.copyWith(fontSize: 18),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Acompanhe o limite e as faturas, veja quando cada uma fecha e '
              'pague em poucos toques.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Cadastrar cartão'),
            ),
          ],
        ),
      ),
    );
  }
}
