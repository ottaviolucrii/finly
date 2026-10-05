import 'package:bloc_test/bloc_test.dart';
import 'package:finly/features/auth/domain/entities/user_entity.dart';
import 'package:finly/features/auth/domain/usecases/get_current_user_use_case.dart';
import 'package:finly/features/auth/domain/usecases/sign_in_use_case.dart';
import 'package:finly/features/auth/domain/usecases/sign_out_use_case.dart';
import 'package:finly/features/auth/domain/usecases/sign_up_use_case.dart';
import 'package:finly/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:finly/features/auth/presentation/bloc/auth_event.dart';
import 'package:finly/features/auth/presentation/bloc/auth_state.dart';
import 'package:mocktail/mocktail.dart';

class MockSignIn extends Mock implements SignInUseCase {}

class MockSignUp extends Mock implements SignUpUseCase {}

class MockSignOut extends Mock implements SignOutUseCase {}

class MockGetCurrentUser extends Mock implements GetCurrentUserUseCase {}

void main() {
  const user = UserEntity(
    id: 'u1',
    fullName: 'Ana Teste',
    email: 'ana@finly.com',
    workspaces: [],
    activeWorkspaceId: 'w2',
  );

  blocTest<AuthBloc, AuthState>(
    'UserReplaced shows the given user as signed in, with no network call',
    build: () => AuthBloc(
      signIn: MockSignIn(),
      signUp: MockSignUp(),
      signOut: MockSignOut(),
      getCurrentUser: MockGetCurrentUser(),
    ),
    act: (bloc) => bloc.add(const UserReplaced(user)),
    expect: () => [AuthState.authenticated(user)],
  );
}