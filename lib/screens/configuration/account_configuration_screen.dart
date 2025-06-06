import 'package:flutter/material.dart';
import '../../services/configuration_service.dart'; // Ajusta la ruta
import '../../widgets/common/custom_card.dart'; // Ajusta la ruta

class AccountConfigurationScreen extends StatefulWidget {
  const AccountConfigurationScreen({super.key});

  @override
  State<AccountConfigurationScreen> createState() => _AccountConfigurationScreenState();
}

class _AccountConfigurationScreenState extends State<AccountConfigurationScreen> {
  final _formKey = GlobalKey<FormState>();
  final ConfigurationService _configService = ConfigurationService();

  final TextEditingController _unitNameController = TextEditingController();
  final TextEditingController _unitNumberController = TextEditingController();
  final TextEditingController _bishopNameController = TextEditingController();
  final TextEditingController _firstCounselorController = TextEditingController();
  final TextEditingController _secondCounselorController = TextEditingController();
  final TextEditingController _secretaryController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadConfiguration();
  }

  Future<void> _loadConfiguration() async {
    setState(() => _isLoading = true);
    try {
      final config = await _configService.getAccountConfiguration();
      _unitNameController.text = config.unitName ?? '';
      _unitNumberController.text = config.unitNumber ?? '';
      _bishopNameController.text = config.bishopName ?? '';
      _firstCounselorController.text = config.firstCounselorName ?? '';
      _secondCounselorController.text = config.secondCounselorName ?? '';
      _secretaryController.text = config.secretaryName ?? '';
    } catch (e) {
      _showMessage('Error cargando configuración: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveConfiguration() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await _configService.saveAccountConfiguration(
          unitName: _unitNameController.text.trim(),
          unitNumber: _unitNumberController.text.trim(),
          bishopName: _bishopNameController.text.trim(),
          firstCounselorName: _firstCounselorController.text.trim(),
          secondCounselorName: _secondCounselorController.text.trim(),
          secretaryName: _secretaryController.text.trim(),
        );
        _showMessage('Configuración guardada exitosamente.');
      } catch (e) {
        _showMessage('Error guardando configuración: $e', isError: true);
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    _unitNameController.dispose();
    _unitNumberController.dispose();
    _bishopNameController.dispose();
    _firstCounselorController.dispose();
    _secondCounselorController.dispose();
    _secretaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración de Cuenta'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: CustomCard(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Datos de la Unidad y Liderazgo',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Theme.of(context).primaryColor,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Esta información se usará para completar automáticamente los documentos PDF.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 24),
                      _buildTextField(_unitNameController, 'Nombre de la Unidad Principal (Ej: Estaca/Distrito)', Icons.business_outlined),
                      _buildTextField(_unitNumberController, 'Número de la Unidad Principal', Icons.pin_outlined),
                      _buildTextField(_bishopNameController, 'Nombre del Obispo/Presidente de Estaca', Icons.person_outline),
                      _buildTextField(_firstCounselorController, 'Nombre del 1er Consejero', Icons.person_outline),
                      _buildTextField(_secondCounselorController, 'Nombre del 2do Consejero (Opcional en PDF)', Icons.person_outline, isOptional: true),
                      _buildTextField(_secretaryController, 'Nombre del Secretario (Opcional en PDF)', Icons.person_outline, isOptional: true),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Guardar Configuración'),
                          onPressed: _isLoading ? null : _saveConfiguration,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isOptional = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (!isOptional && (value == null || value.trim().isEmpty)) {
            return 'Este campo es obligatorio.';
          }
          return null;
        },
        textCapitalization: TextCapitalization.words,
      ),
    );
  }
}