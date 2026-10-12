import 'package:finly/core/error/failure.dart';

/// What the person reads when the AI could not fill in the sheet.
String aiFailureMessage(Failure failure) {
  if (failure is NetworkFailure) return 'Sem internet agora. Preencha à mão ou tente de novo.';
  return switch (failure.message) {
    'ai_disabled' => 'A IA está desligada. Ligue em Mais → Configurações → Inteligência artificial.',
    'ai_limit' => 'Você usou bastante a IA hoje. Amanhã ela volta; por enquanto, preencha à mão.',
    'ai_not_understood' || 'empty_text' =>
      'Não entendi. Tente com o valor e o que foi, por exemplo: "gastei 50 no mercado ontem".',
    'text_too_long' => 'Escreva em poucas palavras (até 300 letras).',
    _ => 'A IA não respondeu agora. Tente de novo em instantes ou preencha à mão.',
  };
}
