import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/auth/domain/repositories/auth_repository.dart';

class SignOutParams extends Equatable {
  /// When true, every device is signed out, not only this one.
  final bool allDevices;

  const SignOutParams({this.allDevices = false});

  @override
  List<Object?> get props => [allDevices];
}

class SignOutUseCase implements UseCase<void, SignOutParams> {
  final AuthRepository _repository;

  const SignOutUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(SignOutParams params) {
    return _repository.signOut(allDevices: params.allDevices);
  }
}