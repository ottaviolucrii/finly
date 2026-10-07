import 'package:finly/core/money/money.dart';
import 'package:finly/core/utils/date_format.dart';
import 'package:finly/features/reports/domain/entities/monthly_report.dart';
import 'package:finly/features/reports/domain/report_pdf_builder.dart';
import 'package:finly/features/reports/domain/report_pdf_rules.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Draws the monthly report with the `pdf` package: A4, one section per
/// currency (summary, spending by category, biggest expenses) and a footer with
/// the page number. The standard Helvetica font is used: it covers the accents
/// of Portuguese, and the text avoids characters it does not have.
class PdfReportBuilder implements ReportPdfBuilder {
  const PdfReportBuilder();

  static final _blue = PdfColor.fromHex('#1060E3');
  static final _text = PdfColor.fromHex('#101820');
  static final _muted = PdfColor.fromHex('#6B7280');
  static final _line = PdfColor.fromHex('#C9CED6');
  static final _headerBackground = PdfColor.fromHex('#EEF2F8');
  static final _red = PdfColor.fromHex('#B3261E');
  static final _neutral = PdfColor.fromHex('#A8A8A8');

  @override
  Future<List<int>> build({
    required MonthlyReport report,
    required String workspaceName,
    required DateTime generatedAt,
  }) async {
    final document = pw.Document(
      title: 'Relatório de ${pdfMonthTitle(report.month)}',
      author: 'Finly',
      creator: 'Finly',
    );

    final theme = pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
      italic: pw.Font.helveticaOblique(),
      boldItalic: pw.Font.helveticaBoldOblique(),
    );

    final showCurrency = report.byCurrency.length > 1;

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 48),
        theme: theme,
        footer: (context) => _footer(context, generatedAt),
        build: (context) => [
          _title(report.month, workspaceName),
          for (final currency in report.byCurrency) ...[
            if (showCurrency) _heading('Moeda: ${currency.currency}', size: 14),
            ..._summary(currency),
            ..._categories(currency),
            ..._topExpenses(currency),
          ],
        ],
      ),
    );

    return document.save();
  }

  // ---- pieces -----------------------------------------------------------------

  pw.TextStyle _style({double size = 10, bool bold = false, PdfColor? color}) {
    return pw.TextStyle(
      fontSize: size,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: color ?? _text,
    );
  }

  pw.Widget _title(DateTime month, String workspaceName) {
    final subtitle = workspaceName.isEmpty
        ? pdfMonthTitle(month)
        : '$workspaceName - ${pdfMonthTitle(month)}';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Container(width: 6, height: 38, color: _blue),
            pw.SizedBox(width: 10),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Relatório mensal',
                  style: _style(size: 22, bold: true, color: _blue),
                ),
                pw.SizedBox(height: 2),
                pw.Text(subtitle, style: _style(size: 12, color: _muted)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: _line, thickness: 0.5),
      ],
    );
  }

  pw.Widget _heading(String text, {double size = 13, String? note}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 18, bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(text, style: _style(size: size, bold: true)),
          if (note != null) pw.Text(note, style: _style(size: 8.5, color: _muted)),
        ],
      ),
    );
  }

  pw.Widget _cell(
    String text, {
    bool right = false,
    bool bold = false,
    PdfColor? color,
    double size = 9.5,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Align(
        alignment: right ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        child: pw.Text(
          text,
          textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
          style: _style(size: size, bold: bold, color: color),
        ),
      ),
    );
  }

  pw.Widget _table({
    required List<pw.Widget> header,
    required List<List<pw.Widget>> rows,
    required Map<int, pw.TableColumnWidth> widths,
  }) {
    return pw.Table(
      columnWidths: widths,
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _line, width: 0.5),
        bottom: pw.BorderSide(color: _line, width: 0.5),
      ),
      children: [
        pw.TableRow(
          repeat: true,
          decoration: pw.BoxDecoration(color: _headerBackground),
          children: header,
        ),
        for (final row in rows) pw.TableRow(children: row),
      ],
    );
  }

  List<pw.Widget> _summary(CurrencyReport report) {
    final currency = report.currency;

    List<pw.Widget> row(String label, int cents, int previous, {bool signed = false}) {
      final text = signed
          ? pdfSignedMoney(cents, currency)
          : Money(cents, currency).format();
      return [
        _cell(label),
        _cell(text, right: true, bold: true, color: signed && cents < 0 ? _red : null),
        _cell(Money(previous, currency).format(), right: true, color: _muted),
        _cell(pdfChangeText(cents, previous), right: true),
      ];
    }

    return [
        _heading('Resumo do mês', note: 'Só o que já aconteceu'),
        _table(
          widths: {
            0: const pw.FlexColumnWidth(2.2),
            1: const pw.FlexColumnWidth(2.4),
            2: const pw.FlexColumnWidth(2.4),
            3: const pw.FlexColumnWidth(1.6),
          },
          header: [
            _cell('', bold: true),
            _cell('Este mês', right: true, bold: true),
            _cell('Mês anterior', right: true, bold: true),
            _cell('Variação', right: true, bold: true),
          ],
          rows: [
            row('Entradas', report.incomeCents, report.previousIncomeCents),
            row('Saídas', report.expenseCents, report.previousExpenseCents),
            row('Resultado', report.netCents, report.previousNetCents, signed: true),
          ],
        ),
      ];
  }

  /// A hex colour of the database ("#RRGGBB"), or grey when it is not one.
  PdfColor _dot(String hex) {
    if (!RegExp(r'^#?[0-9a-fA-F]{6}$').hasMatch(hex)) return _neutral;
    return PdfColor.fromHex(hex);
  }

  List<pw.Widget> _categories(CurrencyReport report) {
    final currency = report.currency;
    final total = report.categoryTotalCents;

    return [
        _heading('Gastos por categoria', note: 'Inclui lançamentos pendentes'),
        if (report.categories.isEmpty)
          pw.Text('Nenhum gasto neste mês.', style: _style(color: _muted))
        else
          _table(
            widths: {
              0: const pw.FlexColumnWidth(3.4),
              1: const pw.FlexColumnWidth(2.3),
              2: const pw.FlexColumnWidth(1.3),
              3: const pw.FlexColumnWidth(2.3),
              4: const pw.FlexColumnWidth(1.5),
            },
            header: [
              _cell('Categoria', bold: true),
              _cell('Valor', right: true, bold: true),
              _cell('% do total', right: true, bold: true),
              _cell('Mês anterior', right: true, bold: true),
              _cell('Variação', right: true, bold: true),
            ],
            rows: [
              for (final row in report.categories)
                [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                    child: pw.Row(
                      children: [
                        pw.Container(
                          width: 8,
                          height: 8,
                          decoration: pw.BoxDecoration(
                            color: _dot(row.colorHex),
                            shape: pw.BoxShape.circle,
                          ),
                        ),
                        pw.SizedBox(width: 6),
                        pw.Expanded(
                          child: pw.Text(row.name, style: _style(size: 9.5)),
                        ),
                      ],
                    ),
                  ),
                  _cell(Money(row.spentCents, currency).format(), right: true, bold: true),
                  _cell(
                    total > 0 ? '${(row.spentCents * 100 / total).round()}%' : '-',
                    right: true,
                  ),
                  _cell(Money(row.previousCents, currency).format(), right: true, color: _muted),
                  _cell(pdfChangeText(row.spentCents, row.previousCents), right: true),
                ],
            ],
          ),
      ];
  }

  List<pw.Widget> _topExpenses(CurrencyReport report) {
    final currency = report.currency;

    return [
        _heading('Maiores despesas'),
        if (report.topExpenses.isEmpty)
          pw.Text('Nenhuma despesa neste mês.', style: _style(color: _muted))
        else
          _table(
            widths: {
              0: const pw.FlexColumnWidth(1.7),
              1: const pw.FlexColumnWidth(5),
              2: const pw.FlexColumnWidth(2.3),
            },
            header: [
              _cell('Data', bold: true),
              _cell('Descrição', bold: true),
              _cell('Valor', right: true, bold: true),
            ],
            rows: [
              for (final expense in report.topExpenses)
                [
                  _cell(formatDateBr(expense.occurredAt)),
                  _cell(
                    expense.isPending
                        ? '${expense.description} (pendente)'
                        : expense.description,
                  ),
                  _cell(Money(expense.amountCents, currency).format(), right: true, bold: true),
                ],
            ],
          ),
      ];
  }

  pw.Widget _footer(pw.Context context, DateTime generatedAt) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Finly - ${pdfGeneratedText(generatedAt)}',
            style: _style(size: 8, color: _muted),
          ),
          pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: _style(size: 8, color: _muted),
          ),
        ],
      ),
    );
  }
}
