import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/ui/tp_action_item.dart';

void main() {
  const sharedActions = <TpActionItem<String>>[
    TpActionItem(value: 'edit', label: '行程資料', icon: CupertinoIcons.pencil),
    TpActionItem(
      value: 'delete',
      label: '刪除行程',
      icon: CupertinoIcons.delete,
      dividerBefore: true,
      role: TpActionRole.destructive,
    ),
  ];

  test('one action list carries renderer-independent semantics', () {
    expect(sharedActions.last.role, TpActionRole.destructive);
    expect(sharedActions.last.dividerBefore, isTrue);
    expect(sharedActions.map((action) => action.value), ['edit', 'delete']);
  });
}
