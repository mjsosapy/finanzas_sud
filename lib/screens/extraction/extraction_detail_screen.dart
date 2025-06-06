import 'package:flutter/material.dart';
import 'dart:io';
import '../../models/models.dart';
import '../../models/enums.dart';
import '../../utils/date_formatters.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../services/pdf_storage_service.dart';

class ExpensesList extends StatelessWidget {
  final List<Expense> expenses;
  final Function(Expense) onEditExpense;
  final Function(Expense) onDeleteExpense;
  final VoidCallback onAddExpense;
  final bool canAddExpenses;
  final Function(Expense expense)? onGeneratePdfForItem;

  const ExpensesList({
    super.key,
    required this.expenses,
    required this.onEditExpense,
    required this.onDeleteExpense,
    required this.onAddExpense,
    this.canAddExpenses = true,
    this.onGeneratePdfForItem,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gastos de esta Extracción (${expenses.length})',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.blueGrey[700]
              ),
        ),
        const SizedBox(height: 16),
        
        if (expenses.isEmpty)
          EmptyStateWidget(
            icon: Icons.receipt_long_outlined,
            title: 'No hay gastos registrados',
            subtitle: canAddExpenses 
              ? 'Presiona el botón "+" para registrar el primer gasto.'
              : 'No se pueden agregar gastos sin saldo disponible.',
            action: canAddExpenses 
              ? ElevatedButton.icon(
                  onPressed: onAddExpense,
                  icon: const Icon(Icons.add),
                  label: const Text('Registrar Primer Gasto'),
                )
              : Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange[600], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Fondos agotados',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
          )
        else
          Column(
            children: [
              for (int index = 0; index < expenses.length; index++)
                _ExpenseItemWithPhoto(
                  expense: expenses[index],
                  index: index,
                  onEdit: () => onEditExpense(expenses[index]),
                  onDelete: () => onDeleteExpense(expenses[index]),
                  onGeneratePdf: onGeneratePdfForItem,
                ),
            ],
          ),
      ],
    );
  }
}

class _ExpenseItemWithPhoto extends StatefulWidget {
  final Expense expense;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(Expense expense)? onGeneratePdf;

  const _ExpenseItemWithPhoto({
    required this.expense,
    required this.index,
    required this.onEdit,
    required this.onDelete,
    this.onGeneratePdf,
  });

  @override
  State<_ExpenseItemWithPhoto> createState() => _ExpenseItemWithPhotoState();
}

class _ExpenseItemWithPhotoState extends State<_ExpenseItemWithPhoto> {
  bool _pdfExists = false;
  bool _checkingPdf = false;

  @override
  void initState() {
    super.initState();
    _checkPdfExists();
  }

  @override
  void didUpdateWidget(covariant _ExpenseItemWithPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expense.id != oldWidget.expense.id) {
      _checkPdfExists(); // Re-check if the expense item itself changes
    }
  }

  Future<void> _checkPdfExists() async {
    if (widget.expense.id == null) {
      if (mounted) setState(() => _pdfExists = false);
      return;
    }
    
    if (!mounted) return;
    setState(() => _checkingPdf = true);
    
    try {
      final fileName = PdfStorageService.generatePdfFileName(widget.expense.id!);
      final exists = await PdfStorageService.pdfExists(fileName);
      
      if (mounted) {
        setState(() {
          _pdfExists = exists;
          _checkingPdf = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _checkingPdf = false);
      }
      print("Error checking PDF existence for expense ${widget.expense.id}: $e");
    }
  }

  Widget _buildDetailRow(BuildContext context, String label, String? value, {IconData? icon, Color? iconColor}) {
    if (value == null || value.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: iconColor ?? Colors.grey[700]),
            const SizedBox(width: 8),
          ],
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseInfo(BuildContext context) {
    // Use expense.categoryType if available, otherwise fallback to guessing from name
    final ExpenseCategoryType? categoryType = widget.expense.categoryType ?? _getCategoryTypeFromName(widget.expense.categoryName);
    final PaymentType paymentType = _getPaymentTypeFromExpense(widget.expense);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200] ?? Colors.blue.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Descripción',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[700],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.expense.description,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Detalles Adicionales',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const Divider(height: 12),
              if (categoryType == ExpenseCategoryType.presupuesto) ...[
                _buildDetailRow(context, 'Pagado A', widget.expense.pagadoA, icon: Icons.store_outlined),
                // REMOVED: _buildDetailRow(context, 'Unidad', widget.expense.nombreUnidad, icon: Icons.business_outlined),
                if (paymentType == PaymentType.efectivo)
                  _buildDetailRow(context, 'Recibió', widget.expense.personaQueRecibio, icon: Icons.person_outlined),
              ],
              if (categoryType == ExpenseCategoryType.ofrendaDeAyuno) ...[
                 _buildDetailRow(context, 'Pagado/Entregado A', widget.expense.pagadoA, icon: Icons.handshake_outlined), // Or a more suitable icon
                 _buildDetailRow(context, 'Beneficiario Principal', widget.expense.beneficiarioOfrenda, icon: Icons.volunteer_activism_outlined),
                 if (paymentType == PaymentType.efectivo)
                  _buildDetailRow(context, 'Recibió Efectivo', widget.expense.personaQueRecibio, icon: Icons.person_pin_circle_outlined),
              ],
              
              _buildDetailRow(context, 'Núm. Referencia', widget.expense.numeroReferencia, icon: Icons.confirmation_number_outlined),
              if (widget.expense.numeroReferenciaAdicional != null && widget.expense.numeroReferenciaAdicional!.isNotEmpty)
                 _buildDetailRow(context, 'Ref. Adicional', widget.expense.numeroReferenciaAdicional, icon: Icons.article_outlined),

              _buildDetailRow(context, 'Importe en Letras', widget.expense.importeEnLetras, icon: Icons.text_fields_outlined),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final PaymentType paymentType = _getPaymentTypeFromExpense(widget.expense);
    final ExpenseCategoryType? categoryType = widget.expense.categoryType ?? _getCategoryTypeFromName(widget.expense.categoryName);
    final categoryColors = _getCategoryColors(categoryType);
    final bool hasPhoto = widget.expense.receiptUrls != null && widget.expense.receiptUrls!.isNotEmpty;
    final String? firstImagePath = hasPhoto ? widget.expense.receiptUrls!.first : null;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200] ?? Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  categoryColors['background']!,
                  categoryColors['background']!.withOpacity(0.5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border.all(color: categoryColors['border']!),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: categoryColors['primary'],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${widget.index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormatters.formatCurrency(widget.expense.amount),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: categoryColors['primary'],
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                DateFormatters.formatShortDate(widget.expense.date),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (widget.expense.usesMultipleExtractions) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.purple[100],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'MÚLTIPLE',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.purple[700],
                                    ),
                                  ),
                                ),
                              ],
                              if (hasPhoto) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green[100],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.camera_alt,
                                        size: 10,
                                        color: Colors.green[700],
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        widget.expense.receiptUrls!.length > 1 ? 'FOTOS (${widget.expense.receiptUrls!.length})' : 'FOTO',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.green[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (_pdfExists) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[100],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.picture_as_pdf,
                                        size: 10,
                                        color: Colors.blue[700],
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        'PDF',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.blue[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.onGeneratePdf != null)
                          Container(
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: _pdfExists ? Colors.blue[50] : Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: _checkingPdf 
                                ? SizedBox(
                                    width: 18, 
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        _pdfExists ? Colors.blue[700]! : Colors.red[700]!
                                      ),
                                    ),
                                  )
                                : Icon(
                                    _pdfExists ? Icons.visibility_outlined : Icons.picture_as_pdf_outlined, 
                                    color: _pdfExists ? Colors.blue[700] : Colors.red[700], 
                                    size: 18
                                  ),
                              tooltip: _pdfExists ? 'Ver PDF' : 'Generar PDF',
                              onPressed: _checkingPdf ? null : () async {
                                await widget.onGeneratePdf!(widget.expense);
                                _checkPdfExists();
                              },
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: Icon(Icons.edit_outlined, 
                              color: Colors.blue[600], size: 18),
                            tooltip: 'Editar',
                            onPressed: widget.onEdit,
                            padding: const EdgeInsets.all(8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: Icon(Icons.delete_outline, 
                              color: Colors.red[600], size: 18),
                            tooltip: 'Eliminar',
                            onPressed: widget.onDelete,
                            padding: const EdgeInsets.all(8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: paymentType == PaymentType.efectivo ? Colors.green[50] : Colors.purple[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: paymentType == PaymentType.efectivo ? Colors.green[200]! : Colors.purple[200]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            paymentType == PaymentType.efectivo ? Icons.payments_outlined : Icons.credit_card_outlined,
                            size: 12,
                            color: paymentType == PaymentType.efectivo ? Colors.green[600] : Colors.purple[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            paymentType == PaymentType.efectivo ? 'Efectivo' : 'Tarjeta',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: paymentType == PaymentType.efectivo ? Colors.green[800] : Colors.purple[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: categoryColors['background'],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: categoryColors['border']!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              categoryType == ExpenseCategoryType.presupuesto 
                                ? Icons.account_balance_wallet_outlined 
                                : Icons.volunteer_activism_outlined,
                              size: 14, 
                              color: categoryColors['primary'],
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                widget.expense.categoryName ?? "Sin Categoría",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: categoryColors['text'],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasPhoto && firstImagePath != null) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildReceiptImage(context, firstImagePath),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildExpenseInfo(context),
                      ),
                    ],
                  ),
                ] else ...[
                  _buildExpenseInfo(context),
                ],
                
                if (widget.expense.usesMultipleExtractions) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.purple[200] ?? Colors.purple.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.purple[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(Icons.call_split_outlined, 
                                size: 16, color: Colors.purple[700]),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Gasto con Múltiples Extracciones',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.purple[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        
                        if (widget.expense.amountFromPrimary != null) 
                          _buildAmountDistributionRow(
                            'Extracción Principal:', 
                            widget.expense.amountFromPrimary!,
                            Icons.account_balance_wallet_outlined
                          ),
                        
                        if (widget.expense.amountFromAdditional != null)
                          _buildAmountDistributionRow(
                            'Extracción Adicional:', 
                            widget.expense.amountFromAdditional!,
                            Icons.add_circle_outline
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptImage(BuildContext context, String imagePath) {
    VoidCallback onTapAction = () => _showFullScreenImage(context, imagePath, widget.expense.receiptUrls);

    return GestureDetector(
      onTap: onTapAction,
      child: Container(
        width: 80,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.shade300, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.1),
              spreadRadius: 0,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            children: [
              FutureBuilder<bool>(
                future: File(imagePath).exists(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
                  }
                  if (snapshot.hasData && snapshot.data == true) {
                    return Image.file(
                      File(imagePath),
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildErrorImagePlaceholder();
                      },
                    );
                  } else {
                    return _buildErrorImagePlaceholder();
                  }
                },
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.black.withOpacity(0.1),
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        (widget.expense.receiptUrls?.length ?? 0) > 1 ? Icons.photo_library_outlined : Icons.zoom_in,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorImagePlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            color: Colors.grey[400],
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            'Error',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String currentImagePath, List<String>? allImagePaths) {
    final imagesToShow = allImagePaths != null && allImagePaths.isNotEmpty ? allImagePaths : [currentImagePath];
    final initialIndex = imagesToShow.indexOf(currentImagePath);

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          children: [
            if (imagesToShow.length > 1)
              PageView.builder(
                itemCount: imagesToShow.length,
                controller: PageController(initialPage: initialIndex >= 0 ? initialIndex : 0),
                itemBuilder: (context, index) {
                  return InteractiveViewer(
                    child: Image.file(
                      File(imagesToShow[index]),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Center(child: Icon(Icons.broken_image, size: 50, color: Colors.white54)),
                    ),
                  );
                },
              )
            else 
              Center(
                child: InteractiveViewer(
                  child: Image.file(
                    File(currentImagePath),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Center(child: Icon(Icons.broken_image, size: 50, color: Colors.white54)),
                  ),
                ),
              ),
            Positioned(
              top: 15,
              right: 15,
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
            if (imagesToShow.length > 1)
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: imagesToShow.map((url) {
                    // PageIndex is not needed since we're not tracking active state
                    return Container(
                      width: 8.0,
                      height: 8.0,
                      margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 2.0),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.4), 
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountDistributionRow(String label, double amount, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.purple[600]),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.purple[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            DateFormatters.formatCurrency(amount),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.purple[700],
            ),
          ),
        ],
      ),
    );
  }

  PaymentType _getPaymentTypeFromExpense(Expense expense) {
    // This logic might need adjustment based on how 'tarjeta' vs 'efectivo' is truly determined
    // for both Presupuesto and Ofrenda types if personaQueRecibio is not the sole indicator.
    if (expense.personaQueRecibio == null || expense.personaQueRecibio!.isEmpty) {
      // If 'Pagado A' is also empty, it's less clear. Defaulting to tarjeta if PQR is empty.
      return PaymentType.tarjeta;
    }
    return PaymentType.efectivo;
  }

  ExpenseCategoryType? _getCategoryTypeFromName(String? categoryName) {
    if (categoryName == null) return null;
    // This is a simple heuristic. Using expense.categoryType is more reliable.
    if (categoryName.toLowerCase().contains('presupuesto')) {
      return ExpenseCategoryType.presupuesto;
    } else if (categoryName.toLowerCase().contains('ofrenda')) {
      return ExpenseCategoryType.ofrendaDeAyuno;
    }
    // Fallback or if categoryName is just the subcategory name
    return null; 
  }

  Map<String, Color> _getCategoryColors(ExpenseCategoryType? categoryType) {
    switch (categoryType) {
      case ExpenseCategoryType.presupuesto:
        return {
          'primary': Colors.blue[600]!,
          'background': Colors.blue[50]!,
          'border': Colors.blue[200]!,
          'text': Colors.blue[800]!,
        };
      case ExpenseCategoryType.ofrendaDeAyuno:
        return {
          'primary': Colors.orange[600]!,
          'background': Colors.orange[50]!,
          'border': Colors.orange[200]!,
          'text': Colors.orange[800]!,
        };
      default: // Null or unknown type
        return {
          'primary': Colors.grey[600]!,
          'background': Colors.grey[50]!,
          'border': Colors.grey[200]!,
          'text': Colors.grey[800]!,
        };
    }
  }
}