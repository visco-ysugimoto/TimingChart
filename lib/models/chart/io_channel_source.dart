enum IoChannelSource { dio, plc, eip, plcEip, unknown }

extension IoChannelSourceX on IoChannelSource {
  bool get isPlcLike =>
      this == IoChannelSource.plc || this == IoChannelSource.plcEip;

  bool get isEipLike =>
      this == IoChannelSource.eip || this == IoChannelSource.plcEip;
}
