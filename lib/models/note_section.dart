/// 筆記 5 區;`name` 即 API URL 段（flights/lodgings/reservations/pretrip/emergency）。
/// 注意:聚合 GET /notes 的 response key 是 pretripNotes/emergencyContacts,與此段名不同。
library;

enum NoteSection { flights, lodgings, reservations, pretrip, emergency }
