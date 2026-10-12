import 'package:finly/core/error/failure.dart';

/// What the person reads when a choice about the AI could not be saved.
String aiSaveFailureMessage(Failure failure) => failure is NetworkFailure
    ? 'Sem internet agora. Tente de novo quando estiver conectado.'
    : 'Não consegui salvar agora. Tente de novo em instantes.';

/// What the person reads when the AI could not fill in the sheet.
String aiFailureMessage(Failure failure) {
  if (failure is NetworkFailure) return 'Sem internet agora. Preencha à mão ou tente de novo.';
  return switch (failure.message) {
    'ai_disabled' => 'A IA está desligada. Ligue em Mais → Configurações → Inteligência artificial.',
    'ai_ask_disabled' => 'Para responder, a Amora precisa da sua permissão para ver os totais.',
    'ai_limit' => 'Você usou bastante a IA hoje. Amanhã ela volta; por enquanto, preencha à mão.',
    'ai_not_understood' || 'empty_text' =>
      'Não entendi. Tente de outro jeito, por exemplo: "gastei 50 no mercado ontem" ou "quanto gastei com Uber esse ano?".',
    'text_too_long' => 'Escreva em poucas palavras (até 300 letras).',
    _ => 'A IA não respondeu agora. Tente de novo em instantes ou preencha à mão.',
  };
}
