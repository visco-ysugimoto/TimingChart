/// 出力割り当て情報を保持するモデルクラス
class OutputAssignment {
  final String name;
  final String suggestionId;
  final int portNo0;
  final int outputIndex1Based;

  const OutputAssignment({
    required this.name,
    required this.suggestionId,
    required this.portNo0,
    required this.outputIndex1Based,
  });
}

