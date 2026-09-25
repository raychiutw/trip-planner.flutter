import 'package:tripline/models/notes.dart';

const noteContentFixture = TripNotes(
  flights: [
    TripFlight(
      id: 1,
      sortOrder: 0,
      version: 0,
      airline: '長榮航空',
      flightNo: 'BR112',
      cabinClass: '商務艙',
      departAirport: 'TPE',
      departAt: '2026-10-01 09:00',
      arriveAirport: 'OKA',
      arriveAt: '2026-10-01 11:30',
      note: '提前抵達機場',
    ),
    TripFlight(id: 10, sortOrder: -1, version: 0, flightNo: 'SECOND-BR113'),
    TripFlight(id: 11, sortOrder: 0, version: 0, airline: '  '),
  ],
  lodgings: [
    TripLodging(
      id: 2,
      sortOrder: 0,
      version: 0,
      name: '那霸旅館',
      checkInAt: '2026-10-01',
      checkOutAt: '2026-10-03',
      address: '那霸市一號',
      phone: '+81 98 123 4567',
      bookingNo: 'HOTEL-42',
      note: '禁菸房',
    ),
  ],
  reservations: [
    TripReservation(
      id: 3,
      sortOrder: 0,
      version: 0,
      title: '晚餐預訂',
      reservedAt: '2026-10-01 19:00',
      partySize: 4,
      reservationNo: 'DINNER-7',
      phone: '+81 98 765 4321',
      note: '一位素食',
    ),
    TripReservation(id: 12, sortOrder: -1, version: 0, title: '零人數預訂'),
  ],
  pretripNotes: [
    TripPretripNote(
      id: 4,
      sortOrder: 0,
      version: 0,
      title: '入境準備',
      content: '攜帶護照與雨具。\nhttps://example.com/travel',
    ),
  ],
  emergencyContacts: [
    TripEmergencyContact(
      id: 5,
      sortOrder: 0,
      version: 0,
      name: '王小明',
      relationship: '家人',
      phone: '+886 912 345 678',
      email: 'family@example.com',
    ),
  ],
);

// 公開回應已由後端形成授權視圖：未提供艙等、住宿及緊急聯絡資料。
const publicNoteFixture = TripNotes(
  flights: [
    TripFlight(id: 1, sortOrder: 0, version: 0, flightNo: 'PUBLIC-BR112'),
  ],
  pretripNotes: [
    TripPretripNote(
      id: 2,
      sortOrder: 0,
      version: 0,
      title: '公開提醒',
      content: '攜帶護照',
    ),
  ],
);
const privateNoteFixture = TripNotes(
  emergencyContacts: [
    TripEmergencyContact(
      id: 9,
      sortOrder: 0,
      version: 0,
      name: 'PRIVATE-SECRET-385',
    ),
  ],
);

// 獨立手寫的公開閱讀順序；不透過投影或 renderer 計算預期值。
const noteContentExpectedOrder = [
  '航班',
  '長榮航空',
  'BR112',
  'TPE',
  '2026-10-01 09:00',
  '→ OKA',
  '2026-10-01 11:30',
  '商務艙',
  '提前抵達機場',
  'SECOND-BR113',
  '住宿',
  '那霸旅館',
  '2026-10-01',
  '2026-10-03',
  '那霸市一號',
  '+81 98 123 4567',
  'HOTEL-42',
  '禁菸房',
  '預訂',
  '晚餐預訂',
  '2026-10-01 19:00',
  '4 位',
  'DINNER-7',
  '+81 98 765 4321',
  '一位素食',
  '零人數預訂',
  '行前須知',
  '入境準備',
  '攜帶護照與雨具。',
  'https://example.com/travel',
  '緊急聯絡',
  '王小明',
  '家人',
  '+886 912 345 678',
  'family@example.com',
];

const emptyNoteContentFixture = TripNotes(
  flights: [TripFlight(id: 1, sortOrder: 0, version: 0, airline: '  ')],
  lodgings: [TripLodging(id: 2, sortOrder: 0, version: 0, name: '\t')],
  reservations: [TripReservation(id: 3, sortOrder: 0, version: 0)],
  pretripNotes: [
    TripPretripNote(id: 4, sortOrder: 0, version: 0, content: '\n  '),
  ],
  emergencyContacts: [
    TripEmergencyContact(id: 5, sortOrder: 0, version: 0, phone: ' '),
  ],
);
