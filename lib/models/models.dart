// lib/models/models.dart
import 'dart:convert';
import 'enums.dart';

// --- Clase Category (sin cambios) ---
class Category {
  final int? id;
  final String name;
  final ExpenseCategoryType type;

  Category({this.id, required this.name, required this.type});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
    };
  }

  static Category fromMap(Map<String, dynamic> map) {
    try {
      String typeString = map['type'] as String? ?? ExpenseCategoryType.presupuesto.name;
      ExpenseCategoryType categoryType;
      
      try {
        categoryType = ExpenseCategoryType.values.byName(typeString);
      } catch (e) {
        print("Error al parsear tipo de categoría '$typeString', usando presupuesto por defecto. Error: $e");
        categoryType = ExpenseCategoryType.presupuesto;
      }
      
      return Category(
        id: map['id'] as int?,
        name: map['name'] as String? ?? 'Categoría sin nombre',
        type: categoryType,
      );
    } catch (e) {
      print("Error parseando Category desde map: $e");
      print("Map problemático: $map");
      rethrow;
    }
  }

  @override
  String toString() {
    return 'Category{id: $id, name: $name, type: ${type.name}}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Category && 
      runtimeType == other.runtimeType && 
      id == other.id && 
      name == other.name && 
      type == other.type;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ type.hashCode;
}

// --- Clase Extraction (MODIFICADA) ---
class Extraction {
  final int? id;
  final double amount;
  final String reason;
  final String comments;
  final DateTime date;
  final String? extractionCode;
  double spentAmount; // For direct expenses not part of an advance
  double totalAdvancedAmount; // For money given to members

  Extraction({
    this.id,
    required this.amount,
    required this.reason,
    this.comments = '',
    required this.date,
    this.extractionCode,
    this.spentAmount = 0.0,
    this.totalAdvancedAmount = 0.0, // Initialize
  });

  // Available balance now considers direct expenses and advances
  double get availableBalance => amount - spentAmount - totalAdvancedAmount;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'reason': reason,
      'comments': comments,
      'date': date.toIso8601String(),
      'extraction_code': extractionCode,
      // spentAmount and totalAdvancedAmount are not stored in this table, they are calculated
    };
  }

  static Extraction fromMap(Map<String, dynamic> map) {
    try {
      return Extraction(
        id: map['id'] as int?,
        amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
        reason: map['reason'] as String? ?? 'Sin razón especificada',
        comments: map['comments'] as String? ?? '', 
        date: map['date'] != null ? DateTime.parse(map['date'] as String) : DateTime.now(),
        extractionCode: map['extraction_code'] as String?,
        // spentAmount and totalAdvancedAmount will be populated by the service layer
      );
    } catch (e) {
      print("Error parseando Extraction desde map: $e");
      print("Map problemático: $map");
      rethrow;
    }
  }

  @override
  String toString() {
    return 'Extraction{id: $id, amount: $amount, reason: $reason, date: $date, spentAmount: $spentAmount, totalAdvancedAmount: $totalAdvancedAmount, availableBalance: $availableBalance}';
  }
}

// --- Clase Expense (MODIFICADA) ---
class Expense {
  final int? id;
  final int extractionId; // Original extraction
  final int? fundAdvanceId; // NEW: Link to fund advance if applicable
  final double amount;
  final int? categoryId;
  final String description;
  final DateTime date;
  final List<String>? receiptUrls;
  
  final int? additionalExtractionId;
  final double? amountFromPrimary;
  final double? amountFromAdditional;
  
  final String? personaQueRecibio;
  final String? pagadoA;
  // final String? nombreUnidad; // This field is being phased out from forms/PDF
  final String? beneficiarioOfrenda;
  final String? importeEnLetras;
  final String? numeroReferencia;
  final String? numeroReferenciaAdicional;
  
  String? categoryName; 
  final ExpenseCategoryType? categoryType; 

  Expense({
    this.id,
    required this.extractionId,
    this.fundAdvanceId, // NEW
    required this.amount,
    this.categoryId,       
    required this.description,
    required this.date,
    this.receiptUrls,
    this.additionalExtractionId,
    this.amountFromPrimary,
    this.amountFromAdditional,
    this.personaQueRecibio,
    this.pagadoA,
    // this.nombreUnidad, // Phased out
    this.beneficiarioOfrenda,
    this.importeEnLetras,
    this.numeroReferencia,
    this.numeroReferenciaAdicional,
    this.categoryName, 
    this.categoryType, 
  });

  bool get usesMultipleExtractions => additionalExtractionId != null;

  Map<String, double> get amountDistribution {
    if (!usesMultipleExtractions) {
      return {'primary': amount};
    }
    return {
      'primary': amountFromPrimary ?? 0.0,
      'additional': amountFromAdditional ?? 0.0,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'extraction_id': extractionId,
      'fund_advance_id': fundAdvanceId, // NEW
      'amount': amount,
      'category_id': categoryId, 
      'description': description,
      'date': date.toIso8601String(),
      'receipt_urls': receiptUrls != null ? jsonEncode(receiptUrls) : null,
      'additional_extraction_id': additionalExtractionId,
      'amount_from_primary': amountFromPrimary,
      'amount_from_additional': amountFromAdditional,
      'persona_que_recibio': personaQueRecibio,
      'pagado_a': pagadoA,
      // 'nombre_unidad': nombreUnidad, // Phased out
      'beneficiario_ofrenda': beneficiarioOfrenda,
      'importe_en_letras': importeEnLetras,
      'numero_referencia': numeroReferencia,
      'numero_referencia_adicional': numeroReferenciaAdicional,
    };
  }

  static Expense fromMap(Map<String, dynamic> map) {
    try {
      List<String>? urls;
      if (map['receipt_urls'] != null) {
        try {
            var decoded = jsonDecode(map['receipt_urls'] as String);
            if (decoded is List) {
                urls = List<String>.from(decoded.map((item) => item.toString()));
            }
        } catch (e) {
            print("Error decodificando receipt_urls: $e. Contenido: ${map['receipt_urls']}");
            urls = null;
        }
      }

      return Expense(
        id: map['id'] as int?,
        extractionId: map['extraction_id'] as int? ?? 0,
        fundAdvanceId: map['fund_advance_id'] as int?, // NEW
        amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
        categoryId: map['category_id'] as int?, 
        description: map['description'] as String? ?? 'Sin descripción',
        date: map['date'] != null ? DateTime.parse(map['date'] as String) : DateTime.now(),
        receiptUrls: urls,
        additionalExtractionId: map['additional_extraction_id'] as int?,
        amountFromPrimary: (map['amount_from_primary'] as num?)?.toDouble(),
        amountFromAdditional: (map['amount_from_additional'] as num?)?.toDouble(),
        personaQueRecibio: map['persona_que_recibio'] as String?,
        pagadoA: map['pagado_a'] as String?,
        // nombreUnidad: map['nombre_unidad'] as String?, // Phased out
        beneficiarioOfrenda: map['beneficiario_ofrenda'] as String?,
        importeEnLetras: map['importe_en_letras'] as String?,
        numeroReferencia: map['numero_referencia'] as String?,
        numeroReferenciaAdicional: map['numero_referencia_adicional'] as String?,
      );
    } catch (e) {
      print("Error parseando Expense desde map: $e");
      print("Map problemático: $map");
      rethrow;
    }
  }

  Expense copyWith({
    int? id,
    int? extractionId,
    int? fundAdvanceId, // NEW
    double? amount,
    int? categoryId,
    String? description,
    DateTime? date,
    List<String>? receiptUrls,
    int? additionalExtractionId,
    double? amountFromPrimary,
    double? amountFromAdditional,
    String? personaQueRecibio,
    String? pagadoA,
    // String? nombreUnidad, // Phased out
    String? beneficiarioOfrenda,
    String? importeEnLetras,
    String? numeroReferencia,
    String? numeroReferenciaAdicional,
    String? categoryName,
    ExpenseCategoryType? categoryType,
  }) {
    return Expense(
      id: id ?? this.id,
      extractionId: extractionId ?? this.extractionId,
      fundAdvanceId: fundAdvanceId ?? this.fundAdvanceId, // NEW
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      description: description ?? this.description,
      date: date ?? this.date,
      receiptUrls: receiptUrls ?? this.receiptUrls,
      additionalExtractionId: additionalExtractionId ?? this.additionalExtractionId,
      amountFromPrimary: amountFromPrimary ?? this.amountFromPrimary,
      amountFromAdditional: amountFromAdditional ?? this.amountFromAdditional,
      personaQueRecibio: personaQueRecibio ?? this.personaQueRecibio,
      pagadoA: pagadoA ?? this.pagadoA,
      // nombreUnidad: nombreUnidad ?? this.nombreUnidad, // Phased out
      beneficiarioOfrenda: beneficiarioOfrenda ?? this.beneficiarioOfrenda,
      importeEnLetras: importeEnLetras ?? this.importeEnLetras,
      numeroReferencia: numeroReferencia ?? this.numeroReferencia,
      numeroReferenciaAdicional: numeroReferenciaAdicional ?? this.numeroReferenciaAdicional,
      categoryName: categoryName ?? this.categoryName,
      categoryType: categoryType ?? this.categoryType,
    );
  }

  @override
  String toString() {
    // Simplified for brevity, ensure all relevant fields are included for real debugging
    return 'Expense{id: $id, extractionId: $extractionId, fundAdvanceId: $fundAdvanceId, amount: $amount, description: $description, date: $date, categoryType: ${categoryType?.name}}';
  }
}


// --- NUEVA CLASE: FundAdvance ---
class FundAdvance {
  final int? id;
  final int extractionId;
  final String memberName;
  final double amount;
  final DateTime date;
  final ExpenseCategoryType purposeType; // 'presupuesto' o 'ofrendaDeAyuno'
  final String? reason;
  final String status; // e.g., 'PENDIENTE', 'RECONCILIADO_PARCIAL', 'RECONCILIADO_TOTAL'
  final String? comments;
  // Transient field for total amount of expenses reconciled against this advance
  double amountReconciled; 

  FundAdvance({
    this.id,
    required this.extractionId,
    required this.memberName,
    required this.amount,
    required this.date,
    required this.purposeType,
    this.reason,
    this.status = 'PENDIENTE',
    this.comments,
    this.amountReconciled = 0.0,
  });

  double get pendingAmount => amount - amountReconciled;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'extraction_id': extractionId,
      'member_name': memberName,
      'amount': amount,
      'date': date.toIso8601String(),
      'purpose_type': purposeType.name,
      'reason': reason,
      'status': status,
      'comments': comments,
    };
  }

  static FundAdvance fromMap(Map<String, dynamic> map) {
    ExpenseCategoryType pType;
    try {
      pType = ExpenseCategoryType.values.byName(map['purpose_type'] as String? ?? ExpenseCategoryType.presupuesto.name);
    } catch (e) {
      pType = ExpenseCategoryType.presupuesto; // Default if parsing fails
    }

    return FundAdvance(
      id: map['id'] as int?,
      extractionId: map['extraction_id'] as int,
      memberName: map['member_name'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      purposeType: pType,
      reason: map['reason'] as String?,
      status: map['status'] as String? ?? 'PENDIENTE',
      comments: map['comments'] as String?,
      // amountReconciled will be populated by service layer
    );
  }

  @override
  String toString() {
    return 'FundAdvance{id: $id, extractionId: $extractionId, memberName: $memberName, amount: $amount, date: $date, purposeType: ${purposeType.name}, status: $status, amountReconciled: $amountReconciled}';
  }
}