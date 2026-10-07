import 'package:finly/features/lock/presentation/cubit/app_lock_state.dart';

/// "Imediatamente", "1 minuto", "2 minutos"... (Portuguese for now; replaced by
/// proper localisation in a later phase).
String lockTimeoutLabel(int seconds) {
  if (seconds <= 0) return 'Imediatamente';
  if (seconds == 60) return '1 minuto';
  return '${seconds ~/ 60} minutos';
}

/// "4:32". A part of a second counts as a whole one.
String formatCountdown(Duration remaining) {
  final milliseconds = remaining.inMilliseconds < 0 ? 0 : remaining.inMilliseconds;
  final total = (milliseconds + 999) ~/ 1000;
  final minutes = total ~/ 60;
  final seconds = (total % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// The message under the password field of the lock screen, or null when there
/// is nothing to say.
String? lockUnlockError(AppLockState state, DateTime now) {
  final until = state.blockedUntil;
  if (until != null && now.isBefore(until)) {
    return 'Muitas tentativas erradas. Tente de novo em '
        '${formatCountdown(until.difference(now))}.';
  }

  switch (state.error) {
    case LockError.wrongPassword:
      final left = state.attemptsLeft;
      return left == 1
          ? 'Senha incorreta. Resta 1 tentativa.'
          : 'Senha incorreta. Restam $left tentativas.';
    case LockError.rateLimited:
      return 'Muitas tentativas. Aguarde um pouco e tente de novo.';
    case LockError.network:
      return 'Sem conexão. Verifique sua internet.';
    case LockError.deviceFailed:
      return 'Não foi possível confirmar pelo aparelho. Tente de novo ou use a '
          'senha.';
    case LockError.other:
      return 'Algo deu errado. Tente novamente.';
    case LockError.none:
    case LockError.blocked: // the block is over: nothing to say
    case LockError.biometricUnavailable:
    case LockError.biometricNotConfirmed:
    case LockError.saveFailed:
      return null;
  }
}

/// The message for the lock settings screen, or null when there is nothing to
/// say.
String? lockSettingsError(LockError error) {
  switch (error) {
    case LockError.biometricUnavailable:
      return 'Este aparelho não tem biometria nem bloqueio de tela configurado.';
    case LockError.biometricNotConfirmed:
      return 'Não foi possível confirmar. A biometria continua desativada.';
    case LockError.saveFailed:
      return 'Não foi possível salvar. Tente de novo.';
    case LockError.none:
    case LockError.wrongPassword:
    case LockError.blocked:
    case LockError.rateLimited:
    case LockError.network:
    case LockError.deviceFailed:
    case LockError.other:
      return null;
  }
}