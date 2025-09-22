/// vxVisMgr.ini の解析ユーティリティ
class VxVisMgrParser {
  /// [StatusSignalSetting] セクション内で `xxx.Enable=1` の xxx 名を抽出
  static List<String> parseStatusSignalsEnabled(String iniContent) {
    final settings = parseStatusSignalSettings(iniContent);
    return settings.where((s) => s.enabled).map((s) => s.name).toList();
  }

  /// [StatusSignalSetting] セクション全体を解析し、
  /// 各シグナルの Enable 状態や Port.No 群などの構造を返す
  static List<StatusSignalSetting> parseStatusSignalSettings(String iniContent) {
    final lines = iniContent.split(RegExp(r'\r?\n'));
    final Map<String, _MutableSignal> temp = {};

    bool inSection = false;
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith(';') || line.startsWith('#')) continue; // コメント

      // セクション切替
      if (line.startsWith('[') && line.endsWith(']')) {
        final sectionName = line.substring(1, line.length - 1).trim();
        inSection = sectionName.toLowerCase() == 'statussignalsetting';
        continue;
      }
      if (!inSection) continue;

      // key 形式: Name.Prop (= value) or Name.Prop idx (= value)
      final m = RegExp(r'^([^.=\s]+)\.([^=]+?)\s*=\s*(.*)$').firstMatch(line);
      if (m == null) continue;
      final name = m.group(1)!;
      final propRaw = m.group(2)!.trim();
      final valueRaw = m.group(3)!.trim();

      final sig = temp.putIfAbsent(name, () => _MutableSignal(name));

      // Enable / Port.Size / Port.No k
      final enableMatch = RegExp(r'^Enable$', caseSensitive: false).hasMatch(propRaw);
      final portSizeMatch = RegExp(r'^Port\.Size$', caseSensitive: false).hasMatch(propRaw);
      final portNoMatch = RegExp(r'^Port\.No\s+(\d+)$', caseSensitive: false).firstMatch(propRaw);

      if (enableMatch) {
        final v = int.tryParse(valueRaw) ?? 0;
        sig.enabled = v != 0;
      } else if (portSizeMatch) {
        sig.portSize = int.tryParse(valueRaw) ?? sig.portSize;
      } else if (portNoMatch != null) {
        final idx = int.parse(portNoMatch.group(1)!);
        final v = int.tryParse(valueRaw);
        if (v != null) sig.portNoByIndex[idx] = v;
      }
    }

    return temp.values.map((m) => m.toImmutable()).toList();
  }

  /// [IOSetting] セクションを解析して TriggerMode / UseVirtualIO_on_Trigger を取得
  static IOSetting? parseIOSetting(String iniContent) {
    final lines = iniContent.split(RegExp(r'\r?\n'));
    bool inSection = false;
    int? triggerMode;
    int? useVirtualIoOnTrigger;

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith(';') || line.startsWith('#')) continue;

      if (line.startsWith('[') && line.endsWith(']')) {
        final sectionName = line.substring(1, line.length - 1).trim();
        inSection = sectionName.toLowerCase() == 'iosetting';
        continue;
      }
      if (!inSection) continue;

      final kv = RegExp(r'^([^=]+)=\s*(.*)$').firstMatch(line);
      if (kv == null) continue;
      final key = kv.group(1)!.trim();
      final value = kv.group(2)!.trim();

      if (key.toLowerCase() == 'triggermode') {
        triggerMode = int.tryParse(value) ?? triggerMode;
      } else if (key.toLowerCase() == 'usevirtualio_on_trigger') {
        useVirtualIoOnTrigger = int.tryParse(value) ?? useVirtualIoOnTrigger;
      }
    }

    if (triggerMode == null && useVirtualIoOnTrigger == null) return null;
    return IOSetting(
      triggerMode: triggerMode ?? 1,
      useVirtualIoOnTrigger: useVirtualIoOnTrigger ?? 0,
    );
  }

  /// [IOActive] セクションから Pin.Ports / Pout.Ports を取得
  static IOActive? parseIOActive(String iniContent) {
    final lines = iniContent.split(RegExp(r'\r?\n'));
    bool inSection = false;
    int? pinPorts;
    int? poutPorts;

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith(';') || line.startsWith('#')) continue;

      if (line.startsWith('[') && line.endsWith(']')) {
        final section = line.substring(1, line.length - 1).trim();
        inSection = section.toLowerCase() == 'ioactive';
        continue;
      }
      if (!inSection) continue;

      final m = RegExp(r'^([^=]+)=\s*(.*)$').firstMatch(line);
      if (m == null) continue;
      final key = m.group(1)!.trim().toLowerCase();
      final val = m.group(2)!.trim();
      if (key == 'pin.ports') {
        pinPorts = int.tryParse(val) ?? pinPorts;
      } else if (key == 'pout.ports') {
        poutPorts = int.tryParse(val) ?? poutPorts;
      }
    }

    if (pinPorts == null && poutPorts == null) return null;
    return IOActive(
      pinPorts: pinPorts ?? 0,
      poutPorts: poutPorts ?? 0,
    );
  }
}

/// 解析結果: 不変データ
class StatusSignalSetting {
  final String name;
  final bool enabled;
  final int portSize;
  final Map<int, int> portNoByIndex; // 例: index 0 -> ポート番号

  const StatusSignalSetting({
    required this.name,
    required this.enabled,
    required this.portSize,
    required this.portNoByIndex,
  });
}

class _MutableSignal {
  final String name;
  bool enabled = false;
  int portSize = 0;
  final Map<int, int> portNoByIndex = {};

  _MutableSignal(this.name);

  StatusSignalSetting toImmutable() => StatusSignalSetting(
    name: name,
    enabled: enabled,
    portSize: portSize,
    portNoByIndex: Map.unmodifiable(portNoByIndex),
  );
}

/// [IOSetting] の解析結果
class IOSetting {
  final int triggerMode; // 0: Code Trigger, 1: Single Trigger (要件より)
  final int useVirtualIoOnTrigger; // 0: None, 1: PLC

  const IOSetting({required this.triggerMode, required this.useVirtualIoOnTrigger});
}

/// [IOActive] の解析結果
class IOActive {
  final int pinPorts; // Input Port 数
  final int poutPorts; // Output Port 数

  const IOActive({required this.pinPorts, required this.poutPorts});
}


