import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class TpSettingsGroup extends StatelessWidget {
  const TpSettingsGroup({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TpSpacing.s4,
        TpSpacing.s3,
        TpSpacing.s4,
        TpSpacing.s4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TpSpacing.s3,
                0,
                TpSpacing.s3,
                TpSpacing.s2,
              ),
              child: Text(
                title!,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
          TpGroupedSurface(children: children),
        ],
      ),
    );
  }
}

/// HIG inset-grouped list 的唯一 surface 與 separator 實作。
///
/// 設定、收藏等內容 row 都委派這個元件，避免每筆各自套圓角卡片，並讓
/// light／dark surface、圓角及 inset separator 永遠同步。
class TpGroupedSurface extends StatelessWidget {
  const TpGroupedSurface({
    super.key,
    required this.children,
    this.separatorIndent = TpSpacing.s4,
    this.separatorEndIndent = TpSpacing.s4,
  });

  final List<Widget> children;
  final double separatorIndent;
  final double separatorEndIndent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(TpRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0)
              Divider(
                height: 1,
                indent: separatorIndent,
                endIndent: separatorEndIndent,
                color: theme.colorScheme.outlineVariant,
              ),
            children[index],
          ],
        ],
      ),
    );
  }
}

class TpSettingsRow extends StatelessWidget {
  /// 互斥選項列的勾選欄寬度,未選中時同寬留白讓各列標題欄一致。
  static const _checkmarkSlot = 24.0;

  const TpSettingsRow({
    super.key,
    required this.title,
    this.subtitle,
    this.value,
    this.leading,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.selected,
    this.inMutuallyExclusiveGroup = false,
  });

  final String title;
  final String? subtitle;
  final String? value;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;
  final bool? selected;
  final bool inMutuallyExclusiveGroup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleColor = destructive
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface;
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: TpSpacing.tapMin),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TpSpacing.s4,
          vertical: TpSpacing.s3,
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              IconTheme(
                data: IconThemeData(color: titleColor, size: 21),
                child: leading!,
              ),
              const SizedBox(width: TpSpacing.s3),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: titleColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: TpSpacing.s1),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: TpSpacing.s3),
              // 必須是 Expanded(tight):與 title 同為 loose 時 Row 會留下未分配
              // 空間,把 value 與 chevron 一起往左推,右緣就對不齊隔壁列。
              Expanded(
                child: Text(
                  value!,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            if (trailing != null) ...[
              const SizedBox(width: TpSpacing.s2),
              trailing!,
            ] else if (selected != null) ...[
              // 互斥選項列:選中打勾,未選中留等寬空位,不放 disclosure chevron
              // (chevron 代表「還會往下一層」,選項列點下去只是就地切換)。
              const SizedBox(width: TpSpacing.s2),
              SizedBox(
                width: _checkmarkSlot,
                child: selected!
                    ? Icon(
                        CupertinoIcons.checkmark,
                        size: _checkmarkSlot,
                        color: theme.colorScheme.primary,
                      )
                    : null,
              ),
            ] else if (onTap != null) ...[
              const SizedBox(width: TpSpacing.s2),
              Icon(
                CupertinoIcons.chevron_forward,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );

    return Semantics(
      button: onTap != null,
      label: title,
      selected: selected,
      inMutuallyExclusiveGroup: inMutuallyExclusiveGroup,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}
