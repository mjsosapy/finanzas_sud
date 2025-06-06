import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/extraction_service.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatters.dart';
import '../../widgets/common/custom_card.dart';

class AddExtractionScreen extends StatefulWidget {
  final Extraction? extractionToEdit;

  const AddExtractionScreen({super.key, this.extractionToEdit});

  @override
  State<AddExtractionScreen> createState() => _AddExtractionScreenState();
}

class _AddExtractionScreenState extends State<AddExtractionScreen> {
  final ExtractionService _extractionService = ExtractionService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _commentsController = TextEditingController();
  final TextEditingController _extractionCodeController = TextEditingController();

  bool get _isEditing => widget.extractionToEdit != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadExtractionData();
    }
  }

  void _loadExtractionData() {
    final extraction = widget.extractionToEdit!;
    
    // Formatear el monto usando el currency formatter
    final currencyInputFormatter = CurrencyInputFormatter(locale: 'en_US', decimalDigits: 0);
    _amountController.text = currencyInputFormatter.formatEditUpdate(
      TextEditingValue.empty, 
      TextEditingValue(text: extraction.amount.toInt().toString())
    ).text;
    
    _reasonController.text = extraction.reason;
    _commentsController.text = extraction.comments;
    _extractionCodeController.text = extraction.extractionCode ?? '';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    _commentsController.dispose();
    _extractionCodeController.dispose();
    super.dispose();
  }

  Future<void> _saveExtraction() async {
    if (_formKey.currentState!.validate()) {
      String cleanAmountText = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanAmountText.isEmpty) {
         _showMessage('Por favor, ingrese un monto válido.', isError: true);
         return;
      }

      try {
        if (_isEditing) {
          // Actualizar extracción existente
          final updatedExtraction = Extraction(
            id: widget.extractionToEdit!.id,
            amount: double.parse(cleanAmountText),
            reason: _reasonController.text,
            comments: _commentsController.text,
            date: widget.extractionToEdit!.date, // Mantener la fecha original
            extractionCode: _extractionCodeController.text.isEmpty ? null : _extractionCodeController.text,
          );
          
          await _extractionService.updateExtraction(updatedExtraction);
          _showMessage('Extracción actualizada con éxito!');
          
          if (mounted) {
            Navigator.pop(context, true); // Retornar true para indicar cambios
          }
        } else {
          // Crear nueva extracción
          final newExtraction = Extraction(
            amount: double.parse(cleanAmountText),
            reason: _reasonController.text,
            comments: _commentsController.text,
            date: DateTime.now(),
            extractionCode: _extractionCodeController.text.isEmpty ? null : _extractionCodeController.text,
          );
          
          await _extractionService.createExtraction(newExtraction);
          
          _amountController.clear();
          _reasonController.clear();
          _commentsController.clear();
          _extractionCodeController.clear();
          _showMessage('Extracción registrada con éxito!');
        }
      } catch (e) {
        _showMessage('Error al guardar la extracción: $e', isError: true);
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: isError ? Colors.red[600] : Colors.green[600],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyInputFormatter = CurrencyInputFormatter(locale: 'en_US', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Extracción' : 'Registrar Nueva Extracción'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: CustomCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _isEditing ? Icons.edit_outlined : Icons.add_circle_outline,
                    color: Theme.of(context).primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isEditing 
                          ? 'Edite los detalles de la extracción'
                          : 'Ingrese los detalles de la extracción',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).primaryColor
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Mostrar información adicional si estamos editando
              if (_isEditing) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200] ?? Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Información de la Extracción',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Fecha de creación: ${DateFormatters.formatLongDate(widget.extractionToEdit!.date)}',
                        style: TextStyle(color: Colors.blue[700], fontSize: 13),
                      ),
                      if (widget.extractionToEdit!.spentAmount > 0)
                        Text(
                          'Monto gastado: ${CurrencyUtils.formatCurrency(widget.extractionToEdit!.spentAmount)}',
                          style: TextStyle(color: Colors.blue[700], fontSize: 13),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _extractionCodeController,
                      decoration: const InputDecoration(
                        labelText: 'Código de Extracción (Opcional)',
                        prefixIcon: Icon(Icons.code_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Monto de la Extracción',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [currencyInputFormatter],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, ingrese un monto.';
                        }
                        final cleanValue = value.replaceAll(RegExp(r'[^0-9]'), '');
                        if (cleanValue.isEmpty || double.tryParse(cleanValue) == null || double.parse(cleanValue) <= 0) {
                          return 'Ingrese un monto válido mayor a cero.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _reasonController,
                      decoration: const InputDecoration(
                        labelText: 'Motivo General',
                        prefixIcon: Icon(Icons.description_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, ingrese un motivo.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _commentsController,
                      decoration: const InputDecoration(
                        labelText: 'Comentarios Adicionales (Opcional)',
                        prefixIcon: Icon(Icons.comment_outlined),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    
                    // Botones
                    Row(
                      children: [
                        if (_isEditing) ...[
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancelar'),
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                        Expanded(
                          flex: _isEditing ? 2 : 1,
                          child: ElevatedButton.icon(
                            onPressed: _saveExtraction,
                            icon: Icon(_isEditing ? Icons.save_outlined : Icons.add_circle_outline),
                            label: Text(_isEditing ? 'Actualizar Extracción' : 'Registrar Extracción'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}