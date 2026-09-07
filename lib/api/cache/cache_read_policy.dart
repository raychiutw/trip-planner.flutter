/// GET 的快取政策 —— 取代 transport 上的 `fallbackToCache` / `writeCache` bool 對。
///
/// 三種就是全部;要「不讀但寫」用 [networkOnly],「不讀不寫」用 [noStore]。
enum CacheReadPolicy {
  /// 預設:離線時回退本機快取,成功後寫入快取。
  cached,

  /// 不回退快取(要 server 真相),但成功後仍寫入 —— 例如待確認刪除前的 day 摘要。
  networkOnly,

  /// 不讀不寫 —— 沒有 stale 價值的資料(AI job 狀態、健檢報告)、
  /// 以及 SWR 網路 leg 與 rebase 重抓(不可覆寫已含 pending patch 的快取)。
  noStore;

  bool get readsCache => this == cached;
  bool get writesCache => this != noStore;
}
