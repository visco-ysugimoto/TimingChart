import 'package:flutter/material.dart';

class FormControllersNotifier extends ChangeNotifier {
  FormControllersNotifier()
    : _inputControllers = <TextEditingController>[],
      _plcEipInputControllers = <TextEditingController>[],
      _outputControllers = <TextEditingController>[],
      _plcEipOutputControllers = <TextEditingController>[],
      _hwTriggerControllers = <TextEditingController>[];

  List<TextEditingController> _inputControllers;
  List<TextEditingController> _outputControllers;
  // PLC/EIP 用の出力コントローラ（DIOとは別管理）
  List<TextEditingController> _plcEipOutputControllers;
  List<TextEditingController> _hwTriggerControllers;
  // PLC/EIP 用の入力コントローラ（DIOとは別管理）
  List<TextEditingController> _plcEipInputControllers;

  List<TextEditingController> get inputControllers => _inputControllers;
  List<TextEditingController> get outputControllers => _outputControllers;
  List<TextEditingController> get plcEipOutputControllers =>
      _plcEipOutputControllers;
  List<TextEditingController> get hwTriggerControllers => _hwTriggerControllers;
  List<TextEditingController> get plcEipInputControllers =>
      _plcEipInputControllers;

  void initialize({
    required int inputCount,
    required int outputCount,
    required int hwTriggerCount,
  }) {
    _disposeControllers(_inputControllers);
    _disposeControllers(_plcEipInputControllers);
    _disposeControllers(_outputControllers);
    _disposeControllers(_plcEipOutputControllers);
    _disposeControllers(_hwTriggerControllers);

    _inputControllers = List.generate(
      inputCount,
      (_) => TextEditingController(),
    );
    _plcEipInputControllers = List.generate(
      inputCount,
      (_) => TextEditingController(),
    );
    _outputControllers = List.generate(
      outputCount,
      (_) => TextEditingController(),
    );
    _plcEipOutputControllers = List.generate(
      outputCount,
      (_) => TextEditingController(),
    );
    _hwTriggerControllers = List.generate(
      hwTriggerCount,
      (_) => TextEditingController(),
    );
  }

  void setInputCount(int count) {
    _resizeControllers(_inputControllers, count);
    _resizeControllers(_plcEipInputControllers, count);
  }

  void setOutputCount(int count) {
    _resizeControllers(_outputControllers, count);
    _resizeControllers(_plcEipOutputControllers, count);
  }

  void setHwTriggerCount(int count) {
    _resizeControllers(_hwTriggerControllers, count);
  }

  void clearAllTexts() {
    for (final controller in _inputControllers) {
      controller.clear();
    }
    for (final controller in _plcEipInputControllers) {
      controller.clear();
    }
    for (final controller in _outputControllers) {
      controller.clear();
    }
    for (final controller in _plcEipOutputControllers) {
      controller.clear();
    }
    for (final controller in _hwTriggerControllers) {
      controller.clear();
    }
  }

  void setInputTexts(List<String> values) {
    _assignTexts(_inputControllers, values.asMap());
  }

  void assignInputTexts(Map<int, String> assignments) {
    _assignTexts(_inputControllers, assignments);
  }

  void setPlcEipInputTexts(List<String> values) {
    _assignTexts(_plcEipInputControllers, values.asMap());
  }

  void assignPlcEipInputTexts(Map<int, String> assignments) {
    _assignTexts(_plcEipInputControllers, assignments);
  }

  void setOutputTexts(List<String> values) {
    _assignTexts(_outputControllers, values.asMap());
  }

  void setPlcEipOutputTexts(List<String> values) {
    _assignTexts(_plcEipOutputControllers, values.asMap());
  }

  void setHwTriggerTexts(List<String> values) {
    _assignTexts(_hwTriggerControllers, values.asMap());
  }

  void setInputText(int index, String value) {
    _setText(_inputControllers, index, value);
  }

  void setPlcEipInputText(int index, String value) {
    _setText(_plcEipInputControllers, index, value);
  }

  void setOutputText(int index, String value) {
    _setText(_outputControllers, index, value);
  }

  void setPlcEipOutputText(int index, String value) {
    _setText(_plcEipOutputControllers, index, value);
  }

  void setHwTriggerText(int index, String value) {
    _setText(_hwTriggerControllers, index, value);
  }

  bool _resizeControllers(List<TextEditingController> list, int target) {
    if (target < 0 || list.length == target) return false;

    if (list.length > target) {
      for (int i = target; i < list.length; i++) {
        list[i].dispose();
      }
      list.removeRange(target, list.length);
      return true;
    }

    list.addAll(
      List.generate(target - list.length, (_) => TextEditingController()),
    );
    return true;
  }

  bool _assignTexts(
    List<TextEditingController> controllers,
    Map<int, String> values,
  ) {
    bool changed = false;
    values.forEach((index, value) {
      if (_setText(controllers, index, value)) {
        changed = true;
      }
    });
    return changed;
  }

  bool _setText(
    List<TextEditingController> controllers,
    int index,
    String value,
  ) {
    if (index < 0 || index >= controllers.length) return false;
    final controller = controllers[index];
    if (controller.text == value) return false;
    controller.text = value;
    return true;
  }

  void _disposeControllers(List<TextEditingController> list) {
    for (final controller in list) {
      controller.dispose();
    }
  }

  @override
  void dispose() {
    _disposeControllers(_inputControllers);
    _disposeControllers(_plcEipInputControllers);
    _disposeControllers(_outputControllers);
    _disposeControllers(_plcEipOutputControllers);
    _disposeControllers(_hwTriggerControllers);
    super.dispose();
  }
}
