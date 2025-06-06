// lib/screens/expenses/expense_registration_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import '../../models/models.dart';
import '../../models/enums.dart';
import '../../services/expense_service.dart';
import '../../services/category_service.dart';
import '../../services/extraction_service.dart';
import '../../services/photo_service.dart';
import '../../services/configuration_service.dart';
import '../../services/pdf_storage_service.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/number_to_words_helper.dart';
import '../../utils/date_formatters.dart';
import '../../utils/pdf_generator.dart';
import '../../widgets/common/custom_card.dart';
import '../../widgets/common/receipt_image_widget.dart';
import '../../widgets/forms/conditional_fields.dart';
import '../../widgets/forms/additional_extraction_dialog.dart';

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
  final ConfigurationService _configurationService = ConfigurationService();

  late Extraction _currentExtraction;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _personaQueRecibioController = TextEditingController();
  final TextEditingController _pagadoAController = TextEditingController();
  final TextEditingController _nombreUnidadController = TextEditingController(); // Controller still exists
  final TextEditingController _beneficiarioOfrendaController = TextEditingController();
  final TextEditingController _importeEnLetrasController = TextEditingController();
  final TextEditingController _numeroReferenciaController = TextEditingController();

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

  List<File> _newlySelectedImages = [];
  List<String> _existingImagePaths = [];
  bool _isLoadingImage = false;

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

  Future<void> _handlePhotoSelection() async {
    print('📸 Iniciando selección de foto (múltiple)...');

    setState(() {
      _isLoadingImage = true;
    });

    try {
      final File? imageFile = await PhotoService.showImagePickerOptions(context);

      print('📸 Resultado del PhotoService: ${imageFile?.path ?? "null"}');

      if (imageFile != null && mounted) {
        setState(() {
          _newlySelectedImages.add(imageFile);
          _dataChanged = true;
        });
        _showMessage('Foto adjuntada exitosamente (${_newlySelectedImages.length + _existingImagePaths.length} en total)');
        print('✅ Foto procesada correctamente y añadida a la lista');
      } else {
        print('❌ No se seleccionó imagen - usuario canceló o cerró');
      }
    } catch (e) {
      print('❌ ERROR en _handlePhotoSelection: $e');
      if (mounted) {
        if (e.toString().contains('PERMISSION_DENIED')) {
          print('🚨 Error de permisos detectado, mostrando ayuda...');
          _showPermissionHelpDialog();
        } else {
          _showMessage('Error seleccionando foto: $e', isError: true);
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingImage = false;
        });
      }
    }
  }

  void _showPermissionHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_outlined, color: Colors.orange[600]),
            const SizedBox(width: 8),
            const Text('Permisos Denegados'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Para agregar fotos de facturas, necesitas conceder permisos en la configuración de tu teléfono:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            _buildPermissionStep('Cámara', 'Para tomar fotos nuevas'),
            _buildPermissionStep('Fotos/Almacenamiento', 'Para elegir fotos existentes'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📱 Cómo activar permisos:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. Ve a Configuración del teléfono\n2. Busca "Apps" o "Aplicaciones"\n3. Encuentra "finanzas_local_sud"\n4. Toca "Permisos"\n5. Activa Cámara y Fotos/Almacenamiento\n6. Regresa a la app e intenta de nuevo',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.green[600], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Una vez que actives los permisos, ya no verás este mensaje.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.check_outlined),
            label: const Text('Entendido'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionStep(String permission, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: Colors.green[600], size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  permission,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _removePhoto(dynamic imageIdentifier, bool isExistingPath) async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Foto'),
        content: const Text('¿Estás seguro de que deseas eliminar esta foto de la factura?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmDelete == true) {
      setState(() {
        if (isExistingPath && imageIdentifier is String) {
          _existingImagePaths.remove(imageIdentifier);
        } else if (!isExistingPath && imageIdentifier is File) {
          _newlySelectedImages.remove(imageIdentifier);
        }
        _dataChanged = true;
      });
      _showMessage('Foto eliminada de la selección actual');
    }
  }

  void _showFullScreenImage(dynamic imageSource) {
    String? imagePathToShow;
    File? imageFileToShow;

    if (imageSource is File) {
      imageFileToShow = imageSource;
    } else if (imageSource is String) {
      imagePathToShow = imageSource;
    } else {
      return;
    }

    if (imageFileToShow == null && (imagePathToShow == null || imagePathToShow.isEmpty)) {
      _showMessage('No se puede mostrar la imagen.', isError: true);
      return;
    }

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: imageFileToShow != null
                    ? Image.file(imageFileToShow, fit: BoxFit.contain)
                    : Image.file(File(imagePathToShow!), fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 20,
              right: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white, size: 24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
      _newlySelectedImages = [];
      _existingImagePaths = [];
    });
    _updateNumeroReferencia();
  }

  void _clearConditionalFields() {
    _personaQueRecibioController.clear();
    _pagadoAController.clear();
    _nombreUnidadController.clear();
    _beneficiarioOfrendaController.clear();
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
        await _handleAmountValidationAndSelection(expenseAmount, debugSource: 'realTime');
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
          await _handleAmountValidationAndSelection(expenseAmount, debugSource: 'realTime-reset');
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
      _numeroReferenciaController.text = widget.expenseToEdit?.numeroReferencia ?? '';
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
    } else if (_selectedCategoryId == null && _filteredCategories.isNotEmpty && !_isEditing) {
      // _selectedCategoryId = _filteredCategories.first.id;
    }
    if (mounted) setState(() {});
  }

  void _loadExpenseData(Expense expense) {
    _amountController.text = _currencyInputFormatter.formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: expense.amount.toInt().toString())).text;
    _descriptionController.text = expense.description;
    _personaQueRecibioController.text = expense.personaQueRecibio ?? '';
    _pagadoAController.text = expense.pagadoA ?? '';
    // _nombreUnidadController.text = expense.nombreUnidad ?? ''; // Field removed from UI
    _beneficiarioOfrendaController.text = expense.beneficiarioOfrenda ?? '';
    _importeEnLetrasController.text = expense.importeEnLetras ?? '';
    _numeroReferenciaController.text = expense.numeroReferencia ?? '';

    if (expense.receiptUrls != null && expense.receiptUrls!.isNotEmpty) {
      _existingImagePaths = List<String>.from(expense.receiptUrls!);
    } else {
      _existingImagePaths = [];
    }
    _newlySelectedImages = [];

    if (expense.usesMultipleExtractions) {
      _usesMultipleExtractions = true;
      _amountFromPrimary = expense.amountFromPrimary;
      _amountFromAdditional = expense.amountFromAdditional;
      if (expense.additionalExtractionId != null) {
        _loadAdditionalExtraction(expense.additionalExtractionId!);
      }
    }

    if (expense.categoryId != null) {
        final originalCategory = _allCategories.firstWhere(
            (cat) => cat.id == expense.categoryId,
            orElse: () => Category(id: -1, name: 'Categoría Eliminada', type: expense.categoryType ?? ExpenseCategoryType.presupuesto)
        );
        _selectedExpenseType = originalCategory.type;
    } else if (expense.categoryType != null) {
        _selectedExpenseType = expense.categoryType;
    } else {
        _selectedExpenseType = ExpenseCategoryType.presupuesto;
    }

    if (_selectedExpenseType == ExpenseCategoryType.presupuesto || _selectedExpenseType == ExpenseCategoryType.ofrendaDeAyuno) {
        _selectedPaymentType = (expense.personaQueRecibio == null || expense.personaQueRecibio!.isEmpty)
            ? PaymentType.tarjeta
            : PaymentType.efectivo;
    } else {
        _selectedPaymentType = PaymentType.efectivo;
    }

    if (expense.categoryId != null) {
      _filterCategoriesForSelectedType();
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

  Future<void> _handleAmountValidationAndSelection(double expenseAmount, {bool isFromSave = false, String debugSource = 'unknown'}) async {
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
        _showMessage('Operación cancelada o sin selección. Ajuste el monto o seleccione una extracción adicional si es necesario.', isError: true);
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
      double totalAvailable = currentPrimaryBalance;
      if (_usesMultipleExtractions && _additionalExtraction != null) {
        final currentAdditionalBalance = await _extractionService.getAvailableBalance(_additionalExtraction!.id!);
        totalAvailable += currentAdditionalBalance;
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
        await _handleAmountValidationAndSelection(expenseAmount, isFromSave: true, debugSource: 'saveExpense-recheck');
        if (_usesMultipleExtractions && _additionalExtraction != null) {
            final recheckPrimaryBalance = await _extractionService.getAvailableBalance(_currentExtraction.id!);
            final recheckAdditionalBalance = await _extractionService.getAvailableBalance(_additionalExtraction!.id!);
             if (expenseAmount > recheckPrimaryBalance) {
                _amountFromPrimary = recheckPrimaryBalance > 0 ? recheckPrimaryBalance : 0;
                _amountFromAdditional = expenseAmount - _amountFromPrimary!;
                if (_amountFromAdditional! > recheckAdditionalBalance) {
                    _showMessage('Fondos insuficientes tras seleccionar extracción adicional. Revise saldos.', isError: true);
                    return;
                }
            } else {
                 _amountFromPrimary = expenseAmount;
                 _amountFromAdditional = 0;
            }
        } else if (expenseAmount > await _extractionService.getAvailableBalance(_currentExtraction.id!)) {
          _showMessage('Fondos insuficientes en la extracción principal.', isError: true);
          return;
        }
      } else {
          _amountFromPrimary = expenseAmount;
          _amountFromAdditional = null;
          _usesMultipleExtractions = false;
          _additionalExtraction = null;
      }
    }

    List<String> finalImagePaths = List<String>.from(_existingImagePaths);
    for (File newImageFile in _newlySelectedImages) {
      try {
        File savedFile = await PhotoService.saveImageLocally(newImageFile);
        finalImagePaths.add(savedFile.path);
      } catch (e) {
        _showMessage('Error guardando una de las imágenes: $e', isError: true);
      }
    }

    int? createdExpenseId;

    try {
      setState(() => _isLoading = true);

      Category? selectedCategoryObj;
      if (_selectedCategoryId != null && _allCategories.isNotEmpty) {
        try {
          selectedCategoryObj = _allCategories.firstWhere((cat) => cat.id == _selectedCategoryId);
        } catch (e) {
          selectedCategoryObj = null;
        }
      }
      String? fullCategoryName;
      ExpenseCategoryType? resolvedCategoryType;

      if (selectedCategoryObj != null) {
        fullCategoryName = '${expenseCategoryTypeToDisplayString(selectedCategoryObj.type)} - ${selectedCategoryObj.name}';
        resolvedCategoryType = selectedCategoryObj.type;
      } else if (_selectedExpenseType != null) {
        resolvedCategoryType = _selectedExpenseType;
        fullCategoryName = expenseCategoryTypeToDisplayString(_selectedExpenseType!);
      }

      String? personaQueRecibioValue;
      if ((_selectedExpenseType == ExpenseCategoryType.presupuesto || _selectedExpenseType == ExpenseCategoryType.ofrendaDeAyuno) &&
          _selectedPaymentType == PaymentType.efectivo) {
        personaQueRecibioValue = _personaQueRecibioController.text.trim().isNotEmpty
                                ? _personaQueRecibioController.text.trim()
                                : null;
      }

      String? pagadoAValue;
      if (_selectedExpenseType == ExpenseCategoryType.presupuesto || _selectedExpenseType == ExpenseCategoryType.ofrendaDeAyuno) {
        pagadoAValue = _pagadoAController.text.trim().isNotEmpty
                      ? _pagadoAController.text.trim()
                      : null;
      }

      Expense expenseData = Expense(
        id: _isEditing ? widget.expenseToEdit!.id : null,
        extractionId: _currentExtraction.id!,
        fundAdvanceId: _isEditing ? widget.expenseToEdit!.fundAdvanceId : null, // Preserve if editing, null for new direct expenses
        amount: expenseAmount,
        categoryId: _selectedCategoryId,
        description: _descriptionController.text,
        date: _selectedDate,
        receiptUrls: finalImagePaths.isNotEmpty ? finalImagePaths : null,
        additionalExtractionId: _usesMultipleExtractions ? _additionalExtraction?.id : null,
        amountFromPrimary: _usesMultipleExtractions ? _amountFromPrimary : expenseAmount,
        amountFromAdditional: _usesMultipleExtractions ? _amountFromAdditional : null,
        personaQueRecibio: personaQueRecibioValue,
        pagadoA: pagadoAValue,
        // nombreUnidad: null, // Field removed from form, ensure it's not saved with old controller data
        beneficiarioOfrenda: _selectedExpenseType == ExpenseCategoryType.ofrendaDeAyuno
                              ? (_beneficiarioOfrendaController.text.trim().isNotEmpty ? _beneficiarioOfrendaController.text.trim() : null)
                              : null,
        importeEnLetras: _importeEnLetrasController.text.trim().isNotEmpty ? _importeEnLetrasController.text.trim() : null,
        numeroReferencia: _numeroReferenciaController.text.trim().isNotEmpty ? _numeroReferenciaController.text.trim() : null,
        numeroReferenciaAdicional: _usesMultipleExtractions && _additionalExtraction != null ? _generateAdditionalReference(_additionalExtraction!) : null,
        categoryName: fullCategoryName,
        categoryType: resolvedCategoryType,
      );

      if (_isEditing) {
        List<String> oldImagePaths = widget.expenseToEdit?.receiptUrls ?? [];
        for (String oldPath in oldImagePaths) {
          if (!finalImagePaths.contains(oldPath)) {
            await PhotoService.deleteImage(oldPath);
          }
        }
        await _expenseService.updateExpense(expenseData);
        _showMessage('Gasto actualizado con éxito!');
        createdExpenseId = expenseData.id;
      } else {
        createdExpenseId = await _expenseService.createExpense(expenseData);
        _showMessage(
          _usesMultipleExtractions
              ? 'Gasto registrado usando ${_additionalExtraction!.reason} como extracción adicional!'
              : 'Gasto registrado con éxito!'
        );
      }

      if (mounted && createdExpenseId != null) {
        final expenseForPdf = _isEditing ? expenseData : expenseData.copyWith(id: createdExpenseId);
        try {
          print('📄 Iniciando generación automática de PDF para gasto ID: ${expenseForPdf.id}');

          final accountConfig = await _configurationService.getAccountConfiguration();

          if (!accountConfig.isFullyConfigured) {
            _showMessage('⚠️ Configuración de cuenta incompleta. El PDF no se generó automáticamente. Por favor, complete la configuración e intente generarlo desde los detalles de la extracción.', isError: true);
          } else {
            final Uint8List pdfBytes = await PdfGenerator.generarAutorizacionDesembolso(
              expenseForPdf,
              accountConfig,
            );

            final fileName = PdfStorageService.generatePdfFileName(expenseForPdf.id!);
            await PdfStorageService.savePdfLocally(pdfBytes, fileName);

            _showMessage('✅ PDF del gasto generado y guardado automáticamente.');
            print('✅ PDF guardado automáticamente: $fileName');
          }
        } catch (e) {
          _showMessage('Error generando/guardando PDF del gasto: $e', isError: true);
          print('❌ Error en generación automática de PDF: $e');
        }
      }

      final updatedExtraction = await _extractionService.getExtractionById(_currentExtraction.id!);
      if (updatedExtraction != null && mounted) {
        setState(() {
          _currentExtraction = updatedExtraction;
        });
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
                            ),
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
                        nombreUnidadController: _nombreUnidadController, // Passed but UI field removed from ConditionalFields
                        beneficiarioOfrendaController: _beneficiarioOfrendaController,
                        importeEnLetrasController: _importeEnLetrasController,
                        numeroReferenciaController: _numeroReferenciaController,
                      ),
                      const SizedBox(height: 24),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.camera_alt_outlined, color: Colors.green.shade600, size: 20),
                              const SizedBox(width: 8),
                              Text('Fotos de la Factura', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                              const Spacer(),
                              if ((_newlySelectedImages.isNotEmpty || _existingImagePaths.isNotEmpty))
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(10)),
                                  child: Text('${_newlySelectedImages.length + _existingImagePaths.length} Foto(s)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.green.shade700)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                            child: Column(
                              children: [
                                if (_newlySelectedImages.isEmpty && _existingImagePaths.isEmpty)
                                  Center(
                                    child: Column(
                                      children: [
                                        Icon(Icons.photo_library_outlined, size: 40, color: Colors.grey.shade400),
                                        const SizedBox(height: 8),
                                        const Text('Sin fotos adjuntas', style: TextStyle(color: Colors.grey)),
                                        const SizedBox(height: 8),
                                      ],
                                    ),
                                  )
                                else
                                  Wrap(
                                    spacing: 8.0,
                                    runSpacing: 8.0,
                                    children: [
                                      ..._existingImagePaths.map((path) => ReceiptImageWidget(imagePath: path, onTap: () => _showFullScreenImage(path), onDelete: () => _removePhoto(path, true), width: 80, height: 100)).toList(),
                                      ..._newlySelectedImages.map((file) => ReceiptImageWidget(imagePath: file.path, onTap: () => _showFullScreenImage(file), onDelete: () => _removePhoto(file, false), width: 80, height: 100)).toList(),
                                    ],
                                  ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: _isLoadingImage ? null : _handlePhotoSelection,
                                  icon: _isLoadingImage ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_a_photo_outlined, size: 18),
                                  label: Text(_isLoadingImage ? 'Procesando...' : 'Agregar Foto'),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          if (_isEditing)
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context, _dataChanged),
                                child: const Text('Cancelar'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          if (_isEditing) const SizedBox(width: 12),
                          Expanded(
                            flex: _isEditing ? 2 : 1,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _saveExpense,
                              icon: _isLoading
                                ? Container(width: 18, height: 18, margin: const EdgeInsets.only(right: 8), child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Icon(_isEditing ? Icons.save_as_outlined : Icons.add_circle_outline),
                              label: Text(_isLoading ? 'Guardando...' : (_isEditing ? 'Actualizar Gasto' : 'Guardar Gasto')),
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
                          '• Este gasto utiliza fondos de múltiples extracciones.\n• La distribución se calculó automáticamente.\n• Ambas extracciones quedarán registradas en el comprobante.\n• El sistema detectó automáticamente que el monto superaba el saldo disponible.\n• Las fotos de la factura son opcionales pero recomendadas.\n• ✅ El PDF de autorización se genera y guarda automáticamente al finalizar.',
                          style: TextStyle(fontSize: 13, height: 1.5),
                        )
                      else if (_selectedExpenseType == ExpenseCategoryType.presupuesto)
                        Text( // MODIFIED: Removed "Nombre de la Unidad" mention
                          _selectedPaymentType == PaymentType.efectivo
                              ? '• Campos para Presupuesto (Efectivo):\n  - Persona que Recibió el Fondo\n  - Pagado A (Comercio/Proveedor)\n• El número de referencia e importe en letras se generan automáticamente.\n• Las fotos de la factura son opcionales pero recomendadas.\n• ✅ El PDF de autorización se genera y guarda automáticamente.'
                              : '• Campos para Presupuesto (Tarjeta):\n  - Pagado A (Comercio/Proveedor)\n  - Número de referencia del ticket de compra (manual).\n• El importe en letras se genera automáticamente.\n• Las fotos de la factura son opcionales pero recomendadas.\n• ✅ El PDF de autorización se genera y guarda automáticamente.',
                          style: const TextStyle(fontSize: 13, height: 1.5),
                        )
                      else if (_selectedExpenseType == ExpenseCategoryType.ofrendaDeAyuno)
                        Text(
                          _selectedPaymentType == PaymentType.efectivo
                              ? '• Campos para Ofrenda de Ayuno (Efectivo):\n  - Persona que Recibió el Fondo\n  - Pagado/Entregado A (Beneficiario/Institución)\n  - Beneficiario Principal de Ofrenda de Ayuno\n• El número de referencia e importe en letras se generan automáticamente.\n• Las fotos de la factura son opcionales pero recomendadas.\n• ✅ El PDF de autorización se genera y guarda automáticamente.'
                              : '• Campos para Ofrenda de Ayuno (Tarjeta):\n  - Pagado/Entregado A (Beneficiario/Institución)\n  - Beneficiario Principal de Ofrenda de Ayuno\n  - Número de referencia de la transacción (manual).\n• El importe en letras se genera automáticamente.\n• Las fotos de la factura son opcionales pero recomendadas.\n• ✅ El PDF de autorización se genera y guarda automáticamente.',
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? Colors.black87,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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