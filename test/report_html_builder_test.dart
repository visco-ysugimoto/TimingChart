import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/chart/io_channel_source.dart';
import 'package:flutter_application_1/models/chart/signal_data.dart';
import 'package:flutter_application_1/models/chart/signal_type.dart';
import 'package:flutter_application_1/models/chart/timing_chart_annotation.dart';
import 'package:flutter_application_1/models/form/camera_table_types.dart';
import 'package:flutter_application_1/models/form/form_state.dart';
import 'package:flutter_application_1/services/report_html_builder.dart';
import 'package:flutter_application_1/widgets/form/form_tab_constants.dart';


void main() {
  group('ReportHtmlBuilder', () {
    test('triggerDocFileName は Trigger Option に対応する', () {
      expect(
        ReportHtmlBuilder.triggerDocFileName(TriggerOptions.single),
        'single.md',
      );
      expect(
        ReportHtmlBuilder.triggerDocFileName(TriggerOptions.code),
        'code.md',
      );
      expect(
        ReportHtmlBuilder.triggerDocFileName(TriggerOptions.command),
        'command.md',
      );
    });

    test('HTML 特殊文字をエスケープする', () {
      expect(
        ReportHtmlBuilder.escape('<script>"&\'</script>'),
        '&lt;script&gt;&quot;&amp;&#39;&lt;/script&gt;',
      );
    });

    test('Markdown の表と強調を HTML にする', () {
      const md = '''
# 見出し
**太字** と `CODE_OPTION`

| コード | 名前 |
| --- | --- |
| 1 | タスク実行 |
''';
      final html = ReportHtmlBuilder.markdownToHtml(md);
      expect(html, contains('<h2>見出し</h2>'));
      expect(html, contains('<strong>太字</strong>'));
      expect(html, contains('<code>CODE_OPTION</code>'));
      expect(html, contains('<th>コード</th>'));
      expect(html, contains('<td>タスク実行</td>'));
    });

    test('レポート HTML に信号・カメラ・チャート・コメントを含める', () {
      const data = ReportHtmlData(
        languageCode: 'ja',
        formState: TimingFormState(
          triggerOption: TriggerOptions.code,
          ioPort: 32,
          hwPort: 2,
          camera: 2,
          inputCount: 32,
          outputCount: 16,
        ),
        plcEipOption: PlcEipOptions.none,
        timeUnitIsMs: false,
        msPerStep: 1,
        signals: [
          SignalData(
            name: 'TRIGGER',
            signalType: SignalType.input,
            values: [0, 1],
            isVisible: true,
          ),
          SignalData(
            name: 'BUSY',
            signalType: SignalType.output,
            values: [0, 0],
            isVisible: false,
          ),
        ],
        signalPorts: [1, 4],
        tableData: [
          [CellMode.mode1, CellMode.none],
        ],
        rowModes: [kRowModeSimultaneous],
        triggerMarkdown: '## コードトリガ\n同時に複数の入力を使います。',
        chartJpegBase64: 'AAAA',
        annotations: [
          TimingChartAnnotation(
            id: 'c1',
            startTimeIndex: 3,
            endTimeIndex: 5,
            text: '立ち上がり',
          ),
        ],
      );

      final html = ReportHtmlBuilder.build(data);
      expect(html, contains('lang="ja"'));
      expect(html, contains('class="signal-tables"'));
      expect(html, contains('Code Trigger'));
      expect(html, contains('コードトリガ'));
      expect(html, contains('<h3>Input</h3>'));
      expect(html, contains('<h3>Output</h3>'));
      expect(
        html.indexOf('<h3>Input</h3>'),
        lessThan(html.indexOf('<h3>Output</h3>')),
      );
      expect(html, isNot(contains('<h3>Control</h3>')));
      expect(html, contains('TRIGGER'));
      expect(html, contains('BUSY'));
      expect(html, isNot(contains('アプリ版')));
      expect(html, isNot(contains('作成日時')));
      expect(html, contains('順次取込'));
      expect(html, contains('同時取込'));
      expect(html, contains('data:image/jpeg;base64,AAAA'));
      expect(html, contains('3–5'));
      expect(html, contains('立ち上がり'));
      expect(html, isNot(contains('<script>')));
    });

    test('Input に制御コードを含め、ポート昇順に並べる', () {
      const data = ReportHtmlData(
        languageCode: 'ja',
        formState: TimingFormState(
          triggerOption: TriggerOptions.code,
          ioPort: 32,
          hwPort: 0,
          camera: 1,
          inputCount: 32,
          outputCount: 16,
        ),
        plcEipOption: PlcEipOptions.none,
        timeUnitIsMs: false,
        msPerStep: 1,
        signals: [
          SignalData(
            name: 'BUSY',
            signalType: SignalType.output,
            values: [0],
          ),
          SignalData(
            name: 'Control Code3(bit)',
            signalType: SignalType.control,
            values: [0],
          ),
          SignalData(
            name: 'TRIGGER',
            signalType: SignalType.input,
            values: [0],
          ),
          SignalData(
            name: 'Control Code2(bit)',
            signalType: SignalType.control,
            values: [0],
          ),
        ],
        signalPorts: [8, 3, 1, 2],
        tableData: const [],
        rowModes: const [],
        triggerMarkdown: '',
      );

      final html = ReportHtmlBuilder.build(data);
      expect(html, contains('<h3>Input</h3>'));
      expect(html, isNot(contains('<h3>Control</h3>')));
      expect(html, contains('Control Code2(bit)'));
      expect(html, contains('Control Code3(bit)'));

      final inputHtml = html.substring(
        html.indexOf('<h3>Input</h3>'),
        html.indexOf('<h3>Output</h3>'),
      );
      expect(inputHtml.indexOf('TRIGGER'), lessThan(inputHtml.indexOf('Control Code2(bit)')));
      expect(
        inputHtml.indexOf('Control Code2(bit)'),
        lessThan(inputHtml.indexOf('Control Code3(bit)')),
      );
    });

    test('CODE_OPTION は信号一覧に出さない', () {
      const data = ReportHtmlData(
        languageCode: 'ja',
        formState: TimingFormState(
          triggerOption: TriggerOptions.code,
          ioPort: 32,
          hwPort: 0,
          camera: 1,
          inputCount: 32,
          outputCount: 16,
        ),
        plcEipOption: PlcEipOptions.none,
        timeUnitIsMs: false,
        msPerStep: 1,
        signals: [
          SignalData(
            name: 'TRIGGER',
            signalType: SignalType.input,
            values: [0],
          ),
          SignalData(
            name: SignalNames.codeOption,
            signalType: SignalType.input,
            values: [0],
          ),
        ],
        signalPorts: [1, 0],
        tableData: const [],
        rowModes: const [],
        triggerMarkdown: '',
      );

      final html = ReportHtmlBuilder.build(data);
      expect(html, contains('<h3>Input</h3>'));
      expect(html, contains('TRIGGER'));
      expect(html, isNot(contains('<h3>Auxiliary</h3>')));
      expect(html, isNot(contains('CODE_OPTION')));
    });

    test('PLC 設定時は PLI / PLO を別表にし、同名の DIO も残す', () {
      const data = ReportHtmlData(
        languageCode: 'ja',
        formState: TimingFormState(
          triggerOption: TriggerOptions.single,
          ioPort: 16,
          hwPort: 0,
          camera: 1,
          inputCount: 16,
          outputCount: 16,
        ),
        plcEipOption: PlcEipOptions.plc,
        timeUnitIsMs: false,
        msPerStep: 1,
        signals: [
          SignalData(name: 'TRIGGER', signalType: SignalType.input, values: [0]),
          SignalData(name: 'TRIGGER', signalType: SignalType.input, values: [0]),
          SignalData(name: 'BUSY', signalType: SignalType.output, values: [0]),
          SignalData(
            name: 'PLO1: BUSY',
            signalType: SignalType.output,
            values: [0],
          ),
        ],
        signalPorts: [1, 1, 1, 1],
        signalSources: [
          IoChannelSource.dio,
          IoChannelSource.plc,
          IoChannelSource.dio,
          IoChannelSource.plc,
        ],
        tableData: const [],
        rowModes: const [],
        triggerMarkdown: '',
      );

      final html = ReportHtmlBuilder.build(data);
      expect(html, contains('<h3>Input</h3>'));
      expect(html, contains('<h3>PLI</h3>'));
      expect(html, contains('<h3>Output</h3>'));
      expect(html, contains('<h3>PLO</h3>'));
      expect(html, isNot(contains('<h3>ESI</h3>')));
      expect(html, isNot(contains('<h3>ESO</h3>')));

      final inputHtml = html.substring(
        html.indexOf('<h3>Input</h3>'),
        html.indexOf('<h3>PLI</h3>'),
      );
      final pliHtml = html.substring(
        html.indexOf('<h3>PLI</h3>'),
        html.indexOf('<h3>Output</h3>'),
      );
      final outputHtml = html.substring(
        html.indexOf('<h3>Output</h3>'),
        html.indexOf('<h3>PLO</h3>'),
      );
      final ploHtml = html.substring(html.indexOf('<h3>PLO</h3>'));
      expect(inputHtml, contains('TRIGGER'));
      expect(pliHtml, contains('TRIGGER'));
      expect(outputHtml, contains('BUSY'));
      expect(outputHtml, isNot(contains('PLO1: BUSY')));
      expect(ploHtml, contains('PLO1: BUSY'));
    });

    test('EIP 設定時は ESI / ESO 見出しを使う', () {
      const data = ReportHtmlData(
        languageCode: 'en',
        formState: TimingFormState(
          triggerOption: TriggerOptions.single,
          ioPort: 16,
          hwPort: 0,
          camera: 1,
          inputCount: 16,
          outputCount: 16,
        ),
        plcEipOption: PlcEipOptions.eip,
        timeUnitIsMs: false,
        msPerStep: 1,
        signals: [
          SignalData(name: 'READY', signalType: SignalType.input, values: [0]),
          SignalData(
            name: 'ESO2: COMPLETE',
            signalType: SignalType.output,
            values: [0],
          ),
        ],
        signalPorts: [3, 2],
        signalSources: [IoChannelSource.eip, IoChannelSource.eip],
        tableData: const [],
        rowModes: const [],
        triggerMarkdown: '',
      );

      final html = ReportHtmlBuilder.build(data);
      expect(html, contains('<h3>Input</h3>'));
      expect(html, contains('<h3>ESI</h3>'));
      expect(html, contains('<h3>Output</h3>'));
      expect(html, contains('<h3>ESO</h3>'));
      expect(html, contains('READY'));
      expect(html, contains('ESO2: COMPLETE'));

      final inputHtml = html.substring(
        html.indexOf('<h3>Input</h3>'),
        html.indexOf('<h3>ESI</h3>'),
      );
      final esiHtml = html.substring(
        html.indexOf('<h3>ESI</h3>'),
        html.indexOf('<h3>Output</h3>'),
      );
      expect(inputHtml, isNot(contains('READY')));
      expect(esiHtml, contains('READY'));
    });

    test('PLO/ESO 付き内部名からラベル用 ID を取り出す', () {
      expect(
        ReportHtmlBuilder.signalIdForLabel('PLO2: AUTO_MODE'),
        'AUTO_MODE',
      );
      expect(
        ReportHtmlBuilder.signalIdForLabel('ESO5: CAMERA_1_IMAGE_EXPOSURE'),
        'CAMERA_1_IMAGE_EXPOSURE',
      );
      expect(ReportHtmlBuilder.signalIdForLabel('BUSY'), 'BUSY');
      expect(ReportHtmlBuilder.signalIdForLabel('PLO12'), 'PLO12');
    });

    test('PLO/ESO プレフィックスの信号はソース未指定でも PLC/EIP 表へ入る', () {
      const data = ReportHtmlData(
        languageCode: 'ja',
        formState: TimingFormState(
          triggerOption: TriggerOptions.single,
          ioPort: 16,
          hwPort: 0,
          camera: 1,
          inputCount: 16,
          outputCount: 16,
        ),
        plcEipOption: PlcEipOptions.plc,
        timeUnitIsMs: false,
        msPerStep: 1,
        signals: [
          SignalData(
            name: 'PLO3: ACK',
            signalType: SignalType.output,
            values: [0],
          ),
        ],
        signalPorts: [3],
        tableData: const [],
        rowModes: const [],
        triggerMarkdown: '',
      );

      final html = ReportHtmlBuilder.build(data);
      expect(html, contains('<h3>Output</h3>'));
      expect(html, contains('<h3>PLO</h3>'));
      expect(html, contains('PLO3: ACK'));

      final outputHtml = html.substring(
        html.indexOf('<h3>Output</h3>'),
        html.indexOf('<h3>PLO</h3>'),
      );
      expect(outputHtml, isNot(contains('PLO3: ACK')));
    });

    test('信号一覧は全ポートを出し、未割当の名前は空にする', () {
      const data = ReportHtmlData(
        languageCode: 'ja',
        formState: TimingFormState(
          triggerOption: TriggerOptions.single,
          ioPort: 8,
          hwPort: 2,
          camera: 1,
          inputCount: 4,
          outputCount: 3,
        ),
        plcEipOption: PlcEipOptions.none,
        timeUnitIsMs: false,
        msPerStep: 1,
        signals: [
          SignalData(name: 'TRIGGER', signalType: SignalType.input, values: [0]),
          SignalData(name: 'BUSY', signalType: SignalType.output, values: [0]),
        ],
        signalPorts: [1, 2],
        tableData: const [],
        rowModes: const [],
        triggerMarkdown: '',
      );

      final html = ReportHtmlBuilder.build(data);
      final inputHtml = html.substring(
        html.indexOf('<h3>Input</h3>'),
        html.indexOf('<h3>Output</h3>'),
      );
      final outputHtml = html.substring(
        html.indexOf('<h3>Output</h3>'),
        html.indexOf('<h3>HW Trigger</h3>'),
      );
      final hwHtml = html.substring(html.indexOf('<h3>HW Trigger</h3>'));

      expect(inputHtml, contains('<tr><td>1</td><td>TRIGGER</td></tr>'));
      expect(inputHtml, contains('<tr><td>2</td><td></td></tr>'));
      expect(inputHtml, contains('<tr><td>4</td><td></td></tr>'));
      expect(inputHtml, isNot(contains('<tr><td>5</td>')));

      expect(outputHtml, contains('<tr><td>1</td><td></td></tr>'));
      expect(outputHtml, contains('<tr><td>2</td><td>BUSY</td></tr>'));
      expect(outputHtml, contains('<tr><td>3</td><td></td></tr>'));
      expect(outputHtml, isNot(contains('<tr><td>4</td>')));

      expect(hwHtml, contains('<tr><td>1</td><td></td></tr>'));
      expect(hwHtml, contains('<tr><td>2</td><td></td></tr>'));
      expect(hwHtml, isNot(contains('<tr><td>3</td>')));
    });
  });
}
