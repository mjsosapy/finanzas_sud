import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

class PdfStorageService {
  static const String _pdfFolderName = 'expense_pdfs';

  /// Guarda un PDF localmente y retorna la ruta del archivo
  static Future<String> savePdfLocally(Uint8List pdfBytes, String fileName) async {
    try {
      print('📄 Guardando PDF localmente: $fileName');
      
      final appDir = await getApplicationDocumentsDirectory();
      final pdfDir = Directory('${appDir.path}/$_pdfFolderName');
      
      if (!await pdfDir.exists()) {
        await pdfDir.create(recursive: true);
        print('📁 Directorio de PDFs creado: ${pdfDir.path}');
      }

      final fileName_ = fileName.endsWith('.pdf') ? fileName : '$fileName.pdf';
      final filePath = '${pdfDir.path}/$fileName_';
      
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);
      
      print('✅ PDF guardado exitosamente en: $filePath');
      return filePath;
    } catch (e) {
      print('❌ Error guardando PDF localmente: $e');
      rethrow;
    }
  }

  /// Verifica si un PDF existe localmente
  static Future<bool> pdfExists(String fileName) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName_ = fileName.endsWith('.pdf') ? fileName : '$fileName.pdf';
      final filePath = '${appDir.path}/$_pdfFolderName/$fileName_';
      
      return await File(filePath).exists();
    } catch (e) {
      print('❌ Error verificando existencia de PDF: $e');
      return false;
    }
  }

  /// Obtiene la ruta completa de un PDF
  static Future<String> getPdfPath(String fileName) async {
    final appDir = await getApplicationDocumentsDirectory();
    final fileName_ = fileName.endsWith('.pdf') ? fileName : '$fileName.pdf';
    return '${appDir.path}/$_pdfFolderName/$fileName_';
  }

  /// Muestra un PDF desde el almacenamiento local
  static Future<void> showLocalPdf(String fileName) async {
    try {
      final filePath = await getPdfPath(fileName);
      final file = File(filePath);
      
      if (!await file.exists()) {
        throw Exception('El archivo PDF no existe: $filePath');
      }

      final pdfBytes = await file.readAsBytes();
      
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: fileName,
      );
      
      print('✅ PDF mostrado desde archivo local: $filePath');
    } catch (e) {
      print('❌ Error mostrando PDF local: $e');
      rethrow;
    }
  }

  /// Elimina un PDF del almacenamiento local
  static Future<bool> deletePdf(String fileName) async {
    try {
      final filePath = await getPdfPath(fileName);
      final file = File(filePath);
      
      if (await file.exists()) {
        await file.delete();
        print('🗑️ PDF eliminado: $filePath');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error eliminando PDF: $e');
      return false;
    }
  }

  /// Obtiene el tamaño de un PDF en MB
  static Future<double> getPdfSizeMB(String fileName) async {
    try {
      final filePath = await getPdfPath(fileName);
      final file = File(filePath);
      
      if (await file.exists()) {
        final bytes = await file.length();
        return bytes / (1024 * 1024);
      }
      return 0.0;
    } catch (e) {
      print('❌ Error obteniendo tamaño de PDF: $e');
      return 0.0;
    }
  }

  /// Genera el nombre del archivo PDF para un gasto
  static String generatePdfFileName(int expenseId) {
    return 'autorizacion_desembolso_$expenseId.pdf';
  }

  /// Limpia PDFs antiguos (opcional, para mantenimiento)
  static Future<void> cleanOldPdfs({int daysOld = 90}) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final pdfDir = Directory('${appDir.path}/$_pdfFolderName');
      
      if (!await pdfDir.exists()) return;

      final now = DateTime.now();
      final cutoffDate = now.subtract(Duration(days: daysOld));
      
      await for (final entity in pdfDir.list()) {
        if (entity is File && entity.path.endsWith('.pdf')) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoffDate)) {
            await entity.delete();
            print('🗑️ PDF antiguo eliminado: ${entity.path}');
          }
        }
      }
    } catch (e) {
      print('❌ Error limpiando PDFs antiguos: $e');
    }
  }
}