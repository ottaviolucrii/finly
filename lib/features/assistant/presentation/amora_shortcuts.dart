import 'package:flutter/material.dart';

/// A place of the app Amora can take the person to.
class AmoraShortcut {
  final String title;
  final String hint;
  final IconData icon;

  /// Other words people use for it ("fatura", "cartão"...).
  final List<String> keywords;
  final VoidCallback onOpen;

  const AmoraShortcut({
    required this.title,
    required this.hint,
    required this.icon,
    required this.keywords,
    required this.onOpen,
  });
}

/// [text] in lower case without accents, to compare as people type.
String plainText(String text) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const to = 'aaaaaeeeeiiiiooooouuuuc';
  final lower = text.toLowerCase();
  final out = StringBuffer();
  for (final char in lower.split('')) {
    final i = from.indexOf(char);
    out.write(i < 0 ? char : to[i]);
  }
  return out.toString();
}

/// Words that say nothing about where to go ("como", "eu", "a"...).
const _stopWords = {
  'como', 'onde', 'quero', 'queria', 'preciso', 'posso', 'pode', 'fazer', 'faco', 'ver', 'vejo', 'eu', 'meu',
  'minha', 'meus', 'minhas', 'o', 'a', 'os', 'as', 'de', 'do', 'da', 'dos', 'das', 'um', 'uma', 'no', 'na', 'em',
  'para', 'pra', 'que', 'qual', 'e', 'me', 'se', 'com', 'tem', 'ter', 'esta', 'fica',
};

/// The shortcuts for what the person typed, best first: each meaningful word
/// found in the title, the hint or the keywords counts (a long word also by
/// its start, so "pago" finds "pagar"). Empty query: all of them.
List<AmoraShortcut> searchShortcuts(List<AmoraShortcut> all, String query) {
  final words = plainText(query)
      .split(RegExp(r'[^a-z0-9]+'))
      .where((w) => w.length > 1 && !_stopWords.contains(w))
      .toList();
  if (words.isEmpty) return all;

  final scored = <(AmoraShortcut, int)>[];
  for (final s in all) {
    final text = plainText('${s.title} ${s.hint} ${s.keywords.join(' ')}');
    var score = 0;
    for (final w in words) {
      if (text.contains(w) || (w.length >= 4 && text.contains(w.substring(0, 3)))) score++;
    }
    if (score > 0) scored.add((s, score));
  }
  scored.sort((a, b) => b.$2.compareTo(a.$2));
  return [for (final item in scored) item.$1];
}
