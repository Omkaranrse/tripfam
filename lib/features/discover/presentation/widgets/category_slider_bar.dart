import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';

class CategorySliderBar extends StatelessWidget {
  const CategorySliderBar({
    required this.selectedCategory,
    required this.onSelectCategory,
    super.key,
  });

  final String selectedCategory;
  final ValueChanged<String> onSelectCategory;

  static const categories = ['All', 'Trek', 'Beach', 'Road trip', 'City'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      height: 28,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = cat == selectedCategory;

          return AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.curve,
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary
                  : (isDark
                        ? const Color(0xFF16241C)
                        : const Color(0xFFE5EDE6)),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : (isDark
                          ? Colors.white.withAlpha(20)
                          : theme.colorScheme.outline.withAlpha(50)),
              ),
              boxShadow: isSelected ? AppShadows.subtle(context) : null,
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                onTap: () => onSelectCategory(cat),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 4,
                  ),
                  child: Center(
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11.5,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: isSelected
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
