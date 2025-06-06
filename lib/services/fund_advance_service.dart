// lib/services/fund_advance_service.dart
import '../database/db_helper.dart';
import '../models/models.dart'; // For FundAdvance, Extraction
// REMOVED: import '../services/extraction_service.dart'; // Not directly used here
import '../utils/date_formatters.dart'; // ADDED THIS IMPORT

class FundAdvanceService {
  final DBHelper _dbHelper = DBHelper.instance;

  Future<int> createFundAdvance(FundAdvance advance, Extraction sourceExtraction) async {
    if (advance.amount <= 0) {
      throw ArgumentError('El monto del adelanto debe ser mayor a cero.');
    }
    if (advance.memberName.trim().isEmpty) {
      throw ArgumentError('El nombre del miembro es obligatorio.');
    }
    // Ensure sourceExtraction.availableBalance is up-to-date if not passed fresh
    if (advance.amount > sourceExtraction.availableBalance) {
       throw ArgumentError('El monto del adelanto excede el saldo disponible de la extracción (${DateFormatters.formatCurrency(sourceExtraction.availableBalance)}).');
    }
    
    return await _dbHelper.insertFundAdvance(advance);
  }

  Future<List<FundAdvance>> getFundAdvancesForExtraction(int extractionId) async {
    final advances = await _dbHelper.getFundAdvancesForExtraction(extractionId);
    // TODO: Future enhancement: Populate advance.amountReconciled
    // This would involve querying the expenses table for expenses linked to each advance.id
    // Example:
    // for (var advance in advances) {
    //   final reconciled = await getAmountReconciledForAdvance(advance.id!);
    //   advance.amountReconciled = reconciled;
    // }
    return advances;
  }
  
  Future<double> getTotalAdvancedForExtraction(int extractionId) async {
    return await _dbHelper.getTotalAdvancedAmountForExtraction(extractionId);
  }

  // Example method for future enhancement (not fully implemented here)
  // Future<double> getAmountReconciledForAdvance(int fundAdvanceId) async {
  //   final db = await _dbHelper.database;
  //   final result = await db.rawQuery(
  //     'SELECT SUM(amount) as total FROM ${AppConstants.expensesTable} WHERE ${AppConstants.colFundAdvanceId} = ?',
  //     [fundAdvanceId],
  //   );
  //   var total = result.first['total'];
  //   return (total is num) ? total.toDouble() : 0.0;
  // }

  // TODO: Add methods for updateFundAdvance (e.g., to change status based on reconciliation)
  // TODO: Add method for deleteFundAdvance (and what happens to linked expenses, or if it's allowed)
}