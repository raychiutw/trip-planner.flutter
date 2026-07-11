/// 交通方式 SoT(對照 web `src/lib/travelMode.ts`)。
///
/// 編輯 sheet 的 8 個方式選項與 timeline pill 的方式標籤共用同一份,避免兩處漂移。
/// mode 維持 3 canonical(driving/walking/transit,不碰後端 CHECK),transit 段用
/// submode 分具體方式;driving/walking 的 submode 恆 null。
library;

typedef TravelMethod = ({
  String key,
  String mode,
  String? submode,
  String label,
  bool auto,
});

/// 交通編輯 sheet 的 8 個方式選項(auto=可自動偵測分鐘,對照 web TRAVEL_METHODS)。
const List<TravelMethod> kTravelMethods = [
  (key: 'driving', mode: 'driving', submode: null, label: '駕車', auto: true),
  (key: 'walking', mode: 'walking', submode: null, label: '步行', auto: true),
  (
    key: 'monorail',
    mode: 'transit',
    submode: 'monorail',
    label: '單軌',
    auto: true,
  ),
  (key: 'bus', mode: 'transit', submode: 'bus', label: '公車', auto: true),
  (key: 'metro', mode: 'transit', submode: 'metro', label: '地鐵', auto: false),
  (key: 'train', mode: 'transit', submode: 'train', label: '火車', auto: false),
  (key: 'hsr', mode: 'transit', submode: 'hsr', label: '高鐵', auto: false),
  (key: 'other', mode: 'transit', submode: null, label: '其他', auto: false),
];

/// transit submode → 方式中文名(對照 web `travelMethodLabel('transit', submode)`)。
///
/// - 已知 submode(單軌/公車/地鐵/火車/高鐵)→ 中文名;這幾種在 timeline 共用同一個
///   train/bus icon,靠此文字區分。
/// - 未知 submode(「其他」的自由輸入)→ 原樣 passthrough。
/// - null/空(駕車/步行,或無 submode 的 legacy 段)→ 空字串;pill 端不加方式前綴,
///   靠 icon 區分即可(對齊 web:方式文字僅在 transit+submode 時顯示)。
String travelMethodLabel(String? submode) {
  if (submode == null || submode.isEmpty) return '';
  switch (submode) {
    case 'monorail':
      return '單軌';
    case 'bus':
      return '公車';
    case 'metro':
      return '地鐵';
    case 'train':
      return '火車';
    case 'hsr':
      return '高鐵';
    default:
      return submode;
  }
}
