import 'package:flutter/material.dart';

/// テンプレート定義を管理するクラス
class SignalTemplate {
  final String name;
  final List<String> inputSignals;
  final List<String> outputSignals;
  final List<String> hwTriggerSignals;
  final Color color;

  const SignalTemplate({
    required this.name,
    required this.inputSignals,
    required this.outputSignals,
    required this.hwTriggerSignals,
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
      color: Colors.blue.shade200,
    ),

    // I2C通信テンプレート
    SignalTemplate(
      name: 'I2C通信',
      inputSignals: ['SCL', 'SDA_IN', 'ENABLE', 'RESET'],
      outputSignals: ['SDA_OUT', 'ACK', 'BUSY', 'ERROR'],
      hwTriggerSignals: ['START_CONDITION', 'STOP_CONDITION'],
      color: Colors.green.shade200,
    ),

    // メモリアクセステンプレート
    SignalTemplate(
      name: 'メモリアクセス',
      inputSignals: ['CLK', 'ADDR', 'DATA_IN', 'WE', 'OE', 'CS'],
      outputSignals: ['DATA_OUT', 'READY', 'DONE', 'ERROR', 'WAIT', 'VALID'],
      hwTriggerSignals: ['MEM_START', 'MEM_END'],
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
