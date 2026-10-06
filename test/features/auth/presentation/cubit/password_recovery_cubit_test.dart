import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/auth/domain/usecases/request_password_reset_use_case.dart';
import 'package:finly/features/auth/domain/usecases/reset_password_use_case.dart';
import 'package:finly/features/auth/presentation/cubit/password_recovery_cubit.dart';
import 'package:finly/features/auth/presentation/cubit/password_recovery_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRequestReset extends Mock implements RequestPasswordResetUseCase {}

class MockResetPassword extends Mock implements ResetPasswordUseCase {}

void main() {
  late MockRequestReset requestReset;
  late MockResetPassword resetPassword;

  const params = ResetPasswordParams(
    email: 'ana@exemplo.com',
    code: '123456',
    newPassword: 'novaSenha2',
  );

  setUpAll(() => registerFallbackValue(params));

  setUp(() {
    requestReset = MockRequestReset();
    resetPassword = MockResetPassword();
  });

  PasswordRecoveryCubit buildCubit() => PasswordRecoveryCubit(
        requestReset: requestReset,
        resetPassword: resetPassword,
      );

  group('requestCode', () {
    blocTest<PasswordRecoveryCubit, PasswordRecoveryState>(
      'emits sendingCode then codeSent',
      build: () {
        when(() => requestReset('ana@exemplo.com'))
            .thenAnswer((_) async => const Right<Failure, void>(null));
        return buildCubit();
      },
      act: (cubit) => cubit.requestCode('ana@exemplo.com'),
      expect: () => [
        const PasswordRecoveryState(status: PasswordRecoveryStatus.sendingCode),
        const PasswordRecoveryState(status: PasswordRecoveryStatus.codeSent),
      ],
    );

    blocTest<PasswordRecoveryCubit, PasswordRecoveryState>(
      'emits sendingCode then failure with the reason',
      build: () {
        when(() => requestReset(any())).thenAnswer(
          (_) async => const Left<Failure, void>(AuthFailure('rate_limited')),
        );
        return buildCubit();
      },
      act: (cubit) => cubit.requestCode('ana@exemplo.com'),
      expect: () => [
        const PasswordRecoveryState(status: PasswordRecoveryStatus.sendingCode),
        const PasswordRecoveryState(
          status: PasswordRecoveryStatus.failure,
          failure: AuthFailure('rate_limited'),
        ),
      ],
    );

    blocTest<PasswordRecoveryCubit, PasswordRecoveryState>(
      'can send the code again after it was sent',
      build: () {
        when(() => requestReset(any()))
            .thenAnswer((_) async => const Right<Failure, void>(null));
        return buildCubit();
      },
      act: (cubit) async {
        await cubit.requestCode('ana@exemplo.com');
        await cubit.requestCode('ana@exemplo.com');
      },
      verify: (_) => verify(() => requestReset('ana@exemplo.com')).called(2),
    );
  });

  group('reset', () {
    Future<void> submit(PasswordRecoveryCubit cubit) => cubit.reset(
          email: 'ana@exemplo.com',
          code: '123456',
          newPassword: 'novaSenha2',
        );

    blocTest<PasswordRecoveryCubit, PasswordRecoveryState>(
      'emits resetting then resetDone',
      build: () {
        when(() => resetPassword(params))
            .thenAnswer((_) async => const Right<Failure, void>(null));
        return buildCubit();
      },
      act: submit,
      expect: () => [
        const PasswordRecoveryState(status: PasswordRecoveryStatus.resetting),
        const PasswordRecoveryState(status: PasswordRecoveryStatus.resetDone),
      ],
    );

    blocTest<PasswordRecoveryCubit, PasswordRecoveryState>(
      'emits resetting then failure for a wrong code',
      build: () {
        when(() => resetPassword(params)).thenAnswer(
          (_) async => const Left<Failure, void>(AuthFailure('invalid_code')),
        );
        return buildCubit();
      },
      act: submit,
      expect: () => [
        const PasswordRecoveryState(status: PasswordRecoveryStatus.resetting),
        const PasswordRecoveryState(
          status: PasswordRecoveryStatus.failure,
          failure: AuthFailure('invalid_code'),
        ),
      ],
    );

    blocTest<PasswordRecoveryCubit, PasswordRecoveryState>(
      'calls the use case once with what the form sent',
      build: () {
        when(() => resetPassword(params))
            .thenAnswer((_) async => const Right<Failure, void>(null));
        return buildCubit();
      },
      act: submit,
      verify: (_) => verify(() => resetPassword(params)).called(1),
    );
  });
}