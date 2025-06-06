import '../database/db_helper.dart';
import '../models/models.dart';

class ExpenseService {
  final DBHelper _dbHelper = DBHelper.instance;

  Future<List<Expense>> getExpensesForExtraction(int extractionId) async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'expenses',
        where: 'extraction_id = ? OR additional_extraction_id = ?',
        whereArgs: [extractionId, extractionId],
        orderBy: 'date DESC',
      );
      return List.generate(maps.length, (i) => Expense.fromMap(maps[i]));
    } catch (e) {
      print("❌ Error obteniendo gastos para extracción $extractionId: $e");
      return [];
    }
  }

  Future<List<Expense>> getAllExpenses() async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'expenses',
        orderBy: 'date DESC',
      );
      return List.generate(maps.length, (i) => Expense.fromMap(maps[i]));
    } catch (e) {
      print("❌ Error obteniendo todos los gastos: $e");
      return [];
    }
  }

  Future<int> createExpense(Expense expense) async {
    try {
      final db = await _dbHelper.database;
      
      // Validar que las extracciones tengan saldo suficiente
      if (!await _validateExtractionBalances(expense)) {
        throw Exception('Saldo insuficiente en las extracciones seleccionadas');
      }
      
      final result = await db.insert('expenses', expense.toMap());
      print("✅ Gasto insertado con ID: $result");
      
      // Log adicional para gastos con múltiples extracciones
      if (expense.usesMultipleExtractions) {
        print("🔀 Gasto con múltiples extracciones creado:");
        print("   - Extracción principal: ${expense.extractionId} (${expense.amountFromPrimary} Gs.)");
        print("   - Extracción adicional: ${expense.additionalExtractionId} (${expense.amountFromAdditional} Gs.)");
      }
      
      return result;
    } catch (e) {
      print("❌ Error insertando gasto: $e");
      rethrow;
    }
  }

  Future<int> updateExpense(Expense expense) async {
    try {
      final db = await _dbHelper.database;
      if (expense.id == null) {
        throw ArgumentError('El ID del gasto no puede ser nulo');
      }
      
      // Validar balances antes de actualizar
      if (!await _validateExtractionBalances(expense, excludeExpenseId: expense.id)) {
        throw Exception('Saldo insuficiente en las extracciones seleccionadas');
      }
      
      final result = await db.update(
        'expenses',
        expense.toMap(),
        where: 'id = ?',
        whereArgs: [expense.id],
      );
      
      print("✅ Gasto ID ${expense.id} actualizado");
      return result;
    } catch (e) {
      print("❌ Error actualizando gasto ID ${expense.id}: $e");
      return 0;
    }
  }

  Future<int> deleteExpense(int id) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
      print("✅ Gasto ID $id eliminado");
      return result;
    } catch (e) {
      print("❌ Error eliminando gasto ID $id: $e");
      return 0;
    }
  }

  Future<double> getTotalExpensesForExtraction(int extractionId) async {
    try {
      final db = await _dbHelper.database;
      
      // Sumar gastos donde esta extracción es la principal
      final primaryResult = await db.rawQuery('''
        SELECT SUM(
          CASE 
            WHEN additional_extraction_id IS NULL THEN amount
            ELSE COALESCE(amount_from_primary, amount)
          END
        ) as total 
        FROM expenses 
        WHERE extraction_id = ?
      ''', [extractionId]);
      
      // Sumar gastos donde esta extracción es la adicional
      final additionalResult = await db.rawQuery('''
        SELECT SUM(COALESCE(amount_from_additional, 0)) as total 
        FROM expenses 
        WHERE additional_extraction_id = ?
      ''', [extractionId]);
      
      double primaryTotal = (primaryResult.first['total'] as num?)?.toDouble() ?? 0.0;
      double additionalTotal = (additionalResult.first['total'] as num?)?.toDouble() ?? 0.0;
      
      return primaryTotal + additionalTotal;
    } catch (e) {
      print("❌ Error calculando total de gastos: $e");
      return 0.0;
    }
  }

  Future<List<Expense>> getExpensesWithCategoryNames(int extractionId) async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT e.*, c.name as category_name, c.type as category_type
        FROM expenses e
        LEFT JOIN categories c ON e.category_id = c.id
        WHERE e.extraction_id = ? OR e.additional_extraction_id = ?
        ORDER BY e.date DESC
      ''', [extractionId, extractionId]);
      
      List<Expense> expenses = [];
      for (var map in maps) {
        Expense expense = Expense.fromMap(map);
        if (map['category_name'] != null) {
          expense.categoryName = '${map['category_type']} - ${map['category_name']}';
        } else {
          expense.categoryName = 'Sin categoría';
        }
        expenses.add(expense);
      }
      
      return expenses;
    } catch (e) {
      print("❌ Error obteniendo gastos con nombres de categorías: $e");
      return [];
    }
  }

  // Método para obtener un resumen de gastos por extracción
  Future<Map<String, dynamic>> getExtractionExpenseSummary(int extractionId) async {
    try {
      final db = await _dbHelper.database;
      
      // Gastos donde esta extracción es la principal
      final primaryExpensesResult = await db.rawQuery('''
        SELECT 
          COUNT(*) as count,
          SUM(CASE 
            WHEN additional_extraction_id IS NULL THEN amount
            ELSE COALESCE(amount_from_primary, amount)
          END) as total
        FROM expenses 
        WHERE extraction_id = ?
      ''', [extractionId]);
      
      // Gastos donde esta extracción es la adicional
      final additionalExpensesResult = await db.rawQuery('''
        SELECT 
          COUNT(*) as count,
          SUM(COALESCE(amount_from_additional, 0)) as total
        FROM expenses 
        WHERE additional_extraction_id = ?
      ''', [extractionId]);
      
      final primaryCount = (primaryExpensesResult.first['count'] as int?) ?? 0;
      final primaryTotal = (primaryExpensesResult.first['total'] as num?)?.toDouble() ?? 0.0;
      final additionalCount = (additionalExpensesResult.first['count'] as int?) ?? 0;
      final additionalTotal = (additionalExpensesResult.first['total'] as num?)?.toDouble() ?? 0.0;
      
      return {
        'primary_expenses_count': primaryCount,
        'primary_expenses_total': primaryTotal,
        'additional_expenses_count': additionalCount,
        'additional_expenses_total': additionalTotal,
        'total_expenses_count': primaryCount + additionalCount,
        'total_amount': primaryTotal + additionalTotal,
      };
    } catch (e) {
      print("❌ Error obteniendo resumen de gastos: $e");
      return {
        'primary_expenses_count': 0,
        'primary_expenses_total': 0.0,
        'additional_expenses_count': 0,
        'additional_expenses_total': 0.0,
        'total_expenses_count': 0,
        'total_amount': 0.0,
      };
    }
  }

  // Método para validar que las extracciones tengan saldo suficiente
  Future<bool> _validateExtractionBalances(Expense expense, {int? excludeExpenseId}) async {
    try {
      final db = await _dbHelper.database;
      
      // Obtener información de la extracción principal
      final primaryExtractionResult = await db.query(
        'extractions',
        where: 'id = ?',
        whereArgs: [expense.extractionId],
      );
      
      if (primaryExtractionResult.isEmpty) {
        throw Exception('Extracción principal no encontrada');
      }
      
      final primaryExtraction = Extraction.fromMap(primaryExtractionResult.first);
      double primarySpent = await _getTotalSpentForExtraction(expense.extractionId, excludeExpenseId: excludeExpenseId);
      double primaryAvailable = primaryExtraction.amount - primarySpent;
      
      // Si no usa múltiples extracciones, validar solo la principal
      if (!expense.usesMultipleExtractions) {
        return primaryAvailable >= expense.amount;
      }
      
      // Validar extracción principal
      final requiredFromPrimary = expense.amountFromPrimary ?? 0.0;
      if (primaryAvailable < requiredFromPrimary) {
        return false;
      }
      
      // Validar extracción adicional
      if (expense.additionalExtractionId != null) {
        final additionalExtractionResult = await db.query(
          'extractions',
          where: 'id = ?',
          whereArgs: [expense.additionalExtractionId],
        );
        
        if (additionalExtractionResult.isEmpty) {
          throw Exception('Extracción adicional no encontrada');
        }
        
        final additionalExtraction = Extraction.fromMap(additionalExtractionResult.first);
        double additionalSpent = await _getTotalSpentForExtraction(expense.additionalExtractionId!, excludeExpenseId: excludeExpenseId);
        double additionalAvailable = additionalExtraction.amount - additionalSpent;
        
        final requiredFromAdditional = expense.amountFromAdditional ?? 0.0;
        if (additionalAvailable < requiredFromAdditional) {
          return false;
        }
      }
      
      return true;
    } catch (e) {
      print("❌ Error validando balances de extracciones: $e");
      return false;
    }
  }

  // Método auxiliar para calcular total gastado de una extracción específica
  Future<double> _getTotalSpentForExtraction(int extractionId, {int? excludeExpenseId}) async {
    try {
      final db = await _dbHelper.database;
      
      List<dynamic> whereArgs = [extractionId, extractionId];
      
      if (excludeExpenseId != null) {
        whereArgs.add(excludeExpenseId);
      }
      
      // Sumar gastos donde esta extracción es la principal
      final primaryResult = await db.rawQuery('''
        SELECT SUM(
          CASE 
            WHEN additional_extraction_id IS NULL THEN amount
            ELSE COALESCE(amount_from_primary, amount)
          END
        ) as total 
        FROM expenses 
        WHERE extraction_id = ?${excludeExpenseId != null ? ' AND id != ?' : ''}
      ''', excludeExpenseId != null ? [extractionId, excludeExpenseId] : [extractionId]);
      
      // Sumar gastos donde esta extracción es la adicional
      final additionalResult = await db.rawQuery('''
        SELECT SUM(COALESCE(amount_from_additional, 0)) as total 
        FROM expenses 
        WHERE additional_extraction_id = ?${excludeExpenseId != null ? ' AND id != ?' : ''}
      ''', excludeExpenseId != null ? [extractionId, excludeExpenseId] : [extractionId]);
      
      double primaryTotal = (primaryResult.first['total'] as num?)?.toDouble() ?? 0.0;
      double additionalTotal = (additionalResult.first['total'] as num?)?.toDouble() ?? 0.0;
      
      return primaryTotal + additionalTotal;
    } catch (e) {
      print("❌ Error calculando total gastado para extracción $extractionId: $e");
      return 0.0;
    }
  }

  // Método para obtener todas las extracciones relacionadas con un gasto
  Future<List<Extraction>> getRelatedExtractions(Expense expense) async {
    try {
      final db = await _dbHelper.database;
      List<Extraction> extractions = [];
      
      // Obtener extracción principal
      final primaryResult = await db.query(
        'extractions',
        where: 'id = ?',
        whereArgs: [expense.extractionId],
      );
      
      if (primaryResult.isNotEmpty) {
        extractions.add(Extraction.fromMap(primaryResult.first));
      }
      
      // Obtener extracción adicional si existe
      if (expense.additionalExtractionId != null) {
        final additionalResult = await db.query(
          'extractions',
          where: 'id = ?',
          whereArgs: [expense.additionalExtractionId],
        );
        
        if (additionalResult.isNotEmpty) {
          extractions.add(Extraction.fromMap(additionalResult.first));
        }
      }
      
      return extractions;
    } catch (e) {
      print("❌ Error obteniendo extracciones relacionadas: $e");
      return [];
    }
  }

  // Método para obtener estadísticas de gastos con múltiples extracciones
  Future<Map<String, dynamic>> getMultipleExtractionStats() async {
    try {
      final db = await _dbHelper.database;
      
      final totalExpensesResult = await db.rawQuery('SELECT COUNT(*) as count FROM expenses');
      final multipleExtractionsResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM expenses WHERE additional_extraction_id IS NOT NULL'
      );
      
      final totalExpenses = (totalExpensesResult.first['count'] as int?) ?? 0;
      final multipleExtractionExpenses = (multipleExtractionsResult.first['count'] as int?) ?? 0;
      
      final percentage = totalExpenses > 0 ? (multipleExtractionExpenses / totalExpenses * 100) : 0.0;
      
      return {
        'total_expenses': totalExpenses,
        'multiple_extraction_expenses': multipleExtractionExpenses,
        'single_extraction_expenses': totalExpenses - multipleExtractionExpenses,
        'multiple_extraction_percentage': percentage,
      };
    } catch (e) {
      print("❌ Error obteniendo estadísticas de múltiples extracciones: $e");
      return {
        'total_expenses': 0,
        'multiple_extraction_expenses': 0,
        'single_extraction_expenses': 0,
        'multiple_extraction_percentage': 0.0,
      };
    }
  }
}