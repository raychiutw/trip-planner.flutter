import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/notes.dart';

void main() {
  group('TripFlight.fromJson', () {
    test('解析完整欄位', () {
      final flight = TripFlight.fromJson({
        'id': 1,
        'sortOrder': 1,
        'version': 2,
        'airline': '長榮航空',
        'flightNo': 'BR112',
        'cabinClass': '經濟艙',
        'departAirport': 'TPE',
        'arriveAirport': 'OKA',
        'departAt': '2026-04-23T08:30',
        'arriveAt': '2026-04-23T11:00',
        'note': '靠窗座位',
      });

      expect(flight.id, 1);
      expect(flight.sortOrder, 1);
      expect(flight.version, 2);
      expect(flight.airline, '長榮航空');
      expect(flight.flightNo, 'BR112');
      expect(flight.cabinClass, '經濟艙');
      expect(flight.departAirport, 'TPE');
      expect(flight.arriveAirport, 'OKA');
      expect(flight.departAt, '2026-04-23T08:30');
      expect(flight.arriveAt, '2026-04-23T11:00');
      expect(flight.note, '靠窗座位');
    });

    test('文字欄位缺漏時預設空字串', () {
      final flight = TripFlight.fromJson({
        'id': 2,
        'sortOrder': 1,
        'version': 1,
      });

      expect(flight.airline, '');
      expect(flight.flightNo, '');
      expect(flight.cabinClass, '');
      expect(flight.departAirport, '');
      expect(flight.arriveAirport, '');
      expect(flight.departAt, '');
      expect(flight.arriveAt, '');
      expect(flight.note, '');
    });
  });

  group('TripLodging.fromJson', () {
    test('解析完整欄位含 dayId', () {
      final lodging = TripLodging.fromJson({
        'id': 11,
        'sortOrder': 1,
        'version': 1,
        'dayId': 101,
        'name': '海濱飯店',
        'address': '沖繩縣北谷町',
        'checkInAt': '2026-04-23T15:00',
        'checkOutAt': '2026-04-25T11:00',
        'bookingNo': 'BK-9988',
        'phone': '+81-98-000-0000',
        'note': '高樓層',
      });

      expect(lodging.id, 11);
      expect(lodging.dayId, 101);
      expect(lodging.name, '海濱飯店');
      expect(lodging.address, '沖繩縣北谷町');
      expect(lodging.checkInAt, '2026-04-23T15:00');
      expect(lodging.checkOutAt, '2026-04-25T11:00');
      expect(lodging.bookingNo, 'BK-9988');
      expect(lodging.phone, '+81-98-000-0000');
      expect(lodging.note, '高樓層');
    });

    test('dayId nullable、文字欄位缺漏預設空字串', () {
      final lodging = TripLodging.fromJson({
        'id': 12,
        'sortOrder': 2,
        'version': 1,
      });

      expect(lodging.dayId, isNull);
      expect(lodging.name, '');
      expect(lodging.address, '');
      expect(lodging.note, '');
    });
  });

  group('TripReservation.fromJson', () {
    test('解析完整欄位', () {
      final reservation = TripReservation.fromJson({
        'id': 21,
        'sortOrder': 1,
        'version': 1,
        'kind': 'restaurant',
        'title': '燒肉乃我那霸',
        'reservedAt': '2026-04-24T18:30',
        'partySize': 4,
        'reservationNo': 'R-777',
        'phone': '+81-98-111-1111',
        'note': '需訂金',
      });

      expect(reservation.kind, 'restaurant');
      expect(reservation.title, '燒肉乃我那霸');
      expect(reservation.reservedAt, '2026-04-24T18:30');
      expect(reservation.partySize, 4);
      expect(reservation.reservationNo, 'R-777');
      expect(reservation.phone, '+81-98-111-1111');
      expect(reservation.note, '需訂金');
    });

    test('partySize 缺漏預設 0、kind 缺漏預設 restaurant', () {
      final reservation = TripReservation.fromJson({
        'id': 22,
        'sortOrder': 1,
        'version': 1,
      });

      expect(reservation.partySize, 0);
      expect(reservation.kind, 'restaurant');
      expect(reservation.title, '');
    });
  });

  group('TripPretripNote.fromJson', () {
    test('aiGenerated 0/1 轉 bool', () {
      final aiNote = TripPretripNote.fromJson({
        'id': 31,
        'sortOrder': 1,
        'version': 1,
        'section': '貨幣',
        'title': '日幣兌換',
        'content': '機場匯率較差',
        'aiGenerated': 1,
      });
      final manualNote = TripPretripNote.fromJson({
        'id': 32,
        'sortOrder': 2,
        'version': 1,
        'aiGenerated': 0,
      });

      expect(aiNote.section, '貨幣');
      expect(aiNote.title, '日幣兌換');
      expect(aiNote.content, '機場匯率較差');
      expect(aiNote.aiGenerated, isTrue);
      expect(manualNote.aiGenerated, isFalse);
      expect(manualNote.section, '');
    });
  });

  group('TripEmergencyContact.fromJson', () {
    test('解析完整欄位，aiGenerated true 也支援', () {
      final contact = TripEmergencyContact.fromJson({
        'id': 41,
        'sortOrder': 1,
        'version': 1,
        'name': '台北駐日經濟文化代表處',
        'relationship': '官方機構',
        'phone': '+81-3-3280-7811',
        'email': 'help@example.org',
        'kind': 'embassy',
        'aiGenerated': true,
      });

      expect(contact.name, '台北駐日經濟文化代表處');
      expect(contact.relationship, '官方機構');
      expect(contact.phone, '+81-3-3280-7811');
      expect(contact.email, 'help@example.org');
      expect(contact.kind, 'embassy');
      expect(contact.aiGenerated, isTrue);
    });

    test('kind 缺漏預設 other、aiGenerated 缺漏預設 false', () {
      final contact = TripEmergencyContact.fromJson({
        'id': 42,
        'sortOrder': 1,
        'version': 1,
      });

      expect(contact.kind, 'other');
      expect(contact.aiGenerated, isFalse);
      expect(contact.name, '');
    });
  });

  group('TripNotes.fromJson', () {
    test('聚合 5 區清單', () {
      final notes = TripNotes.fromJson({
        'flights': [
          {'id': 1, 'sortOrder': 1, 'version': 1, 'airline': '長榮航空'},
        ],
        'lodgings': [
          {'id': 11, 'sortOrder': 1, 'version': 1, 'name': '海濱飯店'},
        ],
        'reservations': [
          {'id': 21, 'sortOrder': 1, 'version': 1, 'title': '燒肉'},
        ],
        'pretripNotes': [
          {'id': 31, 'sortOrder': 1, 'version': 1, 'section': '簽證'},
        ],
        'emergencyContacts': [
          {'id': 41, 'sortOrder': 1, 'version': 1, 'name': '保險公司'},
        ],
      });

      expect(notes.flights, hasLength(1));
      expect(notes.flights.first.airline, '長榮航空');
      expect(notes.lodgings, hasLength(1));
      expect(notes.lodgings.first.name, '海濱飯店');
      expect(notes.reservations, hasLength(1));
      expect(notes.reservations.first.title, '燒肉');
      expect(notes.pretripNotes, hasLength(1));
      expect(notes.pretripNotes.first.section, '簽證');
      expect(notes.emergencyContacts, hasLength(1));
      expect(notes.emergencyContacts.first.name, '保險公司');
    });

    test('5 區全部缺漏時各自預設空清單', () {
      final notes = TripNotes.fromJson({});

      expect(notes.flights, isEmpty);
      expect(notes.lodgings, isEmpty);
      expect(notes.reservations, isEmpty);
      expect(notes.pretripNotes, isEmpty);
      expect(notes.emergencyContacts, isEmpty);
    });
  });

  group('TripNoteAiGenerationJob.fromJson', () {
    test('解析 AI 生成 job 與 request id', () {
      final job = TripNoteAiGenerationJob.fromJson({
        'jobId': 77,
        'requestId': 9901,
        'status': 'pending',
        'tripId': 'okinawa-trip-2026',
        'docType': 'tips',
      });

      expect(job.jobId, 77);
      expect(job.requestId, 9901);
      expect(job.status, 'pending');
      expect(job.tripId, 'okinawa-trip-2026');
      expect(job.docType, 'tips');
    });
  });
}
