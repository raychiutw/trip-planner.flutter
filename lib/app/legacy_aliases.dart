/// Web 版 route alias:純字串改寫,一張表 + 幾個公開純函式。
///
/// GoRoute 由 [legacyAliasRoutes] 從表格產生;改寫規則本身不碰 GoRouterState,
/// 所以能直接 unit test,不必把整個 app pump 起來。
library;

import 'package:go_router/go_router.dart';

/// 給定路徑參數與原 URI,回目標 location。
typedef AliasLocation = String Function(Map<String, String> params, Uri uri);

/// 新增停留點的 mode 字串;與 features 層 `EntryAddMode.values` 的 name 一致
/// (app 層不往上依賴 features,由測試釘住兩邊同步)。
const entryAddModes = {'search', 'favorites', 'custom'};

/// query 裡的 mode / tab 字串合法就用它,否則回 [fallback]。
String entryAddModeFromQuery(String? value, {required String fallback}) =>
    entryAddModes.contains(value) ? value! : fallback;

String _encode(Map<String, String> params, String key) =>
    Uri.encodeComponent(params[key]!);

/// `/trip/:tripId[suffix]` → `/trips/:tripId[suffix]`。
String tripAlias(Map<String, String> params, {String suffix = ''}) =>
    '/trips/${_encode(params, 'tripId')}$suffix';

/// `/trip/:tripId/collab` 這類 shell 外全螢幕頁:`prefix/:tripId`。
String outsideTripAlias(Map<String, String> params, {required String prefix}) =>
    '$prefix/${_encode(params, 'tripId')}';

/// `/trip/:tripId/stop/:entryId/<sub>` → `/trips/:tripId/entries/:entryId/<sub>`。
String entrySubpageAlias(Map<String, String> params, String subpage) =>
    '/trips/${_encode(params, 'tripId')}/entries/${_encode(params, 'entryId')}/$subpage';

/// `/trip/:tripId/add-*` → `/trips/:tripId/entries/new?mode=…`(`tab` 換成 `mode`)。
String newEntryAlias(
  Map<String, String> params,
  Uri uri, {
  required String mode,
}) {
  final query = Map<String, String>.from(uri.queryParameters)..remove('tab');
  query['mode'] = mode;
  return Uri(
    path: '/trips/${_encode(params, 'tripId')}/entries/new',
    queryParameters: query,
  ).toString();
}

/// `/trip/:tripId/stop/:entryId/map` → `/trips/:tripId/map?entry=…`。
String entryMapAlias(Map<String, String> params, Uri uri) {
  final query = Map<String, String>.from(uri.queryParameters);
  query['entry'] = params['entryId']!;
  return Uri(
    path: '/trips/${_encode(params, 'tripId')}/map',
    queryParameters: query,
  ).toString();
}

/// `/trip/:tripId/stop/:entryId` → `/trips/:tripId?entry=…`。
String entryTimelineAlias(Map<String, String> params, Uri uri) {
  final query = Map<String, String>.from(uri.queryParameters);
  query['entry'] = params['entryId']!;
  return Uri(
    path: '/trips/${_encode(params, 'tripId')}',
    queryParameters: query,
  ).toString();
}

/// `/trips/:tripId/map` → root 地圖分支 `/map?tripId=…`。
String rootMapAlias(Map<String, String> params, Uri uri) {
  final query = Map<String, String>.from(uri.queryParameters);
  query['tripId'] = params['tripId']!;
  return Uri(path: '/map', queryParameters: query).toString();
}

/// `/trips?selected=<id>[&focus=<entry>]` → `/trips/<id>[?entry=…]`;
/// `selected` 不合法或缺席回 null(不改寫)。
String? selectedTripAlias(Uri uri) {
  final selected = uri.queryParameters['selected'];
  if (selected == null || !RegExp(r'^[\w-]+$').hasMatch(selected)) {
    return null;
  }
  final query = Map<String, String>.from(uri.queryParameters)
    ..remove('selected');
  final focus = query.remove('focus');
  if (focus != null && int.tryParse(focus) != null) {
    query['entry'] = focus;
  }
  return Uri(
    path: '/trips/${Uri.encodeComponent(selected)}',
    queryParameters: query.isEmpty ? null : query,
  ).toString();
}

/// 原 query 原封不動搬到新路徑。
String withQuery(String path, Uri uri) =>
    uri.query.isEmpty ? path : '$path?${uri.query}';

/// 帳號 sheet 以 `?account=<page>` 掛在來源頁上;來源頁與原 query 都保留。
String accountSheetLocation(String originLocation, Uri uri, String page) {
  final origin = Uri.parse(originLocation);
  final query = <String, String>{
    ...origin.queryParameters,
    ...uri.queryParameters,
  };
  query['account'] = page;
  return origin.replace(queryParameters: query).toString();
}

/// 去掉 `account`,就是帳號 sheet 關閉後回去的位置。
String withoutAccount(Uri uri) {
  final query = Map<String, String>.from(uri.queryParameters)
    ..remove('account');
  return Uri(
    path: uri.path,
    queryParameters: query.isEmpty ? null : query,
  ).toString();
}

int? entryFocusFromQuery(Uri uri) =>
    int.tryParse(uri.queryParameters['entry'] ?? '');

int? dayFocusFromQuery(Uri uri) =>
    int.tryParse(uri.queryParameters['day'] ?? '');

/// 舊路徑 → 改寫。表本身就是規格。
final Map<String, AliasLocation> redirectAliases = {
  '/admin': (_, _) => '/trips',
  '/manage': (_, _) => '/chat',
  '/trips/new': (_, _) => '/new-trip',
  '/explore': (_, _) => '/favorites/explore',
  '/add-to-trip': (_, uri) => withQuery('/favorites/add-to-trip', uri),
  '/trip/:tripId': (p, _) => tripAlias(p),
  '/trip/:tripId/map': (p, _) => tripAlias(p, suffix: '/map'),
  '/trip/:tripId/notes': (p, _) => tripAlias(p, suffix: '/notes'),
  '/trip/:tripId/print': (p, _) => tripAlias(p, suffix: '/print'),
  '/trip/:tripId/health': (p, _) => tripAlias(p, suffix: '/health'),
  '/trip/:tripId/audit': (p, _) => tripAlias(p, suffix: '/audit'),
  '/trip/:tripId/collab': (p, _) => outsideTripAlias(p, prefix: '/collab'),
  '/trip/:tripId/edit': (p, _) => outsideTripAlias(p, prefix: '/edit-trip'),
  '/trip/:tripId/add-entry': (p, uri) => newEntryAlias(p, uri, mode: 'search'),
  '/trip/:tripId/add-stop': (p, uri) => newEntryAlias(
    p,
    uri,
    mode: entryAddModeFromQuery(uri.queryParameters['tab'], fallback: 'search'),
  ),
  '/trip/:tripId/add-custom-stop': (p, uri) =>
      newEntryAlias(p, uri, mode: 'custom'),
  '/trip/:tripId/stop/:entryId': entryTimelineAlias,
  '/trip/:tripId/stop/:entryId/map': entryMapAlias,
  '/trip/:tripId/stop/:entryId/edit': (p, _) => entrySubpageAlias(p, 'edit'),
  '/trip/:tripId/stop/:entryId/change-poi': (p, _) =>
      entrySubpageAlias(p, 'pois'),
  '/trip/:tripId/stop/:entryId/copy': (p, _) => entrySubpageAlias(p, 'copy'),
  '/trip/:tripId/stop/:entryId/move': (p, _) => entrySubpageAlias(p, 'move'),
};

/// 舊路徑 → 帳號 sheet 的頁。來源頁由 router 在 redirect 當下決定。
const Map<String, String> accountAliases = {
  '/account': 'root',
  '/account/appearance': 'appearance',
  '/account/sessions': 'sessions',
  '/account/connected-apps': 'connected-apps',
  '/account/notifications': 'notifications',
  '/settings/appearance': 'appearance',
  '/settings/profile': 'profile',
  '/settings/notifications': 'notifications',
  '/settings/sessions': 'sessions',
  '/settings/connected-apps': 'connected-apps',
  '/settings/developer-apps': 'developer-apps',
  '/settings/developer-apps/new': 'developer-apps/new',
  '/developer/apps': 'developer-apps',
  '/developer/apps/new': 'developer-apps/new',
};

/// 由兩張表產生 GoRoute。[accountSheetOrigin] 回帳號 sheet 該掛在哪個來源頁。
List<GoRoute> legacyAliasRoutes({
  required String Function() accountSheetOrigin,
}) => [
  for (final MapEntry(key: path, value: build) in redirectAliases.entries)
    GoRoute(
      path: path,
      redirect: (_, state) => build(state.pathParameters, state.uri),
    ),
  for (final MapEntry(key: path, value: page) in accountAliases.entries)
    GoRoute(
      path: path,
      redirect: (_, state) =>
          accountSheetLocation(accountSheetOrigin(), state.uri, page),
    ),
];
