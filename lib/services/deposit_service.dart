import '../database/db_helper.dart';

class DepositService {
  final DBHelper _dbHelper = DBHelper.instance;

  Future<int> createDeposit({
    required int extractionId, 
    required double amount, 
    required DateTime date, 
    required String comments, 
    required String reason
  }) async {
    try {
      final db = await _dbHelper.database;
      final depositData = {
        'extraction_id': extractionId,
        'amount': amount,
        'reason': reason,
        'comments': comments,
        'date': date.toIso8601String(),
      };
      
      final result = await db.insert('deposits', depositData);
      print("✅ Depósito insertado con ID: $result para extracción $extractionId");
      return result;
    } catch (e) {
      print("❌ Error insertando depósito: $e");
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getDepositsForExtraction(int extractionId) async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'deposits',
        where: 'extraction_id = ?',
        whereArgs: [extractionId],
        orderBy: 'date DESC',
      );
      return maps;
    } catch (e) {
      print("❌ Error obteniendo depósitos para extracción $extractionId: $e");
      return [];
    }
  }

  Future<double> getTotalDepositsForExtraction(int extractionId) async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> result = await db.rawQuery(
        'SELECT SUM(amount) as total FROM deposits WHERE extraction_id = ?',
        [extractionId],
      );
      var total = result.first['total'];
      return (total is num) ? total.toDouble() : 0.0;
    } catch (e) {
      print("❌ Error calculando total de depósitos: $e");
      return 0.0;
    }
  }

  Future<int> deleteDeposit(int id) async {
    try {
      final db = await _dbHelper.database;
      return await db.delete('deposits', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      print("❌ Error eliminando depósito ID $id: $e");
      return 0;
    }
  }
}