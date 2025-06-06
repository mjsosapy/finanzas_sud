// lib/widgets/extraction_detail/fund_advances_section.dart
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../utils/date_formatters.dart';
import '../../models/enums.dart'; 
import '../common/custom_card.dart'; 
import '../common/empty_state_widget.dart'; 

class FundAdvancesSection extends StatelessWidget {
  final List<FundAdvance> fundAdvances;
  final int extractionId; 

  const FundAdvancesSection({
    super.key,
    required this.fundAdvances,
    required this.extractionId,
  });

  @override
  Widget build(BuildContext context) {
    if (fundAdvances.isEmpty) {
      // Show a minimal message or nothing if no advances, to avoid clutter
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Center(
          child: Text(
            'No se ha entregado dinero a miembros desde esta extracción.',
            style: TextStyle(color: Colors.grey[600], fontSize: 13, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    double totalAdvanced = fundAdvances.fold(0.0, (sum, item) => sum + item.amount);

    return CustomCard(
      margin: const EdgeInsets.only(bottom: 24, top:8),
      backgroundColor: Colors.purple[50]?.withOpacity(0.5), // Light purple background for the card
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.purple[100],
                  borderRadius: BorderRadius.circular(6)
                ),
                child: Icon(Icons.send_to_mobile_outlined, color: Colors.purple[700], size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Dinero Entregado a Miembros (${fundAdvances.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.purple[800],
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.purple[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple[200]!),
                ),
                child: Text(
                  'Total: ${DateFormatters.formatCurrency(totalAdvanced)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: fundAdvances.length,
            itemBuilder: (context, index) {
              final FundAdvance advance = fundAdvances[index];
              return _buildAdvanceItem(context, advance);
            },
            separatorBuilder: (context, index) => Divider(color: Colors.purple[100], height:16),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvanceItem(BuildContext context, FundAdvance advance) {
    IconData statusIcon;
    Color statusColor;
    String statusText = advance.status.replaceAll('_', ' ').toUpperCase(); // PENDIENTE, RECONCILIADO TOTAL

    switch (advance.status) {
      case 'PENDIENTE':
        statusIcon = Icons.hourglass_top_outlined; // More indicative of waiting
        statusColor = Colors.orange.shade700;
        break;
      case 'RECONCILIADO_PARCIAL':
        statusIcon = Icons.incomplete_circle_outlined;
        statusColor = Colors.blue.shade700;
        break;
      case 'RECONCILIADO_TOTAL':
        statusIcon = Icons.check_circle_outlined;
        statusColor = Colors.green.shade700;
        break;
      default:
        statusIcon = Icons.help_outline;
        statusColor = Colors.grey.shade600;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     Text(
                      advance.memberName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.purple[900], fontSize: 15),
                    ),
                    Text(
                      'Fecha: ${DateFormatters.formatShortDate(advance.date)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                    ),
                  ],
                )
              ),
              const SizedBox(width: 10),
              Text(
                DateFormatters.formatCurrency(advance.amount),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.purple[900], fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).chipTheme.backgroundColor ?? Colors.grey[200],
              borderRadius: BorderRadius.circular(6)
            ),
            child: Text(
              'Propósito: ${expenseCategoryTypeToDisplayString(advance.purposeType)}',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey[800]),
            ),
          ),
          if (advance.reason != null && advance.reason!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Text('Motivo Específico: ${advance.reason}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
            ),
          if (advance.comments != null && advance.comments!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text('Comentarios: ${advance.comments}', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey[600])),
            ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: statusColor.withOpacity(0.3))
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, color: statusColor, size: 14),
                const SizedBox(width: 6),
                Text(
                  statusText,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ],
            ),
          ),
          // TODO: Add buttons for "Registrar Gasto para esta Entrega" or "Ver Gastos Asociados"
          // These would navigate to ExpenseRegistrationScreen with fundAdvanceId pre-filled,
          // or to a filtered list of expenses.
        ],
      ),
    );
  }
}