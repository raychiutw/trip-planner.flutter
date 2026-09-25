import 'package:flutter/foundation.dart';

/// 草稿必須不可變；送出只讀當時快照，不重讀後來的輸入。
@immutable
class DraftSnapshot<D> {
  const DraftSnapshot({required this.baseline, required this.draft});

  final D baseline;
  final D draft;
}

@immutable
class DraftAccepted<D, R> {
  const DraftAccepted({required this.draft, required this.result});

  final D draft;
  final R result;
}

/// 只有 session 能發出儲存憑證；憑證不是永久的關閉許可。
@immutable
class DraftSaved<R> {
  const DraftSaved._(this.result, this._revision);

  final R result;
  final int _revision;
}

/// 管理單一草稿的提交、baseline 與真正離頁當下的版本檢查。
class DraftSession<D, R> extends ChangeNotifier {
  DraftSession({
    required D initial,
    required bool Function(D, D) equivalent,
    required Future<DraftAccepted<D, R>> Function(DraftSnapshot<D>) write,
  }) : _draft = initial,
       _baseline = initial,
       _equivalent = equivalent,
       _write = write;

  D _draft;
  D _baseline;
  final bool Function(D, D) _equivalent;
  final Future<DraftAccepted<D, R>> Function(DraftSnapshot<D>) _write;
  int _revision = 0;
  bool _submitting = false;
  bool _disposed = false;
  String? _error;
  DraftSaved<R>? _lastSaved;

  D get draft => _draft;
  bool get dirty => !_equivalent(_draft, _baseline);
  bool get submitting => _submitting;
  bool get canSubmit => !_disposed && !_submitting && dirty;
  String? get error => _error;

  void edit(D next) {
    if (_disposed) return;
    _draft = next;
    _revision++;
    notifyListeners();
  }

  Future<DraftSaved<R>?> submit() async {
    if (!canSubmit) return null;
    final revision = _revision;
    final snapshot = DraftSnapshot(baseline: _baseline, draft: _draft);
    _submitting = true;
    _error = null;
    _lastSaved = null;
    notifyListeners();
    try {
      final accepted = await _write(snapshot);
      if (_disposed) return null;
      _baseline = accepted.draft;
      if (_revision == revision) _draft = accepted.draft;
      return _lastSaved = DraftSaved._(accepted.result, revision);
    } on Exception {
      if (!_disposed) _error = '儲存失敗,請稍後再試';
      return null;
    } finally {
      _submitting = false;
      if (!_disposed) notifyListeners();
    }
  }

  bool canFinish(DraftSaved<R> saved) =>
      !_disposed &&
      !_submitting &&
      identical(saved, _lastSaved) &&
      saved._revision == _revision &&
      !dirty;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
