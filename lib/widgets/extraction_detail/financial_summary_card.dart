// lib/widgets/extraction_detail/financial_summary_card.dart
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../utils/date_formatters.dart';
import '../../widgets/common/custom_card.dart';

class FinancialSummaryCard extends StatelessWidget {
  final Extraction extraction; 
  final double totalExpenses; // Direct expenses from extraction
  final double totalAdvanced; 
  final double totalDeposits;
  final int expensesCount; // Count of direct expenses
  final VoidCallback? onDepositExcess;

  const FinancialSummaryCard({
    super.key,
    required this.extraction,
    required this.totalExpenses,
    required this.totalAdvanced, 
    required this.totalDeposits,
    required this.expensesCount,
    this.onDepositExcess,
  });

  @override
  Widget build(BuildContext context) {
    final double realBalanceForDepositButton = extraction.availableBalance; 
    final bool hasSignificantBalance = realBalanceForDepositButton > 1.0;
    
    return CustomCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined, color: Colors.blue[600], size: 24),
              const SizedBox(width: 12),
              Text(
                'Resumen Financiero',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          _buildSummaryItem(
            context,
            label: 'Monto Extraído Originalmente',
            amount: extraction.amount,
            icon: Icons.account_balance_wallet_outlined,
            colorSchemeSeed: Colors.blueGrey,
            description: 'Cantidad inicial retirada del banco.'
          ),
          const SizedBox(height: 12),

          _buildSummaryItem(
            context,
            label: 'Total Gastado Directamente',
            amount: totalExpenses, 
            icon: Icons.shopping_cart_outlined,
            colorSchemeSeed: Colors.orange,
            description: expensesCount > 0 
                ? '$expensesCount ${expensesCount == 1 ? 'gasto directo registrado' : 'gastos directos registrados'}'
                : 'Sin gastos directos registrados.'
          ),
          const SizedBox(height: 12),
          
          if (totalAdvanced > 0) ...[
            _buildSummaryItem(
              context,
              label: 'Total Entregado a Miembros',
              amount: totalAdvanced,
              icon: Icons.send_to_mobile_outlined,
              colorSchemeSeed: Colors.purple,
              description: 'Dinero entregado a miembros para compras.'
            ),
            const SizedBox(height: 12),
          ],
          
          if (totalDeposits > 0) ...[
            _buildSummaryItem(
              context,
              label: 'Total Depositado (Devuelto)',
              amount: totalDeposits,
              icon: Icons.savings_outlined,
              colorSchemeSeed: Colors.green,
              description: 'Fondos devueltos al banco.'
            ),
            const SizedBox(height: 12),
          ],
          
          Divider(color: Colors.grey[300], height: 24, thickness: 1),
          
           _buildSummaryItem(
            context,
            label: 'Saldo Disponible en Extracción',
            amount: extraction.availableBalance, 
            icon: extraction.availableBalance >= 0 ? Icons.check_circle_outline : Icons.warning_outlined,
            colorSchemeSeed: extraction.availableBalance >= 0 ? (hasSignificantBalance ? Colors.teal : Colors.lightBlue) : Colors.red,
            isLargeValue: true,
            description: extraction.availableBalance >= 0 
                          ? (hasSignificantBalance ? 'Disponible para más operaciones.' : 'Fondos completamente utilizados o asignados.')
                          : 'Exceso en gastos/entregas sobre el monto extraído.'
          ),
          
          if (hasSignificantBalance && onDepositExcess != null) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                 icon: const Icon(Icons.savings_outlined, size: 20),
                 label: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Depositar Excedente Actual', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      Text(
                        DateFormatters.formatCurrency(realBalanceForDepositButton),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white70),
                      ),
                    ],
                  ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: onDepositExcess,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    BuildContext context, {
    required String label,
    required double amount,
    required IconData icon,
    required Color colorSchemeSeed, // Changed from MaterialColor to Color for flexibility
    String? description,
    bool isLargeValue = false,
  }) {
    final Color primaryColor = colorSchemeSeed; // Use directly or derive shades
    final Color lightColor = HSLColor.fromColor(colorSchemeSeed).withLightness(0.95).toColor(); // Lighter shade
    final Color darkColor = HSLColor.fromColor(colorSchemeSeed).withLightness(0.35).toColor();  // Darker shade
    final Color iconContainerColor = HSLColor.fromColor(colorSchemeSeed).withLightness(0.90).toColor();


    return Container(
      padding: const EdgeInsets.all(12), // Reduced padding a bit
      decoration: BoxDecoration(
        color: lightColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconContainerColor, 
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: primaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12, // Slightly smaller label
                    fontWeight: FontWeight.w600,
                    color: darkColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormatters.formatCurrency(amount),
                  style: TextStyle(
                    fontSize: isLargeValue ? 18 : 16, // Adjusted sizes
                    fontWeight: FontWeight.bold, // Bolder for emphasis
                    color: darkColor,
                  ),
                ),
                if (description != null && description.isNotEmpty) ... [
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 10, // Smaller description
                      color: primaryColor.withOpacity(0.9),
                    ),
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }
}