// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/providers/form_controllers_notifier.dart';
import 'package:flutter_application_1/providers/form_state_notifier.dart';
import 'package:flutter_application_1/providers/locale_notifier.dart';
import 'package:flutter_application_1/providers/settings_notifier.dart';

void main() {
  testWidgets('App builds (smoke test)', (WidgetTester tester) async {
    // shared_preferences をウィジェットテストで使えるようにする
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => FormStateNotifier()),
          ChangeNotifierProvider(create: (_) => FormControllersNotifier()),
          ChangeNotifierProvider(create: (_) => LocaleNotifier()),
          ChangeNotifierProvider(create: (_) => SettingsNotifier()),
        ],
        child: const TimingChartGeneratorApp(),
      ),
    );

    // 1フレーム進めて初期ビルドが完了することだけ確認
    await tester.pump();
  });
}
