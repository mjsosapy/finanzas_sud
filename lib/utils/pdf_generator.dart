// lib/utils/pdf_generator.dart
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/models.dart';
import '../models/enums.dart';
import '../utils/date_formatters.dart';
import '../services/configuration_service.dart';

class PdfGenerator {
  static Future<Uint8List> generarAutorizacionDesembolso(
    Expense expense,
    AccountConfig accountConfig,
  ) async {
    final pdf = pw.Document();

    final String fechaGasto = DateFormatters.formatShortDate(expense.date);
    final String importeTotalFormateado = DateFormatters.formatCurrency(expense.amount);

    final bool esOfrenda = expense.categoryType == ExpenseCategoryType.ofrendaDeAyuno ||
                         (expense.categoryType == null && (expense.categoryName?.toLowerCase().contains('ofrenda de ayuno') ?? false));
    final bool esPresupuesto = expense.categoryType == ExpenseCategoryType.presupuesto ||
                             (expense.categoryType == null && (expense.categoryName?.toLowerCase().contains('presupuesto') ?? false));
    final bool esPropiedades = (expense.categoryType == ExpenseCategoryType.presupuesto && (expense.categoryName?.toLowerCase().contains('propiedades') ?? false)) ||
                               (expense.categoryType == null && (expense.categoryName?.toLowerCase().contains('propiedades') ?? false));

    final String nombreUnidadPrincipal = accountConfig.unitName ?? 'Unidad No Configurada';
    final String numeroUnidadPrincipal = accountConfig.unitNumber ?? 'N/A';
    final String nombreLiderPrincipal = accountConfig.bishopName ?? 'Obispo No Configurado';
    final String nombreSecretarioOConsejero = accountConfig.firstCounselorName ?? 'Consejero/Secretario No Configurado';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(vertical: 20, horizontal: 25),
        build: (pw.Context context) {
          const double lightBorder = 0.5;
          const PdfColor borderColor = PdfColors.black;
          const double labelFontSize = 8;
          const double valueFontSize = 10;
          const cellPadding = pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4);

          const double altoFilaSimple = 25.0;
          const double altoFilaMedia = 37.5;
          const double altoFilaDoble = 50.0;
          const double altoFilaTresLineas = 75.0;

          String pagadoAValue;
          int pagadoAMaxLines = 1;
          double pagadoAHeight = altoFilaMedia;

          if (esOfrenda) {
            pagadoAValue = expense.pagadoA ?? 'No especificado';
          } else {
            pagadoAValue = expense.pagadoA ?? 'No especificado';
          }

          if (expense.personaQueRecibio != null && expense.personaQueRecibio!.isNotEmpty) {
            pagadoAValue += "\n(Efectivo recibido por: ${expense.personaQueRecibio})";
            pagadoAMaxLines = 2;
            if (pagadoAHeight < altoFilaDoble) pagadoAHeight = altoFilaDoble;
          }
           if (pagadoAValue.length > 50 && !pagadoAValue.contains('\n') && pagadoAMaxLines < 2) {
             pagadoAMaxLines = 2;
             if (pagadoAHeight < altoFilaDoble) pagadoAHeight = altoFilaDoble;
           }

          List<String> referenceItems = [];
          if (expense.numeroReferencia != null && expense.numeroReferencia!.isNotEmpty) {
            referenceItems.add("Ref. Ext. Principal: ${expense.numeroReferencia}");
          }
          if (expense.numeroReferenciaAdicional != null && expense.numeroReferenciaAdicional!.isNotEmpty) {
            referenceItems.add("Ref. Ext. Adicional: ${expense.numeroReferenciaAdicional}");
          }

          String referenceValue = referenceItems.isNotEmpty ? referenceItems.join('\n') : 'No aplica';
          
          int actualMaxLinesForReference;
          double referenceCellHeight;

          if (referenceItems.isEmpty) { 
              referenceCellHeight = altoFilaMedia; 
              actualMaxLinesForReference = 1;
          } else if (referenceItems.length == 1) {
              referenceCellHeight = altoFilaDoble; 
              actualMaxLinesForReference = 2;     
          } else { 
              referenceCellHeight = altoFilaTresLineas; 
              actualMaxLinesForReference = 3;          
          }


          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text('Autorización de desembolso MLS', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 15),

              // 1. Info Unidad y Fecha
              pw.Table(
                border: pw.TableBorder.all(color: borderColor, width: lightBorder),
                columnWidths: const {
                  0: pw.FlexColumnWidth(4), 1: pw.FlexColumnWidth(2.5), 2: pw.FlexColumnWidth(2.5),
                },
                children: [
                  pw.TableRow(children: [
                    _buildTableCell('Nombre de la unidad', nombreUnidadPrincipal, labelFontSize, valueFontSize, cellPadding, altoFilaDoble, valueMaxLines: 2),
                    _buildTableCell('Número de la unidad', numeroUnidadPrincipal, labelFontSize, valueFontSize, cellPadding, altoFilaDoble, valueMaxLines: 1),
                    _buildTableCell('Fecha', fechaGasto, labelFontSize, valueFontSize, cellPadding, altoFilaDoble, valueMaxLines: 1),
                  ]),
                ],
              ),
              pw.SizedBox(height: 10),
              
              // 3. Pagado a / Recibido por / Firma
              pw.Table(
                border: pw.TableBorder.all(color: borderColor, width: lightBorder),
                columnWidths: const { 0: pw.FlexColumnWidth(7), 1: pw.FlexColumnWidth(3) },
                children: [
                  pw.TableRow(children: [
                    _buildTableCell(
                      'Pagado a (Persona/Comercio/Institución)',
                      pagadoAValue,
                      labelFontSize, valueFontSize, cellPadding,
                      pagadoAHeight,
                      valueMaxLines: pagadoAMaxLines,
                    ),
                    _buildTableCell('Firma del que recibe los fondos', '', labelFontSize, valueFontSize, cellPadding, pagadoAHeight, isSignature: true),
                  ]),
                ],
              ),
              pw.SizedBox(height: 10),

              // 4. MODIFICADO: Beneficiario Ofrenda y Firma (solo si es Ofrenda)
              if (esOfrenda) ...[
                pw.Table(
                  border: pw.TableBorder.all(color: borderColor, width: lightBorder),
                  columnWidths: const { 0: pw.FlexColumnWidth(7), 1: pw.FlexColumnWidth(3) },
                  children: [
                    pw.TableRow(children: [
                      _buildTableCell(
                        'Nombre del Beneficiario Principal de Ofrendas de Ayuno',
                        expense.beneficiarioOfrenda ?? 'No especificado', // Ya no necesita 'N/A' porque la sección entera es condicional
                        labelFontSize, valueFontSize, cellPadding, altoFilaMedia, valueMaxLines: 1),
                      _buildTableCell('Firma del beneficiario', '', labelFontSize, valueFontSize, cellPadding, altoFilaMedia, isSignature: true),
                    ]),
                  ],
                ),
                pw.SizedBox(height: 10),
              ],
              // Fin de la sección condicional para Beneficiario de Ofrenda

              // 5. Propósito del Gasto
              pw.Table(
                border: pw.TableBorder.all(color: borderColor, width: lightBorder),
                children: [
                  pw.TableRow(children: [
                    _buildTableCell('Propósito del gasto', expense.description, labelFontSize, valueFontSize, cellPadding, altoFilaTresLineas, valueMaxLines: 3),
                  ]),
                ],
              ),
              pw.SizedBox(height: 10),

              // 6. Categoría Específica
              pw.Table(
                border: pw.TableBorder.all(color: borderColor, width: lightBorder),
                children: [
                  pw.TableRow(children: [
                    _buildTableCell('Categoría Específica (Tipo - Detalle)', expense.categoryName ?? 'Sin categoría', labelFontSize, valueFontSize, cellPadding, altoFilaDoble, valueMaxLines: 2),
                  ]),
                ],
              ),
              pw.SizedBox(height: 10),
              
              // 7. Checkboxes
              pw.Table(
                border: pw.TableBorder.all(color: borderColor, width: lightBorder),
                columnWidths: const { 
                  0: pw.FlexColumnWidth(3), 
                  1: pw.FlexColumnWidth(3), 
                  2: pw.FlexColumnWidth(4) 
                }, 
                children: [
                  pw.TableRow(children: [
                    _buildCheckboxCell('Ofrendas de ayuno', esOfrenda, labelFontSize, cellPadding, altoFilaMedia),
                    _buildCheckboxCell('Presupuesto', esPresupuesto, labelFontSize, cellPadding, altoFilaMedia),
                    _buildCheckboxCell('Propiedades', esPropiedades, labelFontSize, cellPadding, altoFilaMedia),
                  ]),
                ],
              ),
              pw.SizedBox(height: 10),

              // 8. Desglose de Fondos (si aplica Múltiples Extracciones)
              if (expense.usesMultipleExtractions && (expense.amountFromPrimary != null || expense.amountFromAdditional != null)) ...[
                pw.Table(
                  border: pw.TableBorder.all(color: borderColor, width: lightBorder),
                  children: [
                    pw.TableRow(children: [
                      _buildTableCell(
                        'Desglose de Fondos (Múltiples Extracciones)',
                        "Ext. Principal: ${DateFormatters.formatCurrency(expense.amountFromPrimary ?? 0.0)}\n"
                        "Ext. Adicional: ${DateFormatters.formatCurrency(expense.amountFromAdditional ?? 0.0)}",
                        labelFontSize, valueFontSize, cellPadding, altoFilaDoble, valueMaxLines: 2),
                    ]),
                  ],
                ),
                pw.SizedBox(height: 10),
              ],

              // 9. Referencias de Extracción
              pw.Table(
                border: pw.TableBorder.all(color: borderColor, width: lightBorder),
                children: [
                  pw.TableRow(children: [
                    _buildTableCell(
                      'Referencias de Extracción',
                      referenceValue,
                      labelFontSize, valueFontSize, cellPadding, 
                      referenceCellHeight, 
                      valueMaxLines: actualMaxLinesForReference 
                    ),
                  ]),
                ],
              ),
              pw.SizedBox(height: 10),

              // 10. "Importe Total" y "Importe en letras" agrupados
              pw.Table( 
                border: pw.TableBorder.all(color: borderColor, width: lightBorder),
                children: [
                  pw.TableRow(children: [
                    _buildTableCell(
                        'Importe Total', 
                        importeTotalFormateado, 
                        labelFontSize, 
                        valueFontSize + 1, 
                        cellPadding, 
                        altoFilaMedia, 
                        isCurrency: true,
                        valueMaxLines: 1
                    ),
                  ]),
                ],
              ),
              pw.SizedBox(height: 1), 
              pw.Table( 
                border: pw.TableBorder.all(color: borderColor, width: lightBorder),
                children: [
                  pw.TableRow(children: [
                    _buildTableCell(
                        'Importe en letras', 
                        expense.importeEnLetras ?? 'No generado', 
                        labelFontSize, 
                        valueFontSize, 
                        cellPadding, 
                        altoFilaDoble, 
                        valueMaxLines: 2 
                    ),
                  ]),
                ],
              ),
              pw.SizedBox(height: 25),


              // 11. Firmas de Liderazgo
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(child: _buildPdfSignatureBlock('Firma y aclaración del líder de la unidad', nombreLiderPrincipal, labelFontSize, valueFontSize)),
                  pw.SizedBox(width: 30),
                  pw.Expanded(child: _buildPdfSignatureBlock('Firma y aclaración del líder secretario o consejero', nombreSecretarioOConsejero, labelFontSize, valueFontSize)),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Spacer(),
              pw.Center(
                child: pw.Text(
                  'Este documento debe archivarse firmado y junto con los comprobantes de respaldo del gasto, para las auditorías semestrales.',
                  style: pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }

  static pw.Widget _buildTableCell(
    String label, String value,
    double labelFontSize, double valueFontSize,
    pw.EdgeInsets padding, double height, {
    bool isCurrency = false,
    bool isSignature = false,
    int valueMaxLines = 1,
  }) {
    return pw.Container(
      padding: padding,
      height: height,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: isSignature ? pw.MainAxisAlignment.end : pw.MainAxisAlignment.start,
        children: [
          if (label.isNotEmpty)
            pw.Text(
              label,
              style: pw.TextStyle(fontSize: labelFontSize, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
            ),
          if (!isSignature && label.isNotEmpty) pw.SizedBox(height: 3),
          if (!isSignature)
            pw.Expanded(
              child: pw.Text(
                value,
                style: pw.TextStyle(
                  fontSize: valueFontSize,
                  fontWeight: isCurrency ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
                textAlign: pw.TextAlign.left,
                maxLines: valueMaxLines,
                overflow: pw.TextOverflow.clip,
              ),
            )
          else if (isSignature)
            pw.Expanded(child: pw.Container()),
        ],
      ),
    );
  }

  static pw.Widget _buildCheckboxCell(
    String label, bool checked,
    double fontSize, pw.EdgeInsets padding, double height,
  ) {
    return pw.Container(
      padding: padding,
      height: height,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.start,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 10, height: 10,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 0.5),
              color: checked ? PdfColors.black : PdfColors.white,
            ),
            child: checked ? pw.Center(child: pw.Text('X', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.white))) : null,
          ),
          pw.SizedBox(width: 4),
          pw.Expanded(
            child: pw.Text(label, style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.left),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfSignatureBlock(
    String label, String aclaracion,
    double labelFontSize, double valueFontSize,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          width: 150, height: 30,
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))),
        ),
        pw.SizedBox(height: 4),
        pw.Text(label, style: pw.TextStyle(fontSize: labelFontSize - 1, fontWeight: pw.FontWeight.normal, color: PdfColors.grey700), textAlign: pw.TextAlign.center),
        if (aclaracion.trim().isNotEmpty) ...[
          pw.SizedBox(height: 1),
          pw.Text(aclaracion, style: pw.TextStyle(fontSize: labelFontSize, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
        ],
      ],
    );
  }
}