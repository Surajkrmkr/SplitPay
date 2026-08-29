import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/category_app_icons.dart';

class AppIconPickerDialog extends StatefulWidget {
  final List<String> initialSelected;

  const AppIconPickerDialog({
    super.key,
    required this.initialSelected,
  });

  @override
  State<AppIconPickerDialog> createState() => _AppIconPickerDialogState();
}

class _AppIconPickerDialogState extends State<AppIconPickerDialog> {
  late Set<String> _selected;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelected.toSet();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _filteredIcons {
    if (_searchQuery.isEmpty) return CategoryAppIcons.allAvailableAppIcons;
    final query = _searchQuery.toLowerCase();
    return CategoryAppIcons.allAvailableAppIcons.where((fileName) {
      final name = fileName.replaceAll('.png', '').toLowerCase();
      return name.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: const Text(
        'Select Suggested Apps',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.sizeOf(context).height * 0.45,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              decoration: InputDecoration(
                hintText: 'Search app (e.g. Swiggy, Uber)',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                filled: true,
                fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _filteredIcons.isEmpty
                  ? Center(
                      child: Text(
                        'No apps found',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : GridView.builder(
                      itemCount: _filteredIcons.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.9,
                      ),
                      itemBuilder: (context, index) {
                        final fileName = _filteredIcons[index];
                        final isSelected = _selected.contains(fileName);
                        final displayName = fileName.replaceAll('.png', '');

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selected.remove(fileName);
                              } else {
                                _selected.add(fileName);
                              }
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.15)
                                  : (isDark
                                      ? AppColors.darkCard
                                      : AppColors.lightCard),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : (isDark
                                        ? AppColors.darkBorder
                                        : AppColors.lightBorder),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.asset(
                                        CategoryAppIcons.pathFor(fileName),
                                        width: 36,
                                        height: 36,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Icon(
                                          Icons.apps_rounded,
                                          size: 32,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Positioned(
                                        right: 0,
                                        top: 0,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            shape: BoxShape.circle,
                                          ),
                                          padding: const EdgeInsets.all(2),
                                          child: const Icon(
                                            Icons.check,
                                            size: 10,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  displayName,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? AppColors.primary
                                        : (isDark
                                            ? Colors.white
                                            : AppColors.textLight),
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: () => Navigator.pop(context, _selected.toList()),
          child: Text('Save (${_selected.length})'),
        ),
      ],
    );
  }
}
