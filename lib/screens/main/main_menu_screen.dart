// lib/screens/main/main_menu_screen.dart
import 'package:flutter/material.dart';
import '../auth/login_screen.dart';
import '../extractions/add_extraction_screen.dart';
import '../extractions/extraction_list_screen.dart';
import '../categories/category_management_screen.dart';
import '../configuration/account_configuration_screen.dart';
import '../debug/pdf_preview_screen.dart'; // Asegúrate que la ruta sea correcta

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menú Principal'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo o Título Principal (Opcional)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 30.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined, // Un ícono representativo
                          size: 60,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Control de Fondos',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Theme.of(context).primaryColorDark,
                              ),
                        ),
                      ],
                    ),
                  ),

                  _buildMenuItem(
                    context,
                    icon: Icons.add_card_outlined, // Ícono más representativo para extracción
                    label: 'Registrar Nueva Extracción',
                    onPressed: () async {
                      // Navegar a AddExtractionScreen y esperar un resultado
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(builder: (context) => const AddExtractionScreen()),
                      );
                      // Si AddExtractionScreen devuelve true (ej. se guardó algo),
                      // podrías querer actualizar alguna lista o estado aquí si es necesario.
                      if (result == true && context.mounted) {
                        // Lógica para recargar datos si es necesario
                      }
                    },
                  ),
                  const SizedBox(height: 16), // Espaciado reducido

                  _buildMenuItem(
                    context,
                    icon: Icons.list_alt_outlined, // Ícono más representativo
                    label: 'Ver Lista de Extracciones',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ExtractionListScreen(navigateToExpenseFormOnClick: false)
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                   _buildMenuItem(
                    context,
                    icon: Icons.category_outlined,
                    label: 'Gestionar Subcategorías',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CategoryManagementScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  _buildMenuItem(
                    context,
                    icon: Icons.settings_applications_outlined, // Ícono más específico
                    label: 'Configuración de Cuenta',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AccountConfigurationScreen()),
                      );
                    },
                    backgroundColor: Theme.of(context).colorScheme.tertiary, // Usar color del tema
                    foregroundColor: Theme.of(context).colorScheme.onTertiary,
                  ),
                  const SizedBox(height: 16),
                  
                  _buildMenuItem(
                    context,
                    icon: Icons.bar_chart_outlined,
                    label: 'Reportes (Próximamente)',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Módulo de Reportes en desarrollo')),
                      );
                    },
                    backgroundColor: Colors.grey.shade400,
                    foregroundColor: Colors.black87,
                  ),
                  const SizedBox(height: 16),

                  // Botón para la Vista Previa de PDF (Debug)
                  _buildMenuItem(
                    context,
                    icon: Icons.preview_outlined, // Ícono para vista previa
                    label: 'Vista Previa PDF Boleta (Debug)',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PdfPreviewScreen()),
                      );
                    },
                    backgroundColor: Colors.orange.shade700,
                  ),
                  const SizedBox(height: 24), // Más espacio antes de cerrar sesión

                  _buildMenuItem(
                    context,
                    icon: Icons.logout_outlined,
                    label: 'Cerrar Sesión',
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                        (Route<dynamic> route) => false, // Elimina todas las rutas anteriores
                      );
                    },
                    backgroundColor: Theme.of(context).colorScheme.error, // Usar color de error del tema
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? backgroundColor, // Color de fondo personalizado
    Color? foregroundColor, // Color de texto/ícono personalizado
  }) {
    // Usa el estilo de ElevatedButton definido en el tema global (main.dart)
    // pero permite personalizaciones si se proveen backgroundColor o foregroundColor.
    final ButtonStyle? globalStyle = Theme.of(context).elevatedButtonTheme.style;
    
    ButtonStyle effectiveStyle = globalStyle ?? ElevatedButton.styleFrom(); // Empieza con el global o uno por defecto

    if (backgroundColor != null) {
      effectiveStyle = effectiveStyle.copyWith(
        backgroundColor: MaterialStateProperty.all(backgroundColor),
      );
    }
    if (foregroundColor != null) {
      effectiveStyle = effectiveStyle.copyWith(
        foregroundColor: MaterialStateProperty.all(foregroundColor),
      );
    }
    // Asegurar que el padding y shape del tema se mantengan si no se sobreescriben
    effectiveStyle = effectiveStyle.copyWith(
        padding: MaterialStateProperty.all(globalStyle?.padding?.resolve({}) ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
        shape: MaterialStateProperty.all(globalStyle?.shape?.resolve({}) ?? RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        elevation: MaterialStateProperty.all(globalStyle?.elevation?.resolve({}) ?? 6)
    );


    return SizedBox(
      width: double.infinity, // Ocupa todo el ancho disponible
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 22), // Tamaño de ícono ajustado
        label: Text(label, style: const TextStyle(fontSize: 15)), // Tamaño de texto ajustado
        style: effectiveStyle,
      ),
    );
  }
}