import '../models/chart/signal_data.dart';
import '../models/chart/signal_type.dart';
import '../models/chart/io_channel_source.dart';
import '../providers/timing_chart_controller.dart';
import '../widgets/chart/timing_chart.dart';

/// チャート更新処理の結果を保持するクラス
class ChartUpdateResult {
  final List<SignalData> signals;
  final List<int> portNumbers;
  final List<IoChannelSource> ioSources;

  const ChartUpdateResult({
    required this.signals,
    required this.portNumbers,
    required this.ioSources,
  });
}

/// チャート更新処理を担当するサービスクラス
class ChartUpdateService {
  /// チャートを更新する
  /// 
  /// [signalNames] 信号名のリスト
  /// [chartData] チャートデータ（値のリスト）
  /// [signalTypes] 信号タイプのリスト
  /// [portNumbers] ポート番号のリスト
  /// [ioSources] IOソースのリスト
  /// [overrideFlag] 既存の値を上書きするかどうか
  /// [existingSignals] 既存の信号データ
  /// [chartController] チャートコントローラー
  /// [timingChartState] タイミングチャートの状態（null可）
  /// [detectIoSource] IOソースを検出する関数（null可）
  /// 
  /// 戻り値: 更新結果
  static ChartUpdateResult updateChart({
    required List<String> signalNames,
    required List<List<int>> chartData,
    required List<SignalType> signalTypes,
    required List<int> portNumbers,
    required List<IoChannelSource> ioSources,
    required bool overrideFlag,
    required List<SignalData> existingSignals,
    required TimingChartController chartController,
    TimingChartState? timingChartState,
    IoChannelSource Function(String label, SignalType type)? detectIoSource,
  }) {
    // 既存の値のマップを作成
    final Map<String, List<int>> existingValuesMap = {};
    if (timingChartState != null) {
      final currentChartValues = chartController.signals;
      for (int i = 0;
          i < existingSignals.length && i < currentChartValues.length;
          i++) {
        existingValuesMap[existingSignals[i].name] = currentChartValues[i];
      }
    } else {
      for (var signal in existingSignals) {
        existingValuesMap[signal.name] = signal.values;
      }
    }

    // 新しい信号データを作成
    final List<SignalData> newChartSignals = [];
    final List<IoChannelSource> newChartSources = [];

    for (int i = 0; i < signalNames.length; i++) {
      List<int> signalValues;

      if (overrideFlag) {
        if (i < chartData.length) {
          signalValues = List<int>.from(chartData[i]);
        } else {
          signalValues = List.filled(32, 0);
        }
      } else {
        if (existingValuesMap.containsKey(signalNames[i])) {
          signalValues = List<int>.from(existingValuesMap[signalNames[i]]!);

          if (i < chartData.length &&
              signalValues.length != chartData[i].length) {
            if (signalValues.length < chartData[i].length) {
              signalValues.addAll(
                List.filled(
                  chartData[i].length - signalValues.length,
                  0,
                ),
              );
            }
            // 長い場合はそのまま（切り詰めない）
          }
        } else if (i < chartData.length) {
          signalValues = List<int>.from(chartData[i]);
        } else {
          signalValues = List.filled(32, 0);
        }
      }

      newChartSignals.add(
        SignalData(
          name: signalNames[i],
          signalType: signalTypes[i],
          values: signalValues,
          isVisible: true,
        ),
      );
      // IOソースの検出
      if (detectIoSource != null) {
        newChartSources.add(detectIoSource(signalNames[i], signalTypes[i]));
      } else if (ioSources.length > i) {
        newChartSources.add(ioSources[i]);
      } else {
        newChartSources.add(IoChannelSource.unknown);
      }
    }

    // チャートの順序を維持する処理
    var effectiveSources = List<IoChannelSource>.from(newChartSources);

    if (!overrideFlag && timingChartState != null) {
      final currentOrder = chartController.signalNames;

      if (currentOrder.isNotEmpty) {
        final mapByName = {
          for (final s in newChartSignals) s.name: s,
        };
        final sourceByName = <String, List<IoChannelSource>>{};
        for (int i = 0; i < newChartSignals.length; i++) {
          final key = newChartSignals[i].name;
          sourceByName.putIfAbsent(key, () => []).add(effectiveSources[i]);
        }

        final reordered = <SignalData>[];
        final reorderedSources = <IoChannelSource>[];
        for (final name in currentOrder) {
          final signal = mapByName[name];
          if (signal != null) {
            reordered.add(signal);
            final list = sourceByName[name];
            if (list != null && list.isNotEmpty) {
              reorderedSources.add(list.removeAt(0));
            } else {
              reorderedSources.add(IoChannelSource.unknown);
            }
            mapByName.remove(name);
          }
        }
        for (final entry in mapByName.entries) {
          reordered.add(entry.value);
          final list = sourceByName[entry.key];
          if (list != null && list.isNotEmpty) {
            reorderedSources.add(list.removeAt(0));
          } else {
            reorderedSources.add(IoChannelSource.unknown);
          }
        }

        return ChartUpdateResult(
          signals: reordered,
          portNumbers: _mapPortNumbers(reordered, signalNames, portNumbers),
          ioSources: reorderedSources,
        );
      }
    }

    // ポート番号のマッピング
    final mappedPortNumbers = _mapPortNumbers(
      newChartSignals,
      signalNames,
      portNumbers,
    );

    return ChartUpdateResult(
      signals: newChartSignals,
      portNumbers: mappedPortNumbers,
      ioSources: effectiveSources,
    );
  }

  /// 信号名リストに基づいてポート番号をマッピング
  static List<int> _mapPortNumbers(
    List<SignalData> signals,
    List<String> signalNames,
    List<int> portNumbers,
  ) {
    final nameToPort = <String, int>{};
    for (int i = 0; i < signalNames.length && i < portNumbers.length; i++) {
      nameToPort[signalNames[i]] = portNumbers[i];
    }

    return signals.map((s) => nameToPort[s.name] ?? 0).toList();
  }

  /// チャート信号の変更を処理する
  /// 
  /// [names] 信号名のリスト
  /// [values] 値のリスト
  /// [types] 信号タイプのリスト
  /// [existingSignals] 既存の信号データ
  /// 
  /// 戻り値: 更新された信号データのリスト
  static List<SignalData> handleChartSignalsChanged({
    required List<String> names,
    required List<List<int>> values,
    required List<SignalType> types,
    required List<SignalData> existingSignals,
  }) {
    if (names.length != values.length) {
      return existingSignals;
    }

    final currentByName = {
      for (final signal in existingSignals) signal.name: signal,
    };
    final List<SignalData> updatedSignals = [];
    for (int i = 0; i < names.length; i++) {
      final existing = currentByName[names[i]];
      final copiedValues = List<int>.from(values[i]);
      if (existing != null) {
        final signalType = types.length > i ? types[i] : existing.signalType;
        updatedSignals.add(
          existing.copyWith(signalType: signalType, values: copiedValues),
        );
      } else {
        final signalType = types.length > i ? types[i] : SignalType.input;
        updatedSignals.add(
          SignalData(
            name: names[i],
            signalType: signalType,
            values: copiedValues,
          ),
        );
      }
    }
    return updatedSignals;
  }
}

