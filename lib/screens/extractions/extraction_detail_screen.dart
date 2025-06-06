// lib/screens/extractions/extraction_detail_screen.dart
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:open_filex/open_filex.dart';

import '../../models/models.dart';
import '../../models/enums.dart';
import '../../services/extraction_service.dart';
import '../../services/expense_service.dart';
import '../../services/deposit_service.dart';
import '../../services/category_service.dart';
import '../../services/configuration_service.dart';
import '../../services/photo_service.dart';
import '../../services/pdf_storage_service.dart';
import '../../services/fund_advance_service.dart'; 
import '../../widgets/common/loading_widget.dart';
import '../../widgets/extraction_detail/basic_info_card.dart';
import '../../widgets/extraction_detail/financial_summary_card.dart';
import '../../widgets/extraction_detail/deposits_section.dart';
import '../../widgets/extraction_detail/expenses_list.dart';
import '../../widgets/extraction_detail/deposit_dialog.dart';
import '../../widgets/extraction_detail/fund_advances_section.dart'; 
import '../expenses/expense_registration_screen.dart';
import 'add_extraction_screen.dart';
import '../fund_advances/add_fund_advance_screen.dart'; 
import '../../utils/pdf_generator.dart';
import '../../utils/date_formatters.dart';

class ExtractionDetailScreen extends StatefulWidget {
  final int extractionId;
  const ExtractionDetailScreen({super.key, required this.extractionId});

  @override
  State<ExtractionDetailScreen> createState() => _ExtractionDetailScreenState();
}

class _ExtractionDetailScreenState extends State<ExtractionDetailScreen> {
  final ExtractionService _extractionService = ExtractionService();
  final ExpenseService _expenseService = ExpenseService();
  final DepositService _depositService = DepositService();
  final CategoryService _categoryService = CategoryService();
  final ConfigurationService _configurationService = ConfigurationService();
  final FundAdvanceService _fundAdvanceService = FundAdvanceService(); 

  Extraction? _extraction; 
  List<Expense> _expenses = [];
  List<Map<String, dynamic>> _depositsFromDB = []; // Renamed to avoid confusion
  List<FundAdvance> _fundAdvances = []; 
  Map<int, Category> _categoryMap = {};
  
  bool _isLoading = true;
  bool _dataChangedSinceLoad = false; // Tracks if any action that modifies data has occurred
  
  double get _currentAvailableBalance => _extraction?.availableBalance ?? 0.0;
  bool get _canAddAnything => _currentAvailableBalance > 0;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });

    try {
      final categories = await _categoryService.getAllCategories();
      if (!mounted) return;
      _categoryMap = {for (var cat in categories) cat.id!: cat};

      final extraction = await _extractionService.getExtractionById(widget.extractionId);
      if (!mounted) return;
      if (extraction == null) {
        _showMessage('Extracción no encontrada. Puede haber sido eliminada.', isError: true);
        Navigator.of(context).pop(true); // Pop with true to indicate potential data change
        return;
      }

      final expensesFromDb = await _expenseService.getExpensesForExtraction(widget.extractionId);
      if (!mounted) return;
      _expenses = expensesFromDb.map((exp) {
        final category = _categoryMap[exp.categoryId];
        return exp.copyWith(
          categoryName: category != null 
            ? '${expenseCategoryTypeToDisplayString(category.type)} - ${category.name}' 
            : 'Sin categoría',
          categoryType: category?.type,
        );
      }).toList();

      final deposits = await _depositService.getDepositsForExtraction(widget.extractionId);
      if (!mounted) return;
      final fundAdvances = await _fundAdvanceService.getFundAdvancesForExtraction(widget.extractionId);
      if (!mounted) return;

      setState(() {
        _extraction = extraction; 
        _depositsFromDB = deposits;
        _fundAdvances = fundAdvances; 
        _isLoading = false;
        _dataChangedSinceLoad = false; // Reset flag after loading
      });
    } catch (e) {
      if (mounted) {
        setState(() { _isLoading = false; });
        _showMessage('Error cargando datos: $e', isError: true);
      }
    }
  }
  
  Future<void> _refreshData() async {
    await _loadAllData();
  }

  void _flagDataChanged() {
    if (!_dataChangedSinceLoad) {
      setState(() {
        _dataChangedSinceLoad = true;
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

  Future<void> _depositExcess() async {
    if (_extraction == null) return;
    if (_currentAvailableBalance <= 1.0) { 
      _showMessage('No hay excedente significativo para depositar.', isError: false);
      return;
    }

    // Calculate total deposits from DB for the dialog
    double totalDepositsFromDBVal = _depositsFromDB.fold(0.0, (sum, deposit) => sum + (deposit['amount'] as num).toDouble());

    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => DepositDialog(
        extraction: _extraction!,
        totalExpenses: _extraction!.spentAmount + _extraction!.totalAdvancedAmount, // Total outflows before deposits
        totalDeposits: totalDepositsFromDBVal, // Pass current deposits from DB
      ),
    );
    if (result == true) {
      _flagDataChanged();
      _showMessage('Excedente depositado exitosamente.');
      await _refreshData();
    }
  }

  Future<void> _addNewExpense() async {
    if (_extraction == null) return;
    if (!_canAddAnything) { 
      _showMessage(
        'No hay saldo disponible para agregar más gastos. Saldo actual: ${DateFormatters.formatCurrency(_currentAvailableBalance)}',
        isError: true,
      );
      return;
    }
    final bool? result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ExpenseRegistrationScreen(extraction: _extraction!),
      ),
    );
    if (result == true) {
      _flagDataChanged();
      await _refreshData();
    }
  }

  Future<void> _addNewFundAdvance() async {
    if (_extraction == null) return;
    if (!_canAddAnything) {
      _showMessage(
        'No hay saldo disponible en la extracción para entregar dinero. Saldo actual: ${DateFormatters.formatCurrency(_currentAvailableBalance)}',
        isError: true,
      );
      return;
    }
    final bool? result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddFundAdvanceScreen(sourceExtraction: _extraction!),
      ),
    );
    if (result == true) {
      _flagDataChanged();
      await _refreshData();
    }
  }

  Future<void> _editExpense(Expense expense) async {
     if (_extraction == null) return;
    final bool? result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ExpenseRegistrationScreen(
          extraction: _extraction!, // Pass the current _extraction object
          expenseToEdit: expense,
        ),
      ),
    );
    if (result == true) {
      _flagDataChanged();
      await _refreshData();
    }
  }

  Future<void> _deleteExpense(Expense expense) async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Estás seguro de que deseas eliminar este gasto de ${DateFormatters.formatCurrency(expense.amount)}?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_outlined, size: 16, color: Colors.orange[600]),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'También se eliminará el PDF y las fotos asociadas si existen.',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
             if (expense.fundAdvanceId != null) ...[
              const SizedBox(height: 8),
              Container(
                 padding: const EdgeInsets.all(8),
                 decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.blue[200]!)),
                 child: Row(children: [
                    Icon(Icons.info_outline, size:16, color: Colors.blue[600]),
                    const SizedBox(width:8),
                    const Expanded(child: Text('Este gasto está vinculado a una entrega de dinero. Eliminarlo podría afectar el estado de conciliación de la entrega.', style: TextStyle(fontSize:12, color:Colors.blue)))
                 ],)
              )
            ]
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(style: TextButton.styleFrom(foregroundColor: Colors.red), onPressed: () => Navigator.of(context).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );

    if (confirmDelete == true && expense.id != null) {
      try {
        await _expenseService.deleteExpense(expense.id!);
        
        if (expense.id != null) {
          try {
            final fileName = PdfStorageService.generatePdfFileName(expense.id!);
            await PdfStorageService.deletePdf(fileName);
          } catch (e) { print('⚠️ Error eliminando PDF del gasto: $e'); }
        }
        
        if (expense.receiptUrls != null) {
          for (String imagePath in expense.receiptUrls!) {
            try { await PhotoService.deleteImage(imagePath); } 
            catch (e) { print('⚠️ Error eliminando imagen: $e');}
          }
        }
        // TODO: If expense was linked to a FundAdvance, update the FundAdvance status/amountReconciled.
        // This requires more logic in FundAdvanceService.
        _flagDataChanged();
        _showMessage('Gasto y archivos asociados eliminados exitosamente.');
        await _refreshData();
      } catch (e) {
        _showMessage('Error eliminando gasto: $e', isError: true);
      }
    }
  }

  Future<void> _editExtraction() async {
    if (_extraction == null) return;
    final bool? result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => AddExtractionScreen(extractionToEdit: _extraction!)),
    );
    if (result == true) {
      _flagDataChanged();
      await _refreshData();
    }
  }

  Future<void> _deleteExtraction() async {
    if (_extraction == null || _extraction!.id == null) return;

    // Check for related records
    final relatedExpenses = await _expenseService.getExpensesForExtraction(_extraction!.id!);
    final relatedDeposits = await _depositService.getDepositsForExtraction(_extraction!.id!);
    final relatedAdvances = await _fundAdvanceService.getFundAdvancesForExtraction(_extraction!.id!);

    String warningMessage = '¿Estás seguro de que deseas eliminar esta extracción?';
    if (relatedExpenses.isNotEmpty || relatedDeposits.isNotEmpty || relatedAdvances.isNotEmpty) {
        warningMessage += '\n\n⚠️ ¡Atención! Esta acción es irreversible y eliminará también:\n';
        if (relatedExpenses.isNotEmpty) warningMessage += '- ${relatedExpenses.length} gasto(s) asociado(s)\n';
        if (relatedAdvances.isNotEmpty) warningMessage += '- ${relatedAdvances.length} entrega(s) de dinero asociada(s)\n';
        if (relatedDeposits.isNotEmpty) warningMessage += '- ${relatedDeposits.length} depósito(s) asociado(s)\n';
        warningMessage += 'Todos los archivos PDF y fotos de facturas vinculados a estos gastos también serán eliminados.';
    }


    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: Text(warningMessage),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(style: TextButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.red.shade600), onPressed: () => Navigator.of(context).pop(true), child: const Text('Eliminar Todo')),
        ],
      ),
    );
    if (confirmDelete == true) {
      try {
        // Manually delete associated files for expenses if necessary, though CASCADE should handle DB records
        for (var expense in relatedExpenses) {
            if (expense.id != null) {
                final pdfName = PdfStorageService.generatePdfFileName(expense.id!);
                await PdfStorageService.deletePdf(pdfName);
                if (expense.receiptUrls != null) {
                    for (var url in expense.receiptUrls!) {
                        await PhotoService.deleteImage(url);
                    }
                }
            }
        }
        await _extractionService.deleteExtraction(_extraction!.id!); // CASCADE should delete related DB entries
        _showMessage('Extracción y todos los registros asociados eliminados exitosamente.');
        if (mounted) Navigator.pop(context, true); // Indicate data changed
      } catch (e) {
        _showMessage('Error eliminando extracción: $e', isError: true);
      }
    }
  }

  Future<void> _generarYMostrarPdf(Expense expense) async {
    if (_extraction == null || expense.id == null) {
      _showMessage('Datos insuficientes para generar PDF.', isError: true);
      return;
    }
    
    if (!mounted) return;
    setState(() { _isLoading = true; });
    
    String? localPdfPath; 

    try {
      final fileName = PdfStorageService.generatePdfFileName(expense.id!);
      final pdfFileExists = await PdfStorageService.pdfExists(fileName);
      
      if (pdfFileExists) {
        localPdfPath = await PdfStorageService.getPdfPath(fileName);
      } else {
        final accountConfig = await _configurationService.getAccountConfiguration();
        if (!mounted) return;

        if (!accountConfig.isFullyConfigured) {
          final goToConfig = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Configuración Incompleta'),
              content: const Text('Los datos de la unidad o liderazgo no están completos. ¿Desea ir a configurarlos para generar el PDF?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Más tarde')),
                ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Configurar')),
              ],
            )
          );
          if (goToConfig == true && mounted) {
            Navigator.pushNamed(context, '/account-configuration').then((_) => _refreshData());
          }
          setState(() { _isLoading = false; });
          return; 
        }
        
        final Uint8List pdfBytes = await PdfGenerator.generarAutorizacionDesembolso(expense, accountConfig);
        localPdfPath = await PdfStorageService.savePdfLocally(pdfBytes, fileName);
      }

      if (localPdfPath != null && localPdfPath.isNotEmpty && mounted) {
        final OpenResult result = await OpenFilex.open(localPdfPath); 
        if (result.type != ResultType.done) {
          _showMessage('No se pudo abrir el PDF. Mensaje: ${result.message}', isError: true);
        }
      } else if (mounted) { 
         _showMessage('No se pudo obtener la ruta del PDF.', isError: true);
      }
    } catch (e) {
      _showMessage('Error procesando PDF: $e', isError: true);
    } finally {
      if (mounted) { setState(() { _isLoading = false; });}
    }
  }
  
   @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(_extraction?.reason ?? 'Detalle de Extracción')),
        body: const LoadingWidget(message: 'Cargando detalle completo...'),
      );
    }
    if (_extraction == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('No se pudo cargar la extracción. Intente regresar y reabrir.')),
      );
    }
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _dataChangedSinceLoad);
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          title: Text(_extraction!.reason, overflow: TextOverflow.ellipsis),
          centerTitle: true,
          actions: [
            IconButton(icon: const Icon(Icons.refresh), tooltip: 'Actualizar Datos', onPressed: _refreshData),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (String choice) {
                if (choice == 'edit_extraction') _editExtraction();
                else if (choice == 'delete_extraction') _deleteExtraction();
                else if (choice == 'add_advance') _addNewFundAdvance();
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                    value: 'add_advance',
                    child: Row(children: [
                      Icon(Icons.send_to_mobile_outlined, color: Theme.of(context).primaryColorDark),
                      const SizedBox(width: 8),
                      Text('Entregar Dinero a Miembro', style: TextStyle(color: Theme.of(context).primaryColorDark))
                    ])),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(value: 'edit_extraction', child: Row(children: [Icon(Icons.edit_outlined, color: Colors.blue), SizedBox(width: 8), Text('Editar Extracción', style: TextStyle(color: Colors.blue))])),
                const PopupMenuItem<String>(value: 'delete_extraction', child: Row(children: [Icon(Icons.delete_forever, color: Colors.red), SizedBox(width: 8), Text('Eliminar Extracción', style: TextStyle(color: Colors.red))])),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      BasicInfoCard(extraction: _extraction!),
                      FinancialSummaryCard(
                        extraction: _extraction!, 
                        totalExpenses: _extraction!.spentAmount, // Direct expenses
                        totalAdvanced: _extraction!.totalAdvancedAmount, 
                        totalDeposits: _depositsFromDB.fold(0.0, (sum, deposit) => sum + (deposit['amount'] as num).toDouble()),
                        expensesCount: _expenses.where((e) => e.fundAdvanceId == null).length,
                        onDepositExcess: _currentAvailableBalance > 1.0 ? _depositExcess : null,
                      ),
                      DepositsSection(deposits: _depositsFromDB),
                      FundAdvancesSection(fundAdvances: _fundAdvances, extractionId: _extraction!.id!), 
                      ExpensesList( 
                        expenses: _expenses, 
                        onEditExpense: _editExpense,
                        onDeleteExpense: _deleteExpense,
                        onAddExpense: _addNewExpense, // For direct expenses
                        canAddExpenses: _canAddAnything, 
                        onGeneratePdfForItem: _generarYMostrarPdf,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (!_canAddAnything && !_isLoading)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _currentAvailableBalance < 0 ? Colors.red.shade50 : Colors.orange[50],
                  border: Border(top: BorderSide(color: _currentAvailableBalance < 0 ? Colors.red.shade200 : Colors.orange[200]!)),
                ),
                child: Row(children: [
                  Icon(_currentAvailableBalance < 0 ? Icons.error_outline : Icons.info_outline, color: _currentAvailableBalance < 0 ? Colors.red[600] : Colors.orange[600], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _currentAvailableBalance == 0 
                        ? 'Fondos completamente utilizados o asignados. No se pueden agregar más gastos directos o entregas.'
                        : (_currentAvailableBalance < 0 
                            ? '¡Atención! Hay un sobregiro de ${DateFormatters.formatCurrency(_currentAvailableBalance.abs())}. Revisa los movimientos.'
                            : 'Saldo insuficiente para nuevas operaciones. Saldo: ${DateFormatters.formatCurrency(_currentAvailableBalance)}'),
                      style: TextStyle(fontSize: 13, color: _currentAvailableBalance < 0 ? Colors.red[700] : Colors.orange[700], fontWeight: FontWeight.w500),
                    ),
                  ),
                ]),
              ),
          ],
        ),
        floatingActionButton: _canAddAnything
            ? FloatingActionButton.extended(
                onPressed: _addNewExpense, 
                icon: const Icon(Icons.add_shopping_cart_outlined), 
                label: const Text('Gasto Directo'), 
                tooltip: 'Registrar gasto directo de esta extracción')
            : null,
      ),
    );
  }
}