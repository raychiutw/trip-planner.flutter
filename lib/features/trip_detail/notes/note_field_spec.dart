/// 筆記各區的欄位規格（驅動 spec-driven NoteEditSheet）。
/// key 與後端白名單 + model.toEditFields 一致。
library;

import '../../../models/note_section.dart';

enum NoteFieldType { text, multiline, integer, enumChoice, datetime }

class NoteFieldSpec {
  const NoteFieldSpec(
    this.key,
    this.label,
    this.type, {
    this.options = const [],
    this.defaultValue = '',
    this.required = false,
  });

  final String key;
  final String label;
  final NoteFieldType type;

  /// enumChoice 用：(value, 顯示 label)。
  final List<(String, String)> options;

  /// create 預設值（enum 用）。
  final String defaultValue;

  /// 必填（送出前需非空）。各區標一個主要識別欄位,避免建立全空 row。
  final bool required;
}

const Map<NoteSection, String> noteSectionTitles = {
  NoteSection.flights: '航班',
  NoteSection.lodgings: '住宿',
  NoteSection.reservations: '預訂',
  NoteSection.pretrip: '行前須知',
  NoteSection.emergency: '緊急聯絡',
};

const List<(String, String)> _reservationKinds = [
  ('restaurant', '餐廳'),
  ('experience', '體驗'),
  ('ticket', '票券'),
  ('transport', '交通'),
  ('other', '其他'),
];

const List<(String, String)> _emergencyKinds = [
  ('personal', '個人'),
  ('embassy', '大使館'),
  ('police', '警察'),
  ('medical', '醫療'),
  ('insurance', '保險'),
  ('hotel', '飯店'),
  ('other', '其他'),
];

const Map<NoteSection, List<NoteFieldSpec>> noteSectionSpecs = {
  NoteSection.flights: [
    NoteFieldSpec('airline', '航空公司', NoteFieldType.text, required: true),
    NoteFieldSpec('flight_no', '航班編號', NoteFieldType.text),
    NoteFieldSpec('cabin_class', '艙等', NoteFieldType.text),
    NoteFieldSpec('depart_airport', '出發機場', NoteFieldType.text),
    NoteFieldSpec('arrive_airport', '抵達機場', NoteFieldType.text),
    NoteFieldSpec('depart_at', '出發時間', NoteFieldType.datetime),
    NoteFieldSpec('arrive_at', '抵達時間', NoteFieldType.datetime),
    NoteFieldSpec('note', '備註', NoteFieldType.multiline),
  ],
  NoteSection.lodgings: [
    NoteFieldSpec('name', '名稱', NoteFieldType.text, required: true),
    NoteFieldSpec('address', '地址', NoteFieldType.text),
    NoteFieldSpec('check_in_at', '入住', NoteFieldType.datetime),
    NoteFieldSpec('check_out_at', '退房', NoteFieldType.datetime),
    NoteFieldSpec('booking_no', '訂房編號', NoteFieldType.text),
    NoteFieldSpec('phone', '電話', NoteFieldType.text),
    NoteFieldSpec('note', '備註', NoteFieldType.multiline),
  ],
  NoteSection.reservations: [
    NoteFieldSpec(
      'kind',
      '類型',
      NoteFieldType.enumChoice,
      options: _reservationKinds,
      defaultValue: 'restaurant',
    ),
    NoteFieldSpec('title', '名稱', NoteFieldType.text, required: true),
    NoteFieldSpec('reserved_at', '預約時間', NoteFieldType.datetime),
    NoteFieldSpec('party_size', '人數', NoteFieldType.integer),
    NoteFieldSpec('reservation_no', '預約編號', NoteFieldType.text),
    NoteFieldSpec('phone', '電話', NoteFieldType.text),
    NoteFieldSpec('note', '備註', NoteFieldType.multiline),
  ],
  NoteSection.pretrip: [
    NoteFieldSpec('section', '分類', NoteFieldType.text),
    NoteFieldSpec('title', '標題', NoteFieldType.text, required: true),
    NoteFieldSpec('content', '內容', NoteFieldType.multiline),
  ],
  NoteSection.emergency: [
    NoteFieldSpec('name', '名稱', NoteFieldType.text, required: true),
    NoteFieldSpec('relationship', '關係', NoteFieldType.text),
    NoteFieldSpec('phone', '電話', NoteFieldType.text),
    NoteFieldSpec('email', 'Email', NoteFieldType.text),
    NoteFieldSpec(
      'kind',
      '類型',
      NoteFieldType.enumChoice,
      options: _emergencyKinds,
      defaultValue: 'other',
    ),
  ],
};
