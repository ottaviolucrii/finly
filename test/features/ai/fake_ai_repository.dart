import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/ai/domain/entities/ai_draft.dart';
import 'package:finly/features/ai/domain/repositories/ai_repository.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';

/// An AI that answers what the test says, and remembers what it was asked.
class FakeAiRepository implements AiRepository {
  Either<Failure, AiDraft>? answer;
  bool enabled;
  Either<Failure, void> saveResult = const Right(null);
  final sentences = <String>[];
  final changes = <bool>[];

  FakeAiRepository({this.answer, this.enabled = false});

  @override
  Future<Either<Failure, AiDraft>> readSentence({
    required String text,
    required DateTime today,
    required List<CategoryEntity> categories,
    required List<AccountEntity> accounts,
  }) async {
    sentences.add(text);
    return answer!;
  }

  @override
  Future<Either<Failure, bool>> isEnabled() async => Right(enabled);

  @override
  Future<Either<Failure, void>> setEnabled(bool value) async {
    changes.add(value);
    if (saveResult.isRight()) enabled = value;
    return saveResult;
  }
}
