import 'package:equatable/equatable.dart';

typedef JsonRow = Map<String, dynamic>;

/// Everything the database holds about one user, as it was read: raw rows, one
/// list per table. Row Level Security already limits every read to the user's
/// own rows, so nothing of anyone else can be in here.
class UserDataSnapshot extends Equatable {
  final String userId;
  final String? email;

  final JsonRow? profile;
  final JsonRow? settings;

  final List<JsonRow> workspaces;
  final List<JsonRow> accounts;
  final List<JsonRow> cardDetails;
  final List<JsonRow> invoices;
  final List<JsonRow> categories;
  final List<JsonRow> budgets;
  final List<JsonRow> recurring;
  final List<JsonRow> transactions;
  final List<JsonRow> transfers;

  /// Tables that had more rows than the limit, so only the first rows are here.
  final Set<String> truncatedTables;

  const UserDataSnapshot({
    required this.userId,
    this.email,
    this.profile,
    this.settings,
    this.workspaces = const [],
    this.accounts = const [],
    this.cardDetails = const [],
    this.invoices = const [],
    this.categories = const [],
    this.budgets = const [],
    this.recurring = const [],
    this.transactions = const [],
    this.transfers = const [],
    this.truncatedTables = const {},
  });

  /// How many rows are in the snapshot.
  int get rowCount =>
      (profile == null ? 0 : 1) +
      (settings == null ? 0 : 1) +
      workspaces.length +
      accounts.length +
      cardDetails.length +
      invoices.length +
      categories.length +
      budgets.length +
      recurring.length +
      transactions.length +
      transfers.length;

  @override
  List<Object?> get props => [
        userId,
        email,
        profile,
        settings,
        workspaces,
        accounts,
        cardDetails,
        invoices,
        categories,
        budgets,
        recurring,
        transactions,
        transfers,
        truncatedTables,
      ];
}
