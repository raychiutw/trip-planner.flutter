import 'package:flutter/cupertino.dart'
    show
        CupertinoDatePicker,
        CupertinoDatePickerMode,
        CupertinoIcons,
        CupertinoTheme;
import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 輪盤的分鐘間隔 —— 維持 5 分鐘。
///
/// 這個常數只決定**輪盤停得住的位置**,不決定「使用者的值是什麼」。
/// 兩者的差別見 [_TpCompactTimeFieldState._wheelSeed]。
const _kMinuteInterval = 5;

/// `CupertinoDatePicker` 在 1× 字級下的輪盤字級與列高（framework 內建值）。
const _kBaseFontSize = 21.0;
const _kBaseItemExtent = 32.0;

/// 展開後輪盤在 1× 字級下的高度;放大時與字級同比例成長。
const _kBaseWheelHeight = 196.0;

/// 字級放大的上限。
///
/// 輪盤是整組等比放大（字級、列高、容器高一起），AX5（約 3.2×）原封不動照放
/// 會讓單一欄位吃掉超過一屏,表單其餘欄位被推到看不見。收在 2× 仍滿足「大字級
/// 跟著放大」,又不會讓展開區塊爆版。
const _kMaxWheelScale = 2.0;

/// 同一張表單上的 compact 時間欄位共用的展開群組。
///
/// 值是「目前展開的那一顆」的識別權杖;`null` 表示全部收合。共用同一個
/// instance 的欄位因此不可能同時展開 —— 展開第二顆時第一顆自動收起,否則版面
/// 會被兩座輪盤推到看不見。
class TpTimeFieldGroup extends ValueNotifier<Object?> {
  TpTimeFieldGroup() : super(null);
}

/// HIG compact 時間選擇:一列標籤 + 值膠囊,點膠囊在原地展開輪盤。
///
/// HIG `pickers`:「Avoid switching views to show a picker. A picker works well
/// when displayed in context, below or in proximity to the field people are
/// editing.」所以這裡不開 modal、不推 route,輪盤就長在欄位下方、把內容往下推。
///
/// 膠囊按鈕走 Apple 對 compact date picker 的 accent 用法（品牌柔褐淡底 + 柔褐
/// 前景）。這與 ADR-0004 不牴觸:那條管的是**選取指示**,這顆是**值按鈕**;
/// 輪盤內部的選取列仍走中性語意層。
class TpCompactTimeField extends StatefulWidget {
  const TpCompactTimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.group,
    this.buttonKey,
    this.clearKey,
    this.errorKey,
    this.onCleared,
    this.enabled = true,
    this.emptyLabel = '未設定',
    this.fallbackValue = const TimeOfDay(hour: 9, minute: 0),
    this.errorText,
  });

  /// 列首的欄位名（「開始」「結束」）。
  final String label;

  /// 目前的值;`null` 顯示 [emptyLabel]。
  final TimeOfDay? value;

  /// **只有使用者真的滾動過輪盤才會被呼叫。**
  final ValueChanged<TimeOfDay> onChanged;

  /// 清除鈕的動作;`null` 表示這個欄位不可清除。
  final VoidCallback? onCleared;

  /// 與同一張表單上其他時間欄位共用的展開群組。
  final TpTimeFieldGroup? group;

  final Key? buttonKey;
  final Key? clearKey;
  final Key? errorKey;
  final bool enabled;
  final String emptyLabel;

  /// [value] 為 `null` 時輪盤的起點。
  final TimeOfDay fallbackValue;

  /// 顯示在欄位下方的錯誤說明。
  final String? errorText;

  @override
  State<TpCompactTimeField> createState() => _TpCompactTimeFieldState();
}

class _TpCompactTimeFieldState extends State<TpCompactTimeField> {
  TpTimeFieldGroup? _ownedGroup;

  /// 這次展開時輪盤停的位置。展開期間固定不動,避免回寫新值後輪盤被重設。
  DateTime? _wheelInitial;

  TpTimeFieldGroup get _group =>
      widget.group ?? (_ownedGroup ??= TpTimeFieldGroup());

  bool get _isExpanded => _group.value == this;

  @override
  void dispose() {
    _ownedGroup?.dispose();
    super.dispose();
  }

  /// 輪盤起始位置 —— **只寫進輪盤,絕不回寫給呼叫端**。
  ///
  /// `CupertinoDatePicker.minuteInterval` 會 assert 初始分鐘必須是間隔的倍數,
  /// 所以位置一定要 round。但 round 出來的是「輪盤停在哪一格」,不是使用者的
  /// 選擇 —— 舊版把它當成新值送回去,`09:07` 開一次 picker 就被靜默改成
  /// `09:05`(web 與後端都允許任意分鐘)。唯一的回寫入口是 [_commit],只有輪盤
  /// 真的觸發 `onDateTimeChanged` 才會走到。
  DateTime _wheelSeed(TimeOfDay value) => DateTime(
    2000,
    1,
    1,
    value.hour,
    value.minute - value.minute % _kMinuteInterval,
  );

  void _commit(DateTime value) =>
      widget.onChanged(TimeOfDay(hour: value.hour, minute: value.minute));

  void _toggle() {
    if (_isExpanded) {
      _group.value = null;
      return;
    }
    _wheelInitial = _wheelSeed(widget.value ?? widget.fallbackValue);
    _group.value = this;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Object?>(
      valueListenable: _group,
      builder: (context, _, _) {
        final theme = Theme.of(context);
        final expanded = _isExpanded && widget.enabled;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildRow(context, expanded: expanded),
            AnimatedSize(
              duration: TpMotion.resolve(context, TpMotion.normal),
              curve: TpMotion.appleEase,
              alignment: Alignment.topCenter,
              child: expanded
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Divider(
                          key: const ValueKey('tp-compact-time-hairline'),
                          height: TpSpacing.s2,
                          thickness: 0.5,
                          color: theme.colorScheme.outlineVariant,
                        ),
                        _buildWheel(context),
                      ],
                    )
                  : const SizedBox(width: double.infinity),
            ),
            if (widget.errorText case final error?)
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: TpSpacing.s2,
                  top: TpSpacing.s1,
                ),
                child: Text(
                  error,
                  key: widget.errorKey,
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildRow(BuildContext context, {required bool expanded}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final display = widget.value?.format(context) ?? widget.emptyLabel;
    return Row(
      children: [
        Expanded(child: Text(widget.label, style: theme.textTheme.bodyLarge)),
        if (widget.onCleared != null && widget.value != null)
          IconButton(
            key: widget.clearKey,
            onPressed: widget.enabled ? widget.onCleared : null,
            tooltip: '清除${widget.label}時間',
            icon: const Icon(CupertinoIcons.xmark_circle_fill, size: 18),
            color: scheme.onSurfaceVariant,
          ),
        TextButton(
          key: widget.buttonKey,
          onPressed: widget.enabled ? _toggle : null,
          style: TextButton.styleFrom(
            backgroundColor: scheme.primaryContainer,
            foregroundColor: scheme.onPrimaryContainer,
            disabledBackgroundColor: scheme.surfaceContainerHigh,
            disabledForegroundColor: scheme.onSurfaceVariant,
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(
              horizontal: TpSpacing.s3,
              vertical: TpSpacing.s2,
            ),
            minimumSize: const Size(0, TpSpacing.tapMin),
            textStyle: theme.textTheme.bodyLarge,
          ),
          child: Semantics(
            hint: expanded ? '點兩下收合時間選擇' : '點兩下展開時間選擇',
            child: Text(display),
          ),
        ),
      ],
    );
  }

  Widget _buildWheel(BuildContext context) {
    final cupertino = CupertinoTheme.of(context);
    final baseStyle = cupertino.textTheme.dateTimePickerTextStyle;
    final baseFontSize = baseStyle.fontSize ?? _kBaseFontSize;
    // `CupertinoDatePicker` 的 build 最外層是 `MediaQuery.withNoTextScaling`,
    // 輪盤文字因此對 Dynamic Type 免疫 —— 從外面包 `MediaQuery` 蓋不掉它。
    // 改成在外面把字級換算成實際 pt 寫進 `CupertinoTheme`,並同比例放大列高與
    // 容器高度,字級才會生效而且不會被 32pt 的列高裁掉。
    final scale =
        (MediaQuery.textScalerOf(context).scale(baseFontSize) / baseFontSize)
            .clamp(1.0, _kMaxWheelScale);

    return SizedBox(
      height: _kBaseWheelHeight * scale,
      child: ShaderMask(
        // 只吃 alpha 當遮罩,做輪盤上下緣的淡出;顏色本身不會畫到畫面上。
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x00000000),
            Color(0xFF000000),
            Color(0xFF000000),
            Color(0x00000000),
          ],
          stops: [0.0, 0.24, 0.76, 1.0],
        ).createShader(bounds),
        blendMode: BlendMode.dstIn,
        child: CupertinoTheme(
          data: cupertino.copyWith(
            textTheme: cupertino.textTheme.copyWith(
              dateTimePickerTextStyle: baseStyle.copyWith(
                fontSize: baseFontSize * scale,
              ),
            ),
          ),
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.time,
            minuteInterval: _kMinuteInterval,
            // 12／24 小時制一律跟隨系統偏好,不由 app 決定。
            use24hFormat: MediaQuery.alwaysUse24HourFormatOf(context),
            itemExtent: _kBaseItemExtent * scale,
            initialDateTime:
                _wheelInitial ??
                _wheelSeed(widget.value ?? widget.fallbackValue),
            backgroundColor: const Color(0x00000000),
            selectionOverlayBuilder: _buildSelectionOverlay,
            onDateTimeChanged: _commit,
          ),
        ),
      ),
    );
  }

  /// 輪盤的選取列 —— 中性語意層的圓角高亮,不鋪品牌色（ADR-0004）。
  ///
  /// 由 `onSurface` 低透明度導出,兩種明暗模式各自得到可見的中性填充,而且疊在
  /// 文字上不會改變文字顏色（同色相疊加）。
  Widget _buildSelectionOverlay(
    BuildContext context, {
    required int columnCount,
    required int selectedIndex,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isFirst = selectedIndex == 0;
    final isLast = selectedIndex == columnCount - 1;
    return Container(
      key: const ValueKey('tp-compact-time-selection'),
      margin: EdgeInsetsDirectional.only(
        start: isFirst ? TpSpacing.s2 : 0,
        end: isLast ? TpSpacing.s2 : 0,
      ),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.10),
        borderRadius: BorderRadiusDirectional.horizontal(
          start: Radius.circular(isFirst ? TpRadius.md : 0),
          end: Radius.circular(isLast ? TpRadius.md : 0),
        ),
      ),
    );
  }
}
