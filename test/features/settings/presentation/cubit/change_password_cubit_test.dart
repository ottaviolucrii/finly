import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/auth/domain/usecases/change_password_use_case.dart';
import 'package:finly/features/settings/presentation/cubit/change_password_cubit.dart';
import 'package:finly/features/settings/presentation/cubit/change_password_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockChangePassword extends Mock implements ChangePasswordUseCase {}

void main() {
  late MockChangePassword changePassword;

  const params = ChangePasswordParams(
    currentPassword: 'senhaAtual1',
    newPassword: 'novaSenha2',
  );

  setUp(() => changePassword = MockChangePassword());

  Future<void> submit(ChangePasswordCubit cubit) => cubit.submit(
        currentPassword: 'senhaAtual1',
        newPassword: 'novaSenha2',
      );

  blocTest<ChangePasswordCubit, ChangePasswordState>(
    'emits submitting then success',
    build: () {
      when(() => changePassword(params))
          .thenAnswer((_) async => const Right<Failure, void>(null));
      return ChangePasswordCubit(changePassword);
    },
    act: submit,
    expect: () => [
      const ChangePasswordState(status: ChangePasswordStatus.submitting),
      const ChangePasswordState(status: ChangePasswordStatus.success),
    ],
  );

  blocTest<ChangePasswordCubit, ChangePasswordState>(
    'emits submitting then failure with the reason',
    build: () {
      when(() => changePassword(params)).thenAnswer(
        (_) async =>
            const Left<Failure, void>(AuthFailure('invalid_credentials')),
      );
      return ChangePasswordCubit(changePassword);
    },
    act: submit,
    expect: () => [
      const ChangePasswordState(status: ChangePasswordStatus.submitting),
      const ChangePasswordState(
        status: ChangePasswordStatus.failure,
        failure: AuthFailure('invalid_credentials'),
      ),
    ],
  );

  blocTest<ChangePasswordCubit, ChangePasswordState>(
    'calls the use case once with what the form sent',
    build: () {
      when(() => changePassword(params))
          .thenAnswer((_) async => const Right<Failure, void>(null));
      return ChangePasswordCubit(changePassword);
    },
    act: submit,
    verify: (_) => verify(() => changePassword(params)).called(1),
  );
}