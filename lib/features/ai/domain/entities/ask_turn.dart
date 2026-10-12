import 'package:equatable/equatable.dart';

/// One question to Amora and her answer, kept while her sheet is open so a
/// follow-up ("e no mês passado?") makes sense.
class AskTurn extends Equatable {
  final String question;
  final String answer;

  const AskTurn({required this.question, required this.answer});

  Map<String, String> toJson() => {'question': question, 'answer': answer};

  @override
  List<Object?> get props => [question, answer];
}
