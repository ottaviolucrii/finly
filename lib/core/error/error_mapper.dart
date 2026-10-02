import 'dart:async';

import 'package:finly/core/error/failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Turns exceptions thrown by Supabase into domain [Failure]s.
/// Failure messages are stable codes; the UI translates them.
abstract final class ErrorMapper {
  static Failure toFailure(Object error) {
    // AuthRetryableFetchException extends AuthException: check it first.
    if (error is AuthRetryableFetchException || error is TimeoutException) {
      return const NetworkFailure('network_error');
    }
    if (error is AuthException) return _fromAuth(error);
    if (error is PostgrestException) return _fromPostgrest(error);
    return const ServerFailure('unknown_error');
  }

  static Failure _fromAuth(AuthException e) {
    final code = e.code ?? '';
    final message = e.message.toLowerCase();

    if (code == 'invalid_credentials' ||
        message.contains('invalid login credentials')) {
      return const AuthFailure('invalid_credentials');
    }
    if (code == 'email_not_confirmed' ||
        message.contains('email not confirmed')) {
      return const AuthFailure('email_not_confirmed');
    }
    if (code == 'user_already_exists' ||
        code == 'email_exists' ||
        message.contains('already registered')) {
      return const AuthFailure('email_already_registered');
    }
    if (code == 'weak_password') {
      return const ValidationFailure('weak_password');
    }
    if (code == 'over_request_rate_limit' ||
        code == 'over_email_send_rate_limit' ||
        e.statusCode == '429') {
      return const AuthFailure('rate_limited');
    }
    return const AuthFailure('auth_error');
  }

  static Failure _fromPostgrest(PostgrestException e) {
    final text = e.message;

    // Stable keys raised by our SQL functions (sql/03_logic.sql).
    if (text.contains('invalid_tax_id')) {
      return const ValidationFailure('invalid_tax_id');
    }
    if (text.contains('workspace_type_already_exists')) {
      return const ConflictFailure('workspace_type_already_exists');
    }

    switch (e.code) {
      case '28000':
        return const AuthFailure('not_authenticated');
      case '42501':
        return const PermissionFailure('forbidden');
      case '23505':
        return const ConflictFailure('already_exists');
      case '23514':
      case 'P0001':
        return RuleFailure(text);
      default:
        return const ServerFailure('server_error');
    }
  }
}