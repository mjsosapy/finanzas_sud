import '../database/db_helper.dart';
import '../models/models.dart';
import '../models/enums.dart';

class CategoryService {
  final DBHelper _dbHelper = DBHelper.instance;

  Future<List<Category>> getAllCategories() async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'categories', 
        orderBy: 'type ASC, name ASC'
      );
      return List.generate(maps.length, (i) => Category.fromMap(maps[i]));
    } catch (e) {
      print("❌ Error obteniendo categorías: $e");
      return [];
    }
  }

  Future<List<Category>> getCategoriesByType(ExpenseCategoryType type) async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'categories',
        where: 'type = ?',
        whereArgs: [type.name],
        orderBy: 'name ASC'
      );
      return List.generate(maps.length, (i) => Category.fromMap(maps[i]));
    } catch (e) {
      print("❌ Error obteniendo categorías por tipo: $e");
      return [];
    }
  }

  Future<int> createCategory(Category category) async {
    try {
      final db = await _dbHelper.database;
      return await db.insert('categories', category.toMap());
    } catch (e) {
      print("❌ Error creando categoría: $e");
      return -1;
    }
  }

  Future<int> updateCategory(Category category) async {
    try {
      final db = await _dbHelper.database;
      if (category.id == null) {
        throw ArgumentError('El ID de la categoría no puede ser nulo');
      }
      return await db.update(
        'categories',
        category.toMap(),
        where: 'id = ?',
        whereArgs: [category.id],
      );
    } catch (e) {
      print("❌ Error actualizando categoría: $e");
      return 0;
    }
  }

  Future<int> deleteCategory(int id) async {
    try {
      final db = await _dbHelper.database;
      return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      print("❌ Error eliminando categoría: $e");
      return 0;
    }
  }

  Future<Map<ExpenseCategoryType, List<Category>>> getCategoriesGroupedByType() async {
    final categories = await getAllCategories();
    Map<ExpenseCategoryType, List<Category>> grouped = {
      for (var type in ExpenseCategoryType.values) type: []
    };
    
    for (var category in categories) {
      grouped[category.type]?.add(category);
    }
    
    return grouped;
  }
}