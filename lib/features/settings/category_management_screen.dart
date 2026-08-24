import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/category_app_icons.dart';
import '../../data/models/custom_category.dart';
import '../../data/models/transaction_model.dart';
import '../../providers/settings_provider.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../shared/widgets/create_category_dialog.dart';

enum _CategoryTab { all, custom, system }

class CategoryManagementScreen extends ConsumerStatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  ConsumerState<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState
    extends ConsumerState<CategoryManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  _CategoryTab _selectedTab = _CategoryTab.all;
  bool _isGridView = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openCreateCategorySheet(BuildContext context,
      {CustomCategory? categoryToEdit}) {
    showCreateCategoryBottomSheet(
      context,
      categoryToEdit: categoryToEdit,
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, CustomCategory cat) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Category?'),
        content: Text(
          'Delete "${cat.label}"? Existing transactions will remain unaffected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.expense,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(customCategoriesProvider.notifier).remove(cat.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customCategories = ref.watch(customCategoriesProvider);
    final hiddenCategories = ref.watch(hiddenCategoriesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    // Filter categories by search query
    final filteredCustom = customCategories.where((c) {
      if (_searchQuery.isEmpty) return true;
      final matchLabel = c.label.toLowerCase().contains(_searchQuery);
      final matchApps = c.suggestedApps
          .any((app) => app.toLowerCase().contains(_searchQuery));
      return matchLabel || matchApps;
    }).toList();

    final filteredSystem = Category.values.where((c) {
      if (_searchQuery.isEmpty) return true;
      final matchLabel = c.label.toLowerCase().contains(_searchQuery);
      final builtInApps = CategoryAppIcons.iconsFor(c);
      final matchApps = builtInApps
          .any((app) => app.toLowerCase().contains(_searchQuery));
      return matchLabel || matchApps;
    }).toList();

    final visibleSystemCount =
        Category.values.where((c) => !hiddenCategories.contains(c.name)).length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  const AppBackButton(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Manage Categories',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // View mode toggle (List vs Grid)
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _isGridView = !_isGridView;
                      });
                    },
                    tooltip: _isGridView ? 'Switch to List' : 'Switch to Grid',
                    icon: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkCard
                            : AppColors.lightCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                      ),
                      child: Icon(
                        _isGridView
                            ? Icons.view_list_rounded
                            : Icons.grid_view_rounded,
                        size: 18,
                        color: primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Primary Add Category Button
                  GestureDetector(
                    onTap: () => _openCreateCategorySheet(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.add_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Add',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content Area
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                children: [
                  // Overview Stats Banner
                  _CategoryStatsBanner(
                    totalCustom: customCategories.length,
                    totalSystem: Category.values.length,
                    visibleSystem: visibleSystemCount,
                    isDark: isDark,
                    primary: primary,
                  ),
                  const SizedBox(height: 16),

                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search categories or linked apps...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary.withValues(alpha: 0.7),
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: AppColors.textSecondary,
                                ),
                                onPressed: () => _searchController.clear(),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Category Type Filter Tabs
                  Row(
                    children: [
                      _FilterTabChip(
                        label: 'All (${customCategories.length + Category.values.length})',
                        isSelected: _selectedTab == _CategoryTab.all,
                        onTap: () =>
                            setState(() => _selectedTab = _CategoryTab.all),
                        primary: primary,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _FilterTabChip(
                        label: 'Custom (${customCategories.length})',
                        isSelected: _selectedTab == _CategoryTab.custom,
                        onTap: () =>
                            setState(() => _selectedTab = _CategoryTab.custom),
                        primary: primary,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _FilterTabChip(
                        label: 'System (${Category.values.length})',
                        isSelected: _selectedTab == _CategoryTab.system,
                        onTap: () =>
                            setState(() => _selectedTab = _CategoryTab.system),
                        primary: primary,
                        isDark: isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Custom Categories Section
                  if (_selectedTab == _CategoryTab.all ||
                      _selectedTab == _CategoryTab.custom) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'CUSTOM CATEGORIES (${filteredCustom.length})',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        if (customCategories.isNotEmpty)
                          GestureDetector(
                            onTap: () => _openCreateCategorySheet(context),
                            child: Text(
                              '+ Create New',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (filteredCustom.isEmpty)
                      _EmptyCategoryCard(
                        title: _searchQuery.isNotEmpty
                            ? 'No custom categories found'
                            : 'No custom categories yet',
                        subtitle: _searchQuery.isNotEmpty
                            ? 'Try searching for a different term.'
                            : 'Tap below to create your first custom spend category.',
                        buttonLabel: _searchQuery.isEmpty ? 'Add Category' : null,
                        onButtonTap: () => _openCreateCategorySheet(context),
                        isDark: isDark,
                      )
                    else if (_isGridView)
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredCustom.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.15,
                        ),
                        itemBuilder: (context, index) {
                          final cat = filteredCustom[index];
                          return _CustomCategoryGridTile(
                            cat: cat,
                            isDark: isDark,
                            onEdit: () => _openCreateCategorySheet(
                              context,
                              categoryToEdit: cat,
                            ),
                            onDelete: () => _confirmDelete(context, ref, cat),
                          );
                        },
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredCustom.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final cat = filteredCustom[index];
                          return _CustomCategoryListTile(
                            cat: cat,
                            isDark: isDark,
                            onEdit: () => _openCreateCategorySheet(
                              context,
                              categoryToEdit: cat,
                            ),
                            onDelete: () => _confirmDelete(context, ref, cat),
                          );
                        },
                      ),
                    const SizedBox(height: 24),
                  ],

                  // System Categories Section
                  if (_selectedTab == _CategoryTab.all ||
                      _selectedTab == _CategoryTab.system) ...[
                    Text(
                      'SYSTEM CATEGORIES (${filteredSystem.length})',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (filteredSystem.isEmpty)
                      _EmptyCategoryCard(
                        title: 'No system categories match',
                        subtitle: 'Check your search query or clear the filter.',
                        isDark: isDark,
                      )
                    else if (_isGridView)
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredSystem.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.15,
                        ),
                        itemBuilder: (context, index) {
                          final sysCat = filteredSystem[index];
                          final isHidden =
                              hiddenCategories.contains(sysCat.name);
                          final builtInApps =
                              CategoryAppIcons.iconsFor(sysCat);

                          return _SystemCategoryGridTile(
                            sysCat: sysCat,
                            isHidden: isHidden,
                            builtInApps: builtInApps,
                            isDark: isDark,
                            onToggle: () {
                              ref
                                  .read(hiddenCategoriesProvider.notifier)
                                  .toggle(sysCat);
                            },
                          );
                        },
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredSystem.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final sysCat = filteredSystem[index];
                          final isHidden =
                              hiddenCategories.contains(sysCat.name);
                          final builtInApps =
                              CategoryAppIcons.iconsFor(sysCat);

                          return _SystemCategoryListTile(
                            sysCat: sysCat,
                            isHidden: isHidden,
                            builtInApps: builtInApps,
                            isDark: isDark,
                            onToggle: () {
                              ref
                                  .read(hiddenCategoriesProvider.notifier)
                                  .toggle(sysCat);
                            },
                          );
                        },
                      ),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stats Banner ─────────────────────────────────────────────────────────────

class _CategoryStatsBanner extends StatelessWidget {
  final int totalCustom;
  final int totalSystem;
  final int visibleSystem;
  final bool isDark;
  final Color primary;

  const _CategoryStatsBanner({
    required this.totalCustom,
    required this.totalSystem,
    required this.visibleSystem,
    required this.isDark,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = Theme.of(context).cardTheme.color ?? AppColors.darkCard;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? cardBg : AppColors.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.7,
        ),
      ),
      child: Row(
        children: [
          _StatItem(
            label: 'Custom',
            value: '$totalCustom',
            color: primary,
          ),
          _StatDivider(isDark: isDark),
          _StatItem(
            label: 'Active System',
            value: '$visibleSystem / $totalSystem',
            color: const Color(0xFF3B82F6),
          ),
          _StatDivider(isDark: isDark),
          _StatItem(
            label: 'Total Active',
            value: '${totalCustom + visibleSystem}',
            color: const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  final bool isDark;
  const _StatDivider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      width: 1,
      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
    );
  }
}

// ─── Filter Chip ──────────────────────────────────────────────────────────────

class _FilterTabChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color primary;
  final bool isDark;

  const _FilterTabChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.primary,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? primary.withValues(alpha: 0.18)
              : (isDark ? AppColors.darkCard : AppColors.lightCard),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? primary.withValues(alpha: 0.6)
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected
                ? primary
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── Custom Category List Tile (Full Horizontal Space) ───────────────────────

class _CustomCategoryListTile extends StatelessWidget {
  final CustomCategory cat;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CustomCategoryListTile({
    required this.cat,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = Theme.of(context).cardTheme.color ?? AppColors.darkCard;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? cardBg : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.6,
        ),
      ),
      child: Row(
        children: [
          // Icon Container
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cat.color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(cat.icon, color: cat.color, size: 20),
          ),
          const SizedBox(width: 14),

          // Label & Apps (Gets all available space!)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cat.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (cat.suggestedApps.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: cat.suggestedApps.map((fileName) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.asset(
                              CategoryAppIcons.pathFor(fileName),
                              width: 20,
                              height: 20,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.apps_rounded,
                                size: 14,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  )
                else
                  Text(
                    'No apps linked',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),

          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: onEdit,
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                tooltip: 'Edit',
              ),
              IconButton(
                onPressed: onDelete,
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: AppColors.expense,
                ),
                tooltip: 'Delete',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Custom Category Grid Tile (Vertical Stack Layout) ──────────────────────

class _CustomCategoryGridTile extends StatelessWidget {
  final CustomCategory cat;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CustomCategoryGridTile({
    required this.cat,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = Theme.of(context).cardTheme.color ?? AppColors.darkCard;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? cardBg : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.6,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Icon + Actions
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cat.color.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(cat.icon, color: cat.color, size: 18),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onEdit,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onDelete,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: AppColors.expense,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Title on its own line — full card width!
          Text(
            cat.label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const Spacer(),

          // Apps Row
          if (cat.suggestedApps.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: cat.suggestedApps.map((fileName) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: Image.asset(
                        CategoryAppIcons.pathFor(fileName),
                        width: 18,
                        height: 18,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.apps_rounded,
                          size: 14,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            )
          else
            Text(
              'No apps',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary.withValues(alpha: 0.5),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── System Category List Tile (Full Horizontal Space) ──────────────────────

class _SystemCategoryListTile extends StatelessWidget {
  final Category sysCat;
  final bool isHidden;
  final List<String> builtInApps;
  final bool isDark;
  final VoidCallback onToggle;

  const _SystemCategoryListTile({
    required this.sysCat,
    required this.isHidden,
    required this.builtInApps,
    required this.isDark,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final cardBg = Theme.of(context).cardTheme.color ?? AppColors.darkCard;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? cardBg : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.6,
        ),
      ),
      child: Row(
        children: [
          // Icon Container
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: sysCat.color.withValues(alpha: isHidden ? 0.08 : 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              sysCat.icon,
              color: isHidden ? AppColors.textSecondary : sysCat.color,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),

          // Title & Apps
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        sysCat.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: isHidden
                              ? AppColors.textSecondary
                              : (isDark ? Colors.white : AppColors.textLight),
                          decoration:
                              isHidden ? TextDecoration.lineThrough : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isHidden) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.textSecondary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Hidden',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                if (builtInApps.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: builtInApps.take(6).map((fileName) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.asset(
                              CategoryAppIcons.pathFor(fileName),
                              width: 20,
                              height: 20,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.apps_rounded,
                                size: 14,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  )
                else
                  Text(
                    'Default system category',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),

          // Visibility Switch
          Switch.adaptive(
            value: !isHidden,
            activeTrackColor: primary,
            onChanged: (_) => onToggle(),
          ),
        ],
      ),
    );
  }
}

// ─── System Category Grid Tile (Vertical Stack Layout) ──────────────────────

class _SystemCategoryGridTile extends StatelessWidget {
  final Category sysCat;
  final bool isHidden;
  final List<String> builtInApps;
  final bool isDark;
  final VoidCallback onToggle;

  const _SystemCategoryGridTile({
    required this.sysCat,
    required this.isHidden,
    required this.builtInApps,
    required this.isDark,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final cardBg = Theme.of(context).cardTheme.color ?? AppColors.darkCard;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? cardBg : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.6,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Icon + Switch
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: sysCat.color.withValues(alpha: isHidden ? 0.08 : 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  sysCat.icon,
                  color: isHidden ? AppColors.textSecondary : sysCat.color,
                  size: 18,
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 24,
                width: 36,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Switch.adaptive(
                    value: !isHidden,
                    activeTrackColor: primary,
                    onChanged: (_) => onToggle(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Title on its own line — full card width!
          Text(
            sysCat.label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: isHidden
                  ? AppColors.textSecondary
                  : (isDark ? Colors.white : AppColors.textLight),
              decoration: isHidden ? TextDecoration.lineThrough : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const Spacer(),

          // Apps Row
          if (builtInApps.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: builtInApps.take(4).map((fileName) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: Image.asset(
                        CategoryAppIcons.pathFor(fileName),
                        width: 18,
                        height: 18,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.apps_rounded,
                          size: 14,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            )
          else
            Text(
              'System',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary.withValues(alpha: 0.5),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Empty State Card ─────────────────────────────────────────────────────────

class _EmptyCategoryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? buttonLabel;
  final VoidCallback? onButtonTap;
  final bool isDark;

  const _EmptyCategoryCard({
    required this.title,
    required this.subtitle,
    this.buttonLabel,
    this.onButtonTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.category_outlined,
            size: 36,
            color: AppColors.textSecondary.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          if (buttonLabel != null && onButtonTap != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: primary,
                side: BorderSide(color: primary.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onButtonTap,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(buttonLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
