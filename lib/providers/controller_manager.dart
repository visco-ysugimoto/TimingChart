import 'package:flutter/material.dart';

/// 入力／出力／HW Trigger の TextEditingController を集中管理するプロバイダ
class ControllerManager extends ChangeNotifier {
  ControllerManager() {
    init(inputs: 32, outputs: 32, hw: 0);
  }

  List<TextEditingController> inputs = [];
  List<TextEditingController> outputs = [];
  List<TextEditingController> hwTriggers = [];

  void init({required int inputs, required int outputs, required int hw}) {
    _disposeAll();
    this.inputs = List.generate(inputs, (_) => TextEditingController());
    this.outputs = List.generate(outputs, (_) => TextEditingController());
    this.hwTriggers = List.generate(hw, (_) => TextEditingController());
    notifyListeners();
  }

  void resizeInputs(int count) {
    _resizeList(this.inputs, count);
    notifyListeners();
  }

  void resizeOutputs(int count) {
    _resizeList(this.outputs, count);
    notifyListeners();
  }

  void resizeHwTriggers(int count) {
    _resizeList(this.hwTriggers, count);
    notifyListeners();
  }

  void _resizeList(List<TextEditingController> list, int target) {
    if (list.length > target) {
      for (int i = target; i < list.length; i++) {
        list[i].dispose();
      }
      list.removeRange(target, list.length);
    } else if (list.length < target) {
      list.addAll(
        List.generate(target - list.length, (_) => TextEditingController()),
      );
    }
  }

  void _disposeAll() {
    for (final c in [...inputs, ...outputs, ...hwTriggers]) {
      c.dispose();
    }
    inputs.clear();
    outputs.clear();
    hwTriggers.clear();
  }

  @override
  void dispose() {
    _disposeAll();
    super.dispose();
  }
}
