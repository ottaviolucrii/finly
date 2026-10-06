/// How long a deleted transaction stays in the trash. The daily database job
/// (sql/13) removes it for good after this.
const int trashRetentionDays = 30;

/// Whole days left before a transaction deleted at [deletedAt] is removed for
/// good, from 0 to [trashRetentionDays]. A partial last day still counts.
int trashDaysLeft(DateTime deletedAt, DateTime now) {
  final elapsedDays = now.difference(deletedAt).inDays;
  return (trashRetentionDays - elapsedDays).clamp(0, trashRetentionDays);
}

String trashDaysLeftLabel(int daysLeft) {
  if (daysLeft <= 0) return 'Será removida hoje';
  if (daysLeft == 1) return 'Resta 1 dia';
  return 'Restam $daysLeft dias';
}