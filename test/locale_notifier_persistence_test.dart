import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

import 'package:flutter_application_1/providers/locale_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('LocaleNotifier は言語コードを保存し、再生成時に復元できる', () async {
    // 初期状態: ja
    final first = LocaleNotifier();
    await first.initialized;
    expect(first.locale, const Locale('ja'));

    // 言語を英語に変更
    first.setLocale(const Locale('en'));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('localeCode'), 'en');

    // 新しいインスタンスで復元されることを確認
    final second = LocaleNotifier();
    await second.initialized;
    expect(second.locale, const Locale('en'));
  });
}


