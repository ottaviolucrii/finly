

import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable{

  final String message;

  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

// Specific failure for Server/Database issues
class ServerFailure extends Failure{
  const ServerFailure(super.message);
}

// Specific failure for Authentication issues
class AuthFailure extends Failure{
  const AuthFailure(super.message);
}