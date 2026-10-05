import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/auth/domain/repositories/auth_repository.dart';
import 'package:finly/features/auth/domain/usecases/sign_out_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;
  late SignOutUseCase useCase;

  setUp(() {
    repository = MockAuthRepository();
    useCase = SignOutUseCase(repository);
  });

  test('signs out this device only by default', () async {
    when(() => repository.signOut(allDevices: false))
        .thenAnswer((_) async => const Right<Failure, void>(null));

    final result = await useCase(const SignOutParams());

    expect(result.isRight(), isTrue);
    verify(() => repository.signOut(allDevices: false)).called(1);
  });

  test('signs out every device when asked', () async {
    when(() => repository.signOut(allDevices: true))
        .thenAnswer((_) async => const Right<Failure, void>(null));

    final result = await useCase(const SignOutParams(allDevices: true));

    expect(result.isRight(), isTrue);
    verify(() => repository.signOut(allDevices: true)).called(1);
  });

  test('passes a repository failure through unchanged', () async {
    when(() => repository.signOut(allDevices: false)).thenAnswer(
      (_) async => const Left<Failure, void>(ServerFailure('network_error')),
    );

    final result = await useCase(const SignOutParams());

    expect(result, const Left<Failure, void>(ServerFailure('network_error')));
  });
}