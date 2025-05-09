import 'package:flutter/material.dart';

/// テンプレート定義を管理するクラス
class SignalTemplate {
  final String name;
  final List<String> inputSignals;
  final List<String> outputSignals;
  final List<String> hwTriggerSignals;
  // 各信号の値を保持するリスト
  final List<String> inputValues;
  final List<String> outputValues;
  final List<String> hwTriggerValues;
  // カメラテーブル設定用のパターン情報
  final List<List<int>> cameraPatterns;
  final Color color;

  const SignalTemplate({
    required this.name,
    required this.inputSignals,
    required this.outputSignals,
    required this.hwTriggerSignals,
    required this.inputValues,
    required this.outputValues,
    required this.hwTriggerValues,
    this.cameraPatterns = const [], // デフォルトは空のリスト
    required this.color,
  });
}

/// 定義済みテンプレートの一覧
class TemplateDefinitions {
  // シングルトンパターンの実装
  static final TemplateDefinitions _instance = TemplateDefinitions._internal();

  factory TemplateDefinitions() {
    return _instance;
  }

  TemplateDefinitions._internal();

  // 利用可能なテンプレート一覧
  final List<SignalTemplate> templates = [
    // デジタル通信テンプレート (SPI)
    SignalTemplate(
      name: 'SPI通信',
      inputSignals: ['SCLK', 'MOSI', 'CS', 'RESET'],
      outputSignals: ['MISO', 'READY', 'INT', 'STATUS'],
      hwTriggerSignals: ['TRIGGER_IN', 'TRIGGER_OUT'],
      inputValues: ['10MHz', '0x55AA', 'Low', 'High'],
      outputValues: ['0xAA55', 'Active', 'Rising Edge', 'OK'],
      hwTriggerValues: ['Falling Edge', 'Rising Edge'],
      // カメラパターン: 数値は各カメラのモード (1=mode1, 2=mode2, 3=mode3, 0=none)
      // 行 x カメラ の2次元配列
      cameraPatterns: [
        [1, 1, 0, 0], // row1: 最初の2カメラはmode1（入力）
        [2, 2, 0, 0], // row2: 最初の2カメラはmode2（出力）
        [3, 3, 0, 0], // row3: 最初の2カメラはmode3（HWトリガー）
        [0, 0, 1, 1], // row4: 後ろの2カメラはmode1（入力）
        [0, 0, 2, 2], // row5: 後ろの2カメラはmode2（出力）
        [0, 0, 3, 3], // row6: 後ろの2カメラはmode3（HWトリガー）
      ],
      color: Colors.blue.shade200,
    ),

    // I2C通信テンプレート
    SignalTemplate(
      name: 'I2C通信',
      inputSignals: ['SCL', 'SDA_IN', 'ENABLE', 'RESET'],
      outputSignals: ['SDA_OUT', 'ACK', 'BUSY', 'ERROR'],
      hwTriggerSignals: ['START_CONDITION', 'STOP_CONDITION'],
      inputValues: ['400kHz', 'High-Z', 'High', 'Low'],
      outputValues: ['0x7E', 'Valid', 'No', 'None'],
      hwTriggerValues: ['Detected', 'Detected'],
      // I2C用カメラパターン
      cameraPatterns: [
        [1, 2, 3, 0], // row1: カメラ1=入力, 2=出力, 3=HWトリガー
        [1, 2, 3, 0], // row2: 同様のパターン
        [0, 0, 0, 1], // row3: カメラ4は入力
        [0, 0, 0, 2], // row4: カメラ4は出力
      ],
      color: Colors.green.shade200,
    ),

    // メモリアクセステンプレート
    SignalTemplate(
      name: 'メモリアクセス',
      inputSignals: ['CLK', 'ADDR', 'DATA_IN', 'WE', 'OE', 'CS'],
      outputSignals: ['DATA_OUT', 'READY', 'DONE', 'ERROR', 'WAIT', 'VALID'],
      hwTriggerSignals: ['MEM_START', 'MEM_END'],
      inputValues: ['50MHz', '0x2000', '0xDEAD', 'Active', 'Active', 'Low'],
      outputValues: ['0xBEEF', 'High', 'High', 'Low', 'Low', 'High'],
      hwTriggerValues: ['Pulse', 'Pulse'],
      // メモリアクセス用カメラパターン（より多くの信号があるので、分散パターン）
      cameraPatterns: [
        [1, 1, 2, 2], // row1: カメラ1,2=入力, 3,4=出力
        [1, 1, 2, 2], // row2: 同様
        [1, 1, 3, 3], // row3: カメラ1,2=入力, 3,4=HWトリガー
        [2, 2, 1, 1], // row4: カメラ1,2=出力, 3,4=入力
        [2, 2, 3, 3], // row5: カメラ1,2=出力, 3,4=HWトリガー
        [3, 3, 1, 1], // row6: カメラ1,2=HWトリガー, 3,4=入力
      ],
      color: Colors.purple.shade200,
    ),
  ];

  // 名前からテンプレートを取得するメソッド
  SignalTemplate? getTemplateByName(String name) {
    try {
      return templates.firstWhere((template) => template.name == name);
    } catch (e) {
      return null;
    }
  }
}
