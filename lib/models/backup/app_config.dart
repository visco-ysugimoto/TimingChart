import 'dart:convert';
import 'package:flutter/material.dart';
import '../form/form_state.dart';
import '../chart/signal_data.dart';
import '../chart/signal_type.dart';
import '../../widgets/form/form_tab.dart';

/// アプリケーションの全設定を保持するクラス
class AppConfig {
  // フォーム設定
  final TimingFormState formState;

  // 信号データ
  final List<SignalData> signals;

  // カメラテーブル設定
  final List<List<CellMode>> tableData;

  // 信号名
  final List<String> inputNames;
  final List<String> outputNames;
  final List<String> hwTriggerNames;

  // 表示/非表示状態
  final List<bool> inputVisibility;
  final List<bool> outputVisibility;
  final List<bool> hwTriggerVisibility;

  const AppConfig({
    required this.formState,
    required this.signals,
    required this.tableData,
    required this.inputNames,
    required this.outputNames,
    required this.hwTriggerNames,
    required this.inputVisibility,
    required this.outputVisibility,
    required this.hwTriggerVisibility,
  });

  /// TextEditingControllerからテキスト値を抽出
  static List<String> _extractTextValues(
    List<TextEditingController> controllers,
  ) {
    return controllers.map((controller) => controller.text).toList();
  }

  /// 現在の状態からAppConfigインスタンスを生成
  static AppConfig fromCurrentState({
    required TimingFormState formState,
    required List<SignalData> signals,
    required List<List<CellMode>> tableData,
    required List<TextEditingController> inputControllers,
    required List<TextEditingController> outputControllers,
    required List<TextEditingController> hwTriggerControllers,
    required List<bool> inputVisibility,
    required List<bool> outputVisibility,
    required List<bool> hwTriggerVisibility,
  }) {
    return AppConfig(
      formState: formState,
      signals: signals,
      tableData: tableData,
      inputNames: _extractTextValues(inputControllers),
      outputNames: _extractTextValues(outputControllers),
      hwTriggerNames: _extractTextValues(hwTriggerControllers),
      inputVisibility: inputVisibility,
      outputVisibility: outputVisibility,
      hwTriggerVisibility: hwTriggerVisibility,
    );
  }

  /// JSONにシリアライズ
  Map<String, dynamic> toJson() {
    return {
      'formState': {
        'triggerOption': formState.triggerOption,
        'ioPort': formState.ioPort,
        'hwPort': formState.hwPort,
        'camera': formState.camera,
        'inputCount': formState.inputCount,
        'outputCount': formState.outputCount,
      },
      'signals':
          signals
              .map(
                (signal) => {
                  'name': signal.name,
                  'signalType': signal.signalType.index,
                  'values': signal.values,
                  'isVisible': signal.isVisible,
                },
              )
              .toList(),
      'tableData':
          tableData
              .map((row) => row.map((cell) => cell.index).toList())
              .toList(),
      'inputNames': inputNames,
      'outputNames': outputNames,
      'hwTriggerNames': hwTriggerNames,
      'inputVisibility': inputVisibility,
      'outputVisibility': outputVisibility,
      'hwTriggerVisibility': hwTriggerVisibility,
    };
  }

  /// JSONからデシリアライズ
  static AppConfig fromJson(Map<String, dynamic> json) {
    // フォーム状態の作成
    final formStateJson = json['formState'];
    final formState = TimingFormState(
      triggerOption: formStateJson['triggerOption'],
      ioPort: formStateJson['ioPort'],
      hwPort: formStateJson['hwPort'],
      camera: formStateJson['camera'],
      inputCount: formStateJson['inputCount'],
      outputCount: formStateJson['outputCount'],
    );

    // 信号データの作成
    final List<SignalData> signals =
        (json['signals'] as List)
            .map(
              (signalJson) => SignalData(
                name: signalJson['name'],
                signalType: SignalType.values[signalJson['signalType']],
                values: (signalJson['values'] as List).cast<int>(),
                isVisible: signalJson['isVisible'],
              ),
            )
            .toList();

    // テーブルデータの作成
    final List<List<CellMode>> tableData =
        (json['tableData'] as List)
            .map(
              (row) =>
                  (row as List)
                      .map((cellIndex) => CellMode.values[cellIndex])
                      .toList(),
            )
            .toList();

    return AppConfig(
      formState: formState,
      signals: signals,
      tableData: tableData,
      inputNames: (json['inputNames'] as List).cast<String>(),
      outputNames: (json['outputNames'] as List).cast<String>(),
      hwTriggerNames: (json['hwTriggerNames'] as List).cast<String>(),
      inputVisibility: (json['inputVisibility'] as List).cast<bool>(),
      outputVisibility: (json['outputVisibility'] as List).cast<bool>(),
      hwTriggerVisibility: (json['hwTriggerVisibility'] as List).cast<bool>(),
    );
  }

  /// JSONをStringにエンコード
  String toJsonString() {
    return jsonEncode(toJson());
  }

  /// StringからAppConfigを生成
  static AppConfig fromJsonString(String jsonString) {
    final Map<String, dynamic> json = jsonDecode(jsonString);
    return fromJson(json);
  }

  /// 新しいTextEditingControllerのリストを生成
  List<TextEditingController> createInputControllers() {
    return inputNames.map((name) => TextEditingController(text: name)).toList();
  }

  /// 新しいTextEditingControllerのリストを生成
  List<TextEditingController> createOutputControllers() {
    return outputNames
        .map((name) => TextEditingController(text: name))
        .toList();
  }

  /// 新しいTextEditingControllerのリストを生成
  List<TextEditingController> createHwTriggerControllers() {
    return hwTriggerNames
        .map((name) => TextEditingController(text: name))
        .toList();
  }
}
