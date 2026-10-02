import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:flutter/material.dart';

String accountTypeLabel(AccountType type) => switch (type) {
      AccountType.checking => 'Conta corrente',
      AccountType.savings => 'Poupança',
      AccountType.investment => 'Investimentos',
      AccountType.creditCard => 'Cartão de crédito',
    };

IconData accountTypeIcon(AccountType type) => switch (type) {
      AccountType.checking => Icons.account_balance_outlined,
      AccountType.savings => Icons.savings_outlined,
      AccountType.investment => Icons.trending_up,
      AccountType.creditCard => Icons.credit_card,
    };