import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/auth/domain/usecases/delete_account_use_case.dart';
import 'package:finly/features/settings/presentation/cubit/delete_account_cubit.dart';
import 'package:finly/features/settings/presentation/cubit/delete_account_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDeleteAccount extends Mock implements DeleteAccountUseCase {}

void main() {
  late MockDeleteAccount deleteAccount;

  const params = DeleteAccountParams(password: 'senha123', confirmation: 'EXCLUIR');

  setUp(() => deleteAccount = MockDeleteAccount());

  Future<void> submit(DeleteAccountCubit cubit) =>
      cubit.submit(password: 'senha123', confirmation: 'EXCLUIR');

  blocTest<DeleteAccountCubit, DeleteAccountState>(
    'emits submitting then success',
    build: () {
      when(() => deleteAccount(params))
          .thenAnswer((_) async => const Right<Failure, void>(null));
      return DeleteAccountCubit(deleteAccount);
    },
    act: submit,
    expect: () => [
      const DeleteAccountState(status: DeleteAccountStatus.submitting),
      const DeleteAccountState(status: DeleteAccountStatus.success),
    ],
  );

  blocTest<DeleteAccountCubit, DeleteAccountState>(
    'emits submitting then failure with the reason',
    build: () {
      when(() => deleteAccount(params)).thenAnswer(
        (_) async =>
            const Left<Failure, void>(AuthFailure('invalid_credentials')),
      );
      return DeleteAccountCubit(deleteAccount);
    },
    act: submit,
    expect: () => [
      const DeleteAccountState(status: DeleteAccountStatus.submitting),
      const DeleteAccountState(
        status: DeleteAccountStatus.failure,
        failure: AuthFailure('invalid_credentials'),
      ),
    ],
  );

  blocTest<DeleteAccountCubit, DeleteAccountState>(
    'calls the use case once with what the form sent',
    build: () {
      when(() => deleteAccount(params))
          .thenAnswer((_) async => const Right<Failure, void>(null));
      return DeleteAccountCubit(deleteAccount);
    },
    act: submit,
    verify: (_) => verify(() => deleteAccount(params)).called(1),
  );
}