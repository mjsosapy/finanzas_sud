import 'package:flutter/material.dart';
import 'dart:async';
// Ensure all necessary imports are present, like for File if you add image handling
// import 'dart:io';
// import 'dart:typed_data';
import '../../models/models.dart';
import '../../models/enums.dart';
import '../../services/expense_service.dart';
import '../../services/category_service.dart';
import '../../services/extraction_service.dart';
// import '../../services/photo_service.dart'; // If adding photo features here
// import '../../services/configuration_service.dart'; // If PDF generation is added here
// import '../../services/pdf_storage_service.dart'; // If PDF generation is added here
import '../../utils/currency_formatter.dart';
import '../../utils/number_to_words_helper.dart';
import '../../utils/date_formatters.dart';
// import '../../utils/pdf_generator.dart'; // If PDF generation is added here
import '../../widgets/common/custom_card.dart';
// import '../../widgets/common/receipt_image_widget.dart'; // If adding photo features here
import '../../widgets/forms/conditional_fields.dart';
import '../../widgets/forms/additional_extraction_dialog.dart';

// NOTA: Esta clase se llama ExpenseRegistrationScreen pero reside en widgets/extraction_detail/
// Considera si este archivo es una versión antigua o duplicada de
// lib/screens/expenses/expense_registration_screen.dart
class ExpenseRegistrationScreen extends StatefulWidget {
  final Extraction extraction;
  final Expense? expenseToEdit;

  const ExpenseRegistrationScreen({
    super.key,
    required this.extraction,
    this.expenseToEdit,
  });

  @override
  State<ExpenseRegistrationScreen> createState() =>
      _ExpenseRegistrationScreenState();
}

class _ExpenseRegistrationScreenState extends State<ExpenseRegistrationScreen> {
  final ExpenseService _expenseService = ExpenseService();
  final CategoryService _categoryService = CategoryService();
  final ExtractionService _extractionService = ExtractionService();
  // final ConfigurationService _configurationService = ConfigurationService(); // If needed

  late Extraction _currentExtraction;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _personaQueRecibioController =
      TextEditingController();
  final TextEditingController _pagadoAController = TextEditingController();
  final TextEditingController _nombreUnidadController = TextEditingController(); // Controller exists
  final TextEditingController _beneficiarioOfrendaController =
      TextEditingController();
  final TextEditingController _importeEnLetrasController =
      TextEditingController();
  final TextEditingController _numeroReferenciaController =
      TextEditingController();

  ExpenseCategoryType? _selectedExpenseType;
  PaymentType _selectedPaymentType = PaymentType.efectivo;
  int? _selectedCategoryId;
  List<Category> _allCategories = [];
  List<Category> _filteredCategories = [];

  Extraction? _additionalExtraction;
  double? _amountFromPrimary;
  double? _amountFromAdditional;
  bool _usesMultipleExtractions = false;

  Timer? _amountInputTimer;
  bool _isCheckingAmount = false;

  // Add these if you plan to use image handling in this version of the screen
  // List<File> _newlySelectedImages = [];
  // List<String> _existingImagePaths = [];
  // bool _isLoadingImage = false;

  DateTime _selectedDate = DateTime.now();
  bool _dataChanged = false;
  bool _isLoading = false;
  bool get _isEditing => widget.expenseToEdit != null;

  final CurrencyInputFormatter _currencyInputFormatter =
      CurrencyInputFormatter(locale: 'es_PY', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _currentExtraction = widget.extraction;
    _selectedDate = _currentExtraction.date;
    _loadInitialData();

    _amountController.addListener(_updateImporteEnLetras);
    _amountController.addListener(_onAmountChanged);
    // _updateNumeroReferencia(); // Called within _loadInitialData
  }

  @override
  void dispose() {
    _amountController.removeListener(_updateImporteEnLetras);
    _amountController.removeListener(_onAmountChanged);
    _amountInputTimer?.cancel();

    _amountController.dispose();
    _descriptionController.dispose();
    _personaQueRecibioController.dispose();
    _pagadoAController.dispose();
    _nombreUnidadController.dispose();
    _beneficiarioOfrendaController.dispose();
    _importeEnLetrasController.dispose();
    _numeroReferenciaController.dispose();
    super.dispose();
  }


  void _updateImporteEnLetras() {
    final cleanAmountText =
        _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanAmountText.isNotEmpty) {
      final amount = double.tryParse(cleanAmountText);
      if (amount != null && amount > 0) {
        final importeEnLetras = NumberToWordsHelper.convertToWords(amount);
        _importeEnLetrasController.text = importeEnLetras;
      } else {
        _importeEnLetrasController.text = '';
      }
    } else {
      _importeEnLetrasController.text = '';
    }
  }

  void _onAmountChanged() {
    _amountInputTimer?.cancel();
    if (_isEditing || _isCheckingAmount) return;
    _amountInputTimer = Timer(const Duration(milliseconds: 1000), () {
      _checkAmountInRealTime();
    });
  }

  void _checkAmountInRealTime() async {
    if (_isCheckingAmount || _isEditing) return;
    final cleanAmountText = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanAmountText.isEmpty) {
      if (_usesMultipleExtractions) {
        setState(() {
          _usesMultipleExtractions = false;
          _additionalExtraction = null;
          _amountFromPrimary = null;
          _amountFromAdditional = null;
        });
      }
      return;
    }
    final expenseAmount = double.tryParse(cleanAmountText);
    if (expenseAmount == null || expenseAmount <= 0) return;
    final availableBalance = _currentExtraction.availableBalance;
    if (expenseAmount > availableBalance) {
      if (!_usesMultipleExtractions) {
        setState(() { _isCheckingAmount = true; });
        await _handleAmountValidationAndSelection(expenseAmount); // Removed debugSource
        setState(() { _isCheckingAmount = false; });
      } else {
        final totalAvailable = availableBalance + (_additionalExtraction?.availableBalance ?? 0.0);
        if (expenseAmount <= totalAvailable) {
           setState(() {
            _amountFromPrimary = availableBalance;
            _amountFromAdditional = expenseAmount - availableBalance;
          });
        } else {
          setState(() {
            _usesMultipleExtractions = false;
            _additionalExtraction = null;
            _amountFromPrimary = null;
            _amountFromAdditional = null;
            _isCheckingAmount = true;
          });
          await _handleAmountValidationAndSelection(expenseAmount); // Removed debugSource
          setState(() { _isCheckingAmount = false; });
        }
      }
    } else {
      if (_usesMultipleExtractions) {
        setState(() {
          _usesMultipleExtractions = false;
          _additionalExtraction = null;
          _amountFromPrimary = null;
          _amountFromAdditional = null;
        });
      }
    }
  }

  void _updateNumeroReferencia() {
    if (_selectedPaymentType == PaymentType.efectivo) {
      final extractionDate = _currentExtraction.date;
      final dayStr = extractionDate.day.toString().padLeft(2, '0');
      final monthStr = extractionDate.month.toString().padLeft(2, '0');
      final formattedExtractionAmount = CurrencyUtils.formatAmountWithDots(_currentExtraction.amount.toInt());
      final numeroReferencia = '$dayStr-$monthStr/$formattedExtractionAmount';
      _numeroReferenciaController.text = numeroReferencia;
    } else {
      // If editing and it's tarjeta, keep the existing value, otherwise clear for new card expense
      _numeroReferenciaController.text = (_isEditing && widget.expenseToEdit?.numeroReferencia != null && _selectedPaymentType == PaymentType.tarjeta)
        ? widget.expenseToEdit!.numeroReferencia!
        : '';
    }
  }

  String _generateAdditionalReference(Extraction additionalExtraction) {
    if (_selectedPaymentType == PaymentType.efectivo) {
      final extractionDate = additionalExtraction.date;
      final dayStr = extractionDate.day.toString().padLeft(2, '0');
      final monthStr = extractionDate.month.toString().padLeft(2, '0');
      final formattedExtractionAmount = CurrencyUtils.formatAmountWithDots(additionalExtraction.amount.toInt());
      return '$dayStr-$monthStr/$formattedExtractionAmount';
    }
    return '';
  }

  Future<void> _loadInitialData() async {
    setState(() { _isLoading = true; });
    try {
      await _loadCategories();
      if (_isEditing && widget.expenseToEdit != null) {
        _loadExpenseData(widget.expenseToEdit!);
      } else {
        _selectedExpenseType = ExpenseCategoryType.presupuesto;
        _selectedPaymentType = PaymentType.efectivo;
        _filterCategoriesForSelectedType();
      }
      final updatedExtraction = await _extractionService.getExtractionById(_currentExtraction.id!);
      if (updatedExtraction != null) {
        _currentExtraction = updatedExtraction;
      }
    } catch (e) {
      _showMessage('Error cargando datos: $e', isError: true);
    } finally {
      if(mounted){
        setState(() { _isLoading = false; });
        _updateNumeroReferencia();
      }
    }
  }

  Future<void> _loadCategories() async {
    final categories = await _categoryService.getAllCategories();
    if (mounted) {
      setState(() {
        _allCategories = categories;
        // Filter categories after _selectedExpenseType is potentially set by _loadExpenseData
         if (_selectedExpenseType != null) {
          _filterCategoriesForSelectedType();
        }
      });
    }
  }

  void _filterCategoriesForSelectedType() {
    if (_selectedExpenseType == null) {
      _filteredCategories = [];
    } else {
      _filteredCategories = _allCategories.where((cat) => cat.type == _selectedExpenseType).toList();
    }
    if (_selectedCategoryId != null && !_filteredCategories.any((cat) => cat.id == _selectedCategoryId)) {
      _selectedCategoryId = null;
    }
    if (mounted) setState(() {});
  }

  void _clearConditionalFields() {
    _personaQueRecibioController.clear();
    _pagadoAController.clear();
    _nombreUnidadController.clear(); // Clear it even if not used in UI
    _beneficiarioOfrendaController.clear();
  }

  void _loadExpenseData(Expense expense) {
    _amountController.text = _currencyInputFormatter.formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: expense.amount.toInt().toString())).text;
    _descriptionController.text = expense.description;
    _personaQueRecibioController.text = expense.personaQueRecibio ?? '';
    _pagadoAController.text = expense.pagadoA ?? '';
    // _nombreUnidadController.text = expense.nombreUnidad ?? ''; // REMOVED: This line caused the error
    _beneficiarioOfrendaController.text = expense.beneficiarioOfrenda ?? '';
    _importeEnLetrasController.text = expense.importeEnLetras ?? '';
    _numeroReferenciaController.text = expense.numeroReferencia ?? '';

    // Assuming this screen version does not handle images for now, based on original comment
    // if (expense.receiptUrls != null && expense.receiptUrls!.isNotEmpty) {
    //   _existingImagePaths = List<String>.from(expense.receiptUrls!);
    // } else {
    //   _existingImagePaths = [];
    // }
    // _newlySelectedImages = [];

    if (expense.usesMultipleExtractions) {
      _usesMultipleExtractions = true;
      _amountFromPrimary = expense.amountFromPrimary;
      _amountFromAdditional = expense.amountFromAdditional;
      if (expense.additionalExtractionId != null) {
        _loadAdditionalExtraction(expense.additionalExtractionId!);
      }
    }

    // Determine _selectedExpenseType first
    if (expense.categoryId != null && _allCategories.isNotEmpty) { // Ensure _allCategories is populated
        final originalCategory = _allCategories.firstWhere(
            (cat) => cat.id == expense.categoryId,
            orElse: () => Category(id: -1, name: 'Categoría Eliminada', type: expense.categoryType ?? ExpenseCategoryType.presupuesto)
        );
        _selectedExpenseType = originalCategory.type;
    } else if (expense.categoryType != null) {
        _selectedExpenseType = expense.categoryType;
    } else {
        _selectedExpenseType = ExpenseCategoryType.presupuesto; // Default
    }


    if (_selectedExpenseType == ExpenseCategoryType.presupuesto || _selectedExpenseType == ExpenseCategoryType.ofrendaDeAyuno) {
        _selectedPaymentType = (expense.personaQueRecibio == null || expense.personaQueRecibio!.isEmpty)
            ? PaymentType.tarjeta
            : PaymentType.efectivo;
    } else {
        _selectedPaymentType = PaymentType.efectivo;
    }


    if (expense.categoryId != null) {
      _filterCategoriesForSelectedType(); // Call filter after _selectedExpenseType is set
      _selectedCategoryId = expense.categoryId;
    } else {
       _filterCategoriesForSelectedType();
    }
    _selectedDate = expense.date;
  }

  Future<void> _loadAdditionalExtraction(int extractionId) async {
    try {
      final extraction = await _extractionService.getExtractionById(extractionId);
      if (extraction != null && mounted) {
        setState(() { _additionalExtraction = extraction; });
      }
    } catch (e) {
      print('Error cargando extracción adicional: $e');
    }
  }


  Future<void> _handleAmountValidationAndSelection(double expenseAmount, {bool isFromSave = false}) async {
    final availableBalance = _currentExtraction.availableBalance;
    if (expenseAmount <= availableBalance) {
      setState(() {
        _usesMultipleExtractions = false;
        _additionalExtraction = null;
        _amountFromPrimary = null;
        _amountFromAdditional = null;
      });
      return;
    }
    if (isFromSave && _usesMultipleExtractions && _additionalExtraction != null) return;

    final deficit = expenseAmount - availableBalance;
    final result = await showDialog<AdditionalExtractionSelectionResult>(
      context: context,
      barrierDismissible: !isFromSave,
      builder: (context) => AdditionalExtractionDialog(
        primaryExtraction: _currentExtraction,
        totalExpenseAmount: expenseAmount,
        availableInPrimary: availableBalance,
        deficit: deficit,
      ),
    );
    if (result != null) {
      setState(() {
        _usesMultipleExtractions = true;
        _additionalExtraction = result.additionalExtraction;
        _amountFromPrimary = result.amountFromPrimary;
        _amountFromAdditional = result.amountFromAdditional;
      });
    } else {
      if (isFromSave) {
        _amountController.clear(); // Clearing amount if save is cancelled due to deficit
        _showMessage('Operación cancelada. Ajuste el monto o seleccione una extracción adicional.', isError: true);
      } else {
        setState(() {
          _usesMultipleExtractions = false;
          _additionalExtraction = null;
          _amountFromPrimary = null;
          _amountFromAdditional = null;
        });
      }
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;
    _dataChanged = true;
    String cleanAmountText = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanAmountText.isEmpty) {
      _showMessage('Por favor, ingrese un monto válido para el gasto.', isError: true);
      return;
    }
    final expenseAmount = double.parse(cleanAmountText);

    if (!_isEditing) {
      final currentPrimaryBalance = await _extractionService.getAvailableBalance(_currentExtraction.id!);
      if (_usesMultipleExtractions && _additionalExtraction != null) {
        final currentAdditionalBalance = await _extractionService.getAvailableBalance(_additionalExtraction!.id!);
         if (expenseAmount > currentPrimaryBalance) {
            _amountFromPrimary = currentPrimaryBalance > 0 ? currentPrimaryBalance : 0;
            _amountFromAdditional = expenseAmount - _amountFromPrimary!;
            if (_amountFromAdditional! > currentAdditionalBalance) {
                 _showMessage('Fondos insuficientes incluso con extracción adicional. Revise montos y saldos.', isError: true);
                 return;
            }
        } else {
            _amountFromPrimary = expenseAmount;
            _amountFromAdditional = 0;
            _usesMultipleExtractions = false;
            _additionalExtraction = null;
        }
      } else if (expenseAmount > currentPrimaryBalance) {
        await _handleAmountValidationAndSelection(expenseAmount, isFromSave: true);
        if (!_usesMultipleExtractions && expenseAmount > await _extractionService.getAvailableBalance(_currentExtraction.id!)) {
          _showMessage('Fondos insuficientes en la extracción principal.', isError: true);
          return;
        }
         // Re-evaluate amounts if an additional extraction was selected during save
        if (_usesMultipleExtractions && _additionalExtraction != null) {
            final recheckPrimaryBalance = await _extractionService.getAvailableBalance(_currentExtraction.id!);
            final recheckAdditionalBalance = await _extractionService.getAvailableBalance(_additionalExtraction!.id!);
             if (expenseAmount > recheckPrimaryBalance) {
                _amountFromPrimary = recheckPrimaryBalance > 0 ? recheckPrimaryBalance : 0;
                _amountFromAdditional = expenseAmount - _amountFromPrimary!;
                if (_amountFromAdditional! > recheckAdditionalBalance) { // Check again
                    _showMessage('Fondos insuficientes tras seleccionar extracción adicional. Revise saldos.', isError: true);
                    return;
                }
            } else { // Covered by primary after all checks
                 _amountFromPrimary = expenseAmount;
                 _amountFromAdditional = 0; // Ensure this is reset
                 _usesMultipleExtractions = false;
                 _additionalExtraction = null;
            }
        }
      } else { // Expense amount is covered by primary extraction initially
          _amountFromPrimary = expenseAmount;
          _amountFromAdditional = null;
          _usesMultipleExtractions = false;
          _additionalExtraction = null;
      }
    }
    // Placeholder for image paths if this screen were to handle them
    final List<String>? imagePathsToSave = _isEditing ? widget.expenseToEdit?.receiptUrls : null;

    try {
      setState(() => _isLoading = true);

      Category? selectedCategoryObj;
      if (_selectedCategoryId != null && _allCategories.isNotEmpty) {
        try {
          selectedCategoryObj = _allCategories.firstWhere((cat) => cat.id == _selectedCategoryId);
        } catch (e) { selectedCategoryObj = null;}
      }
      String? fullCategoryName = selectedCategoryObj != null ? '${expenseCategoryTypeToDisplayString(selectedCategoryObj.type)} - ${selectedCategoryObj.name}' : (_selectedExpenseType != null ? expenseCategoryTypeToDisplayString(_selectedExpenseType!) : null);
      ExpenseCategoryType? resolvedCategoryType = selectedCategoryObj?.type ?? _selectedExpenseType;


      String? personaQueRecibioValue;
      if ((_selectedExpenseType == ExpenseCategoryType.presupuesto || _selectedExpenseType == ExpenseCategoryType.ofrendaDeAyuno) &&
          _selectedPaymentType == PaymentType.efectivo) {
        personaQueRecibioValue = _personaQueRecibioController.text.trim().isNotEmpty ? _personaQueRecibioController.text.trim() : null;
      }

      String? pagadoAValue;
      if (_selectedExpenseType == ExpenseCategoryType.presupuesto || _selectedExpenseType == ExpenseCategoryType.ofrendaDeAyuno) {
        pagadoAValue = _pagadoAController.text.trim().isNotEmpty ? _pagadoAController.text.trim() : null;
      }

      final expenseData = Expense(
        id: _isEditing ? widget.expenseToEdit!.id : null,
        extractionId: _currentExtraction.id!,
        fundAdvanceId: _isEditing ? widget.expenseToEdit!.fundAdvanceId : null,
        amount: expenseAmount,
        categoryId: _selectedCategoryId,
        description: _descriptionController.text,
        date: _selectedDate,
        receiptUrls: imagePathsToSave,
        additionalExtractionId: _usesMultipleExtractions ? _additionalExtraction?.id : null,
        amountFromPrimary: _usesMultipleExtractions ? _amountFromPrimary : expenseAmount,
        amountFromAdditional: _usesMultipleExtractions ? _amountFromAdditional : null,
        personaQueRecibio: personaQueRecibioValue,
        pagadoA: pagadoAValue,
        // nombreUnidad: null, // Not saving this field
        beneficiarioOfrenda: _selectedExpenseType == ExpenseCategoryType.ofrendaDeAyuno ? (_beneficiarioOfrendaController.text.trim().isNotEmpty ? _beneficiarioOfrendaController.text.trim() : null) : null,
        importeEnLetras: _importeEnLetrasController.text.trim().isNotEmpty ? _importeEnLetrasController.text.trim() : null,
        numeroReferencia: _numeroReferenciaController.text.trim().isNotEmpty ? _numeroReferenciaController.text.trim() : null,
        numeroReferenciaAdicional: _usesMultipleExtractions && _additionalExtraction != null ? _generateAdditionalReference(_additionalExtraction!) : null,
        categoryName: fullCategoryName,
        categoryType: resolvedCategoryType,
      );

      if (_isEditing) {
        await _expenseService.updateExpense(expenseData);
        _showMessage('Gasto actualizado con éxito!');
      } else {
        await _expenseService.createExpense(expenseData);
        _showMessage(
          _usesMultipleExtractions
              ? 'Gasto registrado usando ${_additionalExtraction!.reason} como extracción adicional!'
              : 'Gasto registrado con éxito!'
        );
      }

      final updatedExtraction = await _extractionService.getExtractionById(_currentExtraction.id!);
      if (updatedExtraction != null && mounted) {
        setState(() { _currentExtraction = updatedExtraction; });
      }

      if (!_isEditing) {
         _clearForm();
      } else if (mounted) {
        Navigator.pop(context, _dataChanged);
      }

    } catch (e) {
      _showMessage('Error guardando gasto: $e', isError: true);
    } finally {
       if (mounted) setState(() => _isLoading = false);
    }
  }


  void _clearForm() {
    _amountController.clear();
    _descriptionController.clear();
    _personaQueRecibioController.clear();
    _pagadoAController.clear();
    _nombreUnidadController.clear();
    _beneficiarioOfrendaController.clear();
    _importeEnLetrasController.clear();
    _numeroReferenciaController.clear();

    setState(() {
      _selectedCategoryId = null;
      _selectedPaymentType = PaymentType.efectivo;
      _selectedDate = _currentExtraction.date;
      _usesMultipleExtractions = false;
      _additionalExtraction = null;
      _amountFromPrimary = null;
      _amountFromAdditional = null;
      // _newlySelectedImages = []; // If handling images
      // _existingImagePaths = [];  // If handling images
    });
    _updateNumeroReferencia();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
      ),
    );
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
        _dataChanged = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _allCategories.isEmpty && !_isEditing) {
      return Scaffold(
        appBar: AppBar(title: Text(_isEditing ? 'Editar Gasto' : 'Registrar Nuevo Gasto')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _dataChanged);
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Editar Gasto' : 'Registrar Nuevo Gasto'),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.account_balance_wallet_outlined,
                            color: Theme.of(context).primaryColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Extracción Principal',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _currentExtraction.reason,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (_currentExtraction.extractionCode != null &&
                                  _currentExtraction.extractionCode!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Código: ${_currentExtraction.extractionCode}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade600,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          _buildInfoRow(
                            'Fecha:',
                            DateFormatters.formatShortDate(_currentExtraction.date),
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            'Monto Extraído:',
                            DateFormatters.formatCurrency(_currentExtraction.amount),
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            'Saldo Disponible:',
                            DateFormatters.formatCurrency(_currentExtraction.availableBalance),
                            valueColor: _currentExtraction.availableBalance >= 0
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (_usesMultipleExtractions && _additionalExtraction != null) ...[
                const SizedBox(height: 16),
                CustomCard(
                  backgroundColor: Colors.orange.shade50,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.add_circle_outline,
                              color: Colors.orange.shade700,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Extracción Adicional',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _additionalExtraction!.reason,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (_additionalExtraction!.extractionCode != null && _additionalExtraction!.extractionCode!.isNotEmpty)
                                  Text(
                                    'Código: ${_additionalExtraction!.extractionCode}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Column(
                          children: [
                            _buildInfoRow(
                              'Saldo Disponible (Adic.):',
                              DateFormatters.formatCurrency(_additionalExtraction!.availableBalance),
                            ),
                            if (_amountFromPrimary != null || _amountFromAdditional != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Distribución del Gasto',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (_amountFromPrimary != null)
                                      _buildDistributionRow(
                                        'De Ext. Principal:',
                                        DateFormatters.formatCurrency(_amountFromPrimary!),
                                        Icons.account_balance_wallet_outlined,
                                      ),
                                    if (_amountFromAdditional != null) ...[
                                      const SizedBox(height: 4),
                                      _buildDistributionRow(
                                        'De Ext. Adicional:',
                                        DateFormatters.formatCurrency(_amountFromAdditional!),
                                        Icons.add_circle_outline,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              CustomCard(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_isEditing ? 'Editar Detalles del Gasto' : 'Registrar Nuevo Gasto', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 20),
                       GestureDetector(
                        onTap: () => _selectDate(context),
                        child: AbsorbPointer(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Fecha del Gasto',
                              prefixIcon: Icon(Icons.calendar_today_outlined),
                              suffixIcon: Icon(Icons.arrow_drop_down_outlined),
                            ), // Uses global theme for border
                            controller: TextEditingController(text: DateFormatters.formatShortDate(_selectedDate)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<PaymentType>(
                        value: _selectedPaymentType,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de Pago',
                          prefixIcon: Icon(Icons.payment_outlined),
                        ),
                        items: PaymentType.values.map((type) => DropdownMenuItem<PaymentType>(value: type, child: Text(paymentTypeToDisplayString(type)))).toList(),
                        onChanged: (PaymentType? newValue) {
                          setState(() {
                            _selectedPaymentType = newValue ?? PaymentType.efectivo;
                            if (_selectedPaymentType == PaymentType.tarjeta) _personaQueRecibioController.clear();
                            _updateNumeroReferencia();
                            _dataChanged = true;
                          });
                        },
                        validator: (value) => value == null ? 'Seleccione un tipo de pago.' : null,
                        isExpanded: true,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<ExpenseCategoryType>(
                        value: _selectedExpenseType,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de Gasto Principal',
                          prefixIcon: Icon(Icons.folder_special_outlined),
                        ),
                        items: ExpenseCategoryType.values.map((type) => DropdownMenuItem<ExpenseCategoryType>(value: type, child: Text(expenseCategoryTypeToDisplayString(type)))).toList(),
                        onChanged: (ExpenseCategoryType? newValue) {
                          setState(() {
                            _selectedExpenseType = newValue;
                            _selectedCategoryId = null;
                            _clearConditionalFields();
                            _filterCategoriesForSelectedType();
                            _updateNumeroReferencia();
                            _dataChanged = true;
                          });
                        },
                        validator: (value) => value == null ? 'Seleccione un tipo principal.' : null,
                        isExpanded: true,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: _selectedCategoryId,
                        decoration: const InputDecoration(
                          labelText: 'Subcategoría Específica',
                          prefixIcon: Icon(Icons.bookmark_border_outlined),
                        ),
                        items: _filteredCategories.map<DropdownMenuItem<int>>((Category category) => DropdownMenuItem<int>(value: category.id, child: Text(category.name))).toList(),
                        onChanged: (_selectedExpenseType == null || _filteredCategories.isEmpty) ? null : (int? newValue) => setState(() {
                           _selectedCategoryId = newValue;
                           _dataChanged = true;
                        }),
                        validator: (value) => value == null ? 'Seleccione una subcategoría.' : null,
                        isExpanded: true,
                        hint: (_selectedExpenseType == null || _filteredCategories.isEmpty) ? const Text("Seleccione un tipo principal primero") : const Text("Seleccione subcategoría..."),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _amountController,
                        decoration: InputDecoration(
                          labelText: 'Monto del Gasto',
                          prefixIcon: const Icon(Icons.payments_outlined),
                          helperText: _usesMultipleExtractions ? 'Este gasto usa múltiples extracciones' : null,
                          suffixIcon: _usesMultipleExtractions
                            ? Container(
                                margin: const EdgeInsets.all(8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(12)),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [ Icon(Icons.call_split_outlined, size: 16, color: Colors.orange.shade700), const SizedBox(width: 4), Text('MÚLTIPLE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.orange.shade700))]))
                            : null,
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [_currencyInputFormatter],
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Por favor, ingrese un monto.';
                          final cleanValue = value.replaceAll(RegExp(r'[^0-9]'), '');
                          if (cleanValue.isEmpty || double.tryParse(cleanValue) == null || double.parse(cleanValue) <= 0) return 'Ingrese un monto válido mayor a cero.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(labelText: 'Descripción del Gasto', prefixIcon: Icon(Icons.description_outlined)),
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        validator: (value) => (value == null || value.trim().isEmpty) ? 'Por favor, ingrese una descripción.' : null,
                      ),
                      ConditionalFields(
                        selectedType: _selectedExpenseType,
                        selectedPaymentType: _selectedPaymentType,
                        personaQueRecibioController: _personaQueRecibioController,
                        pagadoAController: _pagadoAController,
                        nombreUnidadController: _nombreUnidadController, // Correctly passed
                        beneficiarioOfrendaController: _beneficiarioOfrendaController,
                        importeEnLetrasController: _importeEnLetrasController,
                        numeroReferenciaController: _numeroReferenciaController,
                      ),
                      const SizedBox(height: 24),
                      // Placeholder for image selection UI if this screen variant needs it
                      // For now, it relies on imagePathsToSave from widget.expenseToEdit for edits.
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (_isEditing)
                            TextButton(
                              onPressed: () => Navigator.pop(context, _dataChanged),
                              child: const Text('Cancelar'),
                            ),
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : _saveExpense,
                            icon: Icon(_isEditing ? Icons.save_as_outlined : Icons.add_circle_outline),
                            label: Text(_isEditing ? 'Actualizar Gasto' : 'Guardar Gasto'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor, // Uses global theme
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_selectedExpenseType != null)
                CustomCard(
                  backgroundColor: Colors.blue.shade50,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Información Importante',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: Colors.blue.shade600,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_usesMultipleExtractions)
                        const Text(
                          '• Este gasto utiliza fondos de múltiples extracciones.\n• La distribución se calculó automáticamente.\n• Ambas extracciones quedarán registradas en el comprobante.\n• El sistema detectó automáticamente que el monto superaba el saldo disponible.\n• El PDF de autorización se genera y guarda automáticamente al finalizar (si la cuenta está configurada).',
                          style: TextStyle(fontSize: 13, height: 1.5),
                        )
                      else if (_selectedExpenseType == ExpenseCategoryType.presupuesto)
                        Text(
                          _selectedPaymentType == PaymentType.efectivo
                              ? '• Campos para Presupuesto (Efectivo):\n  - Persona que Recibió el Fondo\n  - Pagado A (Comercio/Proveedor)\n• El número de referencia e importe en letras se generan automáticamente.\n• El PDF de autorización se genera y guarda automáticamente (si la cuenta está configurada).'
                              : '• Campos para Presupuesto (Tarjeta):\n  - Pagado A (Comercio/Proveedor)\n  - Número de referencia del ticket de compra (manual).\n• El importe en letras se genera automáticamente.\n• El PDF de autorización se genera y guarda automáticamente (si la cuenta está configurada).',
                          style: const TextStyle(fontSize: 13, height: 1.5),
                        )
                      else if (_selectedExpenseType == ExpenseCategoryType.ofrendaDeAyuno)
                        Text(
                          _selectedPaymentType == PaymentType.efectivo
                              ? '• Campos para Ofrenda de Ayuno (Efectivo):\n  - Persona que Recibió el Fondo\n  - Pagado/Entregado A (Beneficiario/Institución)\n  - Beneficiario Principal de Ofrenda de Ayuno\n• El número de referencia e importe en letras se generan automáticamente.\n• El PDF de autorización se genera y guarda automáticamente (si la cuenta está configurada).'
                              : '• Campos para Ofrenda de Ayuno (Tarjeta):\n  - Pagado/Entregado A (Beneficiario/Institución)\n  - Beneficiario Principal de Ofrenda de Ayuno\n  - Número de referencia de la transacción (manual).\n• El importe en letras se genera automáticamente.\n• El PDF de autorización se genera y guarda automáticamente (si la cuenta está configurada).',
                          style: const TextStyle(fontSize: 13, height: 1.5),
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

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? Colors.black87,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionRow(String label, String amount, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.blue.shade600),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.blue.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            amount,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.blue.shade700,
            ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}