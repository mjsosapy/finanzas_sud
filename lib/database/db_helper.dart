import 'package:flutter/foundation.dart' hide Category;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/models.dart';
import '../models/enums.dart';
import '../constants/app_constants.dart';

class DBHelper {
  static Database? _database;

  DBHelper._privateConstructor();
  static final DBHelper instance = DBHelper._privateConstructor();

  Future<Database> get database async {
    try {
      if (_database != null) return _database!;
      _database = await _initDB();
      return _database!;
    } catch (e) {
      debugPrint("❌ Error accediendo a la base de datos: $e");
      await deleteAppDatabase(); // Attempt to clean up on severe error
      _database = await _initDB(); // Re-initialize
      return _database!;
    }
  }

  Future<Database> _initDB() async {
    try {
      String path = p.join(await getDatabasesPath(), AppConstants.databaseName);
      debugPrint("🔧 Inicializando base de datos en: $path");
      
      return await openDatabase(
        path,
        version: AppConstants.databaseVersion, // Should be 6
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onConfigure: _onConfigure,
      );
    } catch (e) {
      debugPrint("❌ Error inicializando base de datos: $e");
      rethrow;
    }
  }

  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
    debugPrint("🔩 Foreign keys PRAGMA ON.");
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint("🔄 Actualizando base de datos de v$oldVersion a v$newVersion");
    
    if (oldVersion < 2) {
      debugPrint("🆕 (v2) Agregando columna numero_referencia a tabla expenses...");
      await db.execute('ALTER TABLE ${AppConstants.expensesTable} ADD COLUMN numero_referencia TEXT;');
      debugPrint("✅ (v2) Columna numero_referencia agregada exitosamente");
    }
    
    if (oldVersion < 3) {
      debugPrint("🆕 (v3) Creando tabla de depósitos...");
      await db.execute('''
        CREATE TABLE ${AppConstants.depositsTable}(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          extraction_id INTEGER NOT NULL,
          amount REAL NOT NULL,
          reason TEXT NOT NULL,
          comments TEXT DEFAULT '',
          date TEXT NOT NULL,
          FOREIGN KEY (extraction_id) REFERENCES ${AppConstants.extractionsTable}(id) ON DELETE CASCADE
        )
      ''');
      debugPrint("✅ (v3) Tabla ${AppConstants.depositsTable} creada exitosamente");
    }

    if (oldVersion < 4) {
      debugPrint("🆕 (v4) Agregando columnas para múltiples extracciones...");
      await db.execute('ALTER TABLE ${AppConstants.expensesTable} ADD COLUMN additional_extraction_id INTEGER;');
      await db.execute('ALTER TABLE ${AppConstants.expensesTable} ADD COLUMN amount_from_primary REAL;');
      await db.execute('ALTER TABLE ${AppConstants.expensesTable} ADD COLUMN amount_from_additional REAL;');
      await db.execute('ALTER TABLE ${AppConstants.expensesTable} ADD COLUMN numero_referencia_adicional TEXT;');
      debugPrint("✅ (v4) Columnas para múltiples extracciones agregadas exitosamente");
    }

    if (oldVersion < 5) {
      debugPrint("🆕 (v5) Modificando expenses para múltiples URLs de recibos...");
      try {
          await db.execute('ALTER TABLE ${AppConstants.expensesTable} ADD COLUMN receipt_urls TEXT;');
          debugPrint("✅ (v5) Columna receipt_urls (TEXT) agregada a expenses");
      } catch (e) {
          debugPrint("⚠️ (v5) Error agregando columna receipt_urls (quizás ya existe): $e");
      }
    }

    if (oldVersion < 6) {
      debugPrint("🆕 (v6) Creando tabla ${AppConstants.fundAdvancesTable} y actualizando ${AppConstants.expensesTable}...");
      await db.execute('''
        CREATE TABLE ${AppConstants.fundAdvancesTable}(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          extraction_id INTEGER NOT NULL,
          member_name TEXT NOT NULL,
          amount REAL NOT NULL,
          date TEXT NOT NULL,
          purpose_type TEXT NOT NULL, 
          reason TEXT,
          status TEXT NOT NULL DEFAULT 'PENDIENTE',
          comments TEXT,
          FOREIGN KEY (extraction_id) REFERENCES ${AppConstants.extractionsTable}(id) ON DELETE CASCADE
        )
      ''');
      debugPrint("✅ (v6) Tabla ${AppConstants.fundAdvancesTable} creada exitosamente");

      try {
        // Attempt to add with FK, though older SQLite versions might not support ADD CONSTRAINT on ALTER TABLE
        await db.execute('ALTER TABLE ${AppConstants.expensesTable} ADD COLUMN ${AppConstants.colFundAdvanceId} INTEGER REFERENCES ${AppConstants.fundAdvancesTable}(id) ON DELETE SET NULL;');
        debugPrint("✅ (v6) Columna ${AppConstants.colFundAdvanceId} con FK agregada a ${AppConstants.expensesTable}");
      } catch (e) {
         debugPrint("⚠️ (v6) Error agregando columna ${AppConstants.colFundAdvanceId} con FK a ${AppConstants.expensesTable}: $e. Intentando sin FK explícita en ALTER.");
         try {
            await db.execute('ALTER TABLE ${AppConstants.expensesTable} ADD COLUMN ${AppConstants.colFundAdvanceId} INTEGER;');
            debugPrint("✅ (v6) Columna ${AppConstants.colFundAdvanceId} (sin FK explícita en ALTER) agregada a ${AppConstants.expensesTable}.");
         } catch (e2) {
            debugPrint("❌ (v6) Fallo también al agregar ${AppConstants.colFundAdvanceId} sin FK: $e2");
         }
      }
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    debugPrint("🏗️ Creando tablas de base de datos versión $version...");
    
    await db.execute('''
      CREATE TABLE ${AppConstants.extractionsTable}(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        reason TEXT NOT NULL,
        comments TEXT DEFAULT '',
        date TEXT NOT NULL,
        extraction_code TEXT
      )
    ''');
    debugPrint("✅ Tabla ${AppConstants.extractionsTable} creada");

    await db.execute('''
      CREATE TABLE ${AppConstants.categoriesTable}(
        ${AppConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${AppConstants.colName} TEXT NOT NULL, 
        ${AppConstants.colType} TEXT NOT NULL DEFAULT 'presupuesto',   
        UNIQUE(${AppConstants.colName}, ${AppConstants.colType}) 
      )
    ''');
    debugPrint("✅ Tabla ${AppConstants.categoriesTable} creada");
    
    await db.execute('''
      CREATE TABLE ${AppConstants.fundAdvancesTable}(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        extraction_id INTEGER NOT NULL,
        member_name TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        purpose_type TEXT NOT NULL, 
        reason TEXT,
        status TEXT NOT NULL DEFAULT 'PENDIENTE',
        comments TEXT,
        FOREIGN KEY (extraction_id) REFERENCES ${AppConstants.extractionsTable}(id) ON DELETE CASCADE
      )
    ''');
    debugPrint("✅ Tabla ${AppConstants.fundAdvancesTable} creada");
    
    await db.execute('''
      CREATE TABLE ${AppConstants.expensesTable}(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        extraction_id INTEGER NOT NULL,
        ${AppConstants.colFundAdvanceId} INTEGER, 
        amount REAL NOT NULL,
        ${AppConstants.colCategoryId} INTEGER,          
        description TEXT NOT NULL,
        date TEXT NOT NULL,
        receipt_urls TEXT,
        additional_extraction_id INTEGER,
        amount_from_primary REAL,
        amount_from_additional REAL,
        persona_que_recibio TEXT,
        pagado_a TEXT,
        nombre_unidad TEXT, 
        beneficiario_ofrenda TEXT,
        importe_en_letras TEXT,
        numero_referencia TEXT,
        numero_referencia_adicional TEXT,
        FOREIGN KEY (extraction_id) REFERENCES ${AppConstants.extractionsTable}(id) ON DELETE CASCADE,
        FOREIGN KEY (additional_extraction_id) REFERENCES ${AppConstants.extractionsTable}(id) ON DELETE CASCADE,
        FOREIGN KEY (${AppConstants.colCategoryId}) REFERENCES ${AppConstants.categoriesTable}(${AppConstants.colId}) ON DELETE SET NULL,
        FOREIGN KEY (${AppConstants.colFundAdvanceId}) REFERENCES ${AppConstants.fundAdvancesTable}(id) ON DELETE SET NULL
      )
    ''');
    debugPrint("✅ Tabla ${AppConstants.expensesTable} creada con ${AppConstants.colFundAdvanceId}");

    await db.execute('''
      CREATE TABLE ${AppConstants.depositsTable}(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        extraction_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        reason TEXT NOT NULL,
        comments TEXT DEFAULT '',
        date TEXT NOT NULL,
        FOREIGN KEY (extraction_id) REFERENCES ${AppConstants.extractionsTable}(id) ON DELETE CASCADE
      )
    ''');
    debugPrint("✅ Tabla ${AppConstants.depositsTable} creada");
    
    await _insertDefaultCategories(db);
    
    debugPrint("🎉 Todas las tablas creadas exitosamente para la versión $version");
  }

  Future<void> _insertDefaultCategories(Database db) async {
    try {
      debugPrint("📝 Insertando categorías por defecto...");
      
      List<String> presupuestoCategories = [
        'Alimentos', 'Transporte', 'Materiales de Oficina', 'Mantenimiento',
        'Servicios Básicos', 'Medicamentos', 'Educación', 'Actividades', 'Otros Presupuesto'
      ];

      for (String categoryName in presupuestoCategories) {
        await db.insert(AppConstants.categoriesTable, {
          AppConstants.colName: categoryName,
          AppConstants.colType: ExpenseCategoryType.presupuesto.name,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      List<String> ofrendaCategories = [
        'Ayuda Humanitaria', 'Apoyo a Familias', 'Donativo Misionero',
        'Programa Social', 'Emergencias', 'Otros Ofrenda'
      ];

      for (String categoryName in ofrendaCategories) {
        await db.insert(AppConstants.categoriesTable, {
          AppConstants.colName: categoryName,
          AppConstants.colType: ExpenseCategoryType.ofrendaDeAyuno.name,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      debugPrint("✅ Categorías por defecto insertadas");
    } catch (e) {
      debugPrint("⚠️ Error insertando categorías por defecto: $e");
    }
  }
  
  Future<void> debugDatabaseAndReset() async {
    try {
      debugPrint("🔍 === DEBUG DATABASE ===");
      final db = await database; 
      debugPrint("✅ Base de datos conectada exitosamente (Versión: ${await db.getVersion()})");
      
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_metadata'");
      debugPrint("📋 Tablas de la aplicación: ${tables.map((t) => t['name']).toList()}");
      
      for (var table in tables) {
        final tableName = table['name'] as String;
        final columns = await db.rawQuery("PRAGMA table_info($tableName)");
        debugPrint("📝 Columnas en $tableName: ${columns.map((c) => '${c['name']}(${c['type']})').toList()}");
        final foreignKeys = await db.rawQuery("PRAGMA foreign_key_list($tableName)");
        if (foreignKeys.isNotEmpty) {
             debugPrint("🔑 Foreign Keys en $tableName: ${foreignKeys.map((fk) => 'from ${fk['from']} to ${fk['table']}(${fk['to']}) ON DELETE ${fk['on_delete']}').toList()}");
        }
      }
      
      final extractionsCount = Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM ${AppConstants.extractionsTable}"));
      final categoriesCount = Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM ${AppConstants.categoriesTable}"));
      final expensesCount = Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM ${AppConstants.expensesTable}"));
      final depositsCount = Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM ${AppConstants.depositsTable}"));
      final advancesCount = Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM ${AppConstants.fundAdvancesTable}"));
      
      debugPrint("📊 Registros - Extracciones: $extractionsCount, Categorías: $categoriesCount, Gastos: $expensesCount, Depósitos: $depositsCount, Adelantos: $advancesCount");
      
    } catch (e) {
      debugPrint("❌ Error en debugDatabaseAndReset: $e");
    }
  }

  Future<void> checkForNullData() async {
    try {
      final db = await database;
      
      final nullExtractions = await db.rawQuery(
        "SELECT * FROM ${AppConstants.extractionsTable} WHERE amount IS NULL OR reason IS NULL OR date IS NULL LIMIT 5"
      );
      if (nullExtractions.isNotEmpty) {
        debugPrint("⚠️ ADVERTENCIA: Extracciones con datos nulos: $nullExtractions");
      }
    } catch (e) {
      debugPrint("❌ Error verificando datos nulos: $e");
    }
  }

  Future<int> insertExtraction(Extraction extraction) async {
    try {
      final db = await database;
      final result = await db.insert(AppConstants.extractionsTable, extraction.toMap(), 
        conflictAlgorithm: ConflictAlgorithm.replace);
      debugPrint("✅ Extracción insertada con ID: $result");
      return result;
    } catch (e) {
      debugPrint("❌ Error insertando extracción: $e");
      rethrow;
    }
  }

  Future<List<Extraction>> getExtractions() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(AppConstants.extractionsTable, orderBy: 'date DESC');
      List<Extraction> extractions = [];
      for (var map in maps) {
          Extraction extraction = Extraction.fromMap(map);
          if (extraction.id != null) {
              extraction.spentAmount = await getTotalSpentForExtraction(extraction.id!);
              extraction.totalAdvancedAmount = await getTotalAdvancedAmountForExtraction(extraction.id!);
          }
          extractions.add(extraction);
      }
      return extractions;
    } catch (e) {
      debugPrint("❌ Error obteniendo extracciones: $e");
      return [];
    }
  }
  
  Future<Extraction?> getExtractionById(int id) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(AppConstants.extractionsTable, 
        where: 'id = ?', whereArgs: [id]);
      if (maps.isNotEmpty) {
        Extraction extraction = Extraction.fromMap(maps.first);
        extraction.spentAmount = await getTotalSpentForExtraction(id);
        extraction.totalAdvancedAmount = await getTotalAdvancedAmountForExtraction(id);
        return extraction;
      }
      return null;
    } catch (e) {
      debugPrint("❌ Error obteniendo extracción por ID $id: $e");
      return null;
    }
  }

  Future<int> updateExtraction(Extraction extraction) async {
     try {
      final db = await database;
      if (extraction.id == null) {
        throw ArgumentError('El ID de la extracción no puede ser nulo para la operación de actualización.');
      }
      final result = await db.update(
        AppConstants.extractionsTable,
        extraction.toMap(),
        where: 'id = ?',
        whereArgs: [extraction.id],
      );
      debugPrint("✅ Extracción ID ${extraction.id} actualizada");
      return result;
    } catch (e) {
      debugPrint("❌ Error actualizando extracción ID ${extraction.id}: $e");
      return 0;
    }
  }

  Future<int> deleteExtraction(int id) async {
    try {
      final db = await database;
      final result = await db.delete(AppConstants.extractionsTable, where: 'id = ?', whereArgs: [id]);
      debugPrint("✅ Extracción ID $id eliminada (registros relacionados afectados por CASCADE)");
      return result;
    } catch (e) {
      debugPrint("❌ Error eliminando extracción ID $id: $e");
      return 0;
    }
  }

  Future<double> getTotalSpentForExtraction(int extractionId) async {
    try {
      final db = await database;
      
      final primaryResult = await db.rawQuery('''
        SELECT SUM(
          CASE 
            WHEN additional_extraction_id IS NULL THEN amount
            ELSE COALESCE(amount_from_primary, amount)
          END
        ) as total 
        FROM ${AppConstants.expensesTable} 
        WHERE extraction_id = ? AND ${AppConstants.colFundAdvanceId} IS NULL 
      ''', [extractionId]);
      
      final additionalResult = await db.rawQuery('''
        SELECT SUM(COALESCE(amount_from_additional, 0)) as total 
        FROM ${AppConstants.expensesTable} 
        WHERE additional_extraction_id = ? AND ${AppConstants.colFundAdvanceId} IS NULL
      ''', [extractionId]);
      
      double primaryTotal = (primaryResult.first['total'] as num?)?.toDouble() ?? 0.0;
      double additionalTotal = (additionalResult.first['total'] as num?)?.toDouble() ?? 0.0;
      double totalDirectSpent = primaryTotal + additionalTotal;
      
      return totalDirectSpent;
    } catch (e) {
      debugPrint("❌ Error calculando total gastado directamente para extracción $extractionId: $e");
      return 0.0;
    }
  }
  
  Future<double> getTotalAdvancedAmountForExtraction(int extractionId) async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT SUM(amount) as total FROM ${AppConstants.fundAdvancesTable} WHERE extraction_id = ?',
        [extractionId],
      );
      var total = result.first['total'];
      return (total is num) ? total.toDouble() : 0.0;
    } catch (e) {
      debugPrint("❌ Error calculando total de adelantos para extracción $extractionId: $e");
      return 0.0;
    }
  }

  Future<void> deleteAppDatabase() async {
    try {
      String path = p.join(await getDatabasesPath(), AppConstants.databaseName);
      await deleteDatabase(path);
      _database = null; 
      debugPrint("🗑️ Base de datos eliminada exitosamente.");
    } catch (e) {
      debugPrint("❌ Error eliminando base de datos: $e");
    }
  }

  Future<int> insertExpense(Expense expense) async {
    try {
      final db = await database;
      final result = await db.insert(AppConstants.expensesTable, expense.toMap(), 
        conflictAlgorithm: ConflictAlgorithm.replace);
      debugPrint("✅ Gasto insertado con ID: $result. FundAdvanceID: ${expense.fundAdvanceId}");
      return result;
    } catch (e) {
      debugPrint("❌ Error insertando gasto: $e");
      debugPrint("📋 Datos del gasto: ${expense.toMap()}");
      rethrow;
    }
  }

  Future<List<Expense>> getExpensesForExtraction(int extractionId) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        AppConstants.expensesTable,
        where: 'extraction_id = ? OR additional_extraction_id = ?',
        whereArgs: [extractionId, extractionId],
        orderBy: 'date DESC',
      );
      return List.generate(maps.length, (i) => Expense.fromMap(maps[i]));
    } catch (e) {
      debugPrint("❌ Error obteniendo gastos para extracción $extractionId: $e");
      return [];
    }
  }

  Future<int> updateExpense(Expense expense) async {
    try {
      final db = await database;
      if (expense.id == null) throw ArgumentError("Expense ID cannot be null for update");
      return await db.update(
        AppConstants.expensesTable,
        expense.toMap(),
        where: '${AppConstants.colId} = ?',
        whereArgs: [expense.id],
      );
    } catch (e) {
      debugPrint("❌ Error actualizando gasto ID ${expense.id}: $e");
      return 0;
    }
  }

  Future<int> deleteExpense(int id) async {
     try {
      final db = await database;
      return await db.delete(AppConstants.expensesTable, where: '${AppConstants.colId} = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint("❌ Error eliminando gasto ID $id: $e");
      return 0;
    }
  }

  Future<int> insertCategory(Category category) async {
    try {
      final db = await database;
      return await db.insert(AppConstants.categoriesTable, category.toMap(), 
        conflictAlgorithm: ConflictAlgorithm.fail);
    } catch (e) {
      if (e.toString().contains('UNIQUE constraint failed')) {
        debugPrint("⚠️ Error al insertar categoría '${category.name}' (tipo ${category.type.name}): ya existe");
        return -1; 
      }
      debugPrint("❌ Error inesperado insertando categoría: $e");
      rethrow;
    }
  }

  Future<List<Category>> getCategories() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(AppConstants.categoriesTable, 
        orderBy: '${AppConstants.colType} ASC, ${AppConstants.colName} ASC');
      return List.generate(maps.length, (i) => Category.fromMap(maps[i]));
    } catch (e) {
      debugPrint("❌ Error obteniendo categorías: $e");
      return [];
    }
  }

  Future<int> updateCategory(Category category) async {
    try {
      final db = await database;
      if (category.id == null) {
        throw ArgumentError('El ID de la categoría no puede ser nulo para la operación de actualización.');
      }
      return await db.update(
        AppConstants.categoriesTable,
        category.toMap(),
        where: '${AppConstants.colId} = ?',
        whereArgs: [category.id],
        conflictAlgorithm: ConflictAlgorithm.fail, 
      );
    } catch (e) {
      if (e.toString().contains('UNIQUE constraint failed')) {
        debugPrint("⚠️ Error de constraint al actualizar categoría '${category.name}' (tipo ${category.type.name}): $e");
        return -2; 
      } else if (e is ArgumentError) {
        rethrow;
      } else {
        debugPrint("❌ Excepción no esperada durante updateCategory: $e");
        rethrow;
      }
    }
  }

  Future<int> deleteCategory(int id) async {
    try {
      final db = await database;
      return await db.delete(AppConstants.categoriesTable, where: '${AppConstants.colId} = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint("❌ Error eliminando categoría ID $id: $e");
      return 0;
    }
  }

  Future<int> insertFundAdvance(FundAdvance advance) async {
    try {
      final db = await database;
      final result = await db.insert(AppConstants.fundAdvancesTable, advance.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      debugPrint("✅ Adelanto de fondos insertado con ID: $result para extracción ${advance.extractionId}");
      return result;
    } catch (e) {
      debugPrint("❌ Error insertando adelanto de fondos: $e");
      rethrow;
    }
  }

  Future<List<FundAdvance>> getFundAdvancesForExtraction(int extractionId) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        AppConstants.fundAdvancesTable,
        where: 'extraction_id = ?',
        whereArgs: [extractionId],
        orderBy: 'date DESC',
      );
      return List.generate(maps.length, (i) => FundAdvance.fromMap(maps[i]));
    } catch (e) {
      debugPrint("❌ Error obteniendo adelantos de fondos para extracción $extractionId: $e");
      return [];
    }
  }
}