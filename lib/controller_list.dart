// controller_list.dart の build メソッドを一時的に変更

import 'package:flutter/material.dart';
import 'common_padding.dart'; // 一時的に使わない

class ControllerList extends StatelessWidget {
  final List<TextEditingController> controllers;
  final String labelPrefix;

  const ControllerList({
    super.key,
    required this.controllers,
    required this.labelPrefix,
  });

  @override
  Widget build(BuildContext context) {
    debugPrint(
      "Building ControllerList with ${controllers.length} items.",
    ); // ★ログ追加

    // ★★★ TextFieldの代わりに単純なTextウィジェットを表示 ★★★
    List<Widget> textWidgets = [];
    for (int index = 0; index < controllers.length; index++) {
      textWidgets.add(
        Padding(
          // CommonPaddingの代わりにシンプルなPaddingを使用
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Text('$labelPrefix ${index + 1}: Controller exists'), // 存在確認だけ
        ),
      );
    }
    // ListView.builderの代わりに単純なColumnで表示
    /*return Column(
      crossAxisAlignment: CrossAxisAlignment.start, // 元のFormTabのColumnに合わせる
      children: textWidgets,
    );*/
    // ★★★ ここまで変更 ★★★

    // --- 元のコード ---
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: controllers.length,
      itemBuilder: (context, index) {
        return CommonPadding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controllers[index],
            builder: (context, value, child) {
              return Container(
                color:
                    value.text.isNotEmpty
                        ? Colors.lightBlueAccent.withOpacity(0.2)
                        : Colors.white,
                child: TextField(
                  controller: controllers[index],
                  decoration: InputDecoration(
                    labelText: '$labelPrefix ${index + 1}',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.transparent,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
    //--- 元のコードここまで --- */
  }
}
