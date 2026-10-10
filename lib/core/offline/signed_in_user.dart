import 'dart:async';

import 'package:finly/core/offline/remembered_user.dart';

enum UserSource {
  /// The login library has a session.
  library,

  /// The library has none, but the phone remembers who was signed in.
  remembered,
}

class SignedInUser {
  final KnownUser user;
  final UserSource source;

  const SignedInUser(this.user, this.source);
}

/// Who is signed in, for the start of the app.
///
/// The login library comes first. It can have no session for a moment while it
/// restores it, or for good when it could not renew an expired login without
/// internet. In that case the person remembered from the saved session is used,
/// after waiting [patience] for the library, so the app opens with the saved
/// data instead of asking for the password again. Null when nobody is signed in.
Future<SignedInUser?> resolveSignedInUser({
  required KnownUser? Function() fromLibrary,
  required SessionMemory? memory,
  Duration patience = const Duration(seconds: 2),
  Duration step = const Duration(milliseconds: 100),
}) async {
  final first = fromLibrary();
  if (first != null) return SignedInUser(first, UserSource.library);

  KnownUser? remembered;
  try {
    remembered = await memory?.user();
  } catch (_) {
    remembered = null;
  }
  if (remembered == null) return null;

  var waited = Duration.zero;
  while (waited < patience) {
    await Future<void>.delayed(step);
    waited += step;

    final late = fromLibrary();
    if (late != null) return SignedInUser(late, UserSource.library);
  }

  return SignedInUser(remembered, UserSource.remembered);
}
