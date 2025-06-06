import 'package:flutter/material.dart';
import '../../widgets/common/custom_card.dart';

class MultipleExtractionsGuideWidget extends StatelessWidget {
  const MultipleExtractionsGuideWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sistema de Múltiples Extracciones'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Introducción
            CustomCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[600], size: 24),
                      const SizedBox(width: 12),
                      Text(
                        '¿Qué es el Sistema de Múltiples Extracciones?',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Este sistema permite registrar gastos que excedan el saldo de una sola extracción, '
                    'distribuyendo automáticamente el monto entre múltiples extracciones disponibles. '
                    'Esto garantiza una gestión precisa de fondos y facilita las auditorías.',
                    style: TextStyle(fontSize: 15, height: 1.5),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Flujo de trabajo
            CustomCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.timeline_outlined, color: Colors.green[600], size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'Flujo de Trabajo',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.green[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  _buildWorkflowStep(
                    context,
                    1,
                    'Ingreso del Monto',
                    'El usuario ingresa el monto total del gasto en el formulario.',
                    Icons.payments_outlined,
                    Colors.blue,
                  ),
                  
                  _buildWorkflowStep(
                    context,
                    2,
                    'Verificación Automática',
                    'El sistema verifica si el saldo de la extracción principal es suficiente.',
                    Icons.verified_outlined,
                    Colors.orange,
                  ),
                  
                  _buildWorkflowStep(
                    context,
                    3,
                    'Detección de Déficit',
                    'Si hay déficit, se calcula automáticamente el monto faltante.',
                    Icons.warning_outlined,
                    Colors.red,
                  ),
                  
                  _buildWorkflowStep(
                    context,
                    4,
                    'Selección de Extracción Adicional',
                    'Se presenta una lista de extracciones con saldo suficiente para cubrir el déficit.',
                    Icons.list_outlined,
                    Colors.purple,
                  ),
                  
                  _buildWorkflowStep(
                    context,
                    5,
                    'Distribución Automática',
                    'El sistema calcula y registra la distribución del gasto entre las extracciones.',
                    Icons.call_split_outlined,
                    Colors.green,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Ejemplo práctico
            CustomCard(
              backgroundColor: Colors.amber[50],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: Colors.amber[700], size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'Ejemplo Práctico',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.amber[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  _buildExampleScenario(context),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Beneficios
            CustomCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.star_outline, color: Colors.indigo[600], size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'Beneficios del Sistema',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.indigo[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  _buildBenefitItem(
                    context,
                    'Trazabilidad Completa',
                    'Cada gasto queda vinculado a todas las extracciones utilizadas con montos específicos.',
                    Icons.timeline_outlined,
                  ),
                  
                  _buildBenefitItem(
                    context,
                    'Auditoría Facilitada',
                    'Los auditores pueden verificar fácilmente el origen de cada fondo utilizado.',
                    Icons.verified_outlined,
                  ),
                  
                  _buildBenefitItem(
                    context,
                    'Gestión Automática',
                    'No es necesario calcular manualmente las distribuciones de gastos.',
                    Icons.auto_fix_high_outlined,
                  ),
                  
                  _buildBenefitItem(
                    context,
                    'Prevención de Errores',
                    'El sistema valida automáticamente que haya fondos suficientes.',
                    Icons.shield_outlined,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Información técnica
            CustomCard(
              backgroundColor: Colors.grey[50],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.settings_outlined, color: Colors.grey[700], size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'Información Técnica',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  const Text(
                    '• Cada gasto puede referenciar máximo 2 extracciones\n'
                    '• La distribución se calcula automáticamente\n'
                    '• Se mantienen ambos números de referencia\n'
                    '• Los reportes muestran el origen de cada fondo\n'
                    '• Compatible con todos los tipos de gastos existentes',
                    style: TextStyle(fontSize: 14, height: 1.6),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkflowStep(
    BuildContext context,
    int stepNumber,
    String title,
    String description,
    IconData icon,
    MaterialColor color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color[100],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color[300]!),
            ),
            child: Center(
              child: Text(
                stepNumber.toString(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color[700],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 20, color: color[600]),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: color[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleScenario(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Escenario: Compra de materiales de oficina',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          
          _buildExampleRow('Gasto total:', '500,000 Gs.', null),
          _buildExampleRow('Extracción A (disponible):', '300,000 Gs.', Colors.blue),
          _buildExampleRow('Déficit:', '200,000 Gs.', Colors.red),
          
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Solución Automática:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.green[700],
                  ),
                ),
                const SizedBox(height: 8),
                _buildExampleRow('Desde Extracción A:', '300,000 Gs.', Colors.green),
                _buildExampleRow('Desde Extracción B:', '200,000 Gs.', Colors.green),
                const Divider(height: 16),
                _buildExampleRow('Total cubierto:', '500,000 Gs.', Colors.green),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleRow(String label, String value, Color? valueColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(
    BuildContext context,
    String title,
    String description,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.indigo[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: Colors.indigo[600]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}