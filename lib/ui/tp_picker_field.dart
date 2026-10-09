import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../app/adaptive.dart';
import '../theme/tokens.dart';
import 'tp_action_item.dart';
import 'tp_tap_target.dart';

const _compactChevronSize = 12.0;
const _fieldChevronSize = 14.0;

/// 單選欄位,取代 Material 的 `DropdownButton`／`DropdownButtonFormField`。
///
/// 欄位列顯示 [label] 與目前值,點擊開 action sheet(`showAppActionSheet`),選項
/// 以 [options] 的迭代順序列出,目前值打勾。[onChanged] 為 null 時停用。
/// [value] 為 null 或不在 [options] 裡時顯示 [placeholder],不留空白。
class TpPickerField<T extends Object> extends StatelessWidget {
  const TpPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.sheetTitle,
    this.compact = false,
    this.placeholder = '未選擇',
  });

  final String label;
  final T? value;
  final Map<T, String> options;
  final ValueChanged<T>? onChanged;

  /// action sheet 標題;預設用 [label]。
  final String? sheetTitle;

  /// true 時只畫「目前值 + 上下箭頭」(行內用,不畫標籤與外框);語意仍朗讀 [label]。
  final bool compact;

  /// 沒有可顯示的目前值時的文字。
  final String placeholder;

  Future<void> _open(BuildContext context) async {
    final picked = await showAppActionSheet<T>(
      context,
      title: sheetTitle ?? label,
      actions: [
        for (final entry in options.entries)
          TpActionItem<T>(
            value: entry.key,
            label: entry.value,
            selected: entry.key == value,
          ),
      ],
    );
    if (picked != null) onChanged?.call(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onChanged != null;
    final current = value == null ? null : options[value];
    return TpTapTarget(
      onTap: enabled ? () => _open(context) : null,
      button: true,
      label: label,
      value: current ?? placeholder,
      minWidth: TpSpacing.tapMin,
      child: compact
          ? _compactRow(theme, enabled, current)
          : _fieldRow(theme, enabled, current),
    );
  }

  Widget _compactRow(ThemeData theme, bool enabled, String? current) {
    final scheme = theme.colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: TpSpacing.tapMin),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            current ?? placeholder,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: !enabled
                  ? scheme.onSurface.withAlpha(TpDisabled.contentAlpha)
                  : current == null
                  ? scheme.onSurfaceVariant
                  : scheme.primary,
            ),
          ),
          const SizedBox(width: TpSpacing.s1),
          Icon(
            CupertinoIcons.chevron_up_chevron_down,
            size: _compactChevronSize,
            color: scheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  Widget _fieldRow(ThemeData theme, bool enabled, String? current) {
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TpRadius.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: TpSpacing.s3),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: TpSpacing.tapMin),
          child: Row(
            children: [
              Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: enabled
                      ? scheme.onSurface
                      : scheme.onSurface.withAlpha(TpDisabled.contentAlpha),
                ),
              ),
              const SizedBox(width: TpSpacing.s3),
              Expanded(
                child: Text(
                  current ?? placeholder,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: TpSpacing.s2),
              Icon(
                CupertinoIcons.chevron_up_chevron_down,
                size: _fieldChevronSize,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
