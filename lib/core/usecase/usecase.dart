import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';

/// One use case = one business action, one public method.
abstract class UseCase<T, Params> {
  Future<Either<Failure, T>> call(Params params);
}

/// For use cases that need no input.
class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => [];
}