import 'package:equatable/equatable.dart';

/// An expense category, with whether it counts as a tax in the tax reserve.
class TaxCategory extends Equatable {
  final String id;
  final String name;

  /// A hex colour such as "#F29D38".
  final String colorHex;
  final bool isTax;

  const TaxCategory({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.isTax,
  });

  TaxCategory withTax(bool value) {
    return TaxCategory(id: id, name: name, colorHex: colorHex, isTax: value);
  }

  @override
  List<Object?> get props => [id, name, colorHex, isTax];
}
