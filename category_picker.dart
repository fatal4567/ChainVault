import 'package:flutter/material.dart';

class CategoryPicker extends StatelessWidget {
  final List<String> categories;
  final String? selectedCategory;
  final ValueChanged<String?> onSelected;

  const CategoryPicker({
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: selectedCategory,
      decoration: const InputDecoration(
        labelText: 'Category',
        prefixIcon: Icon(Icons.category),
      ),
      items: categories.map((category) => DropdownMenuItem(value: category, child: Text(category))).toList(),
      onChanged: onSelected,
    );
  }
}