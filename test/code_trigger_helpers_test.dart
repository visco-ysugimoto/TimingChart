import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/utils/code_trigger_helpers.dart';

void main() {
  group('CODE_OPTION コメント用ビット変換', () {
    test('32ポートのビット幅は Control8 / Group6 / Task6', () {
      final widths = CodeTriggerHelpers.bitWidths(32);
      expect(widths.control, 8);
      expect(widths.group, 6);
      expect(widths.task, 6);
    });

    test('16ポートのビット幅は Control4 / Group3 / Task6', () {
      final widths = CodeTriggerHelpers.bitWidths(16);
      expect(widths.control, 4);
      expect(widths.group, 3);
      expect(widths.task, 6);
    });

    test('制御コード4は8bitで00000100', () {
      expect(CodeTriggerHelpers.formatBits(4, 8), '00000100');
    });

    test('グループ10は6bitで001010', () {
      expect(CodeTriggerHelpers.formatBits(10, 6), '001010');
    });

    test('タスク5は6bitで000101', () {
      expect(CodeTriggerHelpers.formatBits(5, 6), '000101');
    });

    test('16ポートでは4bitに収まらない制御コードを候補から外す', () {
      final codes = CodeTriggerHelpers.availableControlCodes(16);
      expect(codes, containsAll([1, 2, 3, 4, 5, 9, 10, 12]));
      expect(codes, isNot(contains(34)));
      expect(codes, isNot(contains(49)));
    });

    test('32ポートでは既知の制御コードをすべて候補にする', () {
      final codes = CodeTriggerHelpers.availableControlCodes(32);
      expect(codes, CodeTriggerHelpers.knownControlCodes);
    });

    test('タスク実行・ロード・アンロードはグループとタスクが必要', () {
      for (final code in [1, 3, 4, 5]) {
        final spec = CodeTriggerHelpers.commandSpec(code);
        expect(spec.requiresGroup, isTrue, reason: 'code $code');
        expect(spec.requiresTask, isTrue, reason: 'code $code');
      }
    });

    test('システム系制御コードはグループとタスクが不要', () {
      for (final code in [2, 9, 10, 12, 34, 35, 37, 38, 39, 40, 42, 43, 44, 45, 48, 49]) {
        final spec = CodeTriggerHelpers.commandSpec(code);
        expect(spec.requiresGroup, isFalse, reason: 'code $code');
        expect(spec.requiresTask, isFalse, reason: 'code $code');
      }
    });

    test('コメント本文はコマンド名とビット列を結合する', () {
      final text = CodeTriggerHelpers.formatCodeOptionComment(
        commandName: 'タスクロード',
        controlCode: 4,
        group: 10,
        task: 5,
        inputCount: 32,
      );
      expect(text, 'タスクロード T:000101 G:001010 C:00000100');
    });

    test('自動コメントのビット列も TGC 順', () {
      const inputCount = 32;
      final indices = CodeTriggerHelpers.codeBitIndices(inputCount);
      final bitSeries = [
        for (final _ in indices) List<int>.filled(1, 0),
      ];
      final pattern = CodeTriggerHelpers.formatCodeBitPatternAt(
        t: 0,
        indices: indices,
        bitSeries: bitSeries,
        inputCount: inputCount,
      );
      expect(pattern.indexOf('T:'), lessThan(pattern.indexOf('G:')));
      expect(pattern.indexOf('G:'), lessThan(pattern.indexOf('C:')));
    });

    test('グループとタスクが不要な制御コードはビット列に含めない', () {
      final text = CodeTriggerHelpers.formatCodeOptionComment(
        commandName: '全タスクアンロード',
        controlCode: 12,
        inputCount: 32,
      );
      expect(text, '全タスクアンロード C:00001100');
    });
  });
}
