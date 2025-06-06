import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/extraction_service.dart';
import '../../utils/date_formatters.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/custom_card.dart';
import 'extraction_detail_screen.dart';
import '../expenses/expense_registration_screen.dart';

class ExtractionListScreen extends StatefulWidget {
  final bool navigateToExpenseFormOnClick; 

  const ExtractionListScreen({
    super.key, 
    this.navigateToExpenseFormOnClick = false, 
  });

  @override
  State<ExtractionListScreen> createState() => _ExtractionListScreenState();
}

class _ExtractionListScreenState extends State<ExtractionListScreen> {
  final ExtractionService _extractionService = ExtractionService();
  List<Extraction> _extractions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExtractions();
  }

  Future<void> _loadExtractions() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });
    
    try {
      final extractions = await _extractionService.getAllExtractions();
      if (mounted) {
        setState(() {
          _extractions = extractions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cargando extracciones: $e'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.navigateToExpenseFormOnClick 
            ? 'Seleccionar Extracción para Gasto' 
            : 'Extracciones Registradas'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Recargar Extracciones',
            onPressed: _loadExtractions,
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Cargando extracciones...')
          : _extractions.isEmpty
              ? EmptyStateWidget(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'No hay extracciones registradas',
                  subtitle: 'Presiona el botón "+" para agregar la primera extracción',
                  action: widget.navigateToExpenseFormOnClick ? null : ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.pushNamed(context, '/add-extraction');
                      if (result == true) {
                        _loadExtractions();
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar Extracción'),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: _extractions.length,
                  itemBuilder: (context, index) {
                    final extraction = _extractions[index];
                    return _buildExtractionCard(extraction);
                  },
                ),
    );
  }

  Widget _buildExtractionCard(Extraction extraction) {
    final double availableBalance = extraction.amount - extraction.spentAmount;
    final bool hasBalance = availableBalance > 0;
    
    return CustomCard(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      child: InkWell(
        onTap: () async {
          print("🔍 Toque detectado en extracción: ${extraction.reason}");
          print("🔍 navigateToExpenseFormOnClick: ${widget.navigateToExpenseFormOnClick}");
          
          bool? dataChanged;
          try {
            if (widget.navigateToExpenseFormOnClick) {
              print("🚀 Navegando al formulario de gastos...");
              dataChanged = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) => ExpenseRegistrationScreen(extraction: extraction),
                ),
              );
              print("✅ Navegación completada. Datos cambiados: $dataChanged");
            } else {
              print("🚀 Navegando al detalle de extracción...");
              dataChanged = await Navigator.push<bool>( 
                context,
                MaterialPageRoute(
                  builder: (context) => ExtractionDetailScreen(extractionId: extraction.id!),
                ),
              );
              print("✅ Navegación completada. Datos cambiados: $dataChanged");
            }
            
            if (dataChanged == true && mounted) { 
              print("🔄 Recargando extracciones...");
              _loadExtractions(); 
            }
          } catch (e) {
            print("❌ Error en navegación: $e");
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error al navegar: $e'),
                  backgroundColor: Colors.red[600],
                ),
              );
            }
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con fecha y código
              Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Theme.of(context).primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormatters.formatShortDate(extraction.date),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (extraction.extractionCode != null && extraction.extractionCode!.isNotEmpty)
                          Text(
                            'Código: ${extraction.extractionCode}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.blueGrey[700],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: hasBalance ? Colors.green[100] : Colors.orange[100],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: hasBalance ? Colors.green[300]! : Colors.orange[300]!,
                      ),
                    ),
                    child: Text(
                      hasBalance ? 'Disponible' : 'Usado',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: hasBalance ? Colors.green[700] : Colors.orange[700],
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Motivo/Razón
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
                      'Motivo',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      extraction.reason,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Información financiera
              Row(
                children: [
                  Expanded(
                    child: _buildAmountInfo(
                      'Monto Extraído',
                      extraction.amount,
                      Colors.blue,
                      Icons.account_balance_outlined,
                    ),
                  ),
                  if (extraction.spentAmount > 0) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildAmountInfo(
                        'Gastado',
                        extraction.spentAmount,
                        Colors.orange,
                        Icons.shopping_cart_outlined,
                      ),
                    ),
                  ],
                ],
              ),
              
              if (availableBalance != extraction.amount) ...[
                const SizedBox(height: 12),
                _buildAmountInfo(
                  'Saldo Disponible',
                  availableBalance,
                  hasBalance ? Colors.green : Colors.red,
                  hasBalance ? Icons.savings_outlined : Icons.warning_outlined,
                  isFullWidth: true,
                ),
              ],
              
              // Comentarios si existen
              if (extraction.comments.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.comment_outlined, color: Colors.grey[600], size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Comentarios',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        extraction.comments,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[700],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
              
              // Indicador visual para el modo de gastos
              if (widget.navigateToExpenseFormOnClick) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_circle_outline, color: Colors.green[600], size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Toca para registrar gasto',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountInfo(String label, double amount, MaterialColor color, IconData icon, {bool isFullWidth = false}) {
    return Container(
      width: isFullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color[100],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color[600], size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color[700],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormatters.formatCurrency(amount),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}