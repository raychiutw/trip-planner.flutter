import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/note_section.dart';
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

  group('toEditFields（edit 預填用,snake_case key）', () {
    test('TripFlight', () {
      const flight = TripFlight(
        id: 1,
        sortOrder: 0,
        version: 1,
        airline: 'IT',
        flightNo: 'IT232',
        departAt: '2026-04-23T08:30',
      );
      final fields = flight.toEditFields();
      expect(fields['airline'], 'IT');
      expect(fields['flight_no'], 'IT232');
      expect(fields['depart_at'], '2026-04-23T08:30');
      expect(fields.containsKey('note'), isTrue);
    });

    test('TripReservation（含 enum kind + int party_size）', () {
      const reservation = TripReservation(
        id: 5,
        sortOrder: 0,
        version: 2,
        kind: 'experience',
        title: '潛水',
        partySize: 4,
        reservationNo: 'R-1',
      );
      final fields = reservation.toEditFields();
      expect(fields['kind'], 'experience');
      expect(fields['title'], '潛水');
      expect(fields['party_size'], 4);
      expect(fields['reservation_no'], 'R-1');
    });
  });

  // POST /trips/:id/notes/:type/generate 的回應。原本是 repository 內的 inline
  // record + 非 null cast,契約一變動就在畫面層炸開;改成具名 model 後,wire 解析
  // 收在 models 這一層。
  group('TripNoteAiJob.fromJson', () {
    test('解析完整欄位（含 generation / createdAt / timeoutAt）', () {
      final job = TripNoteAiJob.fromJson({
        'jobId': 12,
        'requestId': 34,
        'status': 'pending',
        'tripId': 'okinawa',
        'docType': 'tips',
        'generation': 3,
        'createdAt': '2026-07-25T10:00:00Z',
        'timeoutAt': '2026-07-25T10:07:00Z',
      });

      expect(job.jobId, 12);
      expect(job.requestId, 34);
      expect(job.status, TripNoteAiJobStatus.pending);
      expect(job.status.isTerminal, isFalse);
      expect(job.tripId, 'okinawa');
      expect(job.docType, NoteGenerationType.tips);
      expect(job.generation, 3);
      // 日期時間存字串不轉 DateTime（全專案慣例）
      expect(job.createdAt, isA<String>());
      expect(job.createdAt, '2026-07-25T10:00:00Z');
      expect(job.timeoutAt, isA<String>());
      expect(job.timeoutAt, '2026-07-25T10:07:00Z');
    });

    test('全欄位缺漏走預設值,不丟 TypeError', () {
      final job = TripNoteAiJob.fromJson(const <String, dynamic>{});

      expect(job.jobId, 0);
      expect(job.requestId, 0);
      expect(job.generation, 0);
      expect(job.tripId, '');
      expect(job.docType, isNull);
      expect(job.createdAt, isNull);
      expect(job.timeoutAt, isNull);
      expect(job.status.isTerminal, isFalse);
    });

    test('未知 status 字串不判為終止態,completed/failed 才是', () {
      TripNoteAiJob jobWithStatus(String? status) => TripNoteAiJob.fromJson({
        'jobId': 1,
        'requestId': 2,
        'status': status,
      });

      expect(jobWithStatus('rehydrating').status.isTerminal, isFalse);
      expect(jobWithStatus('').status.isTerminal, isFalse);
      expect(jobWithStatus(null).status.isTerminal, isFalse);

      expect(jobWithStatus('completed').status, TripNoteAiJobStatus.completed);
      expect(jobWithStatus('completed').status.isTerminal, isTrue);
      expect(jobWithStatus('failed').status, TripNoteAiJobStatus.failed);
      expect(jobWithStatus('failed').status.isTerminal, isTrue);
    });

    test('docType 同時接受 lodging-tips 與 lodgingTips 兩形', () {
      NoteGenerationType? docTypeOf(String raw) =>
          TripNoteAiJob.fromJson({'docType': raw}).docType;

      // 契約未凍結:#1214 的範例只給 "tips",URL 形與 enum 形同字,
      // 推導不出 lodging-tips 會回哪一種,兩形都吃。
      expect(docTypeOf('lodging-tips'), NoteGenerationType.lodgingTips);
      expect(docTypeOf('lodgingTips'), NoteGenerationType.lodgingTips);
      expect(docTypeOf('tips'), NoteGenerationType.tips);
      expect(docTypeOf('emergency'), NoteGenerationType.emergency);
      expect(docTypeOf('weather'), isNull);
    });
  });
}
