import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../models/enums.dart';
import '../../services/category_service.dart';

class CategoryFormDialog extends StatefulWidget {
  final Category? categoryToEdit;

  const CategoryFormDialog({super.key, this.categoryToEdit});

  @override
  State<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<CategoryFormDialog> {
  final CategoryService _categoryService = CategoryService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  
  ExpenseCategoryType _selectedType = ExpenseCategoryType.presupuesto;
  bool _isLoading = false;
  List<Category> _existingCategories = [];

  bool get _isEditing => widget.categoryToEdit != null;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _existingCategories = await _categoryService.getAllCategories();
    
    if (_isEditing) {
      _nameController.text = widget.categoryToEdit!.name;
      _selectedType = widget.categoryToEdit!.type;
    }
    
    if (mounted) setState(() {});
  }

  Future<void> _saveCategory() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() { _isLoading = true; });

    try {
      final categoryName = _nameController.text.trim();
      final category = Category(
        id: _isEditing ? widget.categoryToEdit!.id : null,
        name: categoryName,
        type: _selectedType,
      );

      int result;
      if (_isEditing) {
        result = await _categoryService.updateCategory(category);
      } else {
        result = await _categoryService.createCategory(category);
      }

      if (mounted) {
        Navigator.of(context).pop(result > 0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _isEditing ? Icons.edit_outlined : Icons.add_circle_outline,
              color: Colors.blue[700],
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isEditing ? 'Editar Subcategoría' : 'Nueva Subcategoría',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<ExpenseCategoryType>(
                value: _selectedType,
                decoration: InputDecoration(
                  labelText: 'Tipo de Gasto Principal',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                items: ExpenseCategoryType.values.map((type) {
                  return DropdownMenuItem<ExpenseCategoryType>(
                    value: type,
                    child: Text(expenseCategoryTypeToDisplayString(type)),
                  );
                }).toList(),
                onChanged: _isEditing ? null : (ExpenseCategoryType? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedType = newValue;
                    });
                  }
                },
                validator: (value) => value == null ? 'Seleccione un tipo.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nombre de la Subcategoría',
                  hintText: 'Ej: Alimentos, Transporte, Donativo Misionero',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor, ingrese un nombre.';
                  }
                  
                  // Verificar duplicados
                  final nameExists = _existingCategories.any(
                    (cat) => cat.name.trim().toLowerCase() == value.trim().toLowerCase() && 
                    cat.type == _selectedType &&
                    (!_isEditing || cat.id != widget.categoryToEdit!.id)
                  );
                  
                  if (nameExists) {
                    return 'Esta subcategoría ya existe para este tipo.';
                  }
                  
                  return null;
                },
                autofocus: !_isEditing,
                textCapitalization: TextCapitalization.sentences,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _saveCategory,
          icon: _isLoading 
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(_isEditing ? Icons.save_outlined : Icons.add_circle_outline),
          label: Text(_isEditing ? 'Actualizar' : 'Guardar'),
        ),
      ],
    );
  }
}