import 'package:flutter/material.dart';
import '../../models/enums.dart';

class ConditionalFields extends StatelessWidget {
  final ExpenseCategoryType? selectedType;
  final PaymentType selectedPaymentType;
  final TextEditingController personaQueRecibioController;
  final TextEditingController pagadoAController;
  final TextEditingController nombreUnidadController; // Controller will still be passed but not used for input here
  final TextEditingController beneficiarioOfrendaController;
  final TextEditingController importeEnLetrasController;
  final TextEditingController numeroReferenciaController;

  const ConditionalFields({
    super.key,
    required this.selectedType,
    required this.selectedPaymentType,
    required this.personaQueRecibioController,
    required this.pagadoAController,
    required this.nombreUnidadController,
    required this.beneficiarioOfrendaController,
    required this.importeEnLetrasController,
    required this.numeroReferenciaController,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedType == null) {
      return const SizedBox.shrink();
    }

    List<Widget> conditionalFields = [];

    // Campo "Persona que Recibió" - Común para Presupuesto y Ofrenda si es EFECTIVO
    if ((selectedType == ExpenseCategoryType.presupuesto || selectedType == ExpenseCategoryType.ofrendaDeAyuno) &&
        selectedPaymentType == PaymentType.efectivo) {
      conditionalFields.addAll([
        const SizedBox(height: 16),
        TextFormField(
          controller: personaQueRecibioController,
          decoration: const InputDecoration(
            labelText: 'Persona que Recibió el Fondo *',
            prefixIcon: Icon(Icons.person_pin_circle_outlined),
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Este campo es obligatorio para pagos en efectivo.';
            }
            return null;
          },
          textCapitalization: TextCapitalization.words,
        ),
      ]);
    }

    // Campo "Pagado A / Entregado A" - Común para Presupuesto y Ofrenda
    if (selectedType == ExpenseCategoryType.presupuesto || selectedType == ExpenseCategoryType.ofrendaDeAyuno) {
      conditionalFields.addAll([
        const SizedBox(height: 16),
        TextFormField(
          controller: pagadoAController,
          decoration: InputDecoration(
            labelText: selectedType == ExpenseCategoryType.presupuesto
              ? 'Pagado A (Comercio/Proveedor) *'
              : 'Pagado/Entregado A (Beneficiario/Institución) *',
            prefixIcon: const Icon(Icons.business_center_outlined),
            border: const OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Este campo es obligatorio para este tipo de gasto.';
            }
            return null;
          },
          textCapitalization: TextCapitalization.words,
        ),
      ]);
    }

    // Campos específicos para Presupuesto
    // "Nombre de la Unidad" field is REMOVED from here
    // if (selectedType == ExpenseCategoryType.presupuesto) {
    //   conditionalFields.addAll([
    //     const SizedBox(height: 16),
    //     TextFormField(
    //       controller: nombreUnidadController, // This controller is now unused for input
    //       decoration: const InputDecoration(
    //         labelText: 'Nombre de la Unidad (Interna) *',
    //         prefixIcon: Icon(Icons.group_work_outlined),
    //         border: OutlineInputBorder(),
    //       ),
    //       validator: (value) {
    //         if (value == null || value.trim().isEmpty) {
    //           return 'Este campo es obligatorio para gastos de presupuesto.';
    //         }
    //         return null;
    //       },
    //       textCapitalization: TextCapitalization.words,
    //     ),
    //   ]);
    // }

    // Campo específico para Ofrenda de Ayuno (Beneficiario de la Ofrenda)
    if (selectedType == ExpenseCategoryType.ofrendaDeAyuno) {
      conditionalFields.addAll([
        const SizedBox(height: 16),
        TextFormField(
          controller: beneficiarioOfrendaController,
          decoration: const InputDecoration(
            labelText: 'Beneficiario Principal de Ofrenda de Ayuno *',
            prefixIcon: Icon(Icons.volunteer_activism_outlined),
            border: OutlineInputBorder(),
            helperText: 'Nombre de la persona o familia que recibe la ayuda directa.',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Este campo es obligatorio para gastos de ofrenda de ayuno.';
            }
            return null;
          },
          textCapitalization: TextCapitalization.words,
          maxLines: 2,
        ),
      ]);
    }

    // Campos comunes al final: Número de referencia e Importe en letras
    conditionalFields.addAll([
      const SizedBox(height: 16),
      TextFormField(
        controller: numeroReferenciaController,
        decoration: InputDecoration(
          labelText: 'Número de Referencia',
          prefixIcon: const Icon(Icons.confirmation_number_outlined),
          border: const OutlineInputBorder(),
          helperText: selectedPaymentType == PaymentType.efectivo
              ? 'Se genera automáticamente con fecha y monto de la extracción'
              : 'Ingrese el código del ticket de compra manualmente',
        ),
        readOnly: selectedPaymentType == PaymentType.efectivo,
        style: TextStyle(
          color: Colors.grey[700],
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        validator: selectedPaymentType == PaymentType.tarjeta ? (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Ingrese el número de referencia del ticket de compra.';
          }
          return null;
        } : null,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: importeEnLetrasController,
        decoration: const InputDecoration(
          labelText: 'Importe en Letras',
          prefixIcon: Icon(Icons.text_fields_outlined),
          border: OutlineInputBorder(),
          helperText: 'Se actualiza automáticamente al ingresar el monto',
        ),
        readOnly: true,
        maxLines: 2,
        style: TextStyle(
          color: Colors.grey[700],
          fontStyle: FontStyle.italic,
        ),
      ),
    ]);

    return Column(children: conditionalFields);
  }
}