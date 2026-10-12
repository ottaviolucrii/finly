import 'package:dartz/dartz.dart';
import 'package:finly/core/error/error_mapper.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/ai/data/ai_remote_data_source.dart';
import 'package:finly/features/ai/domain/entities/ai_draft.dart';
import 'package:finly/features/ai/domain/repositories/ai_repository.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';

class AiRepositoryImpl implements AiRepository {
  final AiRemoteDataSource _remote;

  const AiRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, AiDraft>> readSentence({
    required String text,
    required DateTime today,
    required List<CategoryEntity> categories,
    required List<AccountEntity> accounts,
  }) {
    return _guard(() => _remote.readSentence(text: text, today: today, categories: categories, accounts: accounts));
  }

  @override
  Future<Either<Failure, bool>> isEnabled() => _guard(_remote.isEnabled);

  @override
  Future<Either<Failure, void>> setEnabled(bool enabled) => _guard(() => _remote.setEnabled(enabled));

  @override
  Future<Either<Failure, String>> ask({
    required String question,
    required String workspaceId,
    required DateTime today,
  }) {
    return _guard(() => _remote.ask(question: question, workspaceId: workspaceId, today: today));
  }

  @override
  Future<Either<Failure, bool>> isAskEnabled() => _guard(_remote.isAskEnabled);

  @override
  Future<Either<Failure, void>> setAskEnabled(bool enabled) => _guard(() => _remote.setAskEnabled(enabled));

  /// Runs [action]; an answer of the AI that is not a draft becomes a
  /// RuleFailure with its code, anything else goes through the ErrorMapper.
  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right<Failure, T>(await action());
    } on AiException catch (e) {
      return Left<Failure, T>(RuleFailure(e.code));
    } catch (e) {
      return Left<Failure, T>(ErrorMapper.toFailure(e));
    }
  }
}
