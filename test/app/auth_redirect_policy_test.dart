import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/app/auth_redirect_policy.dart';

void main() {
  String? redirect(
    String location, {
    bool loggedIn = false,
    bool loading = false,
    String? matched,
  }) {
    final uri = Uri.parse(location);
    return authRedirect(
      isLoading: loading,
      isLoggedIn: loggedIn,
      uri: uri,
      matchedLocation: matched ?? uri.path,
    );
  }

  test('認證狀態載入中不 redirect', () {
    expect(redirect('/trips', loading: true), isNull);
  });

  test('未登入:私有頁導向 welcome 並保留站內目的地;/trips 不帶 redirect_after', () {
    expect(redirect('/trips'), '/welcome');
    expect(
      redirect('/trips/t1?day=2'),
      '/welcome?redirect_after=%2Ftrips%2Ft1%3Fday%3D2',
    );
  });

  test('未登入:公開頁不 redirect(含 /s/:token 與登入頁本身)', () {
    for (final path in [
      '/welcome',
      '/login',
      '/signup',
      '/login/forgot',
      '/auth/verify-email',
      '/oauth/consent',
      '/invite',
    ]) {
      expect(redirect(path), isNull, reason: path);
    }
    expect(redirect('/s/abc'), isNull);
    expect(redirect('/s/abc/extra'), isNotNull);
  });

  test('已登入:登入頁與 welcome 導回 redirect_after,只接受站內路徑', () {
    expect(redirect('/login', loggedIn: true), '/trips');
    expect(redirect('/welcome', loggedIn: true), '/trips');
    expect(
      redirect('/login?redirect_after=%2Ftrips%2Ft1', loggedIn: true),
      '/trips/t1',
    );
    expect(
      redirect('/login?redirect_after=https%3A%2F%2Fevil.com', loggedIn: true),
      '/trips',
    );
    expect(
      redirect('/login?redirect_after=%2F%2Fevil.com', loggedIn: true),
      '/trips',
    );
    expect(
      redirect('/login?redirect_after=%2Flogin', loggedIn: true),
      '/trips',
    );
  });

  test('已登入:其餘頁面不 redirect', () {
    expect(redirect('/trips/t1', loggedIn: true), isNull);
  });

  test('welcome 的登入按鈕沿用 redirect_after', () {
    expect(loginLocationFromWelcome(Uri.parse('/welcome')), '/login');
    expect(
      loginLocationFromWelcome(Uri.parse('/welcome?redirect_after=%2Fmap')),
      '/login?redirect_after=%2Fmap',
    );
  });

  test('shell 內容頁判斷:四個 root 與行程 / 收藏子頁;/trips/new 不算', () {
    for (final p in [
      '/chat',
      '/map',
      '/trips',
      '/favorites',
      '/trips/t1',
      '/favorites/explore',
    ]) {
      expect(isShellContentLocation(p), isTrue, reason: p);
    }
    for (final p in ['/trips/new', '/edit-trip/t1', '/login']) {
      expect(isShellContentLocation(p), isFalse, reason: p);
    }
  });
}
