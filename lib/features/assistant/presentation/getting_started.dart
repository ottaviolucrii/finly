import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The first steps of a new workspace, in order.
enum StartStep {
  account('Cadastre sua primeira conta', 'Com o saldo de hoje', null),
  transaction('Faça seu primeiro lançamento', 'Dica: escreva como você falaria', null),
  card('Cadastre um cartão', 'Limite, faturas e parcelas', 'Não tenho cartão'),
  budget('Defina um orçamento', 'Um limite para uma categoria', 'Não preciso'),
  goal('Crie uma meta', 'Guardar para um objetivo', 'Não preciso');

  final String title;
  final String hint;

  /// The words of the button that skips this step; null when it cannot be
  /// skipped (the guide itself still can).
  final String? skipLabel;

  const StartStep(this.title, this.hint, this.skipLabel);
}

/// The steps already done, from what Início already knows.
Set<StartStep> startStepsDone({
  required bool hasAccount,
  required bool hasTransaction,
  required bool hasCard,
  required bool hasBudget,
  required bool hasGoal,
}) {
  return {
    if (hasAccount) StartStep.account,
    if (hasTransaction) StartStep.transaction,
    if (hasCard) StartStep.card,
    if (hasBudget) StartStep.budget,
    if (hasGoal) StartStep.goal,
  };
}

/// What the person chose about the guide, per workspace: hidden, and the
/// steps they said they do not need.
abstract class GettingStartedStore {
  Future<bool> isHidden(String workspaceId);
  Future<void> setHidden(String workspaceId, bool hidden);
  Future<Set<StartStep>> skipped(String workspaceId);
  Future<void> skip(String workspaceId, StartStep step);

  /// Changes when the guide is brought back (Início reads it again).
  static final changes = ValueNotifier<int>(0);
}

/// Kept on the phone, like the other small choices of the app.
class PrefsGettingStartedStore implements GettingStartedStore {
  const PrefsGettingStartedStore();

  String _hiddenKey(String id) => 'getting_started.hidden.$id';
  String _skippedKey(String id) => 'getting_started.skipped.$id';

  @override
  Future<bool> isHidden(String workspaceId) async =>
      (await SharedPreferences.getInstance()).getBool(_hiddenKey(workspaceId)) ?? false;

  @override
  Future<void> setHidden(String workspaceId, bool hidden) async {
    await (await SharedPreferences.getInstance()).setBool(_hiddenKey(workspaceId), hidden);
    GettingStartedStore.changes.value++;
  }

  @override
  Future<Set<StartStep>> skipped(String workspaceId) async {
    final names = (await SharedPreferences.getInstance()).getStringList(_skippedKey(workspaceId)) ?? const [];
    return {for (final step in StartStep.values) if (names.contains(step.name)) step};
  }

  @override
  Future<void> skip(String workspaceId, StartStep step) async {
    final prefs = await SharedPreferences.getInstance();
    final names = {...prefs.getStringList(_skippedKey(workspaceId)) ?? const <String>[], step.name};
    await prefs.setStringList(_skippedKey(workspaceId), names.toList());
  }
}
