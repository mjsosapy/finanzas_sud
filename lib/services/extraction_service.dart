// lib/services/extraction_service.dart
import '../database/db_helper.dart';
import '../models/models.dart';
import '../constants/app_constants.dart'; // For Sqflite if used directly for counts
import 'package:sqflite/sqflite.dart';     // For Sqflite.firstIntValue

class ExtractionService {
  final DBHelper _dbHelper = DBHelper.instance;

  Future<List<Extraction>> getAllExtractions() async {
    return await _dbHelper.getExtractions();
  }

  Future<Extraction?> getExtractionById(int id) async {
    return await _dbHelper.getExtractionById(id);
  }

  Future<int> createExtraction(Extraction extraction) async {
    return await _dbHelper.insertExtraction(extraction);
  }

  Future<int> updateExtraction(Extraction extraction) async {
    return await _dbHelper.updateExtraction(extraction);
  }

  Future<int> deleteExtraction(int id) async {
    return await _dbHelper.deleteExtraction(id);
  }

  Future<double> getTotalDirectExpensesForExtraction(int extractionId) async {
    return await _dbHelper.getTotalSpentForExtraction(extractionId);
  }
  
  Future<double> getTotalAdvancedAmountForExtraction(int extractionId) async {
    return await _dbHelper.getTotalAdvancedAmountForExtraction(extractionId);
  }

  Future<bool> hasAvailableBalance(int extractionId, double requiredAmount) async {
    final extraction = await getExtractionById(extractionId); 
    if (extraction == null) return false;
    return extraction.availableBalance >= requiredAmount; 
  }

  Future<double> getAvailableBalance(int extractionId) async {
    final extraction = await getExtractionById(extractionId); 
    if (extraction == null) return 0.0;
    return extraction.availableBalance; 
  }

  Future<List<Extraction>> getExtractionsWithBalance({double? minimumBalance}) async {
    try {
      final allExtractions = await getAllExtractions(); 
      return allExtractions.where((extraction) {
        return minimumBalance == null ? extraction.availableBalance > 0 : extraction.availableBalance >= minimumBalance;
      }).toList();
    } catch (e) {
      print("❌ Error obteniendo extracciones con saldo: $e");
      return [];
    }
  }
  
  Future<Map<String, dynamic>> getExtractionFinancialSummary(int extractionId) async {
    try {
      final extraction = await getExtractionById(extractionId); 
      if (extraction == null) {
        throw Exception('Extracción no encontrada con ID: $extractionId');
      }

      final db = await _dbHelper.database;
      
      final depositsResult = await db.rawQuery('''
        SELECT COUNT(*) as count, SUM(amount) as total
        FROM ${AppConstants.depositsTable} WHERE extraction_id = ?
      ''', [extractionId]);
      
      final depositsCount = (depositsResult.first['count'] as int?) ?? 0;
      final depositsTotal = (depositsResult.first['total'] as num?)?.toDouble() ?? 0.0;

      final directExpensesQuery = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${AppConstants.expensesTable} WHERE (extraction_id = ? OR additional_extraction_id = ?) AND ${AppConstants.colFundAdvanceId} IS NULL',
        [extractionId, extractionId]
      );
      final directExpensesCount = Sqflite.firstIntValue(directExpensesQuery) ?? 0;
      
      return {
        'extraction_object': extraction, 
        'original_amount': extraction.amount,
        'total_direct_expenses_amount': extraction.spentAmount, 
        'direct_expenses_count': directExpensesCount,
        'total_advanced_amount': extraction.totalAdvancedAmount,
        'deposits_count': depositsCount,
        'deposits_total': depositsTotal,
        'final_available_balance': extraction.availableBalance, 
        'utilization_percentage': extraction.amount > 0 
            ? ((extraction.spentAmount + extraction.totalAdvancedAmount + depositsTotal) / extraction.amount * 100) 
            : 0.0,
      };
    } catch (e) {
      print("❌ Error obteniendo resumen financiero de extracción $extractionId: $e");
      // Return a map with default/error values to prevent null issues in UI
      return {
        'extraction_object': null,
        'original_amount': 0.0,
        'total_direct_expenses_amount': 0.0,
        'direct_expenses_count': 0,
        'total_advanced_amount': 0.0,
        'deposits_count': 0,
        'deposits_total': 0.0,
        'final_available_balance': 0.0,
        'utilization_percentage': 0.0,
        'error': e.toString(),
      };
    }
  }

  // Other methods like getGeneralExtractionStats, canDeleteExtraction, getBestExtractionOptionsForAmount
  // can be added or reviewed here as needed, considering the new data structure.
  // For example, canDeleteExtraction should also check for related fund_advances.
  Future<Map<String, dynamic>> canDeleteExtraction(int extractionId) async {
    try {
      final db = await _dbHelper.database;
      
      final primaryExpensesResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${AppConstants.expensesTable} WHERE extraction_id = ?', [extractionId]
      );
      final additionalExpensesResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${AppConstants.expensesTable} WHERE additional_extraction_id = ?', [extractionId]
      );
      final depositsResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${AppConstants.depositsTable} WHERE extraction_id = ?', [extractionId]
      );
      final advancesResult = await db.rawQuery( // Check for related fund advances
        'SELECT COUNT(*) as count FROM ${AppConstants.fundAdvancesTable} WHERE extraction_id = ?', [extractionId]
      );
      
      final primaryExpensesCount = Sqflite.firstIntValue(primaryExpensesResult) ?? 0;
      final additionalExpensesCount = Sqflite.firstIntValue(additionalExpensesResult) ?? 0;
      final depositsCount = Sqflite.firstIntValue(depositsResult) ?? 0;
      final advancesCount = Sqflite.firstIntValue(advancesResult) ?? 0; // Get advances count
      
      final totalRelatedRecords = primaryExpensesCount + additionalExpensesCount + depositsCount + advancesCount; // Add advances to total
      final canDelete = totalRelatedRecords == 0;
      
      String warningMsg = 'Esta extracción tiene $totalRelatedRecords registro(s) asociado(s) (gastos, depósitos o entregas de dinero). Al eliminarla se eliminarán todos estos registros relacionados y sus archivos.';
      
      return {
        'can_delete': canDelete,
        'expenses_count': primaryExpensesCount + additionalExpensesCount, // Combined for simplicity
        'deposits_count': depositsCount,
        'advances_count': advancesCount, // Return advances count
        'total_related_records': totalRelatedRecords,
        'warning_message': canDelete ? null : warningMsg,
      };
    } catch (e) {
      print("❌ Error verificando si se puede eliminar extracción $extractionId: $e");
      return {
        'can_delete': false,
        'expenses_count': 0,
        'deposits_count': 0,
        'advances_count': 0,
        'total_related_records': 0,
        'warning_message': 'Error verificando la extracción. $e',
      };
    }
  }
}