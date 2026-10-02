import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';

/// One use case = one business action, one public method.
abstract class UseCase<T, Params> {
  Future<Either<Failure, T>> call(Params params);
}