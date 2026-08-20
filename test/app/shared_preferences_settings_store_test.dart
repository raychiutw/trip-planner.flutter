import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripline/api/settings_store.dart';
import 'package:tripline/app/shared_preferences_settings_store.dart';

class _MockSharedPreferencesAsync extends Mock
    implements SharedPreferencesAsync {}

void main() {
  test('本機 settings adapter 透過平台 preferences 讀寫字串', () async {
    final preferences = _MockSharedPreferencesAsync();
    when(
      () => preferences.getString('theme_mode'),
    ).thenAnswer((_) async => 'dark');
    when(
      () => preferences.setString('theme_mode', 'light'),
    ).thenAnswer((_) async {});
    final SettingsStore store = SharedPreferencesSettingsStore(
      preferences: preferences,
    );

    expect(await store.read('theme_mode'), 'dark');
    await store.write('theme_mode', 'light');

    verify(() => preferences.getString('theme_mode')).called(1);
    verify(() => preferences.setString('theme_mode', 'light')).called(1);
  });
}
