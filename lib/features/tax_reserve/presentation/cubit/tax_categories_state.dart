import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/tax_reserve/domain/entities/tax_category.dart';

enum TaxCategoriesStatus { loading, loaded, failure }

class TaxCategoriesState extends Equatable {
  final TaxCategoriesStatus status;
  final List<TaxCategory> categories;
  final Failure? failure;

  /// The category being saved right now, if any.
  final String? savingId;

  /// Why the last change was refused (the switch went back).
  final Failure? saveFailure;

  /// How many changes were saved: the screen reads the numbers again when it
  /// goes up.
  final int changes;

  const TaxCategoriesState({
    this.status = TaxCategoriesStatus.loading,
    this.categories = const [],
    this.failure,
    this.savingId,
    this.saveFailure,
    this.changes = 0,
  });

  /// The names of the categories marked as a tax.
  List<String> get markedNames => [
        for (final category in categories)
          if (category.isTax) category.name,
      ];

  @override
  List<Object?> get props => [status, categories, failure, savingId, saveFailure, changes];
}
