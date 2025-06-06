// lib/screens/fund_advances/add_fund_advance_screen.dart
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../models/enums.dart';
import '../../services/extraction_service.dart';
import '../../services/fund_advance_service.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatters.dart';
import '../../widgets/common/custom_card.dart';

class AddFundAdvanceScreen extends StatefulWidget {
  final Extraction? sourceExtraction; 

  const AddFundAdvanceScreen({super.key, this.sourceExtraction});

  @override
  State<AddFundAdvanceScreen> createState() => _AddFundAdvanceScreenState();
}

class _AddFundAdvanceScreenState extends State<AddFundAdvanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final FundAdvanceService _fundAdvanceService = FundAdvanceService();
  final ExtractionService _extractionService = ExtractionService();

  final TextEditingController _memberNameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _commentsController = TextEditingController();

  Extraction? _selectedExtraction;
  List<Extraction> _availableExtractions = [];
  DateTime _selectedDate = DateTime.now();
  ExpenseCategoryType _selectedPurposeType = ExpenseCategoryType.presupuesto;
  bool _isLoadingExtractions = true;
  bool _isSaving = false;

  final CurrencyInputFormatter _currencyFormatter =
      CurrencyInputFormatter(locale: 'es_PY', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    if (widget.sourceExtraction != null) {
      // If a source extraction is provided, fetch its latest state to ensure balance is current
      _loadSpecificExtraction(widget.sourceExtraction!.id!);
    } else {
      _loadAvailableExtractions();
    }
  }

  Future<void> _loadSpecificExtraction(int extractionId) async {
    setState(() => _isLoadingExtractions = true);
    try {
      final extraction = await _extractionService.getExtractionById(extractionId);
      if (mounted) {
        setState(() {
          _selectedExtraction = extraction;
          // If loaded specifically, it's the only one "available" in this context
          _availableExtractions = (extraction == null) ? [] : [extraction]; 
          _isLoadingExtractions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingExtractions = false);
        _showMessage('Error cargando extracción fuente: $e', isError: true);
      }
    }
  }


  Future<void> _loadAvailableExtractions() async {
    setState(() => _isLoadingExtractions = true);
    try {
      final extractions = await _extractionService.getExtractionsWithBalance();
      if (mounted) {
        setState(() {
          _availableExtractions = extractions;
          if (_availableExtractions.isNotEmpty && _selectedExtraction == null) {
            // Optionally pre-select or leave for user
            // _selectedExtraction = _availableExtractions.first; 
          }
          _isLoadingExtractions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingExtractions = false);
        _showMessage('Error cargando extracciones disponibles: $e', isError: true);
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('es', 'PY'),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _saveFundAdvance() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedExtraction == null) {
      _showMessage('Por favor, seleccione una extracción de origen.', isError: true);
      return;
    }

    final String cleanAmountText = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final double amount = double.tryParse(cleanAmountText) ?? 0.0;

    if (amount <= 0) {
      _showMessage('El monto debe ser mayor a cero.', isError: true);
      return;
    }
    
    // Fetch the latest state of the selected extraction to confirm balance
    final freshSelectedExtraction = await _extractionService.getExtractionById(_selectedExtraction!.id!);
    if (freshSelectedExtraction == null) {
        _showMessage('No se pudo verificar la extracción seleccionada.', isError: true);
        return;
    }
    if (amount > freshSelectedExtraction.availableBalance) {
        _showMessage('Saldo insuficiente en la extracción seleccionada. Saldo actual: ${DateFormatters.formatCurrency(freshSelectedExtraction.availableBalance)}.', isError: true);
        // Optionally refresh the list of available extractions if not coming from a fixed source
        if (widget.sourceExtraction == null) {
            _loadAvailableExtractions();
        }
        return;
    }

    setState(() => _isSaving = true);

    final newAdvance = FundAdvance(
      extractionId: freshSelectedExtraction.id!, // Use the fresh extraction's ID
      memberName: _memberNameController.text.trim(),
      amount: amount,
      date: _selectedDate,
      purposeType: _selectedPurposeType,
      reason: _reasonController.text.trim().isEmpty ? null : _reasonController.text.trim(),
      comments: _commentsController.text.trim().isEmpty ? null : _commentsController.text.trim(),
      status: 'PENDIENTE', 
    );

    try {
      // Pass the freshSelectedExtraction to check balance again inside the service if needed, or rely on this check.
      await _fundAdvanceService.createFundAdvance(newAdvance, freshSelectedExtraction);
      _showMessage('Entrega de dinero registrada exitosamente.');
      if (mounted) {
        Navigator.pop(context, true); 
      }
    } catch (e) {
      _showMessage('Error registrando la entrega: ${e.toString()}', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Entrega de Dinero'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: CustomCard(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Origen de los Fondos', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_isLoadingExtractions)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (widget.sourceExtraction == null) 
                  DropdownButtonFormField<Extraction>(
                    value: _selectedExtraction,
                    decoration: InputDecoration(
                      labelText: 'Extracción de Origen *',
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined, 
                        color: (_selectedExtraction?.availableBalance ?? 0) > 0 ? Theme.of(context).iconTheme.color : Colors.orange.shade700),
                      border: const OutlineInputBorder(),
                      hintText: _availableExtractions.isEmpty ? 'No hay extracciones con saldo' : 'Seleccione una extracción',
                    ),
                    items: _availableExtractions.map((extraction) {
                      return DropdownMenuItem<Extraction>(
                        value: extraction,
                        child: Text(
                          '${extraction.reason} (${DateFormatters.formatCurrency(extraction.availableBalance)})',
                           style: TextStyle(color: extraction.availableBalance > 0 ? null : Colors.orange.shade700)
                        ),
                      );
                    }).toList(),
                    onChanged: (Extraction? newValue) {
                      setState(() {
                        _selectedExtraction = newValue;
                      });
                    },
                    validator: (value) => value == null ? 'Seleccione una extracción.' : null,
                    isExpanded: true,
                  )
                else 
                  Padding(
                    padding: const EdgeInsets.only(bottom:16.0),
                    child: InputDecorator(
                       decoration: InputDecoration(
                         labelText: 'Extracción de Origen (Saldo Actual: ${DateFormatters.formatCurrency(_selectedExtraction?.availableBalance ?? 0.0)})',
                         prefixIcon: Icon(Icons.account_balance_wallet_outlined, color: (_selectedExtraction?.availableBalance ?? 0) > 0 ? null : Colors.orange.shade700),
                         border: const OutlineInputBorder(),
                       ),
                       child: Text(_selectedExtraction?.reason ?? 'Extracción no cargada', style: Theme.of(context).textTheme.titleMedium),
                    ),
                  ),
                const SizedBox(height: 20),
                Text('Detalles de la Entrega', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _memberNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del Miembro Receptor *',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Ingrese el nombre del miembro.'
                      : null,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Monto Entregado *',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [_currencyFormatter],
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Ingrese un monto.';
                    final cleanValue = value.replaceAll(RegExp(r'[^0-9]'), '');
                    final double? numericValue = double.tryParse(cleanValue);
                    if (numericValue == null || numericValue <= 0) {
                      return 'Monto inválido. Debe ser mayor a cero.';
                    }
                    if (_selectedExtraction != null && numericValue > _selectedExtraction!.availableBalance) {
                        return 'Excede saldo disponible (${DateFormatters.formatCurrency(_selectedExtraction!.availableBalance)}).';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => _selectDate(context),
                  child: AbsorbPointer(
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Fecha de Entrega *',
                        prefixIcon: const Icon(Icons.calendar_today_outlined),
                        suffixIcon: Icon(Icons.arrow_drop_down_outlined, color: Theme.of(context).primaryColor)
                      ),
                      controller: TextEditingController(text: DateFormatters.formatShortDate(_selectedDate)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ExpenseCategoryType>(
                  value: _selectedPurposeType,
                  decoration: const InputDecoration(
                    labelText: 'Propósito General del Dinero *',
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                  items: ExpenseCategoryType.values.map((type) {
                    return DropdownMenuItem<ExpenseCategoryType>(
                      value: type,
                      child: Text(expenseCategoryTypeToDisplayString(type)),
                    );
                  }).toList(),
                  onChanged: (ExpenseCategoryType? newValue) {
                    if (newValue != null) {
                      setState(() => _selectedPurposeType = newValue);
                    }
                  },
                  isExpanded: true,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Motivo Específico de la Entrega (Opcional)',
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _commentsController,
                  decoration: const InputDecoration(
                    labelText: 'Comentarios Adicionales (Opcional)',
                    prefixIcon: Icon(Icons.comment_outlined),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveFundAdvance,
                    icon: _isSaving
                        ? Container(
                            width: 18, height: 18,
                            margin: const EdgeInsets.only(right: 8),
                            child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_to_mobile_outlined), // Consider a more appropriate icon
                    label: Text(_isSaving ? 'Guardando...' : 'Registrar Entrega de Dinero'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}