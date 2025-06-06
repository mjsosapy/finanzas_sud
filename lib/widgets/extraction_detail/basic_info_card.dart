import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../utils/date_formatters.dart';
import '../../widgets/common/custom_card.dart';

class BasicInfoCard extends StatelessWidget {
  final Extraction extraction;

  const BasicInfoCard({super.key, required this.extraction});

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined, 
                color: Theme.of(context).primaryColor, 
                size: 24
              ),
              const SizedBox(width: 12),
              Text(
                'Información de la Extracción',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).primaryColor
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildInfoRow(context, 'Motivo:', extraction.reason),
          
          if (extraction.extractionCode != null && extraction.extractionCode!.isNotEmpty)
            _buildInfoRow(context, 'Código:', extraction.extractionCode!),
            
          _buildInfoRow(context, 'Fecha:', DateFormatters.formatLongDate(extraction.date)),
          _buildInfoRow(context, 'Monto Extraído:', DateFormatters.formatCurrency(extraction.amount)),
          
          // Comentarios si existen
          if (extraction.comments.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200] ?? Colors.grey.shade200),
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
                  const SizedBox(height: 8),
                  Text(
                    extraction.comments,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value, {Color? valueColor}) {
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
}