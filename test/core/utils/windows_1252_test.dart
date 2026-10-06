import 'dart:convert';

import 'package:finly/core/utils/windows_1252.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('plain ASCII stays as it is', () {
    expect(encodeWindows1252('Mercado 25;90'), 'Mercado 25;90'.codeUnits);
  });

  test('line breaks and tabs pass through', () {
    expect(encodeWindows1252('a\r\nb\tc'), [0x61, 0x0D, 0x0A, 0x62, 0x09, 0x63]);
  });

  test('Portuguese accents become single Latin-1 bytes', () {
    expect(encodeWindows1252('ç'), [0xE7]);
    expect(encodeWindows1252('ã'), [0xE3]);
    expect(encodeWindows1252('í'), [0xED]);
    expect(encodeWindows1252('ê'), [0xEA]);
    expect(encodeWindows1252('Ç'), [0xC7]);
    expect(encodeWindows1252('Á'), [0xC1]);
  });

  test('decoding the bytes gives the text back', () {
    const text = 'Saída, ação, Descrição, Transferência (entrada)';

    expect(latin1.decode(encodeWindows1252(text)), text);
  });

  test('the euro sign and typographic punctuation use the 0x80-0x9F range', () {
    expect(encodeWindows1252('€'), [0x80]);
    expect(encodeWindows1252('…'), [0x85]);
    expect(encodeWindows1252('’'), [0x92]);
    expect(encodeWindows1252('“”'), [0x93, 0x94]);
    expect(encodeWindows1252('–—'), [0x96, 0x97]);
  });

  test('a character Windows-1252 does not have becomes one question mark', () {
    expect(encodeWindows1252('😀'), [0x3F]);
    expect(encodeWindows1252('日本'), [0x3F, 0x3F]);
    expect(encodeWindows1252('a😀b'), [0x61, 0x3F, 0x62]);
  });

  test('control characters from the 0x80-0x9F block are not copied through', () {
    expect(encodeWindows1252('\u0085'), [0x3F]);
  });

  test('an empty text gives no bytes', () {
    expect(encodeWindows1252(''), isEmpty);
  });
}