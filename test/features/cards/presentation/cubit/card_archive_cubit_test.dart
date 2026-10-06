import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/accounts/domain/usecases/archive_account_use_case.dart';
import 'package:finly/features/cards/presentation/cubit/card_archive_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/card_archive_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockArchiveAccount extends Mock implements ArchiveAccountUseCase {}

void main() {
  late MockArchiveAccount archiveAccount;

  setUp(() => archiveAccount = MockArchiveAccount());

  blocTest<CardArchiveCubit, CardArchiveState>(
    'emits archiving then archived',
    build: () {
      when(() => archiveAccount('a1'))
          .thenAnswer((_) async => const Right<Failure, void>(null));
      return CardArchiveCubit(archiveAccount);
    },
    act: (cubit) => cubit.archive('a1'),
    expect: () => [
      const CardArchiveState(status: CardArchiveStatus.archiving),
      const CardArchiveState(status: CardArchiveStatus.archived),
    ],
  );

  blocTest<CardArchiveCubit, CardArchiveState>(
    'emits archiving then failure with the reason',
    build: () {
      when(() => archiveAccount('a1')).thenAnswer(
        (_) async =>
            const Left<Failure, void>(PermissionFailure('forbidden')),
      );
      return CardArchiveCubit(archiveAccount);
    },
    act: (cubit) => cubit.archive('a1'),
    expect: () => [
      const CardArchiveState(status: CardArchiveStatus.archiving),
      const CardArchiveState(
        status: CardArchiveStatus.failure,
        failure: PermissionFailure('forbidden'),
      ),
    ],
  );

  blocTest<CardArchiveCubit, CardArchiveState>(
    'calls the use case once with the card account id',
    build: () {
      when(() => archiveAccount('a1'))
          .thenAnswer((_) async => const Right<Failure, void>(null));
      return CardArchiveCubit(archiveAccount);
    },
    act: (cubit) => cubit.archive('a1'),
    verify: (_) => verify(() => archiveAccount('a1')).called(1),
  );
}