// Enum para el Tipo de Gasto de la Categoría
enum ExpenseCategoryType {
  presupuesto,
  ofrendaDeAyuno,
}

// Enum para el Tipo de Pago
enum PaymentType {
  efectivo,
  tarjeta,
}

// Helper para obtener el string legible del ExpenseCategoryType
String expenseCategoryTypeToDisplayString(ExpenseCategoryType type) {
  switch (type) {
    case ExpenseCategoryType.presupuesto:
      return 'Presupuesto';
    case ExpenseCategoryType.ofrendaDeAyuno:
      return 'Ofrenda de Ayuno';
    default:
      return type.name;
  }
}

// Helper para obtener el string legible del PaymentType
String paymentTypeToDisplayString(PaymentType type) {
  switch (type) {
    case PaymentType.efectivo:
      return 'Efectivo (Dinero de Extracción)';
    case PaymentType.tarjeta:
      return 'Tarjeta del Obispo';
    default:
      return type.name;
  }
}

// Helper para determinar el tipo de pago basado en los datos del gasto
PaymentType getPaymentTypeFromExpense(Map<String, dynamic> expenseData) {
  // Si no tiene "persona que recibió" para gastos de presupuesto, es pago con tarjeta
  final personaQueRecibio = expenseData['persona_que_recibio'] as String?;
  if (personaQueRecibio == null || personaQueRecibio.isEmpty) {
    return PaymentType.tarjeta;
  }
  return PaymentType.efectivo;
}