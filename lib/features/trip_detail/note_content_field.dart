/// 筆記欄位的文字選取、讀屏與外部連結；卡片與分頁由各 renderer 負責。
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_feedback.dart';
import '../../models/note_content.dart';
import '../../models/note_section.dart';
import '../../theme/tokens.dart';

/// 公開分享與列印預覽共用筆記區塊圖示。
IconData noteContentSectionIcon(NoteSection section) => switch (section) {
  NoteSection.flights => CupertinoIcons.airplane,
  NoteSection.lodgings => CupertinoIcons.bed_double,
  NoteSection.reservations => CupertinoIcons.checkmark_circle,
  NoteSection.pretrip => CupertinoIcons.doc_text,
  NoteSection.emergency => CupertinoIcons.phone,
};

class NoteContentFieldView extends StatelessWidget {
  const NoteContentFieldView({super.key, required this.field});

  final NoteContentField field;

  @override
  Widget build(BuildContext context) {
    final valueIsLink =
        field.links.length == 1 && field.links.single.label == field.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!valueIsLink)
          Semantics(
            container: true,
            child: Text(field.text, semanticsLabel: field.semanticsLabel),
          ),
        for (final link in field.links)
          Semantics(
            container: true,
            link: true,
            onTap: () => _open(context, link.uri),
            excludeSemantics: true,
            label: valueIsLink ? field.semanticsLabel : link.label,
            child: TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(TpSpacing.tapMin, TpSpacing.tapMin),
                padding: const EdgeInsets.symmetric(horizontal: TpSpacing.s1),
                alignment: Alignment.centerLeft,
              ),
              onPressed: () => _open(context, link.uri),
              child: ExcludeSemantics(child: Text(link.label)),
            ),
          ),
      ],
    );
  }

  Future<void> _open(BuildContext context, Uri uri) async {
    if (!context.mounted) return;
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('無法開啟連結');
      }
    } on Exception {
      if (context.mounted) {
        showAppError(context, '無法開啟連結', onRetry: () => _open(context, uri));
      }
    }
  }
}
