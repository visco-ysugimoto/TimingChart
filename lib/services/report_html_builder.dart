import '../models/chart/io_channel_source.dart';
import '../models/chart/signal_data.dart';
import '../models/chart/signal_type.dart';
import '../models/chart/timing_chart_annotation.dart';
import '../models/form/camera_table_types.dart';
import '../models/form/form_state.dart';
import '../widgets/form/form_tab_constants.dart';

/// HTML レポート内の見出し・列名（UI 言語に合わせる）。
class ReportHtmlLabels {
  final String documentTitle;
  final String sectionComposition;
  final String sectionTrigger;
  final String sectionSignals;
  final String sectionCamera;
  final String sectionChart;
  final String sectionComments;
  final String fieldTrigger;
  final String fieldPlcEip;
  final String fieldInputPorts;
  final String fieldOutputPorts;
  final String fieldHwPorts;
  final String fieldCameras;
  final String fieldTimeUnit;
  final String timeUnitStep;
  final String timeUnitMs;
  final String colPort;
  final String colName;
  final String visibleYes;
  final String visibleNo;
  final String colStep;
  final String colComment;
  final String colRow;
  final String noChart;
  final String noSignals;
  final String noComments;
  final String noCamera;
  final String simultaneous;
  final String inputType;
  final String outputType;
  final String hwTriggerType;
  final String controlType;
  final String groupType;
  final String taskType;
  final String auxiliaryType;
  final String cameraColumnPrefix;
  final String modeNone;
  final String modeSequential;
  final String modeContact;
  final String modeHwTrigger;

  const ReportHtmlLabels({
    required this.documentTitle,
    required this.sectionComposition,
    required this.sectionTrigger,
    required this.sectionSignals,
    required this.sectionCamera,
    required this.sectionChart,
    required this.sectionComments,
    required this.fieldTrigger,
    required this.fieldPlcEip,
    required this.fieldInputPorts,
    required this.fieldOutputPorts,
    required this.fieldHwPorts,
    required this.fieldCameras,
    required this.fieldTimeUnit,
    required this.timeUnitStep,
    required this.timeUnitMs,
    required this.colPort,
    required this.colName,
    required this.visibleYes,
    required this.visibleNo,
    required this.colStep,
    required this.colComment,
    required this.colRow,
    required this.noChart,
    required this.noSignals,
    required this.noComments,
    required this.noCamera,
    required this.simultaneous,
    required this.inputType,
    required this.outputType,
    required this.hwTriggerType,
    required this.controlType,
    required this.groupType,
    required this.taskType,
    required this.auxiliaryType,
    required this.cameraColumnPrefix,
    required this.modeNone,
    required this.modeSequential,
    required this.modeContact,
    required this.modeHwTrigger,
  });

  static const ReportHtmlLabels ja = ReportHtmlLabels(
    documentTitle: 'タイミングチャート',
    sectionComposition: '構成',
    sectionTrigger: 'トリガー方式',
    sectionSignals: '信号一覧',
    sectionCamera: 'カメラ取込表',
    sectionChart: 'チャート',
    sectionComments: 'コメント',
    fieldTrigger: 'トリガー方式',
    fieldPlcEip: 'PLC / EIP',
    fieldInputPorts: '入力ポート数',
    fieldOutputPorts: '出力ポート数',
    fieldHwPorts: 'HWトリガポート数',
    fieldCameras: 'カメラ台数',
    fieldTimeUnit: '時間単位',
    timeUnitStep: 'ステップ',
    timeUnitMs: 'ミリ秒',
    colPort: 'ポート',
    colName: '信号名',
    visibleYes: 'あり',
    visibleNo: 'なし',
    colStep: 'ステップ',
    colComment: '内容',
    colRow: '行',
    noChart: 'チャート画像はありません。',
    noSignals: '信号がありません。',
    noComments: 'コメントはありません。',
    noCamera: 'カメラ取込表がありません。',
    simultaneous: '同時取込',
    inputType: 'Input',
    outputType: 'Output',
    hwTriggerType: 'HW Trigger',
    controlType: 'Control',
    groupType: 'Group',
    taskType: 'Task',
    auxiliaryType: 'Auxiliary',
    cameraColumnPrefix: 'Camera',
    modeNone: 'None',
    modeSequential: '順次取込',
    modeContact: '接点入力',
    modeHwTrigger: 'HWトリガ',
  );

  static const ReportHtmlLabels en = ReportHtmlLabels(
    documentTitle: 'Timing Chart',
    sectionComposition: 'Configuration',
    sectionTrigger: 'Trigger mode',
    sectionSignals: 'Signals',
    sectionCamera: 'Camera configuration',
    sectionChart: 'Chart',
    sectionComments: 'Comments',
    fieldTrigger: 'Trigger mode',
    fieldPlcEip: 'PLC / EIP',
    fieldInputPorts: 'Input ports',
    fieldOutputPorts: 'Output ports',
    fieldHwPorts: 'HW trigger ports',
    fieldCameras: 'Cameras',
    fieldTimeUnit: 'Time unit',
    timeUnitStep: 'step',
    timeUnitMs: 'ms',
    colPort: 'Port',
    colName: 'Name',
    visibleYes: 'Yes',
    visibleNo: 'No',
    colStep: 'Step',
    colComment: 'Comment',
    colRow: 'Row',
    noChart: 'No chart image is available.',
    noSignals: 'No signals.',
    noComments: 'No comments.',
    noCamera: 'No camera configuration table.',
    simultaneous: 'Simultaneous',
    inputType: 'Input',
    outputType: 'Output',
    hwTriggerType: 'HW Trigger',
    controlType: 'Control',
    groupType: 'Group',
    taskType: 'Task',
    auxiliaryType: 'Auxiliary',
    cameraColumnPrefix: 'Camera',
    modeNone: 'None',
    modeSequential: 'Sequential',
    modeContact: 'Contact Input',
    modeHwTrigger: 'HW Trigger',
  );

  factory ReportHtmlLabels.forLanguage(String languageCode) {
    return languageCode.toLowerCase() == 'ja' ? ja : en;
  }

  String signalTypeLabel(SignalType type) {
    switch (type) {
      case SignalType.input:
        return inputType;
      case SignalType.output:
        return outputType;
      case SignalType.hwTrigger:
        return hwTriggerType;
      case SignalType.control:
        return controlType;
      case SignalType.group:
        return groupType;
      case SignalType.task:
        return taskType;
      case SignalType.auxiliary:
        return auxiliaryType;
    }
  }

  String cellModeLabel(CellMode mode) {
    switch (mode) {
      case CellMode.mode1:
        return modeSequential;
      case CellMode.mode2:
        return modeContact;
      case CellMode.mode3:
        return modeHwTrigger;
      case CellMode.none:
      case CellMode.mode4:
      case CellMode.mode5:
        return modeNone;
    }
  }
}

/// HTML レポートに載せるデータ。
class ReportHtmlData {
  final String languageCode;
  final TimingFormState formState;
  final String plcEipOption;
  final bool timeUnitIsMs;
  final double msPerStep;
  final List<SignalData> signals;
  final List<int> signalPorts;
  /// [signals] と同じ並び。DIO と PLI/ESI・PLO/ESO を分ける。
  final List<IoChannelSource> signalSources;
  final List<List<CellMode>> tableData;
  final List<String> rowModes;
  final String triggerMarkdown;
  final String? chartJpegBase64;
  final List<TimingChartAnnotation> annotations;

  const ReportHtmlData({
    required this.languageCode,
    required this.formState,
    required this.plcEipOption,
    required this.timeUnitIsMs,
    required this.msPerStep,
    required this.signals,
    required this.signalPorts,
    this.signalSources = const [],
    required this.tableData,
    required this.rowModes,
    required this.triggerMarkdown,
    this.chartJpegBase64,
    this.annotations = const [],
  });
}

/// 単体の HTML レポートを組み立てる。
class ReportHtmlBuilder {
  ReportHtmlBuilder._();

  /// Trigger Option から説明原稿のファイル名を決める。
  static String triggerDocFileName(String triggerOption) {
    if (triggerOption == TriggerOptions.code) return 'code.md';
    if (triggerOption == TriggerOptions.command) return 'command.md';
    return 'single.md';
  }

  static String triggerDocAssetPath({
    required String triggerOption,
    required String languageCode,
  }) {
    final lang = languageCode.toLowerCase() == 'ja' ? 'ja' : 'en';
    return 'assets/help/$lang/triggers/${triggerDocFileName(triggerOption)}';
  }

  static String escape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  static String markdownToHtml(String markdown) {
    final lines = markdown.replaceAll('\r\n', '\n').split('\n');
    final buf = StringBuffer();
    var i = 0;
    while (i < lines.length) {
      final raw = lines[i];
      final trimmed = raw.trimRight();
      if (trimmed.trim().isEmpty) {
        i++;
        continue;
      }
      if (trimmed.trim() == '---') {
        buf.writeln('<hr>');
        i++;
        continue;
      }
      if (trimmed.startsWith('### ')) {
        buf.writeln('<h3>${_inline(trimmed.substring(4))}</h3>');
        i++;
        continue;
      }
      if (trimmed.startsWith('## ')) {
        buf.writeln('<h2>${_inline(trimmed.substring(3))}</h2>');
        i++;
        continue;
      }
      if (trimmed.startsWith('# ')) {
        buf.writeln('<h2>${_inline(trimmed.substring(2))}</h2>');
        i++;
        continue;
      }
      if (trimmed.trimLeft().startsWith('|')) {
        i = _writeTable(buf, lines, i);
        continue;
      }
      if (_isBullet(trimmed)) {
        i = _writeList(buf, lines, i, ordered: false);
        continue;
      }
      if (_isOrdered(trimmed)) {
        i = _writeList(buf, lines, i, ordered: true);
        continue;
      }
      if (trimmed.startsWith('> ')) {
        i = _writeBlockquote(buf, lines, i);
        continue;
      }
      final para = <String>[trimmed];
      i++;
      while (i < lines.length) {
        final next = lines[i].trimRight();
        if (next.trim().isEmpty ||
            next.startsWith('#') ||
            next.trimLeft().startsWith('|') ||
            _isBullet(next) ||
            _isOrdered(next) ||
            next.startsWith('> ') ||
            next.trim() == '---') {
          break;
        }
        para.add(next);
        i++;
      }
      buf.writeln('<p>${_inline(para.join(' '))}</p>');
    }
    return buf.toString();
  }

  static String build(ReportHtmlData data, {ReportHtmlLabels? labels}) {
    final l = labels ?? ReportHtmlLabels.forLanguage(data.languageCode);
    final lang = data.languageCode.toLowerCase() == 'ja' ? 'ja' : 'en';
    final timeUnit =
        data.timeUnitIsMs
            ? '${l.timeUnitMs} (${_formatNumber(data.msPerStep)} ms/step)'
            : l.timeUnitStep;

    final compositionRows = <List<String>>[
      [l.fieldTrigger, data.formState.triggerOption],
      [l.fieldPlcEip, data.plcEipOption],
      [l.fieldInputPorts, '${data.formState.inputCount}'],
      [l.fieldOutputPorts, '${data.formState.outputCount}'],
      [l.fieldHwPorts, '${data.formState.hwPort}'],
      [l.fieldCameras, '${data.formState.camera}'],
      [l.fieldTimeUnit, timeUnit],
    ];

    final buf = StringBuffer()
      ..writeln('<!DOCTYPE html>')
      ..writeln('<html lang="$lang">')
      ..writeln('<head>')
      ..writeln('<meta charset="utf-8">')
      ..writeln('<meta name="viewport" content="width=device-width, initial-scale=1">')
      ..writeln('<title>${escape(l.documentTitle)}</title>')
      ..writeln('<style>${_css()}</style>')
      ..writeln('</head>')
      ..writeln('<body>')
      ..writeln('<header>')
      ..writeln('<h1>${escape(l.documentTitle)}</h1>')
      ..writeln('</header>');

    buf.writeln('<section id="composition">');
    buf.writeln('<h2>${escape(l.sectionComposition)}</h2>');
    buf.writeln(_kvTable(compositionRows));
    buf.writeln('</section>');

    buf.writeln('<section id="trigger">');
    buf.writeln('<h2>${escape(l.sectionTrigger)}</h2>');
    if (data.triggerMarkdown.trim().isEmpty) {
      buf.writeln('<p>${escape(data.formState.triggerOption)}</p>');
    } else {
      buf.writeln(markdownToHtml(data.triggerMarkdown));
    }
    buf.writeln('</section>');

    buf.writeln('<section id="signals">');
    buf.writeln('<h2>${escape(l.sectionSignals)}</h2>');
    buf.writeln(_signalsTable(data, l));
    buf.writeln('</section>');

    buf.writeln('<section id="camera">');
    buf.writeln('<h2>${escape(l.sectionCamera)}</h2>');
    buf.writeln(_cameraTable(data, l));
    buf.writeln('</section>');

    buf.writeln('<section id="chart">');
    buf.writeln('<h2>${escape(l.sectionChart)}</h2>');
    final jpeg = data.chartJpegBase64;
    if (jpeg == null || jpeg.isEmpty) {
      buf.writeln('<p>${escape(l.noChart)}</p>');
    } else {
      buf.writeln(
        '<img class="chart" alt="${escape(l.sectionChart)}" src="data:image/jpeg;base64,$jpeg">',
      );
    }
    buf.writeln('</section>');

    buf.writeln('<section id="comments">');
    buf.writeln('<h2>${escape(l.sectionComments)}</h2>');
    buf.writeln(_commentsTable(data, l));
    buf.writeln('</section>');

    buf.writeln('</body></html>');
    return buf.toString();
  }

  static const List<_ReportSignalSection> _sectionTypes = [
    _ReportSignalSection.input,
    _ReportSignalSection.plcInput,
    _ReportSignalSection.output,
    _ReportSignalSection.plcOutput,
    _ReportSignalSection.hwTrigger,
  ];

  static bool _isSyntheticOptionSignal(String name) {
    return name == SignalNames.codeOption || name == SignalNames.commandOption;
  }

  static bool _isInputFamily(SignalType type) {
    return type == SignalType.input ||
        type == SignalType.control ||
        type == SignalType.group ||
        type == SignalType.task;
  }

  static bool _isPlcEipSource(IoChannelSource source) {
    return source == IoChannelSource.plc ||
        source == IoChannelSource.eip ||
        source == IoChannelSource.plcEip;
  }

  static IoChannelSource inferSourceFromName(String name) {
    final t = name.trim().toUpperCase();
    if (t.startsWith('PLO') || t.startsWith('PLI')) {
      return IoChannelSource.plc;
    }
    if (t.startsWith('ESO') || t.startsWith('ESI')) {
      return IoChannelSource.eip;
    }
    return IoChannelSource.dio;
  }

  /// `PLO2: AUTO_MODE` のような内部名から、ラベル変換用の ID を取り出す。
  static String signalIdForLabel(String name) {
    final trimmed = name.trim();
    final colonIdx = trimmed.indexOf(':');
    if (colonIdx > 0) {
      final raw = trimmed.substring(colonIdx + 1).trim();
      if (raw.isNotEmpty) return raw;
    }
    return trimmed;
  }

  static IoChannelSource _sourceOf(ReportHtmlData data, int index) {
    if (index >= 0 && index < data.signalSources.length) {
      final source = data.signalSources[index];
      if (source != IoChannelSource.unknown) return source;
    }
    if (index >= 0 && index < data.signals.length) {
      return inferSourceFromName(data.signals[index].name);
    }
    return IoChannelSource.dio;
  }

  static bool _belongsToSection(
    ReportHtmlData data,
    int index,
    _ReportSignalSection section,
  ) {
    if (index < 0 || index >= data.signals.length) return false;
    final signal = data.signals[index];
    // CODE_OPTION / Command Option はポートを持たない合成信号なので一覧から除外する。
    if (_isSyntheticOptionSignal(signal.name)) {
      return false;
    }
    final isPlcEip = _isPlcEipSource(_sourceOf(data, index));
    switch (section) {
      case _ReportSignalSection.input:
        return !isPlcEip && _isInputFamily(signal.signalType);
      case _ReportSignalSection.plcInput:
        return isPlcEip && _isInputFamily(signal.signalType);
      case _ReportSignalSection.output:
        return !isPlcEip && signal.signalType == SignalType.output;
      case _ReportSignalSection.plcOutput:
        return isPlcEip && signal.signalType == SignalType.output;
      case _ReportSignalSection.hwTrigger:
        return signal.signalType == SignalType.hwTrigger;
    }
  }

  static String _sectionHeading(
    ReportHtmlData data,
    ReportHtmlLabels l,
    _ReportSignalSection section,
  ) {
    switch (section) {
      case _ReportSignalSection.input:
        return l.inputType;
      case _ReportSignalSection.plcInput:
        return data.plcEipOption == PlcEipOptions.eip ? 'ESI' : 'PLI';
      case _ReportSignalSection.output:
        return l.outputType;
      case _ReportSignalSection.plcOutput:
        return data.plcEipOption == PlcEipOptions.eip ? 'ESO' : 'PLO';
      case _ReportSignalSection.hwTrigger:
        return l.hwTriggerType;
    }
  }

  static int _portOf(ReportHtmlData data, int index) {
    if (index < 0 || index >= data.signalPorts.length) return 0;
    return data.signalPorts[index];
  }

  static int _sectionPortCount(
    ReportHtmlData data,
    _ReportSignalSection section,
  ) {
    switch (section) {
      case _ReportSignalSection.input:
      case _ReportSignalSection.plcInput:
        return data.formState.inputCount;
      case _ReportSignalSection.output:
      case _ReportSignalSection.plcOutput:
        return data.formState.outputCount;
      case _ReportSignalSection.hwTrigger:
        return data.formState.hwPort;
    }
  }

  static bool _shouldRenderSection(
    ReportHtmlData data,
    _ReportSignalSection section,
  ) {
    final count = _sectionPortCount(data, section);
    if (count <= 0) return false;
    switch (section) {
      case _ReportSignalSection.plcInput:
      case _ReportSignalSection.plcOutput:
        return data.plcEipOption != PlcEipOptions.none;
      case _ReportSignalSection.input:
      case _ReportSignalSection.output:
      case _ReportSignalSection.hwTrigger:
        return true;
    }
  }

  static String _signalsTable(ReportHtmlData data, ReportHtmlLabels l) {
    if (!_sectionTypes.any((section) => _shouldRenderSection(data, section))) {
      return '<p>${escape(l.noSignals)}</p>';
    }
    final buf = StringBuffer();
    buf.writeln('<div class="signal-tables">');
    for (final section in _sectionTypes) {
      if (!_shouldRenderSection(data, section)) continue;
      final portCount = _sectionPortCount(data, section);
      final namesByPort = <int, String>{};
      for (var i = 0; i < data.signals.length; i++) {
        if (!_belongsToSection(data, i, section)) continue;
        final port = _portOf(data, i);
        if (port <= 0 || port > portCount) continue;
        final name = data.signals[i].name.trim();
        if (name.isEmpty) continue;
        namesByPort.putIfAbsent(port, () => name);
      }
      buf.writeln('<div class="signal-col">');
      buf.writeln('<h3>${escape(_sectionHeading(data, l, section))}</h3>');
      buf.writeln('<table>');
      buf.writeln(
        '<thead><tr><th>${escape(l.colPort)}</th><th>${escape(l.colName)}</th></tr></thead>',
      );
      buf.writeln('<tbody>');
      for (var port = 1; port <= portCount; port++) {
        final name = namesByPort[port] ?? '';
        buf.writeln(
          '<tr><td>${escape('$port')}</td>'
          '<td>${escape(name)}</td></tr>',
        );
      }
      buf.writeln('</tbody></table>');
      buf.writeln('</div>');
    }
    buf.writeln('</div>');
    return buf.toString();
  }

  static String _cameraTable(ReportHtmlData data, ReportHtmlLabels l) {
    if (data.tableData.isEmpty) {
      return '<p>${escape(l.noCamera)}</p>';
    }
    final cols =
        data.tableData
            .map((row) => row.length)
            .fold<int>(0, (a, b) => a > b ? a : b);
    if (cols == 0) {
      return '<p>${escape(l.noCamera)}</p>';
    }
    final buf = StringBuffer()..writeln('<table>')..writeln('<thead><tr>');
    buf.write('<th>${escape(l.colRow)}</th>');
    for (var c = 0; c < cols; c++) {
      buf.write('<th>${escape('${l.cameraColumnPrefix} ${c + 1}')}</th>');
    }
    buf.write('<th>${escape(l.simultaneous)}</th>');
    buf.writeln('</tr></thead><tbody>');
    for (var r = 0; r < data.tableData.length; r++) {
      final row = data.tableData[r];
      buf.write('<tr><td>${r + 1}</td>');
      for (var c = 0; c < cols; c++) {
        final mode = c < row.length ? row[c] : CellMode.none;
        buf.write('<td>${escape(l.cellModeLabel(mode))}</td>');
      }
      final simultaneous =
          r < data.rowModes.length &&
          data.rowModes[r] == RowMode.simultaneous.name;
      buf.write('<td>${escape(simultaneous ? l.visibleYes : l.visibleNo)}</td>');
      buf.writeln('</tr>');
    }
    buf.writeln('</tbody></table>');
    return buf.toString();
  }

  static String _commentsTable(ReportHtmlData data, ReportHtmlLabels l) {
    if (data.annotations.isEmpty) {
      return '<p>${escape(l.noComments)}</p>';
    }
    final buf = StringBuffer()
      ..writeln('<table>')
      ..writeln(
        '<thead><tr><th>${escape(l.colStep)}</th><th>${escape(l.colComment)}</th></tr></thead>',
      )
      ..writeln('<tbody>');
    for (final ann in data.annotations) {
      final end = ann.endTimeIndex;
      final step =
          end == null || end == ann.startTimeIndex
              ? '${ann.startTimeIndex}'
              : '${ann.startTimeIndex}–$end';
      buf.writeln(
        '<tr><td>${escape(step)}</td><td>${escape(ann.text)}</td></tr>',
      );
    }
    buf.writeln('</tbody></table>');
    return buf.toString();
  }

  static String _kvTable(List<List<String>> rows) {
    final buf = StringBuffer()
      ..writeln('<table class="kv">')
      ..writeln('<tbody>');
    for (final row in rows) {
      buf.writeln(
        '<tr><th>${escape(row[0])}</th><td>${escape(row[1])}</td></tr>',
      );
    }
    buf.writeln('</tbody></table>');
    return buf.toString();
  }

  static bool _isBullet(String line) {
    final t = line.trimLeft();
    return t.startsWith('- ') || t.startsWith('* ');
  }

  static bool _isOrdered(String line) {
    return RegExp(r'^\d+\.\s').hasMatch(line.trimLeft());
  }

  static int _writeList(
    StringBuffer buf,
    List<String> lines,
    int start, {
    required bool ordered,
  }) {
    buf.writeln(ordered ? '<ol>' : '<ul>');
    var i = start;
    while (i < lines.length) {
      final line = lines[i].trimRight();
      if (ordered) {
        if (!_isOrdered(line)) break;
        final text = line.trimLeft().replaceFirst(RegExp(r'^\d+\.\s+'), '');
        buf.writeln('<li>${_inline(text)}</li>');
      } else {
        if (!_isBullet(line)) break;
        final text = line.trimLeft().substring(2);
        buf.writeln('<li>${_inline(text)}</li>');
      }
      i++;
    }
    buf.writeln(ordered ? '</ol>' : '</ul>');
    return i;
  }

  static int _writeBlockquote(StringBuffer buf, List<String> lines, int start) {
    final parts = <String>[];
    var i = start;
    while (i < lines.length && lines[i].trimRight().startsWith('> ')) {
      parts.add(lines[i].trimRight().substring(2));
      i++;
    }
    buf.writeln('<blockquote><p>${_inline(parts.join(' '))}</p></blockquote>');
    return i;
  }

  static int _writeTable(StringBuffer buf, List<String> lines, int start) {
    final rows = <List<String>>[];
    var i = start;
    while (i < lines.length && lines[i].trimLeft().startsWith('|')) {
      final cells = _splitTableRow(lines[i]);
      if (cells.isNotEmpty) {
        rows.add(cells);
      }
      i++;
    }
    if (rows.isEmpty) return i;
    final bodyStart =
        rows.length > 1 && rows[1].every((c) => RegExp(r'^:?-+:?$').hasMatch(c))
            ? 2
            : 1;
    buf.writeln('<table>');
    if (rows.isNotEmpty) {
      buf.write('<thead><tr>');
      for (final cell in rows[0]) {
        buf.write('<th>${_inline(cell)}</th>');
      }
      buf.writeln('</tr></thead>');
    }
    if (bodyStart < rows.length) {
      buf.writeln('<tbody>');
      for (var r = bodyStart; r < rows.length; r++) {
        buf.write('<tr>');
        for (final cell in rows[r]) {
          buf.write('<td>${_inline(cell)}</td>');
        }
        buf.writeln('</tr>');
      }
      buf.writeln('</tbody>');
    }
    buf.writeln('</table>');
    return i;
  }

  static List<String> _splitTableRow(String line) {
    var t = line.trim();
    if (t.startsWith('|')) t = t.substring(1);
    if (t.endsWith('|')) t = t.substring(0, t.length - 1);
    return t.split('|').map((c) => c.trim()).toList();
  }

  static String _inline(String text) {
    var escaped = escape(text);
    escaped = escaped.replaceAllMapped(
      RegExp(r'`([^`]+)`'),
      (m) => '<code>${m[1]}</code>',
    );
    escaped = escaped.replaceAllMapped(
      RegExp(r'\*\*([^*]+)\*\*'),
      (m) => '<strong>${m[1]}</strong>',
    );
    return escaped;
  }

  static String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toString();
  }

  static String _css() {
    return '''
:root { color-scheme: light; }
body { font-family: "Segoe UI", "Yu Gothic UI", "Hiragino Sans", sans-serif; margin: 24px auto; max-width: 1400px; color: #1a1a1a; line-height: 1.55; }
h1 { font-size: 1.7rem; margin: 0 0 8px; }
h2 { font-size: 1.25rem; margin: 2rem 0 0.7rem; border-bottom: 2px solid #1e88e5; padding-bottom: 4px; }
h3 { font-size: 1.05rem; margin: 1.4rem 0 0.4rem; }
section { break-inside: avoid; }
table { border-collapse: collapse; width: 100%; margin: 0.6rem 0 1rem; font-size: 0.92rem; }
th, td { border: 1px solid #c5c5c5; padding: 6px 8px; text-align: left; vertical-align: top; }
th { background: #f3f6fa; }
table.kv { width: auto; min-width: 360px; }
table.kv th { width: 10rem; }
.signal-tables { display: flex; flex-wrap: nowrap; align-items: flex-start; gap: 16px; overflow-x: auto; }
.signal-col { flex: 1 1 0; min-width: 200px; }
.signal-col h3 { margin-top: 0; }
.signal-col table { margin-top: 0.3rem; }
.signal-col th:first-child, .signal-col td:first-child { width: 4rem; white-space: nowrap; }
img.chart { max-width: 100%; height: auto; border: 1px solid #ccc; background: #fff; }
blockquote { margin: 0.5rem 0; padding: 8px 12px; border-left: 4px solid #1e88e5; background: #f3f6fa; }
code { font-family: Consolas, "Yu Gothic UI", monospace; background: #f0f0f0; padding: 1px 4px; }
ul, ol { margin: 0.4rem 0 0.8rem 1.4rem; }
@media print { body { margin: 8mm; max-width: none; } .signal-tables { flex-wrap: nowrap; overflow: visible; } .signal-col { break-inside: avoid; } img.chart { max-width: 100%; page-break-inside: avoid; } }
''';
  }
}

enum _ReportSignalSection { input, plcInput, output, plcOutput, hwTrigger }
