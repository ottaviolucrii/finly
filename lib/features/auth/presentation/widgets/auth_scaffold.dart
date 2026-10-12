import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/features/dashboard/presentation/widgets/home/home_band.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The screens before the app (sign in, sign up, passwords): the deep blue
/// band of the brand with the logo, and the form in a white card under it.
class AuthScaffold extends StatelessWidget {
  /// The title of the card ("Entrar", "Criar conta").
  final String title;

  /// One line under the title.
  final String? subtitle;
  final Widget child;

  const AuthScaffold({super.key, required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final top = MediaQuery.paddingOf(context).top;
    final canPop = ModalRoute.of(context)?.canPop ?? false;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.deepBlue,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
                ),
                padding: EdgeInsets.fromLTRB(8, top + 8, 8, 56),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: canPop
                          ? IconButton(
                              tooltip: 'Voltar',
                              icon: const Icon(Icons.arrow_back, color: AppColors.white),
                              onPressed: () => Navigator.of(context).maybePop(),
                            )
                          : const SizedBox(height: 48),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(
                        finlyMarkAsset,
                        width: 72,
                        height: 72,
                        semanticLabel: 'Finly',
                        errorBuilder: (context, error, stackTrace) => const SizedBox(width: 72, height: 72),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'FINLY',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 28,
                        letterSpacing: 2,
                        color: AppColors.white,
                      ),
                    ),
                    const Text(
                      'INTELIGÊNCIA FINANCEIRA',
                      style: TextStyle(fontSize: 12, letterSpacing: 1.5, color: AppColors.onBand),
                    ),
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Card(
                        margin: EdgeInsets.zero,
                        elevation: 6,
                        shadowColor: AppColors.midnight.withValues(alpha: 0.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Semantics(
                                container: true,
                                header: true,
                                child: Text(title, style: text.titleLarge),
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: 4),
                                Text(subtitle!, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                              ],
                              const SizedBox(height: 20),
                              child,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
