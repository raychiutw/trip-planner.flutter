import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/note_section.dart';

void main() {
  group('NoteGenerationType 自擁 metadata', () {
    test('每一種生成類型都屬於行前須知或緊急聯絡其中一區', () {
      expect(
        {for (final t in NoteGenerationType.values) t: t.section},
        {
          NoteGenerationType.tips: NoteSection.pretrip,
          NoteGenerationType.lodgingTips: NoteSection.pretrip,
          NoteGenerationType.emergency: NoteSection.emergency,
        },
      );
    });

    test('generationTypesOf 依 enum 宣告順序列出該區的生成類型', () {
      expect(NoteSection.pretrip.generationTypes, [
        NoteGenerationType.tips,
        NoteGenerationType.lodgingTips,
      ]);
      expect(NoteSection.emergency.generationTypes, [
        NoteGenerationType.emergency,
      ]);
      expect(NoteSection.flights.generationTypes, isEmpty);
    });

    test('住宿生成需要先有住宿;其餘沒有前置條件', () {
      expect(
        NoteGenerationType.lodgingTips.disabledReason(hasLodgings: false),
        '需先新增住宿',
      );
      expect(
        NoteGenerationType.tips.disabledReason(hasLodgings: false),
        isNull,
      );
      expect(
        NoteGenerationType.emergency.disabledReason(hasLodgings: false),
        isNull,
      );
      expect(
        NoteGenerationType.lodgingTips.disabledReason(hasLodgings: true),
        isNull,
      );
    });
  });
}
