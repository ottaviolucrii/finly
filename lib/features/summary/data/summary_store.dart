import 'package:shared_preferences/shared_preferences.dart';

/// Which months' summary card the person already closed, per workspace.
abstract class SummaryStore {
  Future<bool> isDismissed(String workspaceId, DateTime month);

  Future<void> dismiss(String workspaceId, DateTime month);
}

/// Kept on the phone, like the other small choices of the app.
class PrefsSummaryStore implements SummaryStore {
  const PrefsSummaryStore();

  String _key(String workspaceId, DateTime month) => 'summary.dismissed.$workspaceId.${month.year}-${month.month}';

  @override
  Future<bool> isDismissed(String workspaceId, DateTime month) async =>
      (await SharedPreferences.getInstance()).getBool(_key(workspaceId, month)) ?? false;

  @override
  Future<void> dismiss(String workspaceId, DateTime month) async {
    await (await SharedPreferences.getInstance()).setBool(_key(workspaceId, month), true);
  }
}
