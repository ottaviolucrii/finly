import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/ai/domain/entities/ai_draft.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';

/// The AI quick add: reading a sentence, and the person's consent.
abstract class AiRepository {
  /// Reads [text] into a draft. Only names go to the AI (see docs/AI.md).
  Future<Either<Failure, AiDraft>> readSentence({
    required String text,
    required DateTime today,
    required List<CategoryEntity> categories,
    required List<AccountEntity> accounts,
  });

  /// True when the person turned the AI on.
  Future<Either<Failure, bool>> isEnabled();

  /// Turns the AI on or off (on records the moment of the consent).
  Future<Either<Failure, void>> setEnabled(bool enabled);
}
