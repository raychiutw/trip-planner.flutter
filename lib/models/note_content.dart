/// 已授權行程筆記的語意內容；不讀取資料，也不決定公開權限。
library;

import 'package:markdown/markdown.dart' as md;

import 'note_section.dart';
import 'notes.dart';

/// 保留原值與顯示語意，讓各 renderer 決定呈現與平台互動。
class NoteContentField {
  NoteContentField(
    this.label,
    this.value, {
    this.prefix = '',
    List<({String label, Uri uri})> links = const [],
  }) : links = List.unmodifiable(links);

  final String label;
  final String value;
  final String prefix;
  final List<({String label, Uri uri})> links;

  String get text => '$prefix$value';
  String get semanticsLabel => '$label：$value';
}

class NoteContentRow {
  NoteContentRow({
    required List<NoteContentField> heading,
    required List<NoteContentField> details,
  }) : heading = List.unmodifiable(heading),
       details = List.unmodifiable(details);

  final List<NoteContentField> heading;
  final List<NoteContentField> details;

  String get title => heading.map((field) => field.text).join(' ');
}

class NoteContentSection {
  NoteContentSection(this.kind, this.label, List<NoteContentRow> rows)
    : rows = List.unmodifiable(
        rows.where((row) => row.heading.isNotEmpty || row.details.isNotEmpty),
      );

  final NoteSection kind;
  final String label;
  final List<NoteContentRow> rows;
}

List<NoteContentField> _fields(List<NoteContentField> fields) =>
    List.unmodifiable(fields.where((field) => field.value.trim().isNotEmpty));

/// 只使用呼叫端提供的 snapshot；公開分享必須傳入 share.notes。
List<NoteContentSection> projectTripNotes(TripNotes notes) => List.unmodifiable(
  [
    if (notes.flights.isNotEmpty)
      NoteContentSection(NoteSection.flights, '航班', [
        for (final flight in notes.flights)
          NoteContentRow(
            heading: _fields([
              NoteContentField('航空公司', flight.airline),
              NoteContentField('航班編號', flight.flightNo),
            ]),
            details: _fields([
              NoteContentField('出發機場', flight.departAirport),
              NoteContentField('出發時間', flight.departAt),
              NoteContentField('抵達機場', flight.arriveAirport, prefix: '→ '),
              NoteContentField('抵達時間', flight.arriveAt),
              NoteContentField('艙等', flight.cabinClass),
              NoteContentField('備註', flight.note),
            ]),
          ),
      ]),
    if (notes.lodgings.isNotEmpty)
      NoteContentSection(NoteSection.lodgings, '住宿', [
        for (final lodging in notes.lodgings)
          NoteContentRow(
            heading: _fields([NoteContentField('住宿名稱', lodging.name)]),
            details: _fields([
              NoteContentField('入住時間', lodging.checkInAt),
              NoteContentField('退房時間', lodging.checkOutAt),
              NoteContentField('地址', lodging.address),
              _phoneField(lodging.phone),
              NoteContentField('訂房編號', lodging.bookingNo),
              NoteContentField('備註', lodging.note),
            ]),
          ),
      ]),
    if (notes.reservations.isNotEmpty)
      NoteContentSection(NoteSection.reservations, '預訂', [
        for (final reservation in notes.reservations)
          NoteContentRow(
            heading: _fields([NoteContentField('預訂名稱', reservation.title)]),
            details: _fields([
              NoteContentField('預訂時間', reservation.reservedAt),
              if (reservation.partySize > 0)
                NoteContentField('人數', '${reservation.partySize} 位'),
              NoteContentField('訂位編號', reservation.reservationNo),
              _phoneField(reservation.phone),
              NoteContentField('備註', reservation.note),
            ]),
          ),
      ]),
    if (notes.pretripNotes.isNotEmpty)
      NoteContentSection(NoteSection.pretrip, '行前須知', [
        for (final note in notes.pretripNotes)
          NoteContentRow(
            heading: _fields([NoteContentField('標題', note.title)]),
            details: _fields([
              NoteContentField(
                '內容',
                note.content,
                links: _markdownLinks(note.content),
              ),
            ]),
          ),
      ]),
    if (notes.emergencyContacts.isNotEmpty)
      NoteContentSection(NoteSection.emergency, '緊急聯絡', [
        for (final contact in notes.emergencyContacts)
          NoteContentRow(
            heading: _fields([NoteContentField('姓名', contact.name)]),
            details: _fields([
              NoteContentField('關係', contact.relationship),
              _phoneField(contact.phone),
              _emailField(contact.email),
            ]),
          ),
      ]),
  ].where((section) => section.rows.isNotEmpty),
);

NoteContentField _phoneField(String value) {
  final number = value.replaceAll(RegExp(r'[\s().-]'), '');
  final valid = RegExp(r'^\+?[0-9]+$').hasMatch(number);
  return NoteContentField(
    '電話',
    value,
    links: [if (valid) (label: value, uri: Uri(scheme: 'tel', path: number))],
  );
}

NoteContentField _emailField(String value) {
  final address = value.trim();
  final valid = RegExp(r'^[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+$').hasMatch(address);
  return NoteContentField(
    '電子郵件',
    value,
    links: [
      if (valid) (label: value, uri: Uri(scheme: 'mailto', path: address)),
    ],
  );
}

/// 沿用既有 Markdown parser，包含括號與 reference links；原文仍留在 value。
List<({String label, Uri uri})> _markdownLinks(String value) {
  final document = md.Document(
    extensionSet: md.ExtensionSet.gitHubFlavored,
    encodeHtml: false,
  );
  return List.unmodifiable(_links(document.parseLines(value.split('\n'))));
}

Iterable<({String label, Uri uri})> _links(Iterable<md.Node> nodes) sync* {
  for (final node in nodes.whereType<md.Element>()) {
    if (node.tag == 'a') {
      final uri = Uri.tryParse(node.attributes['href'] ?? '');
      if (uri != null &&
          (uri.scheme == 'https' || uri.scheme == 'http') &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty) {
        yield (
          label: node.textContent.trim().isEmpty
              ? uri.toString()
              : node.textContent,
          uri: uri,
        );
      }
    } else {
      yield* _links(node.children ?? const []);
    }
  }
}
