import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/reminders/domain/entities/notification_prefs.dart';
import 'package:finly/features/reminders/domain/repositories/reminders_repository.dart';

class GetNotificationPrefsUseCase implements UseCase<NotificationPrefs, NoParams> {
  final RemindersRepository _repository;

  const GetNotificationPrefsUseCase(this._repository);

  @override
  Future<Either<Failure, NotificationPrefs>> call(NoParams params) {
    return _repository.getPrefs();
  }
}
