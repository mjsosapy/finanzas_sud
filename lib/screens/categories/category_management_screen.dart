import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../models/enums.dart';
import '../../services/category_service.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/category_management/category_form_dialog.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  final CategoryService _categoryService = CategoryService();
  Map<ExpenseCategoryType, List<Category>> _groupedCategories = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() { _isLoading = true; });
    
    try {
      final grouped = await _categoryService.getCategoriesGroupedByType();
      if (mounted) {
        setState(() {
          _groupedCategories = grouped;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isLoading = false; });
        _showMessage('Error cargando categorías: $e', isError: true);
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[600] : Colors.green[600],
      ),
    );
  }

  Future<void> _showCategoryDialog({Category? categoryToEdit}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CategoryFormDialog(categoryToEdit: categoryToEdit),
    );

    if (result == true) {
      _loadCategories();
      _showMessage(
        categoryToEdit == null 
          ? 'Subcategoría creada exitosamente' 
          : 'Subcategoría actualizada exitosamente'
      );
    }
  }

  Future<void> _deleteCategory(Category category) async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: Text(
            '¿Estás seguro de que deseas eliminar la subcategoría "${category.name}" (Tipo: ${expenseCategoryTypeToDisplayString(category.type)})?\n\nLos gastos asociados quedarán sin categoría.'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true && category.id != null) {
      try {
        await _categoryService.deleteCategory(category.id!);
        _showMessage('Subcategoría eliminada exitosamente');
        _loadCategories();
      } catch (e) {
        _showMessage('Error eliminando subcategoría: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subcategorías de Gasto'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Cargando categorías...')
          : _groupedCategories.values.every((list) => list.isEmpty)
              ? EmptyStateWidget(
                  icon: Icons.playlist_add_outlined,
                  title: 'No hay subcategorías registradas',
                  subtitle: 'Presiona el botón "+" para añadir una nueva.',
                  action: ElevatedButton.icon(
                    onPressed: () => _showCategoryDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Nueva Subcategoría'),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(8.0),
                  children: ExpenseCategoryType.values.map((type) {
                    final categoriesInType = _groupedCategories[type] ?? [];
                    
                    if (categoriesInType.isEmpty) return const SizedBox.shrink();
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12.0, 16.0, 12.0, 8.0),
                          child: Row(
                            children: [
                              Icon(
                                type == ExpenseCategoryType.presupuesto 
                                  ? Icons.account_balance_wallet_outlined 
                                  : Icons.volunteer_activism_outlined,
                                color: Theme.of(context).primaryColor,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                expenseCategoryTypeToDisplayString(type),
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Theme.of(context).primaryColor.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  '${categoriesInType.length}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: categoriesInType.length,
                          itemBuilder: (context, index) {
                            final category = categoriesInType[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                              elevation: 2,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: type == ExpenseCategoryType.presupuesto 
                                    ? Colors.blue[100] 
                                    : Colors.orange[100],
                                  child: Icon(
                                    type == ExpenseCategoryType.presupuesto 
                                      ? Icons.account_balance_wallet_outlined 
                                      : Icons.volunteer_activism_outlined,
                                    color: type == ExpenseCategoryType.presupuesto 
                                      ? Colors.blue[600] 
                                      : Colors.orange[600],
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  category.name,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  expenseCategoryTypeToDisplayString(category.type),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.edit_note_outlined, color: Colors.blue[600]),
                                      tooltip: 'Editar Subcategoría',
                                      onPressed: () => _showCategoryDialog(categoryToEdit: category),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete_forever_outlined, color: Colors.red[600]),
                                      tooltip: 'Eliminar Subcategoría',
                                      onPressed: () => _deleteCategory(category),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 20),
                      ],
                    );
                  }).toList(),
                ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_outlined),
        label: const Text('Nueva Subcategoría'),
        onPressed: () => _showCategoryDialog(),
      ),
    );
  }
}