/// The three kinds of transfer (SRS BR-10).
enum TransferKind {
  /// Between two accounts of the same workspace.
  internal('internal'),

  /// From the Business workspace to the Personal one (pro-labore, profit).
  ownerWithdrawal('owner_withdrawal'),

  /// From the Personal workspace to the Business one (capital contribution).
  ownerContribution('owner_contribution');

  final String dbValue;

  const TransferKind(this.dbValue);

  /// True when the money moves between the user's two workspaces.
  bool get crossesWorkspaces => this != internal;

  static TransferKind fromDb(String value) {
    for (final kind in TransferKind.values) {
      if (kind.dbValue == value) return kind;
    }
    throw ArgumentError.value(value, 'value', 'Unknown transfer kind');
  }
}