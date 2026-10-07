import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/reminders/domain/entities/notification_prefs.dart';
import 'package:finly/features/reminders/domain/repositories/reminders_repository.dart';

class SaveNotificationPrefsUseCase implements UseCase<void, NotificationPrefs> {
  final RemindersRepository _repository;

  const SaveNotificationPrefsUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(NotificationPrefs prefs) {
    return _repository.savePrefs(prefs);
  }
}
