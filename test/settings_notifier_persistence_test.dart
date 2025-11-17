import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/providers/settings_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // 各テスト前に SharedPreferences の内容をクリア
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('SettingsNotifier は設定値を保存し、再生成時に復元できる', () async {
    final first = SettingsNotifier();
    await first.initialized;

    // デフォルト値を確認
    expect(first.defaultCameraCount, 1);
    expect(first.darkMode, false);

    // 値を変更
    first.defaultCameraCount = 4;
    first.darkMode = true;
    first.exportFolder = 'MyFolder';

    // SharedPreferences に保存されていることを確認
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('defaultCameraCount'), 4);
    expect(prefs.getBool('darkMode'), true);
    expect(prefs.getString('exportFolder'), 'MyFolder');

    // 新しいインスタンスを生成して、保存済みの値が復元されることを確認
    final second = SettingsNotifier();
    await second.initialized;

    expect(second.defaultCameraCount, 4);
    expect(second.darkMode, true);
    expect(second.exportFolder, 'MyFolder');
  });
}


