// lib/screens/debug/pdf_preview_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart'; // Para PdfPreview
import '../../models/models.dart';      // Para Expense
import '../../models/enums.dart';       // Para Enums si los usas en datos de muestra
import '../../services/configuration_service.dart'; // Para AccountConfig
import '../../utils/pdf_generator.dart';     // Para generar el PDF
import '../../utils/number_to_words_helper.dart'; // Para generar importe en letras

class PdfPreviewScreen extends StatefulWidget {
  const PdfPreviewScreen({Key? key}) : super(key: key);

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  Uint8List? _pdfBytes;
  bool _isLoading = false;
  Key _pdfPreviewKey = UniqueKey();

  late Expense _sampleExpense;
  late AccountConfig _sampleAccountConfig;

  @override
  void initState() {
    super.initState();
    _initializeSampleDataAndGeneratePdf();
  }

  void _initializeSampleDataAndGeneratePdf() {
    _sampleAccountConfig = AccountConfig(
      unitName: "Estaca Aurora Pasion",
      unitNumber: "7654321",
      bishopName: "Obispo Ricardo Solis",
      firstCounselorName: "Consejero Miguel Castro",
      secondCounselorName: "Consejero David Rios", 
      secretaryName: "Secretario Armando Paredes",
    );

    final double amountPresupuesto = 185750.0;
    _sampleExpense = Expense(
      id: 2024001,
      extractionId: 101,
      amount: amountPresupuesto,
      categoryId: 1, 
      categoryName: "Presupuesto - Materiales de Oficina y Limpieza General",
      categoryType: ExpenseCategoryType.presupuesto, // Ensure categoryType is provided
      description: "Adquisición de resmas de papel A4, bolígrafos varios colores, carpetas archivadoras, tóner compatible para impresora HL-2370DW, y productos de limpieza (lavandina, desinfectante, paños) para el mantenimiento semanal del centro de reuniones.",
      date: DateTime.now().subtract(const Duration(days: 2)),
      pagadoA: "Distribuidora Comercial \"El Progreso\" S.R.L.",
      personaQueRecibio: "Hermana Juana Díaz (Secretaria Auxiliar)",
      // nombreUnidad: "Comité de Mantenimiento de Edificios", // REMOVED THIS LINE
      importeEnLetras: NumberToWordsHelper.convertToWords(amountPresupuesto),
      numeroReferencia: "03-06/750000", 
      receiptUrls: [], 
    );

    _generatePdf(); 
  }

  Future<void> _generatePdf() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      print("Generando PDF para vista previa...");
      final bytes = await PdfGenerator.generarAutorizacionDesembolso(
        _sampleExpense, 
        _sampleAccountConfig, 
      );
      if (mounted) {
        setState(() {
          _pdfBytes = bytes;
          _pdfPreviewKey = UniqueKey(); 
          _isLoading = false;
        });
        print("PDF para vista previa generado exitosamente.");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _pdfBytes = null; 
        });
      }
      final errorMessage = 'Error generando PDF para vista previa: $e';
      print(errorMessage);
      if (mounted) { // Check mount status before showing SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vista Previa de Boleta PDF'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _generatePdf, 
            tooltip: 'Regenerar PDF',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Modifica 'pdf_generator.dart' o los datos de muestra aquí, guarda los cambios, y luego presiona 'Regenerar PDF' o usa Hot Reload/Restart.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.blueGrey),
            ),
          ),
          const Divider(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _pdfBytes != null
                    ? PdfPreview(
                        key: _pdfPreviewKey, 
                        build: (format) => _pdfBytes!,
                        canChangePageFormat: false, 
                        canChangeOrientation: false, 
                        allowPrinting: true, // Keep or remove as needed
                        allowSharing: true,  // Keep or remove as needed
                        // actions: const [], // Uncomment to remove default actions if desired
                        scrollViewDecoration: BoxDecoration(color: Colors.grey[200]), 
                        pdfPreviewPageDecoration: const BoxDecoration( 
                           color: Colors.white, 
                           boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(2,2))]
                        ),
                      )
                    : const Center(child: Text('No se pudo generar el PDF o no hay datos iniciales.')),
          ),
        ],
      ),
    );
  }
}