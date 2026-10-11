import 'package:finly/core/widgets/form_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A day of the month from 1 to 31, or null.
int? dayOfMonth(String text) {
  final value = int.tryParse(text.trim());
  return (value != null && value >= 1 && value <= 31) ? value : null;
}

/// The closing day and the due day of a card, side by side.
class CardDaysFields extends StatelessWidget {
  final TextEditingController closing;
  final TextEditingController due;
  final bool enabled;

  const CardDaysFields({super.key, required this.closing, required this.due, required this.enabled});

  @override
  Widget build(BuildContext context) {
    Widget day(String label, TextEditingController controller, TextInputAction action) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FieldLabel(label),
              TextFormField(
                controller: controller,
                enabled: enabled,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                textInputAction: action,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                decoration: formFieldDecoration(context, hint: '10'),
                validator: (value) => dayOfMonth(value ?? '') == null ? 'De 1 a 31.' : null,
              ),
            ],
          ),
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        day('Fecha no dia', closing, TextInputAction.next),
        const SizedBox(width: 16),
        day('Vence no dia', due, TextInputAction.done),
      ],
    );
  }
}
