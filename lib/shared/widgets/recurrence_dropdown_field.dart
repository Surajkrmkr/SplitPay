import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/transaction_model.dart';

class RecurrenceDropdownField extends StatelessWidget {
  final RecurrenceType value;
  final ValueChanged<RecurrenceType> onChanged;
  final bool compact;

  const RecurrenceDropdownField({
    super.key,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = value.isRecurring
        ? Theme.of(context).colorScheme.primary
        : AppColors.textTertiary;

    final content = Row(
      children: [
        Icon(Icons.repeat_rounded, color: color, size: 19),
        if (!compact) ...[
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value.label,
              style: TextStyle(
                color: value.isRecurring
                    ? (isDark ? Colors.white : AppColors.textLight)
                    : AppColors.textTertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.textTertiary,
            size: 20,
          ),
        ],
      ],
    );

    if (compact) {
      return IconButton(
        tooltip: 'Repeat: ${value.label}',
        onPressed: () => _showPicker(context),
        style: IconButton.styleFrom(
          backgroundColor:
              value.isRecurring ? color.withValues(alpha: 0.14) : null,
        ),
        icon: content,
      );
    }

    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 0.5,
          ),
        ),
        child: content,
      ),
    );
  }

  void _showPicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Repeat expense',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            ...RecurrenceType.values.map(
              (type) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  type.icon,
                  color: type == value
                      ? Theme.of(context).colorScheme.primary
                      : AppColors.textSecondary,
                ),
                title: Text(type.label),
                trailing: type == value
                    ? Icon(
                        Icons.check_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  onChanged(type);
                  Navigator.of(sheetContext).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
