import 'package:flutter/widgets.dart';

/// The forms whose Save was already tapped.
final _saveTried = Expando<bool>('save tried');

/// Checks the form of [key] when Save is tapped. From then on the form is
/// checked again as the person corrects it (see [revalidateIfTried]), so the
/// errors go away as each field is fixed, but nothing is shown in red before
/// the first Save.
bool validateOnSave(GlobalKey<FormState> key) {
  final state = key.currentState;
  if (state == null) return false;
  _saveTried[state] = true;
  return state.validate();
}

/// For the form's onChanged: checks it again only after a first Save.
void revalidateIfTried(GlobalKey<FormState> key) {
  final state = key.currentState;
  if (state != null && _saveTried[state] == true) state.validate();
}
