import 'package:finly/core/money/money.dart';
import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/core/utils/cents_input_formatter.dart';
import 'package:flutter/material.dart';

/// A form page in the new style: a light bar with an ✕ and the title, the
/// fields in a scrolling list, and the save button fixed at the bottom (it
/// stays above the keyboard, since the body shrinks when the keyboard opens).
class FormPage extends StatelessWidget {
  final String title;
  final Widget form;
  final String saveLabel;

  /// Null disables the button.
  final VoidCallback? onSave;

  /// Shows a spinner in the button.
  final bool saving;

  /// More actions in the bar (like a menu to delete).
  final List<Widget>? actions;

  const FormPage({
    super.key,
    required this.title,
    required this.form,
    required this.saveLabel,
    required this.onSave,
    this.saving = false,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Fechar',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(title),
        actions: actions,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: form,
                ),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(top: BorderSide(color: scheme.outlineVariant)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: FilledButton(
                    onPressed: saving ? null : onSave,
                    child: saving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(saveLabel),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small label above a field ("Nome", "Tipo").
class FieldLabel extends StatelessWidget {
  final String text;

  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The look of a text field in a form: a rounded white box.
InputDecoration formFieldDecoration(BuildContext context, {String? hint, String? helper, String? prefix}) {
  final scheme = Theme.of(context).colorScheme;
  OutlineInputBorder border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color),
      );
  return InputDecoration(
    hintText: hint,
    helperText: helper,
    helperMaxLines: 3,
    prefixText: prefix,
    filled: true,
    fillColor: scheme.surface,
    border: border(scheme.outline),
    enabledBorder: border(scheme.outline),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: scheme.primary, width: 2),
    ),
  );
}

/// One option of a [ChoicePills].
class PillOption<T> {
  final T value;
  final String label;
  final IconData? icon;

  const PillOption(this.value, this.label, {this.icon});
}

/// Options as pills to tap; the chosen one is blue. They wrap to more lines
/// when they do not fit.
class ChoicePills<T> extends StatelessWidget {
  final List<PillOption<T>> options;
  final T? selected;
  final ValueChanged<T>? onSelected;

  const ChoicePills({super.key, required this.options, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          Builder(builder: (context) {
            final on = option.value == selected;
            final tap = onSelected == null ? null : () => onSelected!(option.value);
            final foreground = on ? scheme.onPrimary : scheme.onSurface;
            return Semantics(
              button: true,
              selected: on,
              label: option.label,
              excludeSemantics: true,
              onTap: tap,
              child: Material(
                color: on ? scheme.primary : scheme.surface,
                shape: StadiumBorder(side: BorderSide(color: on ? scheme.primary : scheme.outline)),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: tap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (option.icon != null) ...[
                          Icon(option.icon, size: 18, color: on ? foreground : scheme.primary),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          option.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                            color: foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

/// The money field of a form, large, in its own card, typed like in bank
/// apps. [footer] goes under it (a hint, the sign pills).
class AmountCard extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String currency;
  final bool enabled;
  final String? Function(String?)? validator;
  final Widget? footer;
  final ValueChanged<String>? onChanged;

  /// The key of the field itself.
  final Key? fieldKey;

  const AmountCard({
    super.key,
    this.fieldKey,
    required this.label,
    required this.controller,
    required this.currency,
    this.enabled = true,
    this.validator,
    this.footer,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
            TextFormField(
              key: fieldKey,
              controller: controller,
              enabled: enabled,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: const [CentsInputFormatter()],
              onChanged: onChanged,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 36,
                letterSpacing: -1,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: '0,00',
                prefixText: '${Money.symbolFor(currency)} ',
                prefixStyle: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                  color: scheme.onSurfaceVariant,
                ),
                errorMaxLines: 2,
              ),
              validator: validator,
            ),
            if (footer != null) footer!,
          ],
        ),
      ),
    );
  }
}

/// A light blue box with a rule worth knowing ("Vale a partir de…").
class InfoBox extends StatelessWidget {
  final IconData icon;
  final String text;

  const InfoBox({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? AppColors.techBlueOnDark : const Color(0xFF0B4BB3);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? AppColors.blueTintDark : AppColors.blueTint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontSize: 14, height: 1.4, color: foreground))),
        ],
      ),
    );
  }
}

/// The currencies the app works with, as pills.
const currencyPills = [
  PillOption('BRL', 'Real (R\$)'),
  PillOption('USD', 'Dólar (US\$)'),
  PillOption('EUR', 'Euro (€)'),
];

/// Space between the parts of a form.
const formGap = SizedBox(height: 20);
