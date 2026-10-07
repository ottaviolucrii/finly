import 'package:finly/core/error/failure.dart';
import 'package:finly/features/transactions/presentation/move_messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String text(String message) => moveFailureMessage(RuleFailure(message));

  test('says a card purchase can only go back to a bank account', () {
    expect(
      text('a card purchase can only go to a bank account'),
      'Uma compra no cartão só pode voltar para uma conta comum.',
    );
  });

  test('says an installment cannot be moved', () {
    expect(text('an installment cannot be moved'), 'Uma compra parcelada não pode mudar de conta.');
  });

  test('says only an expense can go to a card', () {
    expect(text('only an expense can be moved to a card'), 'Só uma despesa pode ir para um cartão.');
  });

  test('says the invoice of that date is paid', () {
    expect(
      text('the invoice of that date is already paid'),
      'A fatura da data desta despesa já está paga.',
    );
  });

  test('says the invoice of the purchase is paid', () {
    expect(text('the invoice is already paid'), 'A fatura desta compra já está paga.');
  });

  test('says the card has no closing and due days', () {
    expect(
      text('the card has no details'),
      'O cartão não tem fechamento e vencimento cadastrados.',
    );
  });

  test('says the currency is different', () {
    expect(text('the account has another currency'), 'A outra conta usa outra moeda.');
  });

  test('says the account is archived', () {
    expect(text('the account is archived'), 'A conta escolhida está arquivada.');
  });

  test('says the account is of another workspace', () {
    expect(
      text('the account belongs to another workspace'),
      'A conta escolhida é de outro workspace.',
    );
  });

  test('says it is already there', () {
    expect(text('transaction is already in this account'), 'A transação já está nesta conta.');
  });

  test('says the transaction was deleted', () {
    expect(text('transaction is deleted'), 'Esta transação foi excluída.');
  });

  test('says transfers cannot move', () {
    expect(text('transfer legs cannot be moved'), 'Transferências não podem mudar de conta.');
  });

  test('asks for a valid account when an id is empty', () {
    expect(
      moveFailureMessage(const ValidationFailure('invalid_account')),
      'Escolha uma conta válida.',
    );
  });

  test('anything else gets a message and never the raw text', () {
    final message = moveFailureMessage(const ServerFailure('unknown_error'));

    expect(message, isNotEmpty);
    expect(message, isNot(contains('unknown_error')));
  });
}
