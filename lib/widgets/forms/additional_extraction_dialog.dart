import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/extraction_service.dart';
import '../../utils/date_formatters.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/empty_state_widget.dart';

class AdditionalExtractionSelectionResult {
  final Extraction additionalExtraction;
  final double amountFromPrimary;
  final double amountFromAdditional;

  AdditionalExtractionSelectionResult({
    required this.additionalExtraction,
    required this.amountFromPrimary,
    required this.amountFromAdditional,
  });
}

class AdditionalExtractionDialog extends StatefulWidget {
  final Extraction primaryExtraction;
  final double totalExpenseAmount;
  final double availableInPrimary;
  final double deficit;

  const AdditionalExtractionDialog({
    super.key,
    required this.primaryExtraction,
    required this.totalExpenseAmount,
    required this.availableInPrimary,
    required this.deficit,
  });

  @override
  State<AdditionalExtractionDialog> createState() => _AdditionalExtractionDialogState();
}

class _AdditionalExtractionDialogState extends State<AdditionalExtractionDialog> {
  final ExtractionService _extractionService = ExtractionService();
  List<Extraction> _availableExtractions = [];
  Extraction? _selectedExtraction;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAvailableExtractions();
  }

  Future<void> _loadAvailableExtractions() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });

    try {
      final extractions = await _extractionService.getAllExtractions();
      
      final available = extractions.where((extraction) {
        return extraction.id != widget.primaryExtraction.id &&
               extraction.availableBalance >= widget.deficit;
      }).toList();

      if (mounted) {
        setState(() {
          _availableExtractions = available;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isLoading = false; });
        _showMessage('Error cargando extracciones: $e', isError: true);
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
      ),
    );
  }

  void _confirmSelection() {
    if (_selectedExtraction == null) {
      _showMessage('Por favor, seleccione una extracción adicional.', isError: true);
      return;
    }

    final result = AdditionalExtractionSelectionResult(
      additionalExtraction: _selectedExtraction!,
      amountFromPrimary: widget.availableInPrimary,
      amountFromAdditional: widget.deficit,
    );

    Navigator.of(context).pop(result);
  }

  // Función auxiliar original para filas de resumen (la usaremos para "Monto Faltante")
  Widget _buildSummaryRow(String label, double amount, {bool isDeficit = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.0, top: isDeficit ? 4.0 : 0), // Añadido un poco de top padding para el déficit
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDeficit ? Colors.red[700] : Colors.grey[700],
              fontWeight: isDeficit ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          Text(
            DateFormatters.formatCurrency(amount),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDeficit ? Colors.red[700] : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // NUEVA función auxiliar para el estilo de etiqueta y valor apilados
  Widget _buildStackedSummaryItem(BuildContext context, String label, double amount, {Color? valueColorOverride}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            DateFormatters.formatCurrency(amount),
            style: TextStyle(
              fontSize: 16, 
              fontWeight: FontWeight.w700,
              color: valueColorOverride ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.warning_outlined,
              color: Colors.orange[700],
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Fondos Insuficientes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resumen del Gasto',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.red[700],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // --- MODIFICACIÓN AQUÍ ---
                    _buildStackedSummaryItem(context, 'Monto total del gasto:', widget.totalExpenseAmount),
                    _buildStackedSummaryItem(context, 'Disponible en extracción principal:', widget.availableInPrimary),
                    // --- FIN DE LA MODIFICACIÓN ---
                    const Divider(height: 12, thickness: 1), // Ajuste visual del Divider
                    _buildSummaryRow('Monto faltante:', widget.deficit, 
                      isDeficit: true),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              Container(
                width: double.infinity,
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
                      'Extracción Principal',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.primaryExtraction.reason,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Código: ${widget.primaryExtraction.extractionCode ?? "Sin código"}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              Text(
                'Seleccione una extracción adicional para cubrir el déficit:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 12),
              
              if (_isLoading)
                const SizedBox(
                  height: 200, 
                  child: LoadingWidget(message: 'Cargando extracciones disponibles...'),
                )
              else if (_availableExtractions.isEmpty)
                SizedBox( 
                  child: EmptyStateWidget(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'No hay extracciones disponibles',
                    subtitle: 'No se encontraron extracciones con saldo suficiente (${DateFormatters.formatCurrency(widget.deficit)}) para cubrir el déficit.',
                  ),
                )
              else
                SizedBox(
                  height: 250, 
                  child: SingleChildScrollView(
                    child: Column(
                      children: _availableExtractions.map((extraction) {
                        return _buildExtractionOption(extraction);
                      }).toList(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: _availableExtractions.isEmpty ? null : _confirmSelection,
          icon: const Icon(Icons.check_outlined),
          label: const Text('Confirmar Selección'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[600],
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildExtractionOption(Extraction extraction) {
    final bool isSelected = _selectedExtraction?.id == extraction.id;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedExtraction = extraction;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? Colors.green[50] : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.green[400]! : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
               boxShadow: isSelected ? [
                BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2))
              ] : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 16, 
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? Colors.green[600] : Colors.transparent,
                        border: Border.all(
                          color: isSelected ? Colors.green[600]! : Colors.grey[400]!,
                          width: 2,
                        ),
                      ),
                      child: isSelected 
                        ? const Icon(Icons.check, size: 10, color: Colors.white) 
                        : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            extraction.reason,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.green[700] : Colors.black87,
                            ),
                          ),
                          if (extraction.extractionCode != null && extraction.extractionCode!.isNotEmpty)
                            Text(
                              'Código: ${extraction.extractionCode}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      DateFormatters.formatShortDate(extraction.date),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Saldo: ${DateFormatters.formatCurrency(extraction.availableBalance)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}