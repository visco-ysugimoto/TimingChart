/// HTML レポートに出せるセクション。
enum HtmlReportSection { composition, trigger, signals, camera, chart }

/// HTML レポートへ載せるセクションの選択状態。
class HtmlReportSectionSet {
  final bool composition;
  final bool trigger;
  final bool signals;
  final bool camera;
  final bool chart;

  const HtmlReportSectionSet({
    this.composition = true,
    this.trigger = true,
    this.signals = true,
    this.camera = true,
    this.chart = true,
  });

  /// 全セクションを出力する。
  static const HtmlReportSectionSet all = HtmlReportSectionSet();

  bool get hasAny => composition || trigger || signals || camera || chart;

  bool includes(HtmlReportSection section) {
    switch (section) {
      case HtmlReportSection.composition:
        return composition;
      case HtmlReportSection.trigger:
        return trigger;
      case HtmlReportSection.signals:
        return signals;
      case HtmlReportSection.camera:
        return camera;
      case HtmlReportSection.chart:
        return chart;
    }
  }

  HtmlReportSectionSet withSection(HtmlReportSection section, bool enabled) {
    switch (section) {
      case HtmlReportSection.composition:
        return copyWith(composition: enabled);
      case HtmlReportSection.trigger:
        return copyWith(trigger: enabled);
      case HtmlReportSection.signals:
        return copyWith(signals: enabled);
      case HtmlReportSection.camera:
        return copyWith(camera: enabled);
      case HtmlReportSection.chart:
        return copyWith(chart: enabled);
    }
  }

  HtmlReportSectionSet copyWith({
    bool? composition,
    bool? trigger,
    bool? signals,
    bool? camera,
    bool? chart,
  }) {
    return HtmlReportSectionSet(
      composition: composition ?? this.composition,
      trigger: trigger ?? this.trigger,
      signals: signals ?? this.signals,
      camera: camera ?? this.camera,
      chart: chart ?? this.chart,
    );
  }

  /// SharedPreferences へ保存する ID 一覧。
  List<String> toPrefIds() {
    return [
      for (final section in HtmlReportSection.values)
        if (includes(section)) section.name,
    ];
  }

  /// 未保存・空のときは全選択。未知の ID は無視する。
  static HtmlReportSectionSet fromPrefIds(List<String>? ids) {
    if (ids == null || ids.isEmpty) return all;
    final known = HtmlReportSection.values.map((e) => e.name).toSet();
    if (!ids.any(known.contains)) return all;
    return HtmlReportSectionSet(
      composition: ids.contains(HtmlReportSection.composition.name),
      trigger: ids.contains(HtmlReportSection.trigger.name),
      signals: ids.contains(HtmlReportSection.signals.name),
      camera: ids.contains(HtmlReportSection.camera.name),
      chart: ids.contains(HtmlReportSection.chart.name),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is HtmlReportSectionSet &&
        other.composition == composition &&
        other.trigger == trigger &&
        other.signals == signals &&
        other.camera == camera &&
        other.chart == chart;
  }

  @override
  int get hashCode => Object.hash(composition, trigger, signals, camera, chart);
}
