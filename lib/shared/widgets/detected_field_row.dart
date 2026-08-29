import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Row showing a single detected field (amount, title, date, ...) with a
/// checkbox to include/exclude it, and optional alternative candidates
/// rendered as tappable pills below. Shared by the bill-scan and SMS-paste
/// "confirm what we detected" dialogs.
class DetectedFieldRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final bool checked;
  final ValueChanged<bool>? onChanged;

  /// Optional alternative candidates from the parser. Rendered below the main
  /// value as tappable pills — the [selectedPill] is highlighted; tapping a
  /// pill calls [onPickPill] so the caller can swap the selection.
  final List<String> pills;
  final String? selectedPill;
  final ValueChanged<String>? onPickPill;

  const DetectedFieldRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.checked,
    required this.onChanged,
    this.pills = const [],
    this.selectedPill,
    this.onPickPill,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onChanged == null;
    // Only show alternatives — drop the one we're already displaying.
    final alternatives =
        pills.where((p) => p != selectedPill).toList(growable: false);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      value ?? 'Not detected',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDisabled
                            ? AppColors.textTertiary
                            : Theme.of(context).textTheme.bodyMedium?.color,
                        fontStyle: isDisabled ? FontStyle.italic : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Checkbox(
                value: checked,
                onChanged: isDisabled ? null : (v) => onChanged!(v ?? false),
                activeColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
            ],
          ),
          if (alternatives.isNotEmpty && onPickPill != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final p in alternatives)
                    SuggestionPill(
                      label: p,
                      onTap: () => onPickPill!(p),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SuggestionPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const SuggestionPill({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.35),
              width: 0.8,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}
